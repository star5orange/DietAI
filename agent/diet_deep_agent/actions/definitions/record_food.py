"""record_food：记录用户吃了什么（V5.1 写操作，可撤销）。

链路：LLM 意图解析 → record_food 动作 → 写 food_records（命中食物库时同步写
nutrition_details）→ 重算当日汇总 → 写撤销日志（PRD 4.5）。

口径与 routers/food_router.py 保持一致：营养只把 analysis_status=3 的记录计入日汇总，
用餐次数（meal_count）则按当天全部记录去重 meal_type；食物库未命中时优先用模型
estimated_calories 兜底（analysis_method=ai_estimate，仍计入汇总），无估算才仅存记录
（analysis_status=1，待补充分析）。
"""

import logging
from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.pending import (
    Quantifier,
    build_pending_card,
    build_record_confirm_card,
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

# meal_type: 1早餐 2午餐 3晚餐 4加餐 5夜宵（与 food_records 表定义一致）
MEAL_TYPE_MAP = {
    "早餐": 1,
    "早饭": 1,
    "午餐": 2,
    "午饭": 2,
    "中饭": 2,
    "中餐": 2,
    "晚餐": 3,
    "晚饭": 3,
    "加餐": 4,
    "下午茶": 4,
    "零食": 4,
    "夜宵": 5,
    "宵夜": 5,
}
MEAL_LABELS = {1: "早餐", 2: "午餐", 3: "晚餐", 4: "加餐", 5: "夜宵"}
SOURCE_TAGS = {"canteen", "delivery", "home", "restaurant", "snack", "other"}
DEFAULT_PORTION_G = 100.0

# 模糊量词表（PRD 4.3 / D5 / D13）：顺序敏感——长量词在前
# 每项：(量词, 追问文案, 快捷选项(g), 老人线默认值(g))
FOOD_QUANTIFIERS: tuple[Quantifier, ...] = (
    ("一大碗", "一大碗大概多少克？", (250, 300), 250),
    ("大半碗", "大半碗大概多少克？", (200, 250), 200),
    ("小半碗", "小半碗大概多少克？", (80, 100), 80),
    ("半碗", "半碗大概多少克？", (100, 150), 100),
    ("一小碗", "一小碗大概多少克？", (100, 150), 100),
    ("一碗", "一碗大概是 100g、150g 还是 200g？", (100, 150, 200), 150),
    ("一大杯", "一大杯大概多少克？", (400, 500), 400),
    ("一小杯", "一小杯大概多少克？", (150, 200), 150),
    ("一杯", "一杯大概是 200g 还是 250g？", (200, 250), 250),
    ("一大份", "一大份大概多少克？", (250, 300), 250),
    ("一小份", "一小份大概多少克？", (100, 150), 100),
    ("一份", "一份大概多少克？", (150, 200), 150),
    ("一小块", "一小块大概多少克？", (30, 50), 30),
    ("一块", "一块大概多少克？", (50, 100), 50),
    ("一小勺", "一小勺大概多少克？", (5, 10), 5),
    ("一勺", "一勺大概多少克？", (10, 15), 10),
    ("一个", "一个大概多少克？", (50, 100), 50),
    ("碗", "一碗大概是 100g、150g 还是 200g？", (100, 150, 200), 150),
    ("杯", "一杯大概是 200g 还是 250g？", (200, 250), 250),
    ("份", "一份大概多少克？", (150, 200), 150),
    ("块", "一块大概多少克？", (50, 100), 50),
    ("勺", "一勺大概多少克？", (10, 15), 10),
    ("个", "一个大概多少克？", (50, 100), 50),
)


class RecordFoodArgs(BaseModel):
    """record_food 入参（传给 LLM 的 schema，不含 user_id）"""

    food_name: str = Field(description="食物名称，如「宫保鸡丁」「牛奶」；多种食物请分多次调用")
    meal_type: Optional[str] = Field(
        default=None,
        description="餐次：早餐/午餐/晚餐/加餐/夜宵；不确定时留空，由系统按用餐时间推断",
    )
    quantity_g: Optional[float] = Field(
        default=None,
        description="份量（克）。**只有用户明确说了数值才填**（如「200 克」「三两」「半斤」）；"
        "模糊量词（一碗/一杯/一个/一份）不要自行估算，留空并填 quantity_text",
    )
    quantity_text: Optional[str] = Field(
        default=None,
        description="用户原话里的模糊量词（如「一碗」「一杯」「一个」「一份」「一勺」）。"
        "系统会用它在卡片里给出快捷选项，让用户一次点选（PRD 4.3）；没用量词可留空",
    )
    record_time: Optional[str] = Field(
        default=None,
        description="用餐时间：ISO 时间或 HH:MM。用户说「今天中午」填当天 12:00；未提及留空取当前时间（PRD 4.7）",
    )
    cost: Optional[float] = Field(default=None, description="花费金额（元），用户提到才填")
    source_tag: Optional[str] = Field(
        default=None,
        description="就餐来源：canteen 食堂 / delivery 外卖 / home 家里 / restaurant 餐馆 / snack 零食 / other",
    )
    explicit_request: bool = Field(
        default=False,
        description="用户是否明确要你帮记录（如「帮我记录」「记一下」「把这条记上」）。"
        "叙述性提及（只是说吃了什么，没让记）填 false —— 动作会弹「要帮你记录吗？」确认卡",
    )
    estimated_calories: Optional[float] = Field(
        default=None,
        description="你对这一份食物的热量估算（kcal），按用户说的份量估计。"
        "食物库有该食物时以库为准、此值会被忽略；库未命中时用它兜底，避免记录显示 0 千卡。"
        "不确定就留空，不要编造",
    )


SPEC = ActionSpec(
    name="record_food",
    description="记录用户吃了什么（写入饮食记录，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordFoodArgs,
    card_type=CardType.RECORD_RESULT,
    requires_confirmation=True,
    undoable=True,
    examples=["帮我记录：午饭吃了宫保鸡丁", "我刚吃了一个苹果"],
    notes=(
        "命中食物库的营养数据会同步写入今日汇总；未命中则仅存记录，不写占位营养。"
        "**只记录已发生的事**：用户已吃/正在吃才调用；「我想吃 X」「晚上打算吃 X」「X 可以吗」"
        "是未来时的征询，不要调用本动作，直接用文字给饮食建议。"
        "**食物库没收录的食物（如「泡面」「外卖炒饭」）也要照常调用本动作**，"
        "并把你按份量估算的热量填进 estimated_calories 兜底——否则记录页会显示 0 千卡；"
        "食物库命中时该估算值会被忽略，不必追求精确。"
        "用户用了模糊量词（一碗/一杯/一个/一份…）时**不要自行估算克数**：把原话量词填进 quantity_text、"
        "quantity_g 留空，系统会出快捷选项让用户点选（PRD 4.3）。"
        "复合描述（如「米饭和青菜各 100g」）按每项各 100g 估算，不要合并成一条记录。"
    ),
)


async def record_food(params: RecordFoodArgs, ctx: ActionContext) -> ActionResult:
    """写入一条饮食记录，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物喂食请使用宠物记录工具，不写入本人的饮食记录"
        )

    when = _parse_record_time(params.record_time)
    meal_type = _parse_meal_type(params.meal_type) or _infer_meal_type(when)
    source_tag = params.source_tag if params.source_tag in SOURCE_TAGS else None

    # 叙述性提及但未明确要求记录 → 弹「要帮你记录吗？」确认卡（PRD 4.2），
    # 同时查出本条饮食的营养数据随卡返回，供 LLM 先做一段饮食分析再让用户点按钮。
    # 老人线（hardware 语音）不弹卡，交给下方记录逻辑（默认值/明确值直接落库）。
    if not params.explicit_request and not ctx.is_elder_channel:
        return _confirm_card_with_nutrition(params, when, meal_type, source_tag)

    # 模糊量词（PRD 4.3）：明确数值优先；没有数值但话里有量词时，
    # App 端出待确认卡（追问 + 快捷选项），老人线取默认值直接记录、事后可改
    explicit_g = params.quantity_g if params.quantity_g and params.quantity_g > 0 else None
    quantifier = detect_quantifier(FOOD_QUANTIFIERS, params.quantity_text) if explicit_g is None else None
    used_default = False
    if explicit_g is None and quantifier is not None:
        _, question, pair, elder_default = quantifier
        if ctx.is_elder_channel:
            explicit_g = float(elder_default)
            used_default = True
        else:
            return build_pending_card(
                action=SPEC.name,
                field="quantity_g",
                question=question,
                pair=pair,
                unit="g",
                params={
                    "food_name": params.food_name,
                    "meal_type": MEAL_LABELS[meal_type],
                    "record_time": when.isoformat(),
                    "cost": params.cost,
                    "source_tag": source_tag,
                },
            )

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.food_models import FoodRecord, NutritionDetail

        matched = _lookup_food(db, params.food_name)
        # 份量优先级：LLM 填的/老人线默认值 → 食物名里写明的份量（如「150克鸡胸肉」）→ 默认 100g
        grams = explicit_g if explicit_g else (
            (matched or {}).get("portion_grams") or DEFAULT_PORTION_G
        )

        # 库未命中时的兜底：用模型估的热量（对齐 food_router 的 estimated_calories 口径），
        # 否则这条记录没有 NutritionDetail，记录页会显示 0 千卡
        ai_calories = (
            float(params.estimated_calories)
            if not matched and params.estimated_calories and params.estimated_calories > 0
            else None
        )
        counted = bool(matched) or ai_calories is not None

        record = FoodRecord(
            user_id=ctx.user_id,
            record_date=when.date(),
            record_time=when,
            meal_type=meal_type,
            food_name=params.food_name,
            recording_method=1,  # 1=手动输入（对话记录）
            from_source="manual",
            analysis_status=3 if counted else 1,  # 计入日汇总才置为已分析
            cost=params.cost,
            source_tag=source_tag,
        )
        db.add(record)
        db.flush()

        nutrition: Optional[dict[str, float]] = None
        if matched:
            nutrition = _scale_nutrition(matched["per_100g"], grams)
            db.add(
                NutritionDetail(
                    food_record_id=record.id,
                    analysis_method="food_database",
                    confidence_score=0.9,
                    **nutrition,
                )
            )
        elif ai_calories is not None:
            nutrition = {"calories": ai_calories}
            db.add(
                NutritionDetail(
                    food_record_id=record.id,
                    calories=ai_calories,
                    analysis_method="ai_estimate",  # 与食物库/硬件来源区分，仅热量
                    confidence_score=0.6,
                )
            )
        db.commit()
        db.refresh(record)
        record_id = record.id
        totals = refresh_daily_summary(db, ctx.user_id, record.record_date)
    except Exception as e:
        db.rollback()
        logger.exception("record_food 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    label = MEAL_LABELS[meal_type]
    if not matched and ai_calories is not None:
        message = (
            f"已记录{label}：{params.food_name}（约 {grams:g}g，约 {ai_calories:g} kcal，"
            f"食物库未收录，热量为 AI 估算值）。10 分钟内可撤销。"
        )
    elif not matched:
        message = (
            f"已记录{label}：{params.food_name}（约 {grams:g}g）。"
            f"食物库暂无该食物营养数据，本条暂不计入今日热量。想补上营养："
            f"请用 App 首页的「拍照记录」拍一张这盘菜（AI 图像分析会自动补营养并落库），"
            f"或在记录页手动补充。10 分钟内可撤销。"
        )
    elif matched.get("multi_part"):
        # 复合描述按「每项各 100g」估算，份量口径与单条不同，需在文案里说明
        message = (
            f"已记录{label}：{params.food_name}，约 {nutrition['calories']:g} kcal"
            f"（营养按「{matched['matched_name']}」各项 100g 估算）。10 分钟内可撤销。"
        )
    else:
        message = (
            f"已记录{label}：{params.food_name} 约 {grams:g}g，约 {nutrition['calories']:g} kcal"
            f"（营养数据来自「{matched['matched_name']}」）。10 分钟内可撤销。"
        )
    if used_default:
        # 老人线：按量词表默认值记录，须明确告知可事后修改（PRD 4.3 例外 / D5）
        message += f"本渠道按默认量「{params.quantity_text}≈{grams:g}g」记录，可在记录页修改。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(record_id),
        summary=f"{label}·{params.food_name} {grams:g}g",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.RECORD_RESULT,
        message=message,
        data={
            "record_id": record_id,
            "food_name": params.food_name,
            "meal_type": meal_type,
            "meal_type_label": label,
            "record_time": when.isoformat(),
            "quantity_g": grams,
            "quantity_text": params.quantity_text,
            "used_default": used_default,
            "nutrition_matched": bool(matched),
            "matched_food_name": matched["matched_name"] if matched else None,
            "nutrition": nutrition,
            "daily_totals": totals,
            "cost": params.cost,
            "source_tag": source_tag,
            # 下一步入口（PRD 4.8 记录结果卡 → 查看今日饮食 → 饮食记录页，携带日期上下文）
            "jump": {"page": "history", "date": when.date().isoformat()},
        },
        undo_token=str(record_id),
        undo_deadline=entry.deadline_iso(),
    )


def refresh_daily_summary(db: Any, user_id: int, summary_date: date) -> dict[str, Any]:
    """重算某日营养汇总（营养只统计 analysis_status=3 的记录；用餐次数按全部记录去重 meal_type）"""
    from shared.models.food_models import (
        DailyNutritionSummary,
        FoodRecord,
        NutritionDetail,
    )
    from sqlalchemy import func

    records = (
        db.query(FoodRecord)
        .filter(
            FoodRecord.user_id == user_id,
            FoodRecord.record_date == summary_date,
            FoodRecord.analysis_status == 3,
        )
        .all()
    )

    total_cal = total_pro = total_fat = total_carb = total_fib = total_sod = 0.0
    for r in records:
        detail = (
            db.query(NutritionDetail).filter(NutritionDetail.food_record_id == r.id).first()
        )
        if detail:
            total_cal += float(detail.calories or 0)
            total_pro += float(detail.protein or 0)
            total_fat += float(detail.fat or 0)
            total_carb += float(detail.carbohydrates or 0)
            total_fib += float(detail.dietary_fiber or 0)
            total_sod += float(detail.sodium or 0)

    # 用餐次数口径：当天全部记录去重 meal_type（不受 analysis_status 影响）
    meal_count = db.query(func.count(func.distinct(FoodRecord.meal_type))).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date == summary_date,
    ).scalar() or 0

    summary = (
        db.query(DailyNutritionSummary)
        .filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date == summary_date,
        )
        .first()
    )
    if summary is None:
        summary = DailyNutritionSummary(user_id=user_id, summary_date=summary_date)
        db.add(summary)

    summary.total_calories = round(total_cal, 2)
    summary.total_protein = round(total_pro, 2)
    summary.total_fat = round(total_fat, 2)
    summary.total_carbohydrates = round(total_carb, 2)
    summary.total_fiber = round(total_fib, 2)
    summary.total_sodium = round(total_sod, 2)
    summary.meal_count = meal_count
    db.commit()

    # 失效「今日汇总」缓存：首页/健康页读的 /foods/daily-summary 有 2 小时 Redis 缓存，
    # 这里重算后若不失效，record_food / undo 之后用户会看到最长 2 小时的旧数值。
    try:
        from shared.config.redis_config import cache_service

        cache_service.redis.delete(f"nutrition:daily:{user_id}:{summary_date}")
    except Exception as e:  # 缓存不可用不影响数据落库
        logger.warning(f"失效每日营养汇总缓存失败（非致命）: {e}")

    return {
        "date": summary_date.isoformat(),
        "total_calories": round(total_cal, 2),
        "total_protein": round(total_pro, 2),
        "total_fat": round(total_fat, 2),
        "total_carbohydrates": round(total_carb, 2),
        "total_fiber": round(total_fib, 2),
        "total_sodium": round(total_sod, 2),
        "meal_count": meal_count,
    }


def _lookup_food(db: Any, food_name: str) -> Optional[dict[str, Any]]:
    """在食物库中查找，返回每 100g 营养数据

    匹配规则（归一化 / 复合切分 / 反向包含）统一由 shared.services.food_matching
    提供，与 food_router 的自动填充、回溯脚本共用同一套口径。
    """
    from shared.services.food_matching import match_food

    return match_food(db, food_name)


def _confirm_card_with_nutrition(
    params: RecordFoodArgs,
    when: datetime,
    meal_type: int,
    source_tag: Optional[str],
) -> ActionResult:
    """叙述性提及的确认卡：查营养库并换算份量，把营养数据随卡返回给 LLM。

    让 LLM 读到 calories/protein/fat 等数据后，能先针对这条饮食写一两句
    分析（如「泡面约 470 大卡，钠偏高…」），再提示用户点「帮我记录」按钮
    （需求 2026-09-26）。不落库，仅做分析与辅助展示。
    """
    from shared.models.database import SessionLocal

    matched: Optional[dict[str, Any]] = None
    db = SessionLocal()
    try:
        matched = _lookup_food(db, params.food_name)
    finally:
        db.close()

    # 份量仅用于「这条大概多少/营养估算」的分析文案；不覆盖原始 quantity_g，避免后续误当明确值
    explicit_g = params.quantity_g if params.quantity_g and params.quantity_g > 0 else None
    estimate_grams = explicit_g or (matched or {}).get("portion_grams") or DEFAULT_PORTION_G
    nutrition = _scale_nutrition(matched["per_100g"], estimate_grams) if matched else None

    return build_record_confirm_card(
        action=SPEC.name,
        what=params.food_name,
        params={
            "food_name": params.food_name,
            "meal_type": MEAL_LABELS[meal_type],
            "record_time": when.isoformat(),
            "quantity_text": params.quantity_text,
            "quantity_g": params.quantity_g,
            "cost": params.cost,
            "source_tag": source_tag,
            # 用户点「帮我记录」后下一轮重新调用时，从此处带回估算热量，
            # 避免食物库未收录时记录页显示 0 千卡
            "estimated_calories": params.estimated_calories,
        },
        analysis={
            "nutrition_matched": bool(matched),
            "nutrition": nutrition,
            "estimate_grams": estimate_grams,
        },
    )


def _scale_nutrition(per_100g: dict[str, float], grams: float) -> dict[str, float]:
    """按份量换算营养（库中数据为每 100g）"""
    ratio = grams / 100.0
    return {key: round(value * ratio, 2) for key, value in per_100g.items()}


def _parse_meal_type(raw: Optional[str]) -> Optional[int]:
    """解析餐次：支持 1-5 数字与中文（早/午/晚/加餐/夜宵）"""
    if raw is None:
        return None
    text = str(raw).strip()
    if not text:
        return None
    if text.isdigit():
        value = int(text)
        return value if value in MEAL_LABELS else None
    for keyword, value in MEAL_TYPE_MAP.items():
        if keyword in text:
            return value
    return None


def _infer_meal_type(when: datetime) -> int:
    """按用餐时间推断餐次（未指定 meal_type 时的兜底）"""
    hour = when.hour
    if 5 <= hour < 10:
        return 1
    if 10 <= hour < 15:
        return 2
    if 15 <= hour < 17:
        return 4
    if 17 <= hour < 21:
        return 3
    return 5


def _parse_record_time(raw: Optional[str]) -> datetime:
    """归一化用餐时间（PRD 4.7）：支持 ISO / HH:MM，缺省或非法时取当前时间"""
    now = datetime.now()
    if not raw:
        return now

    text = str(raw).strip()
    parsed: Optional[datetime] = None
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%H:%M:%S", "%H:%M"):
        try:
            value = datetime.strptime(text, fmt)
        except ValueError:
            continue
        parsed = value if fmt.startswith("%Y") else datetime.combine(now.date(), value.time())
        break

    if parsed is None:
        try:
            parsed = datetime.fromisoformat(text)
        except ValueError:
            logger.warning(f"无法解析 record_time={raw}，按当前时间记录")
            return now

    if parsed > now:  # 防止未来时间污染后续日期的汇总
        return now
    return parsed


def register(registry: ActionRegistry) -> None:
    """注册 record_food 动作（V5.1）"""
    registry.register(SPEC, record_food)