"""open_page 页面引导卡的单元测试（纯进程内，不需要后端 / LLM / 数据库）。

覆盖：
    - 动作注册与元数据（QUERY 只跳转、不可撤销、宠物域隔离 D18/D3）
    - System Prompt 接线（人域可见、宠物域不可见）
    - 页面白名单（条目完备 + jump.page 与前端 _openCardJump 路由表对齐）
    - 执行路径（合法出卡 / reason 缺省 / 白名单外失败 / 入参校验）
    - registry 工具层接线（与 Agent 实际调用同路径）

运行：
    uv run pytest tests/test_open_page.py -v
"""

import asyncio
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions import register_all
from agent.diet_deep_agent.actions.definitions.open_page import (
    _PAGES,
    OpenPageArgs,
    open_page,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import ActionKind, CardType


@pytest.fixture(scope="module")
def registry() -> ActionRegistry:
    registry = ActionRegistry()
    register_all(registry)
    return registry


def _ctx(user_id: str = "78") -> ActionContext:
    return ActionContext.from_config({"configurable": {"user_id": user_id}})


def _run(coro):
    return asyncio.run(coro)


class TestRegistration:
    def test_registered(self, registry: ActionRegistry):
        assert "open_page" in registry.names

    def test_metadata_query_only(self, registry: ActionRegistry):
        """只跳转、零数据写入：QUERY 类型、不可撤销、无需确认"""
        spec = registry.get("open_page")
        assert spec is not None
        assert spec.kind is ActionKind.QUERY
        assert spec.card_type is CardType.ACTION_CONFIRM
        assert spec.undoable is False
        assert spec.requires_confirmation is False

    def test_human_session_only(self, registry: ActionRegistry):
        """D18/D3：宠物域不注册，避免把宠物会话引到人域页面"""
        spec = registry.get("open_page")
        assert spec.sessions == ("human",)

    def test_prompt_human_contains_tool(self, registry: ActionRegistry):
        """人域 System Prompt 能看到 open_page（LLM 知道这个能力）"""
        assert "open_page" in registry.prompt_section("human")

    def test_prompt_pet_excludes_tool(self, registry: ActionRegistry):
        """宠物域 System Prompt 不出现 open_page"""
        assert "open_page" not in registry.prompt_section("pet")


class TestWhitelist:
    def test_whitelist_entries(self):
        """白名单条目完备（新增直达页面时同步更新本断言）"""
        assert set(_PAGES) == {"exam_upload", "reminder", "family_health", "history"}

    def test_jump_pages_known_by_frontend(self):
        """契约：后端 jump.page 必须在前端 chat_page._openCardJump 的 case 集合内，
        否则引导卡点了「前往」会走 default 分支跳错页"""
        frontend_pages = {
            "history",
            "diet_records",
            "weight_trend",
            "family_health",
            "weekly_report",
            "cost",
            "reminder",
            "exam_report",
            "exam_reports",
            "exam_upload",
        }
        for page, info in _PAGES.items():
            assert info["jump"]["page"] in frontend_pages, f"{page} 的 jump 目标前端未实现"

    def test_whitelist_items_have_copy(self):
        """每个白名单页面都要有标题与说明文案（引导卡展示用）"""
        for page, info in _PAGES.items():
            assert info.get("title"), page
            assert info.get("desc"), page


class TestOpenPageExecution:
    def test_valid_page_returns_guide_card(self):
        res = _run(
            open_page(
                OpenPageArgs(page="exam_upload", reason="上传今天的体检报告，我来帮你解读"),
                _ctx(),
            )
        )
        assert res.ok is True
        assert res.action == "open_page"
        assert res.card_type is CardType.ACTION_CONFIRM
        assert res.data["jump"] == {"page": "exam_upload"}
        assert res.data["title"] == "上传体检报告"
        # 用户给的 reason 优先作为卡片主文案
        assert res.message == "上传今天的体检报告，我来帮你解读"

    def test_default_message_without_reason(self):
        res = _run(open_page(OpenPageArgs(page="reminder"), _ctx()))
        assert res.ok is True
        assert res.data["jump"] == {"page": "reminder"}
        assert "提醒设置" in res.message

    def test_all_whitelisted_pages_ok(self):
        for page in _PAGES:
            res = _run(open_page(OpenPageArgs(page=page), _ctx()))
            assert res.ok is True, page
            assert res.data["jump"]["page"] == _PAGES[page]["jump"]["page"]

    def test_unknown_page_fails(self):
        """白名单外直接失败：LLM 引不到任意路由（安全边界）"""
        res = _run(open_page(OpenPageArgs(page="/admin"), _ctx()))
        assert res.ok is False
        assert "白名单" in res.message

    def test_page_arg_required(self):
        with pytest.raises(Exception):
            OpenPageArgs()  # 缺 page 必填参数


class TestRegistryToolWiring:
    def test_tool_layer_end_to_end(self, registry: ActionRegistry):
        """走 registry 生成的 LangChain 工具（与 Agent 实际调用同路径）"""
        tool = next(t for t in registry.langchain_tools() if t.name == "open_page")
        raw = _run(
            tool.coroutine(
                config={"configurable": {"user_id": "78"}},
                page="exam_upload",
                reason="上传体检报告",
            )
        )
        payload = json.loads(raw)
        assert payload["ok"] is True
        assert payload["action"] == "open_page"
        assert payload["data"]["jump"] == {"page": "exam_upload"}

    def test_tool_layer_unknown_page(self, registry: ActionRegistry):
        tool = next(t for t in registry.langchain_tools() if t.name == "open_page")
        raw = _run(tool.coroutine(page="/admin"))
        payload = json.loads(raw)
        assert payload["ok"] is False
