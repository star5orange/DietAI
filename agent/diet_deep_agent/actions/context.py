"""动作执行上下文：从 LangChain/LangGraph 的 config 提取运行期信息。

Router（routers/deep_router.py）调用 Agent 时注入：
    config={"configurable": {"thread_id": ..., "user_id": "12",
                             "is_pet_session": False, "input_channel": "app"}}

动作实现从上下文读取 user_id，而不是把 user_id 交给 LLM 当入参
（旧工具的历史缺陷：模型可能编造或串号）；动作的入参 schema 里不再出现 user_id。

input_channel 用于区分输入渠道（PRD 4.9）：app（默认，文本/语音）/ hardware（宠物时钟等硬件语音）。
老人线（hardware）在模糊量词上走「默认值记录 + 事后可改」，App 端走「追问 + 快捷选项」（PRD 4.3/D5）。
"""

from dataclasses import dataclass, field
from typing import Any, Optional

# 老人线渠道：硬件语音走默认值记录，不追问（PRD 4.3 例外）
ELDER_CHANNELS = {"hardware", "hardware_voice"}


@dataclass
class ActionContext:
    """一次动作调用的运行期上下文"""

    user_id: Optional[int] = None
    thread_id: Optional[str] = None
    is_pet_session: bool = False
    input_channel: str = "app"
    raw: dict[str, Any] = field(default_factory=dict)

    @property
    def is_elder_channel(self) -> bool:
        """是否老人线渠道（硬件语音）：模糊量词不追问，直接按默认值记录（PRD 4.3/D5）"""
        return str(self.input_channel or "").strip().lower() in ELDER_CHANNELS

    @classmethod
    def from_config(cls, config: Any = None) -> "ActionContext":
        """从 RunnableConfig 解析上下文；无 config 时返回空上下文（各字段为 None）"""
        cfg: dict[str, Any] = {}
        if isinstance(config, dict):
            cfg = config.get("configurable") or {}

        raw_user_id = cfg.get("user_id")
        user_id: Optional[int] = None
        if raw_user_id is not None:
            try:
                user_id = int(raw_user_id)
            except (TypeError, ValueError):
                user_id = None

        thread_id = cfg.get("thread_id")
        return cls(
            user_id=user_id,
            thread_id=str(thread_id) if thread_id is not None else None,
            is_pet_session=bool(cfg.get("is_pet_session")),
            input_channel=str(cfg.get("input_channel") or "app"),
            raw=dict(cfg),
        )