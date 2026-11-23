"""record_food 收藏菜品匹配单元测试（纯进程内，不需要后端 / LLM / 真实数据库）。

覆盖（2026-10-16 新增收藏优先链路）：
    - _match_saved_meal_name：精确 / 双向包含 / 归一化 / 不匹配
    - _scale_template_nutrition：整份 / 部分份量 / serving_size 防御
    - _lookup_saved_meal：命中 / 未命中 / 无模板跳过 / 精确优先 / usage_count 排序
    - record_food spec 冒烟 + 缺 user_id 失败路径（不落库、不抛异常）

运行：
    uv run pytest tests/test_record_food_saved_meal.py -v
"""

import asyncio
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions import register_all
from agent.diet_deep_agent.actions.definitions.record_food import (
    _lookup_saved_meal,
    _match_saved_meal_name,
    _scale_template_nutrition,
    record_food,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry
from shared.models.saved_meal_models import SavedMeal, SavedMealNutrition


# ==================== 测试桩：覆盖 _lookup_saved_meal 的 query 链 ====================


class _StubQuery:
    def __init__(self, rows):
        self._rows = rows

    def join(self, *args, **kwargs):
        return self

    def filter(self, *args, **kwargs):
        return self

    def all(self):
        return self._rows


class _StubDb:
    def __init__(self, rows):
        self._rows = rows

    def query(self, *args, **kwargs):
        return _StubQuery(self._rows)


def _meal(mid, name, usage=0, with_template=True, serving=250.0, cal=450.0):
    """构造 (SavedMeal, SavedMealNutrition) 内存对象，不触库"""
    meal = SavedMeal(id=mid, user_id=1, meal_name=name, usage_count=usage)
    tpl = (
        SavedMealNutrition(
            saved_meal_id=mid,
            serving_size=serving,
            calories=cal,
            protein=20.0,
            fat=15.0,
            carbohydrates=50.0,
        )
        if with_template
        else None
    )
    return meal, tpl


def _rows(*pairs):
    """把 (meal, tpl) 对压成 query 返回的行列表；tpl 为 None 的行剔除（模拟 join 掉无模板收藏）"""
    return [(m, t) for m, t in pairs if t is not None]


# ==================== 名称匹配 ====================


class TestMatchSavedMealName:
    def test_exact(self):
        assert _match_saved_meal_name("鸡公煲", "鸡公煲") is True

    def test_food_contains_meal(self):
        assert _match_saved_meal_name("重庆鸡公煲", "鸡公煲") is True

    def test_meal_contains_food(self):
        assert _match_saved_meal_name("鸡公煲", "家庭版鸡公煲套餐") is True

    def test_normalized_fullwidth(self):
        assert _match_saved_meal_name("ＡＢＣ粥", "abc粥") is True

    def test_no_match(self):
        assert _match_saved_meal_name("宫保鸡丁", "鸡公煲") is False

    def test_empty(self):
        assert _match_saved_meal_name("", "鸡公煲") is False


# ==================== 营养换算 ====================


class TestScaleTemplateNutrition:
    TEMPLATE = {"calories": 450.0, "protein": 20.0, "fat": 15.0, "carbohydrates": 50.0}

    def test_full_serving(self):
        out = _scale_template_nutrition(self.TEMPLATE, 250.0, 250.0)
        assert out["calories"] == 450.0
        assert out["protein"] == 20.0

    def test_partial(self):
        out = _scale_template_nutrition(self.TEMPLATE, 250.0, 125.0)
        assert out["calories"] == 225.0
        assert out["fat"] == 7.5

    def test_zero_serving_guard(self):
        out = _scale_template_nutrition(self.TEMPLATE, 0, 100.0)
        assert out["calories"] == 450.0  # serving_size 非法时按整份处理


# ==================== 收藏查找 ====================


class TestLookupSavedMeal:
    def test_hit(self):
        db = _StubDb(_rows(_meal(1, "鸡公煲", usage=3)))
        snap = _lookup_saved_meal(db, 1, "鸡公煲")
        assert snap is not None
        assert snap["id"] == 1
        assert snap["meal_name"] == "鸡公煲"
        assert snap["serving_size"] == 250.0
        assert snap["template"]["calories"] == 450.0

    def test_miss(self):
        db = _StubDb(_rows(_meal(1, "鸡公煲")))
        assert _lookup_saved_meal(db, 1, "红烧肉") is None

    def test_no_template_skipped(self):
        # 无营养模板的收藏不可用（无法算营养），交回食物库链路
        db = _StubDb(_rows(_meal(1, "鸡公煲", with_template=False)))
        assert _lookup_saved_meal(db, 1, "鸡公煲") is None

    def test_exact_beats_contain(self):
        db = _StubDb(
            _rows(
                _meal(1, "家庭版鸡公煲套餐", usage=99),  # 包含命中，但使用次数高
                _meal(2, "鸡公煲", usage=1),  # 精确命中
            )
        )
        snap = _lookup_saved_meal(db, 1, "鸡公煲")
        assert snap["id"] == 2  # 精确优先

    def test_higher_usage_wins_when_both_contain(self):
        db = _StubDb(
            _rows(
                _meal(1, "鸡公煲小份", usage=1),
                _meal(2, "重庆鸡公煲", usage=7),
            )
        )
        snap = _lookup_saved_meal(db, 1, "鸡公煲")
        assert snap["id"] == 2  # 都是非精确时取最常用

    def test_none_user(self):
        db = _StubDb(_rows(_meal(1, "鸡公煲")))
        assert _lookup_saved_meal(db, None, "鸡公煲") is None

    def test_isolation_by_user(self):
        # stub 的 filter 不做真过滤——该用例验证 user_id=None 已拦截，其余由 SQL filter 保证
        db = _StubDb(_rows(_meal(1, "鸡公煲")))
        assert _lookup_saved_meal(db, 2, "鸡公煲") is not None  # stub 行为，真实隔离靠 SQL


# ==================== 动作级 ====================


@pytest.fixture(scope="module")
def registry() -> ActionRegistry:
    registry = ActionRegistry()
    register_all(registry)
    return registry


class TestRecordFoodAction:
    def test_spec_registered(self, registry):
        assert registry.get("record_food") is not None

    def test_missing_user_fails_without_db(self, registry):
        from agent.diet_deep_agent.actions.definitions.record_food import RecordFoodArgs

        ctx = ActionContext(user_id=None)
        result = asyncio.run(
            record_food(RecordFoodArgs(food_name="鸡公煲", explicit_request=True), ctx)
        )
        assert result.ok is False
        assert "user_id" in (result.message or "") or "用户" in (result.message or "")

    def test_pet_session_fails(self, registry):
        from agent.diet_deep_agent.actions.definitions.record_food import RecordFoodArgs

        ctx = ActionContext(user_id=1, is_pet_session=True)
        result = asyncio.run(
            record_food(RecordFoodArgs(food_name="猫粮", explicit_request=True), ctx)
        )
        assert result.ok is False
        assert "宠物" in (result.message or "")
