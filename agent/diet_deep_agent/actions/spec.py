"""V5.0 动作注册表 - 动作元数据定义（PRD 4.1）。

动作（Action）与实现分离：
- spec 声明"这个动作长什么样"：入参 schema / 出参 schema / 是否需确认 / 是否可撤销 / 卡片类型
- handler 只实现"这个动作怎么做"
- 注册与派发由 registry.py 统一完成（V6 新增动作只加定义，不改架构）

放置策略：全部在 agent/ 域内，不依赖 routers/。
"""

import json
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional, Type

from pydantic import BaseModel


class ActionKind(str, Enum):
    """动作类型：查询不打扰，写操作给后悔药（PRD 4.2）"""

    QUERY = "query"
    WRITE = "write"


class CardType(str, Enum):
    """结果卡片类型（PRD 4.8 卡片类型与跳转映射）"""

    RECORD_RESULT = "record_result"  # 记录结果卡（含撤销入口）
    DAILY_SUMMARY = "daily_summary"  # 今日汇总卡
    TREND = "trend"  # 趋势卡
    FAMILY_STATUS = "family_status"  # 家人状态卡
    WEEKLY_REPORT = "weekly_report"  # 周报卡
    PENDING_CONFIRM = "pending_confirm"  # 待确认卡（模糊量词追问，带快捷选项，就地回答）
    EXAM_METRIC = "exam_metric"  # 体检指标卡（单项指标 + 参考范围）
    COST = "cost"  # 成本卡（花销统计）
    ACTION_CONFIRM = "action_confirm"  # 操作确认卡（提醒已设置 / 已发送）
    TEXT = "text"  # 纯文本（无卡片）


@dataclass
class ActionSpec:
    """单个动作的元数据（注册表的最小单元）"""

    name: str
    description: str
    kind: ActionKind
    args_schema: Type[BaseModel]
    card_type: CardType = CardType.TEXT
    requires_confirmation: bool = False  # 写操作默认需授权（PRD 4.2 叙述性输入先问一句）
    undoable: bool = False  # 是否进入撤销日志（PRD 4.5）
    # 适用会话域：human（人/家人对话，默认）/ pet（宠物模式）。
    # PRD D18：宠物模式仅切换上下文域，人与宠物能力集隔离，因此宠物会话的提示词
    # 只列出 sessions 含 "pet" 的动作，避免模型在宠物会话里调用人类的记录动作。
    sessions: tuple[str, ...] = ("human",)
    result_schema: Optional[Type[BaseModel]] = None
    examples: tuple[str, ...] = ()
    notes: str = ""  # 追加在工具描述中的补充约束（给 LLM 看）

    def tool_description(self) -> str:
        """生成给 LLM 的工具描述"""
        parts = [self.description.strip()]
        if self.notes:
            parts.append(self.notes.strip())
        if self.examples:
            parts.append("典型说法：" + "；".join(self.examples))
        return "\n".join(parts)


@dataclass
class ActionResult:
    """动作执行结果（统一出参，供卡片渲染与模型回复使用）"""

    ok: bool
    action: str
    card_type: CardType = CardType.TEXT
    message: str = ""
    data: dict[str, Any] = field(default_factory=dict)
    undo_token: Optional[str] = None  # 有值表示可在窗口内撤销
    undo_deadline: Optional[str] = None  # 撤销截止时间（ISO）
    error: Optional[str] = None

    def to_tool_output(self) -> str:
        """序列化为工具返回值（LLM 读取的结构化 JSON 字符串）"""
        return json.dumps(
            {
                "ok": self.ok,
                "action": self.action,
                "card_type": self.card_type.value,
                "message": self.message,
                "data": self.data,
                "undo_token": self.undo_token,
                "undo_deadline": self.undo_deadline,
                "error": self.error,
            },
            ensure_ascii=False,
            default=str,
        )

    @classmethod
    def failure(cls, action: str, error: str, message: str = "") -> "ActionResult":
        """构造失败结果（message 缺省与 error 一致）"""
        return cls(ok=False, action=action, message=message or error, error=error)