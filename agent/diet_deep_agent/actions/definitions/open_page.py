"""open_page：引导用户前往页面操作（V5.2 引导卡，只跳转、零数据写入）。

场景：用户在对话里需要「页面级功能」时（上传体检报告、管理提醒、看家人健康、
翻饮食记录），Agent 出一张引导卡，用户点「前往」一键直达（PRD 4.8
「卡片必须带下一步入口」的延伸：低频页面动作不常驻对话栏，由 Agent 按话题直达）。

页面走白名单（_PAGES），防止 LLM 把用户引到任意路由；
宠物域不注册本动作（sessions=human），避免把宠物会话引到人域页面（D18/D3）。
"""

import logging
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

# 页面白名单：page 参数 → 引导卡文案 + 前端 jump 目标（与 chat_page._openCardJump 对齐）
_PAGES = {
    "exam_upload": {
        "title": "上传体检报告",
        "desc": "拍照上传到本人私有空间；页面自带隐私提醒，AI 分析默认关闭",
        "jump": {"page": "exam_upload"},
    },
    "reminder": {
        "title": "提醒设置",
        "desc": "管理用餐、饮水、运动提醒",
        "jump": {"page": "reminder"},
    },
    "family_health": {
        "title": "家人健康",
        "desc": "查看家人的饮食与健康状态",
        "jump": {"page": "family_health"},
    },
    "history": {
        "title": "饮食记录",
        "desc": "查看、修改历史记录与营养明细",
        "jump": {"page": "history"},
    },
}


class OpenPageArgs(BaseModel):
    """open_page 入参（不含 user_id）"""

    page: str = Field(
        ...,
        description=(
            "目标页面：exam_upload=体检报告上传, reminder=提醒设置, "
            "family_health=家人健康, history=饮食记录"
        ),
    )
    reason: Optional[str] = Field(
        default=None,
        description="一句话说明为什么要去（展示在引导卡上），如「上传今天的体检报告，我来帮你解读」",
    )


SPEC = ActionSpec(
    name="open_page",
    description=(
        "用户需要去 App 页面里完成操作时（上传体检报告、管理提醒、查看家人健康、"
        "翻饮食记录），出一张引导卡让用户一键直达该页面。只跳转，不写任何数据"
    ),
    kind=ActionKind.QUERY,
    args_schema=OpenPageArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=False,
    undoable=False,
    sessions=("human",),
    examples=["我要上传体检报告", "帮我把体检报告传上去", "提醒设置在哪里改"],
    notes=(
        "页面必须在白名单内（exam_upload/reminder/family_health/history），"
        "之外的 page 会失败。仅在用户明确表达要做页面内操作时调用；纯问答不要调用。"
        "卡片只负责跳转，具体操作由用户在页面里完成。"
    ),
)


async def open_page(params: OpenPageArgs, ctx: ActionContext) -> ActionResult:
    """返回页面引导卡（只跳转，零数据写入）"""
    info = _PAGES.get(params.page)
    if info is None:
        return ActionResult.failure(
            SPEC.name,
            f"不支持直达页面：{params.page}（白名单：{'、'.join(_PAGES)}）",
        )

    message = params.reason or f"请前往「{info['title']}」完成操作。"
    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "title": info["title"],
            "desc": info["desc"],
            "jump": info["jump"],
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 open_page 动作（V5.2 引导卡）"""
    registry.register(SPEC, open_page)
