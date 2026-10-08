"""动作注册表元数据单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - 全部动作注册（V5.1 一期 6 + V5.2 二期 9 + 引导卡 1 + V6 健康档案 5 = 21）
    - 表驱动元数据断言（kind / card_type / requires_confirmation / undoable / sessions）
    - PRD 合规：4.2 写操作需授权、4.5 undoable 与 UNDOABLE_ACTIONS 双向一致
    - always_confirm 动作必须带 confirmed_by_user 内部参数（只能由确认凭证回填）
    - D18/D3 域隔离：宠物 prompt 工具集精确等于 {record_pet_feeding, query_pet, undo}
    - System Prompt 授权规则段关键词存在

运行：
    uv run pytest tests/test_actions_meta.py -v
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.actions import registry as registry_module
from agent.diet_deep_agent.actions.definitions import register_all
from agent.diet_deep_agent.actions.definitions.undo import UNDOABLE_ACTIONS
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import ActionKind, CardType

EXPECTED_TOTAL = 21

# 表驱动期望值：name → (card_type, requires_confirmation, undoable)
WRITE_EXPECT = {
    "record_food": (CardType.RECORD_RESULT, True, True),
    "record_water": (CardType.RECORD_RESULT, True, True),
    "record_weight": (CardType.RECORD_RESULT, True, True),
    "record_pet_feeding": (CardType.RECORD_RESULT, True, True),
    "set_reminder": (CardType.ACTION_CONFIRM, True, True),
    "send_reminder_to_family": (CardType.ACTION_CONFIRM, True, False),  # 消息不可撤回
    # V6 健康档案扩权（全部可撤销）
    "record_exercise": (CardType.ACTION_CONFIRM, True, True),
    "record_disease": (CardType.ACTION_CONFIRM, True, True),
    "mark_disease_recovered": (CardType.ACTION_CONFIRM, True, True),
    "record_allergy": (CardType.ACTION_CONFIRM, True, True),
    "set_health_target": (CardType.ACTION_CONFIRM, True, True),
}
# 任何输入都先出确认卡的动作（内部参数由确认凭证回填）
ALWAYS_CONFIRM_ACTIONS = {"record_disease", "mark_disease_recovered"}
# always_confirm 动作用于回填的内部入参名（模型必须始终留空）
CONFIRM_FIELD = "confirmed_by_user"
QUERY_EXPECT = {
    "query_today": CardType.DAILY_SUMMARY,
    "query_nutrition": CardType.TREND,
    "query_weight_trend": CardType.TREND,
    "query_cost": CardType.COST,
    "query_family": CardType.FAMILY_STATUS,
    "query_exam": CardType.EXAM_METRIC,
    "generate_weekly_report": CardType.WEEKLY_REPORT,
    "query_pet": CardType.TREND,
    "open_page": CardType.ACTION_CONFIRM,
}
# sessions 非 ("human",) 默认值的动作（D18：宠物域能力集）
SESSION_OVERRIDES = {
    "record_pet_feeding": ("human", "pet"),
    "query_pet": ("human", "pet"),
    "undo": ("human", "pet"),
    "open_page": ("human",),
}
# D18：宠物会话的能力集精确等于这三个（记录/查询/撤销，均为宠物域动作）
PET_SESSION_TOOLS = {"record_pet_feeding", "query_pet", "undo"}


@pytest.fixture(scope="module")
def registry() -> ActionRegistry:
    registry = ActionRegistry()
    register_all(registry)
    return registry


class TestRegistration:
    def test_total_count(self, registry: ActionRegistry):
        assert len(registry.names) == EXPECTED_TOTAL

    def test_all_expected_registered(self, registry: ActionRegistry):
        expected = (
            set(WRITE_EXPECT) | set(QUERY_EXPECT)
        )
        assert expected <= set(registry.names)

    def test_no_duplicate_registration(self, registry: ActionRegistry):
        """重复注册必须抛错（防同名动作被意外覆盖）"""
        spec = registry.get("open_page")
        handler = registry.handler("open_page")
        with pytest.raises(ValueError):
            registry.register(spec, handler)

    def test_examples_present(self, registry: ActionRegistry):
        """每个动作都要有典型说法（LLM few-shot 质量，PRD 4.1）"""
        for spec in registry.all():
            assert spec.examples, f"{spec.name} 缺少 examples"


class TestWriteActions:
    @pytest.mark.parametrize("name", list(WRITE_EXPECT))
    def test_kind_is_write(self, registry: ActionRegistry, name: str):
        assert registry.get(name).kind is ActionKind.WRITE

    @pytest.mark.parametrize("name", list(WRITE_EXPECT))
    def test_table_metadata(self, registry: ActionRegistry, name: str):
        """PRD 4.2/4.5：写操作需授权 + 可撤销性按动作语义（send_reminder 不可撤回）"""
        spec = registry.get(name)
        card_type, requires_confirmation, undoable = WRITE_EXPECT[name]
        assert spec.card_type is card_type, name
        assert spec.requires_confirmation is True, name  # 写操作一律需授权
        assert spec.undoable is undoable, name


class TestAlwaysConfirmActions:
    """高敏感档案动作（疾病写入 / 标记痊愈）：任何输入都先出确认卡，参数只能由凭证回填"""

    @pytest.mark.parametrize("name", sorted(ALWAYS_CONFIRM_ACTIONS))
    def test_flag_and_confirm_field(self, registry: ActionRegistry, name: str):
        spec = registry.get(name)
        assert spec.always_confirm is True, name
        # 更严的档位必须仍然满足"写操作需授权"的基本要求
        assert spec.requires_confirmation is True, name
        # 回填字段必须真实存在于入参 schema（否则确认时 Pydantic 会忽略它，卡片点了也不落库）
        assert CONFIRM_FIELD in spec.args_schema.model_fields, name

    def test_confirm_field_absent_elsewhere(self, registry: ActionRegistry):
        """只有 always_confirm 动作才带这个内部参数，避免被别的动作误用"""
        for spec in registry.all():
            if spec.name in ALWAYS_CONFIRM_ACTIONS:
                continue
            assert CONFIRM_FIELD not in spec.args_schema.model_fields, spec.name

    def test_always_confirm_only_for_write_actions(self, registry: ActionRegistry):
        for spec in registry.all():
            if spec.always_confirm:
                assert spec.kind is ActionKind.WRITE, spec.name

    def test_prompt_labels_always_confirm(self, registry: ActionRegistry):
        """提示词要给出正确标签，而不是误导成「叙述性输入会出确认卡」"""
        prompt = registry.prompt_section("human")
        for name in sorted(ALWAYS_CONFIRM_ACTIONS):
            line = next(
                (ln for ln in prompt.splitlines() if ln.startswith(f"- {name}（")),
                "",
            )
            assert "任何输入都出确认卡" in line, name

    def test_health_profile_rules_present(self, registry: ActionRegistry):
        """档案类写操作规则段（只追加不删除 / 不再双写记忆）"""
        prompt = registry.prompt_section("human")
        assert "健康档案类写操作" in prompt
        assert "不要声称已删除" in prompt


class TestQueryActions:
    @pytest.mark.parametrize("name", list(QUERY_EXPECT))
    def test_kind_is_query(self, registry: ActionRegistry, name: str):
        assert registry.get(name).kind is ActionKind.QUERY

    @pytest.mark.parametrize("name", list(QUERY_EXPECT))
    def test_no_confirmation_no_undo(self, registry: ActionRegistry, name: str):
        """查询类不打扰：无确认、无撤销（PRD 4.2「查询不打扰」）"""
        spec = registry.get(name)
        assert spec.requires_confirmation is False, name
        assert spec.undoable is False, name

    @pytest.mark.parametrize("name", list(QUERY_EXPECT))
    def test_card_type(self, registry: ActionRegistry, name: str):
        assert registry.get(name).card_type is QUERY_EXPECT[name]


class TestUndoableConsistency:
    def test_undoable_actions_covered(self, registry: ActionRegistry):
        """PRD 4.5：所有 undoable=True 的动作都必须在 undo 的回滚登记表中"""
        for spec in registry.all():
            if spec.undoable:
                assert spec.name in UNDOABLE_ACTIONS, f"{spec.name} 缺少回滚实现"

    def test_undo_registry_matches_specs(self, registry: ActionRegistry):
        """反向：UNDOABLE_ACTIONS 里的每个动作都必须存在且 undoable=True"""
        for name in UNDOABLE_ACTIONS:
            spec = registry.get(name)
            assert spec is not None, f"UNDOABLE_ACTIONS 引用了不存在的动作: {name}"
            assert spec.undoable is True, name


class TestSessionIsolation:
    @pytest.mark.parametrize("name", list(SESSION_OVERRIDES))
    def test_session_override(self, registry: ActionRegistry, name: str):
        assert registry.get(name).sessions == SESSION_OVERRIDES[name]

    def test_default_human_session(self, registry: ActionRegistry):
        for spec in registry.all():
            if spec.name not in SESSION_OVERRIDES:
                assert spec.sessions == ("human",), spec.name

    def _tools_in_prompt(self, prompt: str) -> set:
        import re

        return set(re.findall(r"^- ([a-z_]+)（", prompt, flags=re.MULTILINE))

    def test_pet_prompt_tools_exact(self, registry: ActionRegistry):
        """D18 红线：宠物 prompt 的工具集精确等于宠物域三动作，多一个少一个都算域隔离破坏"""
        pet_tools = self._tools_in_prompt(registry.prompt_section("pet"))
        assert pet_tools == PET_SESSION_TOOLS

    def test_human_prompt_contains_all(self, registry: ActionRegistry):
        human_tools = self._tools_in_prompt(registry.prompt_section("human"))
        assert human_tools == set(registry.names)

    def test_human_write_actions_absent_in_pet_prompt(self, registry: ActionRegistry):
        """人域写操作绝不出现在宠物 prompt（TC-016 红线的架构保证）"""
        pet_prompt = registry.prompt_section("pet")
        for name in ("record_food", "record_water", "record_weight", "set_reminder", "open_page"):
            assert f"- {name}（" not in pet_prompt, name


class TestPromptRules:
    def test_authorization_rules_present(self, registry: ActionRegistry):
        """授权与撤销规则段（PRD 4.2/4.5）必须在 System Prompt 中"""
        prompt = registry.prompt_section("human")
        for keyword in ("先问", "撤销", "10 分钟"):
            assert keyword in prompt, keyword

    def test_no_image_rule_present(self, registry: ActionRegistry):
        """对话不支持发图的引导规则（PRD 4.9）"""
        assert "不支持发送图片" in registry.prompt_section("human")

    def test_quantifier_rules_present(self, registry: ActionRegistry):
        """模糊量词规则段（PRD 4.3/4.4/D5）"""
        prompt = registry.prompt_section("human")
        assert "待确认卡" in prompt
        assert "不要自己在文本里替用户假定数值" in prompt
