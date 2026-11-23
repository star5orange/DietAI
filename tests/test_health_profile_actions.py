"""健康档案类写动作单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - health_profile_common 的三个纯函数（名称归一 / 双向包含匹配 / 目标区间校验）
    - 5 个动作的 spec 元数据冒烟（always_confirm / undoable / sessions / 内部参数）
    - 各动作在缺少 user_id 或入参非法时返回失败（不落库、不抛异常）

运行：
    uv run pytest tests/test_health_profile_actions.py -v
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
from agent.diet_deep_agent.actions.definitions.health_profile_common import (
    MAX_TARGET_CALORIES,
    MAX_WATER_GOAL_ML,
    MIN_TARGET_CALORIES,
    MIN_WATER_GOAL_ML,
    match_indices_by_name,
    normalize_name,
    validate_targets,
)
from agent.diet_deep_agent.actions.definitions.mark_disease_recovered import (
    MarkDiseaseRecoveredArgs,
)
from agent.diet_deep_agent.actions.definitions.mark_disease_recovered import (
    mark_disease_recovered,
)
from agent.diet_deep_agent.actions.definitions.record_allergy import (
    RecordAllergyArgs,
    record_allergy,
)
from agent.diet_deep_agent.actions.definitions.record_disease import (
    RecordDiseaseArgs,
    record_disease,
)
from agent.diet_deep_agent.actions.definitions.record_exercise import (
    RecordExerciseArgs,
    record_exercise,
)
from agent.diet_deep_agent.actions.definitions.set_health_target import (
    SetHealthTargetArgs,
    set_health_target,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import ActionKind, CardType

HEALTH_PROFILE_ACTIONS = {
    "record_exercise",
    "record_disease",
    "mark_disease_recovered",
    "record_allergy",
    "set_health_target",
}


@pytest.fixture(scope="module")
def registry() -> ActionRegistry:
    registry = ActionRegistry()
    register_all(registry)
    return registry


# ==================== 纯函数 ====================


class TestNormalizeName:
    def test_strips_and_lowercases(self):
        assert normalize_name("  Penicillin  ") == "penicillin"

    def test_removes_inner_spaces(self):
        assert normalize_name("腕部 骨折") == "腕部骨折"

    def test_none_and_empty(self):
        assert normalize_name(None) == ""
        assert normalize_name("   ") == ""


class TestMatchIndicesByName:
    def test_exact_unique_hit(self):
        assert match_indices_by_name(["腕部骨折", "高血压"], "腕部骨折") == [0]

    def test_substring_both_directions(self):
        # 用户说「骨折」，档案里写「腕部骨折」→ 命中
        assert match_indices_by_name(["腕部骨折"], "骨折") == [0]
        # 反向也命中（用户说得更具体）
        assert match_indices_by_name(["骨折"], "左腕骨折") == [0]

    def test_multiple_hits_preserve_order(self):
        candidates = ["腕部骨折", "踝部骨折", "高血压"]
        assert match_indices_by_name(candidates, "骨折") == [0, 1]

    def test_no_hit(self):
        assert match_indices_by_name(["高血压"], "骨折") == []

    def test_ignores_empty_query_and_candidates(self):
        assert match_indices_by_name(["高血压"], "") == []
        assert match_indices_by_name(["", "高血压"], "高血压") == [1]

    def test_case_and_space_insensitive(self):
        assert match_indices_by_name([" Penicillin "], "penicillin") == [0]


class TestValidateTargets:
    def test_both_missing(self):
        assert validate_targets(None, None) is not None

    def test_calories_only_ok(self):
        assert validate_targets(1800, None) is None

    def test_water_only_ok(self):
        assert validate_targets(None, 2500) is None

    @pytest.mark.parametrize(
        "calories",
        [MIN_TARGET_CALORIES - 1, MAX_TARGET_CALORIES + 1],
    )
    def test_calories_out_of_range(self, calories: int):
        assert validate_targets(calories, None) is not None

    @pytest.mark.parametrize(
        "water",
        [MIN_WATER_GOAL_ML - 1, MAX_WATER_GOAL_ML + 1],
    )
    def test_water_out_of_range(self, water: int):
        assert validate_targets(None, water) is not None

    def test_boundaries_ok(self):
        assert validate_targets(MIN_TARGET_CALORIES, None) is None
        assert validate_targets(None, MAX_WATER_GOAL_ML) is None


# ==================== spec 元数据 ====================


class TestHealthProfileSpecs:
    @pytest.mark.parametrize("name", sorted(HEALTH_PROFILE_ACTIONS))
    def test_common_metadata(self, registry: ActionRegistry, name: str):
        spec = registry.get(name)
        assert spec is not None, name
        assert spec.kind is ActionKind.WRITE, name
        assert spec.requires_confirmation is True, name
        assert spec.undoable is True, name
        assert spec.card_type is CardType.ACTION_CONFIRM, name
        # 人域专属：宠物会话的能力集精确等于 3 个宠物动作（D18 红线）
        assert spec.sessions == ("human",), name

    def test_confirmed_by_user_only_on_always_confirm(self, registry: ActionRegistry):
        for spec in registry.all():
            if spec.name not in HEALTH_PROFILE_ACTIONS:
                continue
            has_field = "confirmed_by_user" in spec.args_schema.model_fields
            assert has_field is spec.always_confirm, spec.name


# ==================== 缺上下文 / 非法入参（不落库、不抛异常） ====================


def _ctx(user_id=None, input_channel: str = "app") -> ActionContext:
    return ActionContext(user_id=user_id, input_channel=input_channel)


class TestFailurePaths:
    """仅覆盖"进不到写库分支"的路径，避免依赖真实数据库"""

    def test_missing_user_id(self):
        cases = [
            (record_exercise, RecordExerciseArgs(exercise_type="跑步", duration_minutes=30)),
            (record_disease, RecordDiseaseArgs(disease_name="骨折")),
            (mark_disease_recovered, MarkDiseaseRecoveredArgs(disease_name="骨折")),
            (record_allergy, RecordAllergyArgs(allergen_name="青霉素", allergen_type=2)),
            (set_health_target, SetHealthTargetArgs(target_calories=1800)),
        ]
        for handler, params in cases:
            result = asyncio.run(handler(params, _ctx(user_id=None)))
            assert result.ok is False, handler.__name__
            assert "user_id" in (result.error or ""), handler.__name__

    def test_empty_name_rejected(self):
        cases = [
            (record_exercise, RecordExerciseArgs(exercise_type="  ", duration_minutes=30)),
            (record_disease, RecordDiseaseArgs(disease_name="  ")),
            (mark_disease_recovered, MarkDiseaseRecoveredArgs(disease_name="  ")),
            (record_allergy, RecordAllergyArgs(allergen_name="  ", allergen_type=1)),
        ]
        for handler, params in cases:
            result = asyncio.run(handler(params, _ctx(user_id=1)))
            assert result.ok is False, handler.__name__

    def test_exercise_needs_duration_or_distance(self):
        result = asyncio.run(
            record_exercise(RecordExerciseArgs(exercise_type="跑步"), _ctx(user_id=1))
        )
        assert result.ok is False
        assert "时长" in (result.error or "") or "距离" in (result.error or "")

    def test_target_out_of_range_rejected(self):
        result = asyncio.run(
            set_health_target(SetHealthTargetArgs(target_calories=100), _ctx(user_id=1))
        )
        assert result.ok is False
        assert "热量目标" in (result.error or "")

    def test_pet_session_rejected(self):
        ctx = ActionContext(user_id=1, is_pet_session=True)
        result = asyncio.run(
            record_disease(RecordDiseaseArgs(disease_name="骨折"), ctx)
        )
        assert result.ok is False
        assert "宠物" in (result.error or "")