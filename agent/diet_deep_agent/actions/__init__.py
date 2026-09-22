"""V5.0 动作注册表（Tool Registry，PRD 4.1）。

对外入口：
    from agent.diet_deep_agent.actions import registry

    tools = registry.langchain_tools()   # 挂到 Agent 工具列表
    registry.prompt_section()            # 注入 System Prompt 的动作清单与授权/撤销规则

目录结构：
    spec.py            动作元数据（入参/出参/需确认/可撤销/卡片类型）
    context.py         运行期上下文（user_id 等由 Router 注入，不进 LLM schema）
    registry.py        注册与派发（生成 LangChain 工具 + Prompt 段落）
    undo_journal.py    撤销日志（最近一条 + 10 分钟窗口）
    definitions/       动作定义（record_food、undo；V6 在此扩展）
"""

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions import register_all
from agent.diet_deep_agent.actions.registry import ActionHandler, ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)
from agent.diet_deep_agent.actions.undo_journal import (
    UndoEntry,
    UndoJournal,
    undo_journal,
)

# 模块级单例：导入即完成动作注册
registry = ActionRegistry()
register_all(registry)

__all__ = [
    "ActionContext",
    "ActionHandler",
    "ActionKind",
    "ActionRegistry",
    "ActionResult",
    "ActionSpec",
    "CardType",
    "UndoEntry",
    "UndoJournal",
    "registry",
    "undo_journal",
]