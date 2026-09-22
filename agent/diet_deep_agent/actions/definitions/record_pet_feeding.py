"""record_pet_feeding：记录喂宠物（二期写操作，可撤销）。

对应 PRD 二期「宠物喂养记录」：用户说「帮我记一下喂了猫」即可落一条喂食记录。
量词处理与 record_water 一致（PRD 4.3 / D5 / D13）：
- App 端（默认渠道）：份量模糊 → 返回待确认卡（card_type=pending_confirm）+ 快捷选项
- 老人线（input_channel=hardware，硬件语音）：不追问，按默认值记录，事后可在记录页修改
- 用户给了明确克数 → 直接记录

落库复用 shared.services.real_pet_service.add_feeding：
它会同步当日 pet_daily_summaries，因此动作内不重复做汇总计算。
宠物定位只按名称（用户口头说的宠物名），入参里不出现 user_id（由 ctx 注入）。
"""

import logging
from datetime import datetime, time
from typing import Any, Optional

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

# 跳转映射（PRD 4.8）：宠物详情由页面层承载
JUMP_PAGE = "health"

# 常见份量量词表（顺序敏感：长量词在前）；每项 = (量词, 追问文案, 快捷选项(g), 老人线默认值(g))
PET_QUANTIFIERS: tuple[Quantifier, ...] = (
    ("一大碗", "一大碗大概多少克？", (80, 100), 100),
    ("小半碗", "小半碗大概多少克？", (30, 50), 30),
    ("半碗", "半碗大概多少克？", (30, 50), 50),
    ("一碗", "一碗大概是 50g 还是 100g？", (50, 100), 100),
    ("一大勺", "一大勺大概多少克？", (50, 100), 50),
    ("一勺", "一勺大概多少克？", (30, 50), 30),
    ("一小把", "一小把大概多少克？", (30, 50), 30),
    ("一把", "一把大概多少克？", (30, 50), 50),
    ("一袋", "一袋大概多少克？", (50, 100), 100),
    ("一罐", "一罐大概多少克？", (50, 100), 100),
    ("一盒", "一盒大概多少克？", (50, 100), 100),
)

# 用户没给克数也没给量词时的兜底追问（App）与默认值（老人线）
FALLBACK_QUESTION = "这次喂了多少克？"
FALLBACK_OPTIONS = (30, 50, 100)
FALLBACK_ELDER_DEFAULT = 50

# 餐次词 → 当天时刻（用户说「早上喂的」「夜宵」时用于归属记录时间）
MEAL_TIME_HOURS = {
    "早餐": 8,
    "早": 8,
    "早上": 8,
    "午餐": 12,
    "中餐": 12,
    "中": 12,
    "中午": 12,
    "加餐": 15,
    "下午": 15,
    "下午茶": 15,
    "晚餐": 18,
    "晚": 18,
    "晚上": 18,
    "夜宵": 22,
    "宵夜": 22,
    "夜": 22,
}


class RecordPetFeedingArgs(BaseModel):
    """record_pet_feeding 入参（不含 user_id）"""

    pet_name: Optional[str] = Field(
        default=None,
        description="用户口头说的宠物名（如「咪咪」「旺财」）；用户没提且只有一只宠物时可留空",
    )
    food_name: Optional[str] = Field(
        default=None, description="喂的食物名称（如「猫粮」「罐头」）；不确定可留空"
    )
    amount: Optional[str] = Field(
        default=None,
        description="用户原话里的份量（如「一碗」「一勺」「50克」）。模糊量词不要自行估算克数，留空交给系统追问",
    )
    amount_grams: Optional[float] = Field(
        default=None, description="明确的克数。用户说了数值就填（如「50克」填 50）"
    )
    meal_time: Optional[str] = Field(
        default=None, description="喂食时间：早/中/晚/夜宵，或 HH:MM / ISO 时间；未提及留空取当前时间"
    )


SPEC = ActionSpec(
    name="record_pet_feeding",
    description="记录用户喂了宠物什么（写入宠物喂食记录，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordPetFeedingArgs,
    card_type=CardType.RECORD_RESULT,
    requires_confirmation=True,
    undoable=True,
    sessions=("human", "pet"),
    examples=["帮我记一下喂了猫", "刚才给咪咪喂了一碗猫粮", "给旺财喂了 50 克狗粮"],
    notes=(
        "用户用了模糊量词（一碗/一勺/一把…）或没说份量时不要自行估算克数："
        "把原话填进 amount、amount_grams 留空，系统会出快捷选项让用户点选（PRD 4.3）。"
        "只有用户明确说了数值（50 克）才填 amount_grams。"
        "不要传 user_id；宠物用 pet_name 定位，用户没提且只有一只宠物时系统会自动用那一只。"
    ),
)


def _resolve_record_time(meal_time: Optional[str]) -> datetime:
    """归一化喂食时间：餐次词取当天对应时刻，否则按 ISO/HH:MM 解析，缺省取当前时间"""
    if not meal_time:
        return datetime.now()
    text = str(meal_time).strip()
    if text in MEAL_TIME_HOURS:
        return datetime.combine(datetime.now().date(), time(hour=MEAL_TIME_HOURS[text]))
    return _parse_record_time(text)


def _resolve_pet(db, user_id: int, pet_name: Optional[str]) -> tuple[Optional[Any], Optional[str]]:
    """按名称定位宠物（PRD：宠物动作不接收 user_id，靠名称 + 归属校验定位）。

    返回 (宠物对象, 错误文案)。未给名称时仅在只有一只宠物时返回唯一那只。
    """
    from shared.services.real_pet_service import get_pets

    pets = get_pets(db, user_id)
    if not pets:
        return None, "你还没有添加宠物，请先在「宠物」页面添加宠物档案"

    name = (pet_name or "").strip()
    if name:
        exact = [p for p in pets if (p.name or "").strip() == name]
        matched = exact or [p for p in pets if name in (p.name or "")]
        if not matched:
            return None, f"没有找到叫「{name}」的宠物，请先在宠物页添加"
        if len(matched) > 1:
            names = "、".join((p.name or f"宠物{p.id}") for p in matched)
            return None, f"有 {len(matched)} 只宠物都叫「{name}」（{names}），请说明是哪一只"
        return matched[0], None

    if len(pets) == 1:
        return pets[0], None

    names = "、".join((p.name or f"宠物{p.id}") for p in pets)
    return None, f"你有 {len(pets)} 只宠物（{names}），请说明是给哪一只"


def _pending_card(
    pet_name: str,
    food_name: Optional[str],
    params: RecordPetFeedingArgs,
    when: datetime,
    question: str,
    pair: tuple[float, ...],
) -> ActionResult:
    """构造待确认卡（就地回答，无跳转；PRD 4.8）"""
    return build_pending_card(
        action=SPEC.name,
        field="amount_grams",
        question=question,
        pair=pair,
        unit="g",
        params={
            "pet_name": pet_name,
            "food_name": food_name,
            "meal_time": params.meal_time,
            "amount": params.amount,
            "record_time": when.isoformat(),
        },
    )


async def record_pet_feeding(params: RecordPetFeedingArgs, ctx: ActionContext) -> ActionResult:
    """写入一条宠物喂食记录，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")

    when = _resolve_record_time(params.meal_time)
    grams = float(params.amount_grams) if params.amount_grams and params.amount_grams > 0 else None
    quantifier = detect_quantifier(PET_QUANTIFIERS, params.amount)
    used_default = False

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.services.real_pet_service import add_feeding

        pet, pet_error = _resolve_pet(db, ctx.user_id, params.pet_name)
        if pet is None:
            return ActionResult.failure(SPEC.name, pet_error or "没有定位到宠物，无法记录")

        # 先取出标量字段：db.close() 后 ORM 实例会 detached，不能再访问其属性
        pet_id = int(pet.id)
        pet_label = pet.name or f"宠物{pet_id}"
        food_name = (params.food_name or "").strip() or None

        if grams is None:
            if quantifier is not None:
                _, question, pair, elder_default = quantifier
            else:
                question, pair, elder_default = (
                    FALLBACK_QUESTION,
                    FALLBACK_OPTIONS,
                    FALLBACK_ELDER_DEFAULT,
                )

            if ctx.is_elder_channel:
                # 老人线：默认值记录 + 事后可改（PRD 4.3 例外 / D5）
                grams = float(elder_default)
                used_default = True
            else:
                # App 端：追问 + 快捷选项（PRD 4.3）
                return _pending_card(pet_label, food_name, params, when, question, pair)

        # 单次喂食上限兜底（防止模型把「一袋」等误当克数导致离谱数据）
        if grams > 5000:
            return ActionResult.failure(
                SPEC.name, f"单次喂食量 {grams:g}g 超出上限（5000g），请确认后再说一次"
            )

        record = add_feeding(
            db,
            pet_id,
            {
                "food_name": food_name,
                "amount_grams": grams,
                "record_time": when,
                "from_source": "manual",
            },
        )
        record_id = record.id
        calories = float(record.calories) if record.calories is not None else None
        saved_time = record.record_time.isoformat() if record.record_time else when.isoformat()
    except Exception as e:
        db.rollback()
        logger.exception("record_pet_feeding 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    food_label = food_name or "食物"
    message = f"已记录：给 {pet_label} 喂了 {food_label} {grams:g}g。10 分钟内可撤销。"
    if used_default:
        message += "本渠道按默认量记录，可在记录页修改。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(record_id),
        summary=f"给 {pet_label} 喂 {food_label} {grams:g}g",
        payload={"pet_id": pet_id, "pet_name": pet_label},
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.RECORD_RESULT,
        message=message,
        data={
            "pet_id": pet_id,
            "pet_name": pet_label,
            "food_name": food_name,
            "amount_grams": grams,
            "amount_text": params.amount,
            "calories": calories,
            "record_time": saved_time,
            "used_default": used_default,
            "jump": {"page": JUMP_PAGE, "pet_id": pet_id},
        },
        undo_token=str(record_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_pet_feeding 动作（二期）"""
    registry.register(SPEC, record_pet_feeding)
