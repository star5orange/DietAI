"""record_weight：记录体重（V5.1 写操作，可撤销）。

单位换算（PRD 3.1）：「我今天 91 斤」→ 45.5kg 由动作确定完成，不依赖模型换算。
模型只负责把用户原话的数值与单位填进入参，避免各家模型换算口径不一致。
"""

import logging
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.record_food import _parse_record_time
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)
from agent.diet_deep_agent.actions.undo_journal import UndoEntry, undo_journal

logger = logging.getLogger(__name__)

# 单位 → 千克换算系数（斤/两/磅为口语常见单位）
UNIT_TO_KG = {
    "斤": 0.5,
    "两": 0.05,
    "公斤": 1.0,
    "千克": 1.0,
    "kg": 1.0,
    "kilogram": 1.0,
    "磅": 0.4536,
    "lb": 0.4536,
    "lbs": 0.4536,
}
DEFAULT_UNIT = "公斤"
# 体重合理区间（kg）：超出视为听写/单位错误，不落库（PRD 5.3 不写脏数据）
MIN_WEIGHT_KG = 20.0
MAX_WEIGHT_KG = 300.0


class RecordWeightArgs(BaseModel):
    """record_weight 入参（不含 user_id）"""

    weight: float = Field(description="用户说的体重数值，按原话填写（「91 斤」填 91，「45.5 公斤」填 45.5）")
    unit: Optional[str] = Field(
        default=None, description="单位：斤/公斤/千克/kg/磅。用户没说单位留空，按公斤处理"
    )
    record_time: Optional[str] = Field(
        default=None, description="测量时间：ISO 时间或 HH:MM；未提及留空取当前时间（PRD 4.7）"
    )


SPEC = ActionSpec(
    name="record_weight",
    description="记录用户体重（写入体重记录，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordWeightArgs,
    card_type=CardType.RECORD_RESULT,
    requires_confirmation=True,
    undoable=True,
    examples=["我今天 91 斤", "帮我记录：我今天 91 斤", "我早上称了 70.5 公斤"],
    notes=(
        "只填用户原话的数值与单位，**不要自行做斤/公斤换算**，换算由系统完成；"
        "用户没说单位时留空 unit（按公斤处理），不要猜成斤。"
        "用户已给出明确数值与单位时（如「我今天 91 斤」「45.5 公斤」）**直接记录**，"
        "不要因为与档案/上次记录差异大而拒绝记录或反复追问——"
        "合理性由系统校验（20-300kg）；差异大时先记录，再在回复里提示一句让对方核对即可（PRD 3.1 / 4.2）。"
    ),
)


def _to_kg(weight: float, unit: Optional[str]) -> Optional[float]:
    """按单位换算成千克；单位无法识别时返回 None"""
    key = (unit or DEFAULT_UNIT).strip().lower()
    factor = UNIT_TO_KG.get(key) or UNIT_TO_KG.get(key.replace(" ", ""))
    if factor is None:
        return None
    return round(float(weight) * factor, 2)


def _bmi(height_cm: Optional[float], weight_kg: float) -> Optional[float]:
    """BMI = 体重(kg) / 身高(m)²；缺身高则不算（不写脏数据）"""
    if not height_cm or float(height_cm) <= 0:
        return None
    meters = float(height_cm) / 100.0
    return round(weight_kg / (meters * meters), 2)


def _clear_user_cache(user_id: int) -> None:
    """体重变化会影响首页/健康页缓存（PRD：写操作后不留旧值）"""
    try:
        from shared.config.redis_config import cache_service

        cache_service.clear_user_cache(user_id)
    except Exception as e:
        logger.warning(f"清除用户缓存失败（非致命）: {e}")


async def record_weight(params: RecordWeightArgs, ctx: ActionContext) -> ActionResult:
    """写入一条体重记录，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物体重请使用宠物工具，不写入本人的体重记录"
        )

    weight_kg = _to_kg(params.weight, params.unit)
    if weight_kg is None:
        return ActionResult.failure(
            SPEC.name, f"无法识别的体重单位「{params.unit}」，请用斤/公斤/千克"
        )
    if not (MIN_WEIGHT_KG <= weight_kg <= MAX_WEIGHT_KG):
        return ActionResult.failure(
            SPEC.name,
            f"体重 {weight_kg:g}kg 超出合理范围（{MIN_WEIGHT_KG:g}-{MAX_WEIGHT_KG:g}kg），"
            "请确认数值与单位后再说一次",
        )

    when = _parse_record_time(params.record_time)

    from shared.models.database import SessionLocal

    previous_profile_weight: Optional[float] = None
    previous_profile_bmi: Optional[float] = None

    db = SessionLocal()
    try:
        from shared.models.user_models import UserProfile, WeightRecord

        profile = db.query(UserProfile).filter(UserProfile.user_id == ctx.user_id).first()
        bmi = _bmi(profile.height if profile else None, weight_kg)
        # 记录改动前的资料体重/BMI，撤销时精确还原（UndoEntry.payload）
        previous_profile_weight = (
            float(profile.weight) if profile and profile.weight is not None else None
        )
        previous_profile_bmi = float(profile.bmi) if profile and profile.bmi is not None else None

        previous = (
            db.query(WeightRecord)
            .filter(WeightRecord.user_id == ctx.user_id)
            .order_by(WeightRecord.measured_at.desc(), WeightRecord.id.desc())
            .first()
        )
        previous_kg = float(previous.weight) if previous else None

        record = WeightRecord(
            user_id=ctx.user_id,
            weight=weight_kg,
            bmi=bmi,
            measured_at=when,
            device_type="chat",
        )
        db.add(record)
        db.flush()

        # 用户资料里的当前体重同步更新（与页面端记录体重口径一致）
        if profile:
            profile.weight = weight_kg
            profile.bmi = bmi
            profile.updated_at = datetime.utcnow()

        db.commit()
        weight_id = record.id
    except Exception as e:
        db.rollback()
        logger.exception("record_weight 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    _clear_user_cache(ctx.user_id)

    delta = None if previous_kg is None else round(weight_kg - previous_kg, 2)
    jin = round(weight_kg / UNIT_TO_KG["斤"], 2)
    message = f"已记录体重：{weight_kg:g}kg（{jin:g} 斤）"
    if bmi is not None:
        message += f"，BMI {bmi:g}"
    if delta is not None and abs(delta) >= 0.05:
        message += f"，较上次{'增加' if delta > 0 else '减少'} {abs(delta):g}kg"
    message += "。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(weight_id),
        summary=f"体重 {weight_kg:g}kg",
        payload={
            "profile_weight": previous_profile_weight,
            "profile_bmi": previous_profile_bmi,
        },
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.RECORD_RESULT,
        message=message,
        data={
            "weight_record_id": weight_id,
            "weight_kg": weight_kg,
            "weight_jin": jin,
            "bmi": bmi,
            "previous_weight_kg": previous_kg,
            "delta_kg": delta,
            "measured_at": when.isoformat(),
            # 下一步入口（PRD 4.8）：体重记录不在饮食记录页，引导看体重趋势
            "jump": {"page": "weight_trend"},
        },
        undo_token=str(weight_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_weight 动作（V5.1）"""
    registry.register(SPEC, record_weight)
