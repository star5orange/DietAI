"""query_pet：查宠物最近吃得怎么样（二期查询动作，TREND 卡）。

对应 PRD 二期「宠物饮食趋势」：如「我家猫这周吃得怎么样」。
数据源直接复用既有 LangChain 工具：
- tools/pet_data.get_pet_daily_summary：逐日热量/蛋白/脂肪汇总 + 达标统计
- tools/pet_data.calculate_pet_nutrition_target：每日蛋白目标（趋势分析入参）
- tools/pet_diet_trend.analyze_weekly_diet_trend：趋势结论文案
查询类动作不写数据、不需要确认、不可撤销（PRD 4.2）。
宠物只按名称定位，入参里不出现 user_id（由 ctx 注入）。
"""

import logging
from typing import Any, Optional

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

# 跳转映射（PRD 4.8）：宠物详情由页面层承载
JUMP_PAGE = "health"
DEFAULT_DAYS = 7
MIN_DAYS = 1
MAX_DAYS = 90


class QueryPetArgs(BaseModel):
    """query_pet 入参（不含 user_id）"""

    pet_name: Optional[str] = Field(
        default=None,
        description="用户口头说的宠物名（如「咪咪」）；用户没提且只有一只宠物时可留空",
    )
    days: Optional[int] = Field(
        default=None, description="查询天数：用户说「这周」填 7、「这两天」填 2；未提及按 7 天"
    )


SPEC = ActionSpec(
    name="query_pet",
    description="查询宠物最近几天的饮食情况（平均热量、达标天数、趋势）",
    kind=ActionKind.QUERY,
    args_schema=QueryPetArgs,
    card_type=CardType.TREND,
    requires_confirmation=False,
    undoable=False,
    sessions=("human", "pet"),
    examples=["我家猫这周吃得怎么样", "咪咪最近吃得好吗", "旺财这两天吃了多少"],
    notes=(
        "查询类动作，不写数据、不需要确认；只回答问题本身，不要顺便记录。"
        "不要传 user_id；宠物用 pet_name 定位，用户没提且只有一只宠物时系统会自动用那一只。"
    ),
)


def _resolve_pet(db, user_id: int, pet_name: Optional[str]) -> tuple[Optional[Any], Optional[str]]:
    """按名称定位宠物；未给名称时仅在只有一只宠物时返回唯一那只"""
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
    return None, f"你有 {len(pets)} 只宠物（{names}），请说明要查哪一只"


def _normalize_days(raw: Optional[int]) -> int:
    """天数归一化：缺省 7 天，越界按区间收敛（避免一次拉过多数据）"""
    if raw is None:
        return DEFAULT_DAYS
    try:
        value = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_DAYS
    if value <= 0:
        return DEFAULT_DAYS
    return max(MIN_DAYS, min(value, MAX_DAYS))


def _fallback_daily(pet_id: int, days: int) -> tuple[list[dict], dict]:
    """降级聚合：改由喂食记录工具按天汇总（口径与 get_pet_daily_summary 一致）。

    背景：tools/pet_data.get_pet_daily_summary 内部把 @tool 装饰后的
    calculate_pet_nutrition_target 当普通函数调用（pet_data.py:420），运行期必报
    'StructuredTool' object is not callable，该工具当前不可用。此处不改动既有文件，
    用同模块可用的喂食记录工具 + 营养目标工具重算，保证查询动作可用。
    """
    from agent.diet_deep_agent.tools.pet_data import (
        calculate_pet_nutrition_target,
        get_pet_feeding_records,
    )

    feed = get_pet_feeding_records.invoke({"pet_id": pet_id, "days": days})
    if not isinstance(feed, dict) or feed.get("error"):
        raise RuntimeError(str((feed or {}).get("error") or "喂食记录读取异常"))
    records = feed.get("records") or []

    totals: dict[str, dict[str, float]] = {}
    for item in records:
        day = str(item.get("date") or "")
        if not day:
            continue
        bucket = totals.setdefault(
            day, {"calories": 0.0, "protein": 0.0, "fat": 0.0, "meals": 0}
        )
        bucket["calories"] += float(item.get("calories") or 0)
        bucket["protein"] += float(item.get("protein") or 0)
        bucket["fat"] += float(item.get("fat") or 0)
        bucket["meals"] += 1

    daily = [
        {
            "date": day,
            "total_calories": round(data["calories"]),
            "total_protein": round(data["protein"], 1),
            "total_fat": round(data["fat"], 1),
            "meal_count": data["meals"],
        }
        for day, data in sorted(totals.items())[-days:]
    ]

    targets = calculate_pet_nutrition_target.invoke({"pet_id": pet_id}) or {}
    target_cal = int((targets.get("daily_targets", {}) or {}).get("calories_kcal", 0) or 0)
    total_calories = sum(item["total_calories"] for item in daily)
    average = round(total_calories / len(daily)) if daily else 0
    on_target_days = sum(
        1 for item in daily if target_cal > 0 and 0.85 <= item["total_calories"] / target_cal <= 1.15
    )
    stats = {
        "total_calories": total_calories,
        "avg_calories_per_day": average,
        "target_calories_per_day": target_cal,
        "on_target_days": on_target_days,
        "on_target_rate": round(on_target_days / len(daily) * 100) if daily else 0,
    }
    return daily, stats


async def query_pet(params: QueryPetArgs, ctx: ActionContext) -> ActionResult:
    """汇总宠物最近若干天的饮食趋势"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    days = _normalize_days(params.days)

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        pet, pet_error = _resolve_pet(db, ctx.user_id, params.pet_name)
        if pet is None:
            return ActionResult.failure(SPEC.name, pet_error or "没有定位到宠物，无法查询")
        pet_id = pet.id
        pet_label = pet.name or f"宠物{pet.id}"
    except Exception as e:
        logger.exception("query_pet 定位宠物失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    try:
        from agent.diet_deep_agent.tools.pet_data import (
            calculate_pet_nutrition_target,
            get_pet_daily_summary,
        )
        from agent.diet_deep_agent.tools.pet_diet_trend import analyze_weekly_diet_trend

        summary = get_pet_daily_summary.invoke({"pet_id": pet_id, "days": days})
        if isinstance(summary, dict) and summary.get("daily_summaries") is not None and not summary.get("error"):
            daily_summaries = summary.get("daily_summaries") or []
            stats = summary.get("stats") or {}
        else:
            logger.warning(
                f"get_pet_daily_summary 不可用（{(summary or {}).get('error', '返回异常')}），"
                "改由喂食记录聚合"
            )
            daily_summaries, stats = _fallback_daily(pet_id, days)

        target = float(stats.get("target_calories_per_day") or 0)
        average = float(stats.get("avg_calories_per_day") or 0)
        on_target_days = int(stats.get("on_target_days") or 0)
        days_tracked = len(daily_summaries)

        points = [
            {"date": item.get("date"), "value": float(item.get("total_calories") or 0)}
            for item in daily_summaries
        ]
        # change：区间内最后一天相对第一天的变化（不足两天记 0）
        change = round(points[-1]["value"] - points[0]["value"], 2) if len(points) >= 2 else 0.0

        trend_advice = None
        if daily_summaries:
            targets = calculate_pet_nutrition_target.invoke({"pet_id": pet_id})
            target_protein = float(
                (targets or {}).get("daily_targets", {}).get("protein_g", 0) or 0
            )
            trend = analyze_weekly_diet_trend.invoke(
                {
                    "pet_id": pet_id,
                    "daily_summaries": daily_summaries,
                    "target_calories": int(target),
                    "target_protein": target_protein,
                }
            )
            if isinstance(trend, dict):
                trend_advice = trend.get("advice")
    except Exception as e:
        logger.exception("query_pet 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")

    jump = {"page": JUMP_PAGE, "pet_id": pet_id}

    if days_tracked == 0:
        return ActionResult(
            ok=True,
            action=SPEC.name,
            card_type=CardType.TREND,
            message=f"{pet_label} 近 {days} 天还没有喂食记录，先记录几次喂食我就能给出趋势啦。",
            data={
                "pet_id": pet_id,
                "pet_name": pet_label,
                "points": [],
                "unit": "kcal",
                "average": 0,
                "target": target,
                "change": 0,
                "days_tracked": 0,
                "has_data": False,
                "jump": jump,
            },
        )

    message = f"{pet_label} 近 {days} 天平均每天 {average:g} kcal，达标 {on_target_days} 天（共记录 {days_tracked} 天）。"
    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.TREND,
        message=message,
        data={
            "pet_id": pet_id,
            "pet_name": pet_label,
            "points": points,
            "unit": "kcal",
            "average": average,
            "target": target,
            "change": change,
            "days_tracked": days_tracked,
            "on_target_days": on_target_days,
            "on_target_rate": float(stats.get("on_target_rate") or 0),
            "total_calories": float(stats.get("total_calories") or 0),
            "trend_advice": trend_advice,
            "has_data": True,
            "jump": jump,
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_pet 动作（二期）"""
    registry.register(SPEC, query_pet)
