"""undo：撤销最近一条写操作（V5.1，PRD 4.5 硬约束）。

规则：仅可撤销最近一条写操作，且必须在记录后 10 分钟内，不支持批量撤销；
超窗 / 非最近一条 → 拒绝执行，提示用户去对应页面操作。
"""

import logging
from datetime import date, datetime
from typing import Any, Callable

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.record_food import (
    MEAL_LABELS,
    refresh_daily_summary,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)
from agent.diet_deep_agent.actions.undo_journal import UndoEntry, undo_journal

logger = logging.getLogger(__name__)

PAGE_HINT = "如需修改请在对应页面操作"

# 已支持撤销的动作（V6 新增写操作时在此登记对应的回滚实现）
UNDOABLE_ACTIONS = {
    "record_food",
    "record_water",
    "record_weight",
    "record_pet_feeding",
    "set_reminder",
}

# 撤销成功后的补充说明（不同动作影响的面不同）
AFTER_NOTE = {
    "record_food": "今日统计已同步更新。",
    "record_water": "今日饮水统计已同步更新。",
    "record_weight": "体重已回退到记录前的数值。",
    "record_pet_feeding": "宠物当日汇总已同步更新。",
    "set_reminder": "该提醒已删除。",
}


class _UndoRejected(Exception):
    """撤销被拒绝：记录不存在 / 不是最近一条。属业务结果，不是系统故障"""

    def __init__(self, message: str, clear_journal: bool = False) -> None:
        super().__init__(message)
        self.clear_journal = clear_journal


class UndoArgs(BaseModel):
    """undo 入参（撤销对象由撤销日志决定，不需要模型指定记录 ID）"""

    reason: str | None = Field(
        default=None, description="用户说明的撤销原因（如「记错了」「不是这餐」），可留空"
    )


SPEC = ActionSpec(
    name="undo",
    description="撤销最近一条写操作（仅最近一条且在记录后 10 分钟内生效）",
    kind=ActionKind.WRITE,
    args_schema=UndoArgs,
    card_type=CardType.RECORD_RESULT,
    requires_confirmation=False,
    undoable=False,
    # 宠物会话同样需要撤销（record_pet_feeding 可撤销），故两个会话域都出现（PRD 4.5）
    sessions=("human", "pet"),
    examples=["刚才那条记错了，撤销", "删掉刚记录的午餐"],
    notes=(
        "仅在用户本轮明确要求撤销时才调用；"
        "不要为了修正份量、重录或「营养没匹配上」而自行撤销——那类情况直接用 record_food 记录正确数据即可。"
    ),
)


def _mark_card_undone(db, user_id: int, undo_token: str) -> None:
    """把对应卡片回写为「已撤销」，保证重进会话时历史卡片状态一致。

    卡片存在 AI 消息的 message_metadata.cards 里；撤销日志只有最近一条，
    因此只扫描该用户最近若干条助手消息即可命中。失败不影响撤销结果（仅告警）。
    """
    from shared.models.conversation_models import (
        ConversationMessage,
        ConversationSession,
    )

    try:
        messages = (
            db.query(ConversationMessage)
            .join(
                ConversationSession,
                ConversationSession.id == ConversationMessage.session_id,
            )
            .filter(
                ConversationSession.user_id == user_id,
                ConversationMessage.message_type == 2,
                ConversationMessage.message_metadata.isnot(None),
            )
            .order_by(ConversationMessage.id.desc())
            .limit(20)
            .all()
        )

        for message in messages:
            metadata = message.message_metadata or {}
            cards = metadata.get("cards")
            if not isinstance(cards, list):
                continue

            changed = False
            new_cards = []
            for card in cards:
                if (
                    isinstance(card, dict)
                    and str(card.get("undo_token")) == str(undo_token)
                    and not card.get("undone")
                ):
                    card = {**card, "undone": True}
                    changed = True
                new_cards.append(card)

            if changed:
                message.message_metadata = {**metadata, "cards": new_cards}
                db.commit()
                return
    except Exception as e:  # 卡片状态回写属于"锦上添花"，失败不能影响撤销结果
        db.rollback()
        logger.warning(f"卡片撤销状态回写失败（非致命）: {e}")


def _latest_id(db, model, user_id: int) -> Any:
    """某张记录表该用户的最大 id（用于「仅最近一条」校验）"""
    from sqlalchemy import func

    return db.query(func.max(model.id)).filter(model.user_id == user_id).scalar()


def _undo_food(db, user_id: int, entry: UndoEntry) -> tuple[dict, dict]:
    """回滚一条饮食记录：删明细 + 删记录 + 重算当日汇总"""
    from shared.models.food_models import FoodRecord, NutritionDetail

    record = (
        db.query(FoodRecord)
        .filter(FoodRecord.id == int(entry.undo_token), FoodRecord.user_id == user_id)
        .first()
    )
    if record is None:
        raise _UndoRejected("这条饮食记录不存在或已被撤销，无需重复操作。", clear_journal=True)
    if _latest_id(db, FoodRecord, user_id) != record.id:
        raise _UndoRejected(f"该条不是最近一条饮食记录，不支持撤销；{PAGE_HINT}")

    summary_date = record.record_date
    removed = {
        "record_id": record.id,
        "food_name": record.food_name,
        "meal_type_label": MEAL_LABELS.get(record.meal_type, ""),
        "record_time": record.record_time.isoformat() if record.record_time else None,
    }
    db.query(NutritionDetail).filter(NutritionDetail.food_record_id == record.id).delete()
    db.delete(record)
    db.commit()
    return removed, refresh_daily_summary(db, user_id, summary_date)


def _undo_water(db, user_id: int, entry: UndoEntry) -> tuple[dict, dict]:
    """回滚一条饮水记录：删记录 + 重算当日饮水（并让汇总同步）"""
    from shared.models.water_models import WaterIntakeRecord
    from shared.services.water_service import _recalc_daily_water, get_daily_water_summary

    record = (
        db.query(WaterIntakeRecord)
        .filter(
            WaterIntakeRecord.id == int(entry.undo_token),
            WaterIntakeRecord.user_id == user_id,
        )
        .first()
    )
    if record is None:
        raise _UndoRejected("这条饮水记录不存在或已被撤销，无需重复操作。", clear_journal=True)
    if _latest_id(db, WaterIntakeRecord, user_id) != record.id:
        raise _UndoRejected(f"该条不是最近一条饮水记录，不支持撤销；{PAGE_HINT}")

    record_date = record.record_time.date() if record.record_time else date.today()
    removed = {
        "record_id": record.id,
        "amount_ml": record.amount_ml,
        "drink_type": record.drink_type,
        "record_time": record.record_time.isoformat() if record.record_time else None,
    }
    db.delete(record)
    db.flush()
    # 全量重算当日饮水，并同步 daily_nutrition_summaries.water_intake（含缓存失效）
    _recalc_daily_water(db, user_id, record_date)
    db.commit()

    daily = get_daily_water_summary(db, user_id, record_date)
    totals = {
        "date": record_date.isoformat(),
        "total_intake_ml": daily["total_intake_ml"],
        "daily_goal_ml": daily["daily_goal_ml"],
        "completion_rate": daily["completion_rate"],
    }
    return removed, totals


def _undo_weight(db, user_id: int, entry: UndoEntry) -> tuple[dict, dict]:
    """回滚一条体重记录：删记录 + 把 UserProfile 体重/BMI 还原到记录前"""
    from shared.models.user_models import UserProfile, WeightRecord

    record = (
        db.query(WeightRecord)
        .filter(WeightRecord.id == int(entry.undo_token), WeightRecord.user_id == user_id)
        .first()
    )
    if record is None:
        raise _UndoRejected("这条体重记录不存在或已被撤销，无需重复操作。", clear_journal=True)
    if _latest_id(db, WeightRecord, user_id) != record.id:
        raise _UndoRejected(f"该条不是最近一条体重记录，不支持撤销；{PAGE_HINT}")

    removed = {
        "record_id": record.id,
        "weight_kg": float(record.weight) if record.weight is not None else None,
        "measured_at": record.measured_at.isoformat() if record.measured_at else None,
    }
    db.delete(record)
    db.flush()

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    restored = None
    if profile:
        snapshot = entry.payload or {}
        if "profile_weight" in snapshot:
            profile.weight = snapshot.get("profile_weight")
            profile.bmi = snapshot.get("profile_bmi")
        else:
            # 老凭证没有快照时按剩余最近一条体重记录兜底还原
            last = (
                db.query(WeightRecord)
                .filter(WeightRecord.user_id == user_id)
                .order_by(WeightRecord.measured_at.desc(), WeightRecord.id.desc())
                .first()
            )
            profile.weight = float(last.weight) if last and last.weight is not None else profile.weight
            profile.bmi = (
                float(last.bmi) if last and last.bmi is not None else profile.bmi
            )
        profile.updated_at = datetime.utcnow()
        restored = {
            "weight": float(profile.weight) if profile.weight is not None else None,
            "bmi": float(profile.bmi) if profile.bmi is not None else None,
        }
    db.commit()
    return removed, {"profile_restored": restored}


def _undo_pet_feeding(db, user_id: int, entry: UndoEntry) -> tuple[dict, dict]:
    """回滚一条宠物喂食记录：删记录 + 同步当日宠物汇总

    PetFeedingRecord 没有 user_id（归属靠 pet_id），因此不能用 _latest_id 做
    「最近一条」校验；「仅最近一条」由撤销日志（peek 只返回最近一条）保证，
    这里额外校验宠物归属，避免撤销到别人宠物的记录。
    """
    from shared.models.pet_models import PetFeedingRecord, PetProfile
    from shared.services.real_pet_service import delete_feeding

    record_id = int(entry.undo_token)
    pet_id = (entry.payload or {}).get("pet_id")
    if pet_id is None:
        raise _UndoRejected(f"这条喂食记录缺少宠物信息，无法撤销；{PAGE_HINT}")

    pet = (
        db.query(PetProfile)
        .filter(PetProfile.id == int(pet_id), PetProfile.user_id == user_id)
        .first()
    )
    if pet is None:
        raise _UndoRejected("这只宠物不在你的名下，无法撤销该记录。", clear_journal=True)

    record = (
        db.query(PetFeedingRecord)
        .filter(PetFeedingRecord.id == record_id, PetFeedingRecord.pet_id == int(pet_id))
        .first()
    )
    if record is None:
        raise _UndoRejected("这条喂食记录不存在或已被撤销，无需重复操作。", clear_journal=True)

    removed = {
        "record_id": record.id,
        "pet_id": int(pet_id),
        "pet_name": (entry.payload or {}).get("pet_name") or pet.name or "",
        "food_name": record.food_name,
        "amount_grams": float(record.amount_grams) if record.amount_grams is not None else None,
        "record_time": record.record_time.isoformat() if record.record_time else None,
    }
    # delete_feeding 内部会重算当日 PetDailySummary 并提交
    if not delete_feeding(db, int(pet_id), record_id):
        raise _UndoRejected("这条喂食记录不存在或已被撤销，无需重复操作。", clear_journal=True)

    return removed, {"pet_id": int(pet_id)}


def _undo_reminder(db, user_id: int, entry: UndoEntry) -> tuple[dict, dict]:
    """回滚一条提醒设置：删除该提醒"""
    from shared.models.reminder_models import Reminder
    from shared.services.reminder_service import delete_reminder

    reminder_id = int(entry.undo_token)
    reminder = (
        db.query(Reminder)
        .filter(Reminder.id == reminder_id, Reminder.user_id == user_id)
        .first()
    )
    if reminder is None:
        raise _UndoRejected("这条提醒不存在或已被删除，无需重复操作。", clear_journal=True)

    removed = {
        "reminder_id": reminder.id,
        "reminder_type": reminder.reminder_type,
        "remind_time": reminder.remind_time.isoformat() if reminder.remind_time else None,
        "title": reminder.title,
    }
    try:
        delete_reminder(db, reminder_id, user_id)
    except ValueError:
        raise _UndoRejected("这条提醒不存在或已被删除，无需重复操作。", clear_journal=True)

    return removed, {}


_HANDLERS: dict[str, Callable[[Any, int, UndoEntry], tuple[dict, dict]]] = {
    "record_food": _undo_food,
    "record_water": _undo_water,
    "record_weight": _undo_weight,
    "record_pet_feeding": _undo_pet_feeding,
    "set_reminder": _undo_reminder,
}


async def undo(params: UndoArgs, ctx: ActionContext) -> ActionResult:
    """执行撤销：校验窗口与"最近一条"后回滚记录并重算当日统计"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未执行撤销")

    entry = await undo_journal.peek(ctx.user_id)
    if entry is None:
        return ActionResult.failure(
            SPEC.name,
            f"没有可撤销的记录：仅支持撤销最近一条写操作，且需在记录后 10 分钟内；{PAGE_HINT}",
        )
    if entry.action not in UNDOABLE_ACTIONS:
        return ActionResult.failure(SPEC.name, f"暂不支持撤销「{entry.action}」动作；{PAGE_HINT}")

    # 卡片直调路径：客户端带上该卡片的 undo_token，必须就是当前可撤销的那一条，
    # 否则会出现「点 A 会话的卡片、实际撤掉 B 会话记录」的串号问题。
    expected_token = (ctx.raw or {}).get("undo_token")
    if expected_token not in (None, "") and str(expected_token) != str(entry.undo_token):
        return ActionResult.failure(
            SPEC.name,
            f"这条已不是最近一条记录，无法从卡片撤销；{PAGE_HINT}",
        )

    handler = _HANDLERS.get(entry.action)
    if handler is None or not str(entry.undo_token).isdigit():
        return ActionResult.failure(SPEC.name, f"暂不支持撤销「{entry.action}」动作；{PAGE_HINT}")

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        removed, totals = handler(db, ctx.user_id, entry)
        # 卡片状态回写（历史回显时该卡片显示「已撤销」）
        _mark_card_undone(db, ctx.user_id, entry.undo_token)
    except _UndoRejected as e:
        db.rollback()
        if e.clear_journal:
            await undo_journal.clear(ctx.user_id)
        return ActionResult.failure(SPEC.name, str(e))
    except Exception as e:
        db.rollback()
        logger.exception("undo 执行失败")
        return ActionResult.failure(SPEC.name, f"撤销失败：{e}")
    finally:
        db.close()

    await undo_journal.clear(ctx.user_id)
    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.RECORD_RESULT,
        message=f"已撤销「{entry.summary}」。{AFTER_NOTE.get(entry.action, '')}",
        data={"undone": removed, "daily_totals": totals},
    )


def register(registry: ActionRegistry) -> None:
    """注册 undo 动作（V5.1）"""
    registry.register(SPEC, undo)