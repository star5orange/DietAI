"""record_exercise：记录运动（V6 健康档案扩权，写操作，可撤销）。

热量由 `exercise_service.create_exercise_record` 按运动类型 × 时长 × 强度 ×
用户体重自动估算（不依赖模型换算），并同步到当日营养汇总的 exercise_calories。

确认严格度沿用现有写动作：叙述性提及（只是说跑了步、没让记）出确认卡，
明确要求（「帮我记录」）直接写并给 10 分钟撤销。
"""

import logging
from datetime import date, datetime, timedelta
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
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


class RecordExerciseArgs(BaseModel):
    """record_exercise 入参（不含 user_id）"""

    exercise_type: str = Field(
        description="运动类型：跑步/游泳/力量训练/骑行/跳绳/瑜伽/快走/篮球/足球/羽毛球/其他"
    )
    duration_minutes: int = Field(
        default=0,
        ge=0,
        le=1440,
        description="运动时长（分钟）。只报了距离没报时长时填 0（系统会按距离估算）",
    )
    intensity: Optional[int] = Field(
        default=None,
        ge=1,
        le=3,
        description="强度：1=低，2=中，3=高；用户没说留空（按中等强度）",
    )
    distance_km: Optional[float] = Field(
        default=None,
        ge=0,
        le=500,
        description="运动距离（公里），适用于跑步/骑行/游泳/快走；用户没说留空",
    )
    record_date: Optional[str] = Field(
        default=None,
        description="运动日期，按用户原话填（如「今天」「昨天」「2026-10-05」）；未提及留空取今天",
    )
    explicit_request: bool = Field(
        default=False,
        description="用户是否明确要你帮记录（如「帮我记录」「记一下」）。"
        "叙述性提及（只是说跑了步，没让记）填 false —— 动作会弹「要帮你记录吗？」确认卡",
    )


SPEC = ActionSpec(
    name="record_exercise",
    description="记录用户的运动（写入运动记录，热量由系统按类型/时长/强度/体重估算，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordExerciseArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    undoable=True,
    sessions=("human",),
    examples=["我今天跑了 5 公里", "帮我记录：晚上游泳 40 分钟", "下午练了 1 小时力量训练"],
    notes=(
        "热量**由系统估算**（基于用户体重），不要自己算、也不要为凑数值反复追问；"
        "用户只报了距离（如「跑了 5 公里」）时 duration_minutes 可留空/填 0，系统按距离估算。"
        "强度（intensity）用户没提就留空，不要假定。"
    ),
)


def _parse_record_date(raw: Optional[str]) -> date:
    """运动日期：支持 ISO 日期与「今天/昨天/前天」，缺省或非法取今天（PRD 4.7）"""
    today = date.today()
    text = (raw or "").strip()
    if not text:
        return today
    if "前天" in text:
        return today - timedelta(days=2)
    if "昨天" in text or "昨日" in text:
        return today - timedelta(days=1)
    if "今天" in text or "今日" in text:
        return today
    for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            parsed = datetime.strptime(text[:10], fmt).date()
        except ValueError:
            continue
        # 未来日期会让当日汇总出现"提前消耗"，归一到今天
        return parsed if parsed <= today else today
    logger.warning(f"无法解析 record_date={raw}，按今天记录")
    return today


async def record_exercise(params: RecordExerciseArgs, ctx: ActionContext) -> ActionResult:
    """写入一条运动记录，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物运动请使用宠物工具，不写入本人的运动记录"
        )

    exercise_type = (params.exercise_type or "").strip()
    if not exercise_type:
        return ActionResult.failure(SPEC.name, "没听清是什么运动，请说「跑步」「游泳」等具体运动")

    duration = int(params.duration_minutes or 0)
    distance = float(params.distance_km) if params.distance_km else None
    if duration == 0 and not distance:
        return ActionResult.failure(
            SPEC.name, "没听清运动时长或距离，请说「跑了 5 公里」或「游泳 40 分钟」"
        )

    intensity = int(params.intensity) if params.intensity else 2
    when = _parse_record_date(params.record_date)

    confirm_params = {
        "exercise_type": exercise_type,
        "duration_minutes": duration,
        "intensity": params.intensity,
        "distance_km": params.distance_km,
        "record_date": params.record_date,
    }
    what = f"{exercise_type} {duration:g} 分钟" if duration else f"{exercise_type} {distance:g} 公里"

    # 叙述性提及但未明确要求记录 → 弹确认卡；老人线不弹卡，直接记录
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
    from shared.models.schemas.exercise import ExerciseRecordCreate
    from shared.services.exercise_service import create_exercise_record

    db = SessionLocal()
    try:
        record = create_exercise_record(
            db,
            ctx.user_id,
            ExerciseRecordCreate(
                exercise_type=exercise_type,
                duration_minutes=duration,
                intensity=intensity,
                distance_km=distance,
                record_date=when,
            ),
        )
        record_id = record.id
        burned = float(record.calories_burned or 0)
    except Exception as e:
        db.rollback()
        logger.exception("record_exercise 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    amount = f"{duration:g} 分钟" if duration else f"{distance:g} 公里"
    message = f"已记录运动：{exercise_type} {amount}"
    if burned > 0:
        message += f"，约消耗 {burned:g} 大卡"
    message += "。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(record_id),
        summary=f"{exercise_type} {amount}",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "exercise_record_id": record_id,
            "exercise_type": exercise_type,
            "duration_minutes": duration,
            "distance_km": distance,
            "calories_burned": burned,
            "record_date": when.isoformat(),
            "detail": f"{exercise_type} {amount}"
            + (f" · 约 {burned:g} 大卡" if burned > 0 else ""),
            # 运动明细归在健康页（无独立运动记录页），jump page 在 chat_page 落 /health
            "jump": {"page": "health"},
        },
        undo_token=str(record_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_exercise 动作（V6 健康档案扩权）"""
    registry.register(SPEC, record_exercise)