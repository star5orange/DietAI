"""generate_weekly_report：出一份饮食周报（V6 二期查询动作，WEEKLY_REPORT 卡）。

PRD 二期动作：用户一句「给我出一份饮食周报」→ 汇总最近 7 天的饮食、饮水、体重与达标情况，
给一段「人话」摘要 + 3-5 条亮点 + 一句建议，卡片带入口跳到周报页（PRD 4.8）。

口径参考 routers/health_router.py 的周度摘要（`get_weekly_summary` / `_generate_weekly_summary_text`），
但这里只借鉴计算逻辑，不复用路由函数（动作域不依赖 routers/）。

宠物会话（ctx.is_pet_session）或用户点名宠物时走宠物周报：
复用 tools/pet_data.py 的 get_pet_daily_summary 与 tools/pet_diet_trend.py 的 analyze_weekly_diet_trend。
该周没有记录时不编造，返回「没有记录」的提示。
"""

import logging
from datetime import date, timedelta
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

DEFAULT_CALORIE_TARGET = 2000
# 跳转映射（PRD 4.8）：周报卡 → 周报页
JUMP_PAGE = "weekly_report"
# 周报口径：包含结束日的最近 7 天
WEEK_DAYS = 7
# 每日营养汇总字段（口径与 health_router 一致）
FIELDS = (
    "total_calories",
    "total_protein",
    "total_fat",
    "total_carbohydrates",
    "total_fiber",
    "exercise_calories",
    "water_intake",  # 单位：升
)
NO_DATA_MESSAGE = "这一周还没有饮食记录，先把记录补上我再帮你出周报"


class GenerateWeeklyReportArgs(BaseModel):
    """generate_weekly_report 入参（不含 user_id）"""

    week_offset: Optional[int] = Field(
        default=0, description="第几周：0=本周（最近7天，默认），1=上周"
    )
    pet_name: Optional[str] = Field(
        default=None, description="宠物名字（给宠物出周报时填），给人出周报留空"
    )


SPEC = ActionSpec(
    name="generate_weekly_report",
    description="生成用户（或宠物）最近一周的饮食周报（热量/蛋白/饮水均值、达标情况与建议）",
    kind=ActionKind.QUERY,
    args_schema=GenerateWeeklyReportArgs,
    card_type=CardType.WEEKLY_REPORT,
    requires_confirmation=False,
    undoable=False,
    examples=["给我出一份饮食周报", "上周我吃得怎么样", "给我家猫出一份饮食周报"],
    notes=(
        "查询类动作，不写数据、不需要确认。用户没点名宠物就出本人的周报；"
        "该周没有记录时直接如实告知，不要编造数据。"
    ),
)


# ==================== 人类周报 ====================


def _resolve_week(week_offset: Optional[int]) -> tuple[date, date, date, date]:
    """按 week_offset 解析本周与上周的日期区间（含结束日的最近 7 天）"""
    offset = max(int(week_offset or 0), 0)
    end = date.today() - timedelta(days=WEEK_DAYS * offset)
    start = end - timedelta(days=WEEK_DAYS - 1)
    return start, end, start - timedelta(days=WEEK_DAYS), end - timedelta(days=WEEK_DAYS)


def _human_targets(db, user_id: int) -> dict[str, Optional[float]]:
    """每日目标：优先用户自定义热量目标；蛋白/脂肪/碳水按资料算 TDEE 推导（不猜）"""
    from shared.models.user_models import HealthGoal, UserProfile
    from shared.utils.nutrition_calc import (
        calculate_age,
        calculate_bmr,
        calculate_daily_targets,
        calculate_tdee,
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    goal = (
        db.query(HealthGoal)
        .filter(HealthGoal.user_id == user_id, HealthGoal.current_status == 1)
        .first()
    )
    goal_type = goal.goal_type if goal and goal.goal_type else 3
    crowd_tag = getattr(profile, "crowd_tag", None) if profile else None

    derived: dict[str, Any] = {}
    if (
        profile
        and profile.weight
        and profile.height
        and profile.birth_date
        and profile.gender
    ):
        try:
            age = calculate_age(profile.birth_date)
            bmr = calculate_bmr(
                float(profile.weight),
                float(profile.height),
                age,
                int(profile.gender),
            )
            tdee = calculate_tdee(bmr, int(profile.activity_level or 2))
            derived = calculate_daily_targets(tdee, goal_type, crowd_tag)
        except Exception as e:  # 资料不全/异常时退回自定义热量目标，不影响周报
            logger.warning(f"计算每日营养目标失败，改用资料热量目标: {e}")

    calorie_target = (
        float(profile.target_calories)
        if profile and profile.target_calories
        else float(derived.get("calories") or DEFAULT_CALORIE_TARGET)
    )
    return {
        "calories": calorie_target,
        "protein": float(derived["protein"]) if derived.get("protein") else None,
        "fat": float(derived["fat"]) if derived.get("fat") else None,
        "carbs": float(derived["carbs"]) if derived.get("carbs") else None,
    }


def _human_report(db, user_id: int, week_offset: Optional[int]) -> Optional[dict]:
    """汇总一周数据；该周没有任何汇总记录时返回 None（不编造）"""
    from sqlalchemy import func

    from shared.models.food_models import DailyNutritionSummary
    from shared.models.user_models import WeightRecord

    start, end, prev_start, prev_end = _resolve_week(week_offset)

    summaries = (
        db.query(DailyNutritionSummary)
        .filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date >= start,
            DailyNutritionSummary.summary_date <= end,
        )
        .order_by(DailyNutritionSummary.summary_date)
        .all()
    )
    if not summaries:
        return None

    summary_map = {s.summary_date: s for s in summaries}
    days_with_data = len(summaries)
    totals = {f: 0.0 for f in FIELDS}
    for s in summaries:
        for f in FIELDS:
            value = getattr(s, f)
            if value is not None:
                totals[f] += float(value)
    divisor = max(days_with_data, 1)
    averages = {f: round(totals[f] / divisor, 2) for f in FIELDS}

    prev_summaries = (
        db.query(DailyNutritionSummary)
        .filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date >= prev_start,
            DailyNutritionSummary.summary_date <= prev_end,
        )
        .all()
    )
    prev_avg_calories = (
        round(sum(float(s.total_calories or 0) for s in prev_summaries) / len(prev_summaries), 2)
        if prev_summaries
        else None
    )

    targets = _human_targets(db, user_id)
    calorie_target = targets["calories"] or DEFAULT_CALORIE_TARGET
    protein_target = targets["protein"]

    cal_ok_days = 0
    protein_ok_days = 0
    meal_total = 0
    current = start
    while current <= end:
        s = summary_map.get(current)
        if s is not None:
            calories = float(s.total_calories or 0)
            if calories > 0 and 0.85 <= calories / calorie_target <= 1.15:
                cal_ok_days += 1
            if protein_target and float(s.total_protein or 0) >= protein_target:
                protein_ok_days += 1
            meal_total += int(s.meal_count or 0)
        current += timedelta(days=1)

    weights = (
        db.query(WeightRecord)
        .filter(
            WeightRecord.user_id == user_id,
            func.date(WeightRecord.measured_at) >= start,
            func.date(WeightRecord.measured_at) <= end,
        )
        .order_by(WeightRecord.measured_at.asc(), WeightRecord.id.asc())
        .all()
    )
    weight_change: Optional[float] = None
    if len(weights) >= 2:
        weight_change = round(float(weights[-1].weight) - float(weights[0].weight), 2)

    return {
        "start_date": start,
        "end_date": end,
        "days_with_data": days_with_data,
        "averages": averages,
        "prev_avg_calories": prev_avg_calories,
        "calorie_target": calorie_target,
        "protein_target": protein_target,
        "cal_ok_days": cal_ok_days,
        "protein_ok_days": protein_ok_days,
        "meal_total": meal_total,
        "weight_change": weight_change,
    }


def _human_highlights(report: dict) -> list[str]:
    """3-5 条亮点（都基于真实数值，不编造）"""
    highlights: list[str] = []
    calories = report["averages"]["total_calories"]
    highlights.append(f"热量日均 {calories:g} kcal，达标 {report['cal_ok_days']}/7 天")

    protein = report["averages"]["total_protein"]
    if report["protein_target"]:
        highlights.append(f"蛋白质日均 {protein:g}g，达标 {report['protein_ok_days']}/7 天")
    else:
        highlights.append(f"蛋白质日均 {protein:g}g")

    water_ml = report["averages"]["water_intake"] * 1000
    highlights.append(f"饮水日均 {water_ml:.0f}ml")

    prev = report["prev_avg_calories"]
    if prev:
        change_pct = (calories - prev) / prev * 100
        if abs(change_pct) < 3:
            highlights.append("日均热量与上周基本持平")
        else:
            direction = "上升" if change_pct > 0 else "下降"
            highlights.append(f"日均热量较上周{direction} {abs(change_pct):.0f}%")

    if report["weight_change"] is not None and abs(report["weight_change"]) >= 0.1:
        direction = "上升" if report["weight_change"] > 0 else "下降"
        highlights.append(f"体重较上周{direction} {abs(report['weight_change']):g}kg")
    else:
        highlights.append(f"本周共记录 {report['meal_total']} 餐")

    return highlights[:5]


def _human_suggestion(report: dict) -> str:
    """一句可执行的建议"""
    calories = report["averages"]["total_calories"]
    target = report["calorie_target"] or DEFAULT_CALORIE_TARGET
    ratio = calories / target if target else 0
    if ratio < 0.85:
        return "热量摄入偏低，注意三餐规律、别漏餐。"
    if ratio > 1.15:
        return "热量摄入偏高，晚餐清淡些、少油少糖。"
    if report["protein_target"] and report["averages"]["total_protein"] < report["protein_target"] * 0.9:
        return "蛋白质还差一点，可以加个鸡蛋、牛奶或豆制品。"
    if report["averages"]["water_intake"] * 1000 < 1500:
        return "饮水偏少，记得每小时喝几口水。"
    return "整体不错，保持现在的节奏就好。"


def _human_result(report: dict, week_offset: Optional[int]) -> ActionResult:
    """把统计结果包装成周报卡"""
    start = report["start_date"]
    end = report["end_date"]
    calories = report["averages"]["total_calories"]
    protein = report["averages"]["total_protein"]
    water_ml = report["averages"]["water_intake"] * 1000
    suggestion = _human_suggestion(report)
    summary_text = (
        f"{start.strftime('%m月%d日')}-{end.strftime('%m月%d日')} 周报："
        f"日均摄入 {calories:g} kcal（热量达标 {report['cal_ok_days']}/7 天），"
        f"蛋白质 {protein:g}g，饮水 {water_ml:.0f}ml。{suggestion}"
    )

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.WEEKLY_REPORT,
        message=summary_text,
        data={
            "start_date": start.isoformat(),
            "end_date": end.isoformat(),
            "message": summary_text,
            "highlights": _human_highlights(report),
            "suggestion": suggestion,
            "averages": {
                "calories": calories,
                "protein": protein,
                "fat": report["averages"]["total_fat"],
                "carbohydrates": report["averages"]["total_carbohydrates"],
                "water_ml": round(water_ml, 1),
            },
            "days_with_data": report["days_with_data"],
            "week_offset": max(int(week_offset or 0), 0),
            "jump": {"page": JUMP_PAGE},
        },
    )


# ==================== 宠物周报 ====================


def _pet_daily_summaries(pet_id: int, days: int) -> list[dict]:
    """直查喂食记录按天聚合（口径与 tools/pet_data.get_pet_daily_summary 一致）。

    该工具当前内部会直接调用另一个 @tool 对象（`calculate_pet_nutrition_target(...)`），
    调用时会返回 `'StructuredTool' object is not callable`；本动作不改动它，
    仅在其不可用时用同一套聚合口径兜底，保证宠物周报可用。
    """
    from collections import defaultdict
    from datetime import datetime

    from shared.models.database import SessionLocal
    from shared.models.pet_models import PetFeedingRecord

    db = SessionLocal()
    try:
        cutoff = datetime.utcnow() - timedelta(days=days)
        records = (
            db.query(PetFeedingRecord)
            .filter(
                PetFeedingRecord.pet_id == pet_id,
                PetFeedingRecord.record_time >= cutoff,
            )
            .all()
        )
    finally:
        db.close()

    daily_totals: dict[str, dict] = defaultdict(
        lambda: {"calories": 0.0, "protein": 0.0, "fat": 0.0, "meals": 0}
    )
    for r in records:
        day = r.record_time.strftime("%Y-%m-%d")
        daily_totals[day]["calories"] += float(r.calories or 0)
        daily_totals[day]["protein"] += float(r.protein or 0)
        daily_totals[day]["fat"] += float(r.fat or 0)
        daily_totals[day]["meals"] += 1

    return [
        {
            "date": day,
            "total_calories": round(data["calories"]),
            "total_protein": round(data["protein"], 1),
            "total_fat": round(data["fat"], 1),
            "meal_count": data["meals"],
        }
        for day, data in sorted(daily_totals.items())[-days:]
    ]


def _resolve_pet(ctx: ActionContext, pet_name: str) -> tuple[Optional[dict], Optional[ActionResult]]:
    """定位宠物：点名按名字匹配，宠物会话取第一只；返回 (宠物, 失败结果)"""
    from agent.diet_deep_agent.tools.pet_data import get_user_pets

    result = get_user_pets.invoke({"user_id": ctx.user_id})
    pets = (result or {}).get("pets") or []
    if not pets:
        return None, ActionResult.failure(
            SPEC.name, "你还没有添加宠物，先在宠物页添加一只再来看周报吧。"
        )

    if pet_name:
        matched = [p for p in pets if (p.get("name") or "") == pet_name]
        if not matched:
            matched = [p for p in pets if pet_name in (p.get("name") or "")]
        if not matched:
            return None, ActionResult.failure(
                SPEC.name, f"没找到叫「{pet_name}」的宠物，请先在宠物页确认名字。"
            )
        return matched[0], None

    return pets[0], None


def _pet_result(ctx: ActionContext, params: GenerateWeeklyReportArgs) -> ActionResult:
    """宠物周报：复用宠物数据工具（近 7 天喂食聚合 + 趋势分析）"""
    from agent.diet_deep_agent.tools.pet_data import (
        calculate_pet_nutrition_target,
        get_pet_daily_summary,
    )
    from agent.diet_deep_agent.tools.pet_diet_trend import analyze_weekly_diet_trend

    pet_name = (params.pet_name or "").strip()
    pet, failure = _resolve_pet(ctx, pet_name)
    if failure is not None:
        return failure

    pet_id = int(pet["id"])
    name = pet.get("name") or "宠物"
    offset = max(int(params.week_offset or 0), 0)

    # get_pet_daily_summary 只给「最近 N 天」，按 offset 多取一段再切片到目标周
    lookback = WEEK_DAYS * (offset + 1)
    summary = get_pet_daily_summary.invoke({"pet_id": pet_id, "days": lookback})
    if summary.get("error"):
        # 该工具当前调用会报 'StructuredTool' object is not callable，改用同口径直查兜底
        logger.warning(f"get_pet_daily_summary 不可用，改用直查喂食记录：{summary['error']}")
        all_days = _pet_daily_summaries(pet_id, lookback)
    else:
        all_days = summary.get("daily_summaries") or []
    daily = all_days[: -WEEK_DAYS * offset] if offset > 0 else all_days
    if not daily:
        return _no_data_result(pet_name=name)

    target = calculate_pet_nutrition_target.invoke({"pet_id": pet_id})
    daily_targets = (target or {}).get("daily_targets") or {}
    trend = analyze_weekly_diet_trend.invoke(
        {
            "pet_id": pet_id,
            "daily_summaries": daily,
            "target_calories": daily_targets.get("calories_kcal") or 0,
            "target_protein": daily_targets.get("protein_g") or 0,
        }
    )

    days_analyzed = int(trend.get("days_analyzed") or len(daily))
    avg_calories = float(trend.get("avg_calories") or 0)
    avg_protein = float(trend.get("avg_protein") or 0)
    avg_fat = round(sum(float(d.get("total_fat") or 0) for d in daily) / max(len(daily), 1), 1)
    avg_ratio = int(trend.get("avg_ratio_pct") or 0)
    on_target_days = int(trend.get("on_target_days") or 0)
    protein_ratio = int(trend.get("protein_ratio_pct") or 0)
    under_days = int(trend.get("under_days") or 0)
    over_days = int(trend.get("over_days") or 0)

    highlights = [f"热量日均 {avg_calories:g} kcal，达到目标的 {avg_ratio}%"]
    highlights.append(f"达标天数 {on_target_days}/{days_analyzed} 天")
    highlights.append(f"蛋白质日均 {avg_protein:g}g（目标的 {protein_ratio}%）")
    highlights.append(f"日均喂食 {sum(int(d.get('meal_count') or 0) for d in daily) / max(len(daily), 1):.1f} 次")

    if avg_ratio < 85 or under_days > days_analyzed // 2:
        suggestion = "热量和喂食量偏低，建议适当增加喂食量或提高食物营养密度。"
    elif avg_ratio > 115 or over_days > days_analyzed // 2:
        suggestion = "热量摄入偏高，建议控制喂食量、少给零食。"
    elif trend.get("has_protein_deficit"):
        suggestion = "蛋白质持续偏低，建议增加鲜食或高蛋白粮。"
    else:
        suggestion = "整体饮食均衡，继续保持。"

    start_date = daily[0].get("date") or ""
    end_date = daily[-1].get("date") or ""
    summary_text = (
        f"{name} {start_date}~{end_date} 饮食周报："
        f"日均摄入 {avg_calories:g} kcal（目标的 {avg_ratio}%），"
        f"蛋白质日均 {avg_protein:g}g，达标 {on_target_days}/{days_analyzed} 天。{suggestion}"
    )

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.WEEKLY_REPORT,
        message=summary_text,
        data={
            "start_date": start_date,
            "end_date": end_date,
            "message": summary_text,
            "highlights": highlights[:5],
            "suggestion": suggestion,
            "averages": {
                "calories": avg_calories,
                "protein": avg_protein,
                "fat": avg_fat,
                "carbohydrates": None,
                "water_ml": None,
            },
            "pet_id": pet_id,
            "pet_name": name,
            "week_offset": offset,
            "jump": {"page": JUMP_PAGE},
        },
    )


def _no_data_result(pet_name: Optional[str] = None) -> ActionResult:
    """该周没有记录：如实告知，不编造（PRD 4.2）"""
    message = f"{pet_name} 这一周还没有饮食记录，先把记录补上我再帮你出周报" if pet_name else NO_DATA_MESSAGE
    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.WEEKLY_REPORT,
        message=message,
        data={
            "message": message,
            "highlights": [],
            "suggestion": "先记录几天饮食，我就能帮你看出规律啦。",
            "averages": {},
            "jump": {"page": JUMP_PAGE},
        },
    )


async def generate_weekly_report(
    params: GenerateWeeklyReportArgs, ctx: ActionContext
) -> ActionResult:
    """生成周报：宠物会话/点名宠物走宠物周报，否则出本人周报"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法生成周报")

    if params.pet_name or ctx.is_pet_session:
        try:
            return _pet_result(ctx, params)
        except Exception as e:
            logger.exception("generate_weekly_report 宠物周报失败")
            return ActionResult.failure(SPEC.name, f"生成宠物周报失败：{e}")

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        report = _human_report(db, ctx.user_id, params.week_offset)
    except Exception as e:
        logger.exception("generate_weekly_report 查询失败")
        return ActionResult.failure(SPEC.name, f"生成周报失败：{e}")
    finally:
        db.close()

    if report is None:
        return _no_data_result()

    return _human_result(report, params.week_offset)


def register(registry: ActionRegistry) -> None:
    """注册 generate_weekly_report 动作（V6 二期）"""
    registry.register(SPEC, generate_weekly_report)
