"""set_health_target：设置每日热量 / 饮水目标（V6 健康档案扩权，写操作，可撤销）。

「健康目标」指 `UserProfile.target_calories`（kcal/天）与 `UserProfile.daily_water_goal`
（ml/天）——**不含** `health_goals` 减重目标表。区间与页面端同一口径（800-5000 kcal /
500-5000 ml），一次性可只改其中一个。

写后清用户缓存（首页/健康页/宠物页的目标值都从缓存取），撤销按快照还原并同样清缓存。
"""

import logging
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.health_profile_common import (
    validate_targets,
)
from agent.diet_deep_agent.actions.pending import build_record_confirm_card
from agent.diet_deep_agent.actions.pending_store import register_record_confirm
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)
from agent.diet_deep_agent.actions.undo_journal import UndoEntry, undo_journal

logger = logging.getLogger(__name__)


class SetHealthTargetArgs(BaseModel):
    """set_health_target 入参（不含 user_id）"""

    target_calories: Optional[int] = Field(
        default=None,
        description="每日热量目标（kcal，合理范围 800-5000），如「改成 1800」填 1800；本次不涉及留空",
    )
    daily_water_goal: Optional[int] = Field(
        default=None,
        description="每日饮水目标（ml，合理范围 500-5000），如「每天喝 2500 毫升」填 2500；本次不涉及留空",
    )
    explicit_request: bool = Field(
        default=False,
        description="用户是否明确要你帮设置（如「帮我改」「设置成」）。"
        "叙述性提及（只是说自己打算吃多少，没让改）填 false —— 动作会弹「要帮你记录吗？」确认卡",
    )


SPEC = ActionSpec(
    name="set_health_target",
    description="设置用户的每日热量目标或每日饮水目标（写入个人资料，写操作）",
    kind=ActionKind.WRITE,
    args_schema=SetHealthTargetArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    undoable=True,
    sessions=("human",),
    examples=["把我的热量目标改成 1800", "帮我记录：每天喝水目标 2500 毫升"],
    notes=(
        "只改每日热量与饮水目标这两项（减重目标请引导用户去「健康」页设置）。"
        "一次可以只给一个目标，不要求用户两个都给；"
        "用户说「想减到 60 公斤」这类体重目标不属于本动作，用文字说明去「健康」页设置减重目标。"
    ),
)


def _clear_user_cache(user_id: int) -> None:
    """目标值参与首页/健康页/宠物页的缓存计算，写后必须清（与页面端同口径）"""
    try:
        from shared.config.redis_config import cache_service

        cache_service.clear_user_cache(user_id)
    except Exception as e:
        logger.warning(f"清除用户缓存失败（非致命）: {e}")


def _describe(calories: Optional[int], water: Optional[int]) -> str:
    parts = []
    if calories is not None:
        parts.append(f"热量目标 {calories} kcal")
    if water is not None:
        parts.append(f"饮水目标 {water} ml")
    return "、".join(parts)


async def set_health_target(params: SetHealthTargetArgs, ctx: ActionContext) -> ActionResult:
    """upsert 用户资料的目标字段，并登记撤销凭证（快照旧值）"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未设置目标")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物目标请使用宠物工具，不设置本人的健康目标"
        )

    error = validate_targets(params.target_calories, params.daily_water_goal)
    if error:
        return ActionResult.failure(SPEC.name, error)

    what = _describe(params.target_calories, params.daily_water_goal)
    confirm_params = {
        "target_calories": params.target_calories,
        "daily_water_goal": params.daily_water_goal,
    }

    # 叙述性提及但未明确要求设置 → 弹确认卡；老人线不弹卡，直接写
    if not params.explicit_request and not ctx.is_elder_channel:
        confirm_token = await register_record_confirm(
            ctx.user_id, action=SPEC.name, label=what, params=confirm_params
        )
        return build_record_confirm_card(
            action=SPEC.name,
            what=what,
            params=confirm_params,
            confirm_token=confirm_token,
        )

    from shared.models.database import SessionLocal
    from shared.models.user_models import UserProfile

    db = SessionLocal()
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == ctx.user_id).first()
        if profile is None:
            profile = UserProfile(user_id=ctx.user_id)
            db.add(profile)
            db.flush()

        # 快照旧值：撤销时精确还原（None 表示"从未设置"，不能被默认值顶替）
        snapshot: dict[str, Any] = {
            "target_calories": profile.target_calories,
            "daily_water_goal": profile.daily_water_goal,
        }
        before = _describe(profile.target_calories, profile.daily_water_goal) or "（未设置）"

        if params.target_calories is not None:
            profile.target_calories = int(params.target_calories)
        if params.daily_water_goal is not None:
            profile.daily_water_goal = int(params.daily_water_goal)
        db.commit()
        profile_id = profile.id
        after = _describe(profile.target_calories, profile.daily_water_goal)
    except Exception as e:
        db.rollback()
        logger.exception("set_health_target 写库失败")
        return ActionResult.failure(SPEC.name, f"设置失败：{e}")
    finally:
        db.close()

    _clear_user_cache(ctx.user_id)

    message = f"已设置：{after}（原为 {before}）。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(profile_id),
        summary=after,
        payload=snapshot,
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "profile_id": profile_id,
            "target_calories": params.target_calories,
            "daily_water_goal": params.daily_water_goal,
            "detail": after,
            "jump": {"page": "health"},
        },
        undo_token=str(profile_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 set_health_target 动作（V6 健康档案扩权）"""
    registry.register(SPEC, set_health_target)