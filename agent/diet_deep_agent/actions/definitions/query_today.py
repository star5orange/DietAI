"""query_today：查今天吃了多少（V5.1 查询动作，DAILY_SUMMARY 卡）。

PRD 3.1「我今天吃了多少」→ 今日汇总 + 营养进度；
PRD 4.8 今日汇总卡：结论 + 关键数字 + 下一步入口（查看详情 → 首页 / 健康分析页）。
细节（每条记录）留给页面，卡片只给汇总与餐次概要。
"""

import logging
from datetime import date, datetime, timedelta
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.record_food import MEAL_LABELS
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

DEFAULT_CALORIE_TARGET = 2000
DEFAULT_WATER_TARGET_ML = 2000
# 跳转映射（PRD 4.8）：卡片带「下一步入口」，前端按 page 定位页面并携带 date
JUMP_PAGE = "health_analysis"


class QueryTodayArgs(BaseModel):
    """query_today 入参（不含 user_id）"""

    day: Optional[str] = Field(
        default=None, description="查询日期：今天/昨天/前天，或 YYYY-MM-DD；未提及按今天"
    )


SPEC = ActionSpec(
    name="query_today",
    description="查询用户某天的饮食与饮水汇总（今日热量、营养进度、用餐次数）",
    kind=ActionKind.QUERY,
    args_schema=QueryTodayArgs,
    card_type=CardType.DAILY_SUMMARY,
    requires_confirmation=False,
    undoable=False,
    examples=["我今天吃了多少", "我今天热量超了吗", "昨天喝了多少水"],
    notes="查询类动作，不写数据、不需要确认；只回答问题本身，不要顺便记录。",
)


def _resolve_day(raw: Optional[str]) -> date:
    """解析日期（PRD 4.7 时间归属）：今天/昨天/前天/YYYY-MM-DD，缺省按今天"""
    today = date.today()
    if not raw:
        return today
    text = str(raw).strip()
    aliases = {"今天": 0, "今日": 0, "昨天": 1, "昨日": 1, "前天": 2}
    if text in aliases:
        return today - timedelta(days=aliases[text])
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        logger.warning(f"无法解析查询日期={raw}，按今天处理")
        return today


def _target_calories(db, user_id: int) -> int:
    """热量目标：用户资料 target_calories → 按 BMR/TDEE 推算 → 默认 2000

    HealthGoal 表没有热量字段（只有 goal_type / current_status），
    因此「进行中的目标」只用来决定 goal_type，热量统一由 nutrition_calc 推算，
    口径与 query_nutrition / 健康分析页保持一致。
    """
    from shared.models.user_models import HealthGoal, UserProfile

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if profile and profile.target_calories:
        return int(profile.target_calories)

    try:
        from shared.utils.nutrition_calc import (
            GoalType,
            calculate_age,
            calculate_bmr,
            calculate_daily_targets,
            calculate_tdee,
        )

        age = calculate_age(profile.birth_date) if profile and profile.birth_date else 30
        weight = float(profile.weight) if profile and profile.weight else 70.0
        height = float(profile.height) if profile and profile.height else 170.0
        gender = profile.gender if profile and profile.gender else 1
        activity_level = profile.activity_level if profile and profile.activity_level else 2
        crowd_tag = profile.crowd_tag if profile else None

        active_goal = (
            db.query(HealthGoal)
            .filter(HealthGoal.user_id == user_id, HealthGoal.current_status == 1)
            .first()
        )
        goal_type = active_goal.goal_type if active_goal else GoalType.MAINTAIN

        targets = calculate_daily_targets(
            calculate_tdee(calculate_bmr(weight, height, age, gender), activity_level),
            goal_type,
            crowd_tag,
        )
        calories = targets.get("calories") if isinstance(targets, dict) else None
        if calories:
            return int(calories)
    except Exception as e:
        logger.warning(f"推算热量目标失败（非致命），改用默认值: {e}")

    return DEFAULT_CALORIE_TARGET


async def query_today(params: QueryTodayArgs, ctx: ActionContext) -> ActionResult:
    """汇总指定日期的饮食与饮水数据"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    target_date = _resolve_day(params.day)

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.food_models import (
            DailyNutritionSummary,
            FoodRecord,
            NutritionDetail,
        )
        from shared.services.water_service import get_daily_water_summary

        summary = (
            db.query(DailyNutritionSummary)
            .filter(
                DailyNutritionSummary.user_id == ctx.user_id,
                DailyNutritionSummary.summary_date == target_date,
            )
            .first()
        )

        records = (
            db.query(FoodRecord)
            .filter(
                FoodRecord.user_id == ctx.user_id,
                FoodRecord.record_date == target_date,
                FoodRecord.analysis_status == 3,
            )
            .order_by(FoodRecord.record_time.asc(), FoodRecord.id.asc())
            .all()
        )
        pending_count = (
            db.query(FoodRecord)
            .filter(
                FoodRecord.user_id == ctx.user_id,
                FoodRecord.record_date == target_date,
                FoodRecord.analysis_status != 3,
            )
            .count()
        )

        # 各餐次概要（明细留给页面；卡片只给餐次 + 食物名 + 该餐热量）
        meals: dict[int, dict[str, Any]] = {}
        for record in records:
            detail = (
                db.query(NutritionDetail)
                .filter(NutritionDetail.food_record_id == record.id)
                .first()
            )
            bucket = meals.setdefault(
                record.meal_type,
                {
                    "meal_type": record.meal_type,
                    "meal_type_label": MEAL_LABELS.get(record.meal_type, "其他"),
                    "items": [],
                    "calories": 0.0,
                },
            )
            if record.food_name:
                bucket["items"].append(record.food_name)
            if detail:
                bucket["calories"] += float(detail.calories or 0)

        intake = round(float(summary.total_calories or 0), 2) if summary else 0.0
        water = get_daily_water_summary(db, ctx.user_id, target_date)
        target = _target_calories(db, ctx.user_id)
    except Exception as e:
        logger.exception("query_today 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    remaining = round(target - intake, 2)
    meal_list = [
        {**meals[key], "calories": round(meals[key]["calories"], 2)}
        for key in sorted(meals.keys())
    ]
    day_label = "今天" if target_date == date.today() else target_date.strftime("%m月%d日")
    conclusion = (
        f"{day_label}已摄入 {intake:g} kcal，距目标还差 {remaining:g} kcal"
        if remaining >= 0
        else f"{day_label}已摄入 {intake:g} kcal，超出目标 {abs(remaining):g} kcal"
    )

    message = conclusion + f"；饮水 {water['total_intake_ml']}ml。"
    if pending_count:
        message += f"另有 {pending_count} 条记录待补营养（暂未计入热量）。"

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.DAILY_SUMMARY,
        message=message,
        data={
            "date": target_date.isoformat(),
            "calories": {
                "intake": intake,
                "target": float(target),
                "remaining": remaining,
                "progress": round(min(intake / target, 1.0), 2) if target else 0.0,
            },
            "macros": {
                "protein": round(float(summary.total_protein or 0), 2) if summary else 0.0,
                "fat": round(float(summary.total_fat or 0), 2) if summary else 0.0,
                "carbohydrates": round(float(summary.total_carbohydrates or 0), 2)
                if summary
                else 0.0,
                "fiber": round(float(summary.total_fiber or 0), 2) if summary else 0.0,
                "sodium": round(float(summary.total_sodium or 0), 2) if summary else 0.0,
            },
            "water": {
                "intake_ml": water["total_intake_ml"],
                "goal_ml": water["daily_goal_ml"],
                "progress": water["completion_rate"],
            },
            "meal_count": summary.meal_count if summary else 0,
            "meals": meal_list,
            "pending_nutrition_count": pending_count,
            "jump": {"page": JUMP_PAGE, "date": target_date.isoformat()},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_today 动作（V5.1）"""
    registry.register(SPEC, query_today)
