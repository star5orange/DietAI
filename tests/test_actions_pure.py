"""动作层纯函数单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - record_food：餐次推断 _infer_meal_type（PRD 4.7 时间归属，含夜宵 5 的边界）、
      关键词餐次表、时间归一化 _parse_record_time、营养份量缩放 _scale_nutrition
    - pending：模糊量词检测（长量词优先）+ 待确认卡结构（PRD 4.3/D5）
    - undo_journal：撤销凭证序列化往返、10 分钟窗口边界、Redis 降级内存路径（PRD 4.5）
    - query_family：称谓同义组归一（含「姑妈」不被「妈」抢占的顺序敏感断言）
    - context：运行期上下文解析（user_id / 老人线渠道 PRD 4.9/D13）
    - spec：ActionResult 序列化与 failure 构造

运行：
    uv run pytest tests/test_actions_pure.py -v
"""

import json
import sys
from datetime import datetime, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.actions.context import ActionContext, ELDER_CHANNELS
from agent.diet_deep_agent.actions.definitions import query_family
from agent.diet_deep_agent.actions.definitions.record_food import (
    _infer_meal_type,
    _parse_meal_type,
    _parse_record_time,
    _scale_nutrition,
)
from agent.diet_deep_agent.actions.definitions.record_water import (
    WATER_QUANTIFIERS,
)
from agent.diet_deep_agent.actions.definitions.record_food import (
    FOOD_QUANTIFIERS,
)
from agent.diet_deep_agent.actions.pending import (
    build_options,
    build_pending_card,
    detect_quantifier,
)
from agent.diet_deep_agent.actions.spec import ActionResult, CardType
import agent.diet_deep_agent.actions.undo_journal  # noqa: F401  确保子模块已加载
from agent.diet_deep_agent.actions.undo_journal import (
    UNDO_TTL_SECONDS,
    UndoEntry,
    UndoJournal,
    _key,
)

# 注意：actions/__init__.py 导出了同名「单例实例」，包属性会遮蔽子模块，
# 因此必须从 sys.modules 取真正的模块对象（monkeypatch 才能改到模块级开关）
undo_journal_module = sys.modules["agent.diet_deep_agent.actions.undo_journal"]


class TestInferMealType:
    """PRD 4.7 时间归属 + 夜宵边界（前端 camera/home 已对齐此口径）"""

    @pytest.mark.parametrize(
        "hour,expected",
        [
            (4, 5),  # 凌晨 → 夜宵
            (5, 1),  # 早餐起点
            (9, 1),
            (10, 2),  # 午餐起点
            (14, 2),
            (15, 4),  # 加餐起点
            (16, 4),
            (17, 3),  # 晚餐起点
            (20, 3),  # 20:34 的冒菜应归晚餐
            (21, 5),  # 夜宵起点
            (23, 5),
            (2, 5),
        ],
    )
    def test_hour_boundaries(self, hour: int, expected: int):
        assert _infer_meal_type(datetime(2026, 9, 20, hour, 0)) == expected


class TestParseMealType:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("1", 1),
            ("5", 5),
            ("午饭", 2),
            ("夜宵", 5),
            ("宵夜", 5),
            ("下午茶", 4),
            ("我午餐吃了", 2),  # 关键词包含匹配
            ("", None),
            (None, None),
            ("随便", None),
            ("9", None),  # 数字越界
        ],
    )
    def test_parse(self, raw, expected):
        assert _parse_meal_type(raw) == expected


class TestParseRecordTime:
    def test_iso_string(self):
        assert _parse_record_time("2026-09-20 12:30:00").hour == 12

    def test_hhmm_gets_today(self):
        result = _parse_record_time("12:30")
        assert result.hour == 12
        assert result.minute == 30
        assert result.date() == datetime.now().date()

    def test_none_defaults_to_now(self):
        before = datetime.now()
        result = _parse_record_time(None)
        assert before <= result <= datetime.now() + timedelta(seconds=5)

    def test_garbage_defaults_to_now(self):
        before = datetime.now()
        result = _parse_record_time("不是时间的东西")
        assert before <= result <= datetime.now() + timedelta(seconds=5)


class TestScaleNutrition:
    def test_100g_unchanged(self):
        per100 = {"calories": 200.0, "protein": 12.0}
        assert _scale_nutrition(per100, 100.0) == {"calories": 200.0, "protein": 12.0}

    def test_scaled_and_rounded(self):
        result = _scale_nutrition({"calories": 185.0, "protein": 13.0}, 250.0)
        assert result["calories"] == 462.5
        assert result["protein"] == 32.5

    def test_rounding(self):
        # 185 * 0.55 = 101.75 → round 2 位
        assert _scale_nutrition({"calories": 185.0}, 55.0)["calories"] == 101.75


class TestQuantifierDetection:
    """顺序敏感：长量词必须先命中（PRD 4.3 / D5）"""

    def test_water_long_first(self):
        # 「小半杯」不能被「杯」抢先
        q = detect_quantifier(WATER_QUANTIFIERS, "我喝了小半杯水")
        assert q is not None and q[0] == "小半杯"

    def test_water_bottle(self):
        q = detect_quantifier(WATER_QUANTIFIERS, "我刚喝了一瓶水")
        assert q is not None and q[0] == "一瓶"
        assert q[2] == (500, 550)  # 快捷选项

    def test_food_long_first(self):
        q = detect_quantifier(FOOD_QUANTIFIERS, "吃了一大碗面")
        assert q is not None and q[0] == "一大碗"

    def test_food_bowl_default(self):
        q = detect_quantifier(FOOD_QUANTIFIERS, "吃了一碗饭")
        assert q is not None and q[0] == "一碗"
        assert q[2] == (100, 150, 200)
        assert q[3] == 150  # 老人线默认值

    def test_no_quantifier_returns_none(self):
        assert detect_quantifier(WATER_QUANTIFIERS, "帮我记录：喝了 300 毫升水") is None

    def test_none_text(self):
        assert detect_quantifier(FOOD_QUANTIFIERS, None) is None


class TestPendingCard:
    def test_options_end_with_other(self):
        options = build_options((500, 550), "ml")
        assert [o["label"] for o in options] == ["500ml", "550ml", "其他"]
        assert options[-1]["value"] is None  # 「其他」让用户自己输

    def test_build_pending_card_structure(self):
        result = build_pending_card(
            action="record_water",
            field="amount_ml",
            question="一瓶水大概是 500ml 还是 550ml？",
            pair=(500, 550),
            unit="ml",
            params={"drink_type": "水"},
        )
        assert result.ok is True
        assert result.card_type is CardType.PENDING_CONFIRM
        assert result.data["action"] == "record_water"
        assert result.data["field"] == "amount_ml"
        assert result.data["params"] == {"drink_type": "水"}
        assert len(result.data["options"]) == 3


class TestUndoJournal:
    """PRD 4.5：仅最近一条 + 10 分钟窗口。monkeypatch 走内存降级路径，不碰真实 Redis"""

    @pytest.fixture
    def journal(self, monkeypatch):
        monkeypatch.setattr(undo_journal_module, "_redis_disabled", True)  # 强制内存降级
        undo_journal_module._memory_store.clear()
        yield undo_journal_module.undo_journal
        undo_journal_module._memory_store.clear()

    def _entry(self, token: str, created_at=None) -> UndoEntry:
        return UndoEntry(
            action="record_water",
            undo_token=token,
            summary=f"记录 {token}",
            created_at=created_at or datetime.now().timestamp(),
        )

    @pytest.mark.asyncio
    async def test_push_peek_clear(self, journal):
        await journal.push(999001, self._entry("9001"))
        entry = await journal.peek(999001)
        assert entry is not None and entry.undo_token == "9001"
        await journal.clear(999001)
        assert await journal.peek(999001) is None

    @pytest.mark.asyncio
    async def test_overwrite_keeps_latest_only(self, journal):
        """覆盖式写入：新写操作顶掉上一条的撤销凭证（仅最近一条可撤销）"""
        await journal.push(999002, self._entry("A"))
        await journal.push(999002, self._entry("B"))
        entry = await journal.peek(999002)
        assert entry.undo_token == "B"

    def test_expiry_boundary(self):
        fresh = self._entry("x", created_at=datetime.now().timestamp() - (UNDO_TTL_SECONDS - 5))
        stale = self._entry("x", created_at=datetime.now().timestamp() - (UNDO_TTL_SECONDS + 5))
        assert fresh.is_expired() is False
        assert stale.is_expired() is True

    def test_key_format(self):
        assert _key(42) == "dietai:undo:42"

    def test_entry_roundtrip(self):
        entry = UndoEntry(
            action="record_weight",
            undo_token="77",
            summary="体重 70.5kg",
            created_at=1234567890.0,
            payload={"profile_weight": 70.5},
        )
        clone = UndoEntry.from_dict(entry.to_dict())
        assert clone == entry


class TestFamilyRelationMatch:
    """称谓同义组归一（「我妈」↔「母亲/妈妈」）；顺序敏感防「姑妈」被「妈」抢占"""

    def test_canonical_mother(self):
        assert query_family._canonical_relation("我妈") == "妈"
        assert query_family._canonical_relation("母亲") == "妈"
        assert query_family._canonical_relation("老妈") == "妈"

    def test_aunt_not_grabbed_by_mother(self):
        # 「姑妈」含「妈」字，但更具体的同义组排在前面
        assert query_family._canonical_relation("姑妈") == "姑妈"
        assert query_family._canonical_relation("姨妈") == "姨妈"

    def test_non_relation_returns_none(self):
        assert query_family._canonical_relation("小明") is None
        assert query_family._canonical_relation(None) is None
        assert query_family._canonical_relation("") is None

    def test_match_member_by_note(self):
        # 登记称谓「母亲」，用户说「我妈」→ 同义组命中
        assert query_family._match_member("我妈", "王秀兰", "母亲", "famB5690") is True

    def test_match_member_by_name(self):
        assert query_family._match_member("秀兰", "王秀兰", None, "famB5690") is True

    def test_match_member_empty_spoken_returns_all(self):
        # 用户没指定家人 → 不过滤（返回全部家人）
        assert query_family._match_member(None, "王秀兰", "母亲", "famB5690") is True

    def test_match_member_no_match(self):
        assert query_family._match_member("我爸", "王秀兰", "母亲", "famB5690") is False


class TestActionContext:
    def test_from_config(self):
        ctx = ActionContext.from_config(
            {"configurable": {"user_id": "78", "thread_id": "t1", "is_pet_session": True}}
        )
        assert ctx.user_id == 78  # str → int
        assert ctx.thread_id == "t1"
        assert ctx.is_pet_session is True
        assert ctx.input_channel == "app"  # 默认渠道

    def test_elder_channel(self):
        """D13：硬件语音走默认值记录，不追问"""
        ctx = ActionContext.from_config(
            {"configurable": {"user_id": "79", "input_channel": "hardware"}}
        )
        assert ctx.is_elder_channel is True
        assert "hardware" in ELDER_CHANNELS
        assert ActionContext.from_config({}).is_elder_channel is False

    def test_invalid_user_id_becomes_none(self):
        ctx = ActionContext.from_config({"configurable": {"user_id": "not-a-number"}})
        assert ctx.user_id is None


class TestActionResult:
    def test_to_tool_output_roundtrip(self):
        result = ActionResult(
            ok=True,
            action="query_today",
            card_type=CardType.DAILY_SUMMARY,
            message="今日汇总",
            data={"date": "2026-09-20"},
            undo_token="t1",
        )
        payload = json.loads(result.to_tool_output())
        assert payload["ok"] is True
        assert payload["card_type"] == "daily_summary"
        assert payload["data"]["date"] == "2026-09-20"
        assert payload["undo_token"] == "t1"

    def test_failure_defaults_message_to_error(self):
        result = ActionResult.failure("undo", "没有可撤销的记录")
        assert result.ok is False
        assert result.message == "没有可撤销的记录"
        assert result.error == "没有可撤销的记录"
