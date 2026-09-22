"""record_water：记录喝水（V5.1 写操作，可撤销）。

量词处理（PRD 4.3 / D5 / D13）：
- App 端（默认渠道）：模糊量词 → 返回待确认卡（card_type=pending_confirm）+ 快捷选项，一次点击答完
- 老人线（input_channel=hardware，硬件语音）：不追问，按默认值记录，事后可在记录页修改
- 用户给了明确数值（500ml）→ 直接记录

落库复用 shared.services.water_service.create_water_record：它会同步 daily_nutrition_summaries.water_intake
并失效当日汇总缓存，因此不需要在动作里重复计算饮水量。
"""

import logging
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.record_food import _parse_record_time
from agent.diet_deep_agent.actions.pending import (
    Quantifier,
    build_pending_card,
    detect_quantifier,
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

# 常见量词表（D13：先覆盖 8-10 个高频量词，实现时逐项完善）
# 顺序敏感：长量词在前（「小半杯」先于「半杯」先于「杯」）
# 每项：(量词, 追问文案, 快捷选项(ml), 老人线默认值(ml))
WATER_QUANTIFIERS: tuple[Quantifier, ...] = (
    ("小半杯", "小半杯水大概多少毫升？", (80, 100), 80),
    ("半杯", "半杯水大概多少毫升？", (100, 125), 100),
    ("大杯", "一大杯大概多少毫升？", (400, 500), 400),
    ("小瓶", "一小瓶大概多少毫升？", (300, 330), 330),
    ("一瓶", "一瓶水大概是 500ml 还是 550ml？", (500, 550), 500),
    ("一杯", "一杯大概多少毫升？", (200, 250), 250),
    ("半碗", "半碗大概多少毫升？", (100, 150), 100),
    ("一碗", "一碗大概多少毫升？", (200, 250), 250),
    ("大口", "一大口大概多少毫升？", (50, 80), 50),
    ("一口", "一口大概多少毫升？", (30, 50), 30),
    ("杯", "一杯大概多少毫升？", (200, 250), 250),
    ("瓶", "一瓶水大概是 500ml 还是 550ml？", (500, 550), 500),
    ("碗", "一碗大概多少毫升？", (200, 250), 250),
)

# 用户没给任何量词也没给数值时的兜底追问（App）与默认值（老人线）
FALLBACK_QUESTION = "这次喝了大概多少毫升？"
FALLBACK_OPTIONS = (200, 250)
FALLBACK_ELDER_DEFAULT = 250


class RecordWaterArgs(BaseModel):
    """record_water 入参（不含 user_id）"""

    amount_ml: Optional[float] = Field(
        default=None,
        description="明确的水量（毫升）。用户给了数值就填（如 500ml 填 500、「半瓶」按 250 填）；模糊量词不要自行估算，留空并填 amount_text",
    )
    amount_text: Optional[str] = Field(
        default=None,
        description="用户原话里的量词（如「一瓶」「一杯」「一碗」「一口」）。用于出快捷选项追问，未提及量词可留空",
    )
    drink_type: Optional[str] = Field(
        default=None, description="饮品类型：水/牛奶/茶/咖啡/饮料/汤；不确定留空按「水」记"
    )
    record_time: Optional[str] = Field(
        default=None,
        description="饮水时间：ISO 时间或 HH:MM。用户说「今天下午」填当天 15:00；未提及留空取当前时间（PRD 4.7）",
    )


SPEC = ActionSpec(
    name="record_water",
    description="记录用户喝了多少水（写入饮水记录，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordWaterArgs,
    card_type=CardType.RECORD_RESULT,
    requires_confirmation=True,
    undoable=True,
    examples=["帮我记录：我刚喝了一瓶水", "我喝了一杯牛奶"],
    notes=(
        "用户用了模糊量词（一瓶/一杯/一碗/一口…）时不要自行估算毫升数："
        "把原话量词填进 amount_text、amount_ml 留空，系统会出快捷选项让用户点选（PRD 4.3）。"
        "只有用户明确说了数值（500ml）才填 amount_ml。"
    ),
)


def _pending_card(
    question: str,
    pair: tuple[int, ...],
    params: RecordWaterArgs,
    when,
    drink_type: str,
) -> ActionResult:
    """构造待确认卡（就地回答，无跳转；PRD 4.8）"""
    return build_pending_card(
        action=SPEC.name,
        field="amount_ml",
        question=question,
        pair=pair,
        unit="ml",
        params={
            "drink_type": drink_type,
            "record_time": when.isoformat(),
            "amount_text": params.amount_text,
        },
    )


async def record_water(params: RecordWaterArgs, ctx: ActionContext) -> ActionResult:
    """写入一条饮水记录，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物饮水请使用宠物工具，不写入本人的饮水记录"
        )

    when = _parse_record_time(params.record_time)
    drink_type = (params.drink_type or "水").strip() or "水"
    amount = float(params.amount_ml) if params.amount_ml and params.amount_ml > 0 else None
    quantifier = detect_quantifier(WATER_QUANTIFIERS, params.amount_text)
    used_default = False

    if amount is None:
        if quantifier is not None:
            _, question, pair, elder_default = quantifier
        else:
            question, pair, elder_default = FALLBACK_QUESTION, FALLBACK_OPTIONS, FALLBACK_ELDER_DEFAULT

        if ctx.is_elder_channel:
            # 老人线：默认值记录 + 事后可改（PRD 4.3 例外 / D5）
            amount = float(elder_default)
            used_default = True
        else:
            # App 端：追问 + 快捷选项（PRD 4.3）
            return _pending_card(question, pair, params, when, drink_type)

    # 单次饮水量上限与 water_intake_records 表约束一致（gt=0, le=5000）
    if amount > 5000:
        return ActionResult.failure(
            SPEC.name, f"单次饮水量 {amount:g}ml 超出上限（5000ml），请确认后分次记录"
        )

    from shared.models.database import SessionLocal
    from shared.models.schemas.water import WaterIntakeCreate

    db = SessionLocal()
    try:
        from shared.services.water_service import create_water_record, get_daily_water_summary

        record = create_water_record(
            db,
            ctx.user_id,
            WaterIntakeCreate(amount_ml=int(round(amount)), record_time=when, drink_type=drink_type),
        )
        water_id = record.id
        daily = get_daily_water_summary(db, ctx.user_id, when.date())
        summary_public = {
            "total_intake_ml": daily["total_intake_ml"],
            "daily_goal_ml": daily["daily_goal_ml"],
            "completion_rate": daily["completion_rate"],
        }
    except Exception as e:
        db.rollback()
        logger.exception("record_water 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    label = f"{params.amount_text} " if params.amount_text else ""
    message = f"已记录饮水：{label}{amount:g}ml（{drink_type}）。10 分钟内可撤销。"
    if used_default:
        message += "本渠道按默认量记录，可在记录页修改。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(water_id),
        summary=f"饮水 {amount:g}ml（{drink_type}）",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.RECORD_RESULT,
        message=message,
        data={
            "water_record_id": water_id,
            "amount_ml": amount,
            "amount_text": params.amount_text,
            "drink_type": drink_type,
            "record_time": when.isoformat(),
            "used_default": used_default,
            "daily_water": summary_public,
            # 下一步入口（PRD 4.8 记录结果卡 → 查看今日饮食 → 饮食记录页，携带日期上下文）
            "jump": {"page": "history", "date": when.date().isoformat()},
        },
        undo_token=str(water_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_water 动作（V5.1）"""
    registry.register(SPEC, record_water)
