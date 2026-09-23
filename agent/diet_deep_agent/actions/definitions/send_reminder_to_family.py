"""send_reminder_to_family：提醒家人吃饭/喝水（V6 二期写操作，不可撤销）。

PRD 二期动作（PRD D9 红线）：只帮用户「发一条提醒消息」给已绑定的家人，
**绝不会替家人记录或修改任何家人健康数据**（不写家人的饮食/饮水/体重记录）。

三段式流程与 routers/family_router.py 的 remind_family_water 一致：
1) 复用 query_family 的称谓同义归一匹配定位家人（「我妈」↔ 登记的「母亲/妈妈」）；
2) 关系必须为 family 且 status=accepted（由 _family_relations 保证）；
3) 写一条 messages 记录（extra_data.type=meal_remind/water_remind）并 WebSocket 实时推送。

消息发出后不撤回，因此 undoable=False、requires_confirmation=True。
"""

import logging
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.query_family import (
    _family_relations,
    _match_member,
    _member_note,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

# 跳转映射（PRD 4.8）：提醒家人 → 家人健康页
JUMP_PAGE = "family_health"


class SendReminderToFamilyArgs(BaseModel):
    """send_reminder_to_family 入参（不含 user_id）"""

    relation: str = Field(
        description="家人称谓，用用户原话（如「我妈」「爸爸」「奶奶」），用于定位是哪位家人"
    )
    content: Optional[str] = Field(
        default=None,
        description="提醒内容：如「吃饭」「喝水」；用户没说留空，按「吃饭」提醒",
    )


SPEC = ActionSpec(
    name="send_reminder_to_family",
    description="给已绑定的家人发一条吃饭/喝水提醒消息（发消息，写操作）",
    kind=ActionKind.WRITE,
    args_schema=SendReminderToFamilyArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    undoable=False,
    examples=["提醒我妈吃饭", "给我爸发个喝水提醒", "提醒奶奶喝水"],
    notes=(
        "只发提醒消息，**不能替家人记录或修改任何健康数据**（PRD D9 红线）。"
        "称谓按同义组归一匹配（「我妈」可命中登记的「母亲/妈妈」）；"
        "没有绑定该家人时按失败提示引导用户去「家人健康」页，不要编造家人。"
        "消息发出后不支持撤销。"
    ),
)


def _build_content(sender_name: str, content: str) -> tuple[str, str]:
    """生成消息正文与 extra_data 类型：喝水 → water_remind，其余 → meal_remind"""
    if "水" in content:
        return (
            f"💧 {sender_name} 提醒你该喝水啦！记得多喝水，保持健康～",
            "water_remind",
        )
    label = content or "吃饭"
    return (
        f"🍚 {sender_name} 提醒你该{label}啦！记得按时吃饭，保持健康～",
        "meal_remind",
    )


async def send_reminder_to_family(
    params: SendReminderToFamilyArgs, ctx: ActionContext
) -> ActionResult:
    """定位家人 → 写提醒消息 → 实时推送（失败不抛异常）"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未发送提醒")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，不能给家人发提醒，请切回本人会话再说"
        )

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.message_models import Message
        from shared.models.user_models import User, UserProfile

        # 1) 定位家人：_family_relations 已限定 relationship_type=family 且 status=accepted
        relations = _family_relations(db, ctx.user_id)
        if not relations:
            return ActionResult.failure(
                SPEC.name,
                "还没有绑定家人，无法发送提醒。请先在「家人健康」页绑定家人后再试。",
            )

        matched: list[dict] = []
        for rel in relations:
            member_id = rel.related_user_id if rel.user_id == ctx.user_id else rel.user_id
            note = _member_note(rel, ctx.user_id)
            member_user = db.query(User).filter(User.id == member_id).first()
            member_profile = (
                db.query(UserProfile).filter(UserProfile.user_id == member_id).first()
            )
            real_name = (
                member_profile.real_name
                if member_profile and member_profile.real_name
                else ""
            ) or ""
            username = (member_user.username if member_user else "") or ""
            display_name = real_name or note or username or "家人"
            if _match_member(params.relation, display_name, note, username):
                matched.append(
                    {"user_id": member_id, "note": note, "name": display_name}
                )

        if not matched:
            return ActionResult.failure(
                SPEC.name,
                f"没有找到你说的「{params.relation}」这位家人，"
                "请先在「家人健康」页绑定或确认称谓。",
            )
        if len(matched) > 1:
            return ActionResult.failure(
                SPEC.name,
                f"「{params.relation}」匹配到多位家人，请说得更具体些（如「我妈」「二姨」）。",
            )

        target = matched[0]
        target_user_id = int(target["user_id"])
        target_name = target["name"]
        label = target["note"] or target_name

        # 发送者展示名（与 family_router.remind_family_water 口径一致）
        sender_user = db.query(User).filter(User.id == ctx.user_id).first()
        sender_profile = (
            db.query(UserProfile).filter(UserProfile.user_id == ctx.user_id).first()
        )
        sender_username = (sender_user.username if sender_user else "") or ""
        sender_avatar = (sender_user.avatar_url if sender_user else None) or None
        sender_name = (
            sender_profile.real_name if sender_profile and sender_profile.real_name else ""
        ) or sender_username or "家人"

        content_label = "喝水" if "水" in (params.content or "") else (params.content or "吃饭")
        content_text, extra_type = _build_content(sender_name, params.content or "")

        # 2) 只写提醒消息，绝不写家人的健康数据（PRD D9）
        message = Message(
            sender_id=ctx.user_id,
            receiver_id=target_user_id,
            content=content_text,
            message_type="text",
            extra_data={"type": extra_type},
        )
        db.add(message)
        db.commit()
        db.refresh(message)
        message_id = message.id
        created_at = message.created_at
        if created_at is not None and created_at.tzinfo is None:
            from datetime import timezone

            created_at = created_at.replace(tzinfo=timezone.utc)
        created_at_iso = created_at.isoformat() if created_at else None
    except Exception as e:
        db.rollback()
        logger.exception("send_reminder_to_family 写库失败")
        return ActionResult.failure(SPEC.name, f"发送提醒失败：{e}")
    finally:
        db.close()

    # 3) WebSocket 实时推送（失败不影响消息已落库的事实，仅告警）
    try:
        from routers.message_router import manager

        await manager.send_to_user(
            target_user_id,
            {
                "type": "new_message",
                "data": {
                    "id": message_id,
                    "sender_id": ctx.user_id,
                    "receiver_id": target_user_id,
                    "content": content_text,
                    "message_type": "text",
                    "created_at": created_at_iso,
                    "sender_username": sender_username,
                    "sender_avatar_url": sender_avatar,
                },
            },
        )
    except Exception as ws_error:
        logger.warning(f"家人提醒 WebSocket 推送失败（非致命）: {ws_error}")

    message_text = f"已提醒 {label} {content_label}"
    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message_text,
        data={
            "target_user_id": target_user_id,
            "target_name": target_name,
            "member_name": target_name,
            "relation": params.relation,
            "content": content_label,
            "message_id": message_id,
            "jump": {"page": JUMP_PAGE},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 send_reminder_to_family 动作（V6 二期）"""
    registry.register(SPEC, send_reminder_to_family)
