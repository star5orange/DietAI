"""query_nutrition：查近 N 天某营养素摄入够不够（TREND 卡）。

PRD 二期查询动作：「我这周蛋白质够吗」→ 逐日折线 + 日均 vs 推荐结论；
PRD 4.8 趋势卡：结论 + 关键数字 + 下一步入口（查看健康分析 → 健康页）。

数据来源与 routers/health_router.py 的 analyze_nutrition_balance 口径一致：
DailyNutritionSummary 逐日汇总；推荐量复用 shared/utils/nutrition_calc 的
calculate_bmr / calculate_tdee / calculate_daily_targets（不直接调用路由函数）。
"""

import logging
from datetime import date, timedelta
from typing import Optional

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

# 跳转映射（PRD 4.8）：趋势卡 → 健康分析页
JUMP_PAGE = "health"

# 营养素口径：命中关键词 → 汇总字段 / 推荐量 key / 单位 / 中文名
# 顺序敏感：更长/更具体的词在前，避免「碳水」被「蛋白」之类的短词抢先匹配
NUTRIENT_SPECS: tuple[dict, ...] = (
    {
        "key": "protein",
        "label": "蛋白质",
        "keywords": ("蛋白质", "蛋白質", "蛋白"),
        "field": "total_protein",
        "target_key": "protein",
        "unit": "g",
    },
    {
        "key": "carbs",
        "label": "碳水",
        "keywords": ("碳水化合物", "碳水", "醣类", "糖类"),
        "field": "total_carbohydrates",
        "target_key": "carbs",
        "unit": "g",
    },
    {
        "key": "fat",
        "label": "脂肪",
        "keywords": ("脂肪", "油脂"),
        "field": "total_fat",
        "target_key": "fat",
        "unit": "g",
    },
    {
        "key": "fiber",
        "label": "膳食纤维",
        "keywords": ("膳食纤维", "纤维素", "纤维"),
        "field": "total_fiber",
        "target_key": "fiber",
        "unit": "g",
    },
    {
        "key": "calories",
        "label": "热量",
        "keywords": ("热量", "熱量", "卡路里", "能量", "kcal"),
        "field": "total_calories",
        "target_key": "calories",
        "unit": "kcal",
    },
)
DEFAULT_NUTRIENT = NUTRIENT_SPECS[0]  # 用户没指定营养素时默认按蛋白质


class QueryNutritionArgs(BaseModel):
    """query_nutrition 入参（不含 user_id）"""

    days: Optional[int] = Field(
        default=None, description="统计天数：这周=7、这个月=30；未提及按 7 天"
    )
    nutrient: Optional[str] = Field(
        default=None,
        description="用户提到的营养素中文名（蛋白质/脂肪/碳水/热量/纤维）；未提及留空，默认按蛋白质",
    )


SPEC = ActionSpec(
    name="query_nutrition",
    description="查询用户近 N 天某营养素（蛋白质/脂肪/碳水/热量/纤维）的摄入够不够",
    kind=ActionKind.QUERY,
    args_schema=QueryNutritionArgs,
    card_type=CardType.TREND,
    requires_confirmation=False,
    undoable=False,
    examples=["我这周蛋白质够吗", "最近一个月脂肪吃多了没", "这几天纤维达标了吗"],
    notes=(
        "查询类动作，不写数据、不需要确认；只回答问题本身，不要顺便记录。"
        "用户没指明营养素时按蛋白质回答；用户说「这周」用 days=7、「这个月」用 days=30。"
        "没有记录时如实说明，不要编造摄入量。"
    ),
)


def _normalize_days(raw: Optional[int]) -> int:
    """归一统计天数：缺省 7，限制在 1~365 天，避免异常入参"""
    try:
        days = int(raw) if raw is not None else 7
    except (TypeError, ValueError):
        days = 7
    return max(1, min(days, 365))


def _resolve_nutrient(raw: Optional[str]) -> dict:
    """把用户口语归一到营养素口径；未提及或没听懂则默认按蛋白质"""
    if not raw:
        return DEFAULT_NUTRIENT
    text = str(raw).strip()
    if not text:
        return DEFAULT_NUTRIENT
    for spec in NUTRIENT_SPECS:
        if any(word in text for word in spec["keywords"]):
            return spec
    logger.warning(f"未能识别营养素={raw}，按蛋白质处理")
    return DEFAULT_NUTRIENT


def _daily_targets(db, user_id: int) -> dict:
    """推荐摄入量：用户资料 + 进行中目标 → BMR/TDEE → 每日推荐（口径同 health 分析）"""
    from shared.models.user_models import HealthGoal, UserProfile
    from shared.utils.nutrition_calc import (
        GoalType,
        calculate_age,
        calculate_bmr,
        calculate_daily_targets,
        calculate_tdee,
    )

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()

    age = calculate_age(profile.birth_date) if profile and profile.birth_date else 30
    weight = float(profile.weight) if profile and profile.weight else 70.0
    height = float(profile.height) if profile and profile.height else 170.0
    gender = (profile.gender if profile and profile.gender else 1)
    activity_level = (profile.activity_level if profile and profile.activity_level else 2)
    crowd_tag = profile.crowd_tag if profile else None

    bmr = calculate_bmr(weight, height, age, gender)
    tdee = calculate_tdee(bmr, activity_level)

    active_goal = (
        db.query(HealthGoal)
        .filter(HealthGoal.user_id == user_id, HealthGoal.current_status == 1)
        .first()
    )
    goal_type = active_goal.goal_type if active_goal else GoalType.MAINTAIN

    return calculate_daily_targets(tdee, goal_type, crowd_tag)


async def query_nutrition(params: QueryNutritionArgs, ctx: ActionContext) -> ActionResult:
    """汇总近 N 天某营养素的逐日摄入，并给出日均 vs 推荐的结论"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    days = _normalize_days(params.days)
    nutrient = _resolve_nutrient(params.nutrient)
    today = date.today()
    start_date = today - timedelta(days=days - 1)

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.food_models import DailyNutritionSummary

        summaries = (
            db.query(DailyNutritionSummary)
            .filter(
                DailyNutritionSummary.user_id == ctx.user_id,
                DailyNutritionSummary.summary_date >= start_date,
                DailyNutritionSummary.summary_date <= today,
            )
            .order_by(DailyNutritionSummary.summary_date.asc())
            .all()
        )

        points = [
            {
                "date": summary.summary_date.isoformat(),
                "value": round(float(getattr(summary, nutrient["field"]) or 0), 2),
            }
            for summary in summaries
        ]

        targets = _daily_targets(db, ctx.user_id)
        target = round(float(targets.get(nutrient["target_key"], 0)), 2)
    except Exception as e:
        logger.exception("query_nutrition 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    label = nutrient["label"]
    unit = nutrient["unit"]
    days_with_data = len(points)

    if not points:
        message = f"近 {days} 天还没有饮食记录，暂时看不出{label}够不够。"
        average = 0.0
        change = 0.0
    else:
        total = sum(point["value"] for point in points)
        # 日均按「有记录的天数」计算，避免漏记的天被当成 0 拉低结果
        average = round(total / days_with_data, 2)
        change = round(points[-1]["value"] - points[0]["value"], 2)
        verdict = "达到" if average >= target else "低于"
        message = f"近 {days} 天{label}日均 {average:g}{unit}，{verdict}推荐 {target:g}{unit}"
        if days_with_data < days:
            message += f"（基于 {days_with_data} 天有记录）"
        message += "。"

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.TREND,
        message=message,
        data={
            "points": points,
            "unit": unit,
            "target": target,
            "average": average,
            "change": change,
            "nutrient": label,
            "days": days,
            "days_with_data": days_with_data,
            "jump": {"page": JUMP_PAGE, "nutrient": label, "days": days},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_nutrition 动作（PRD 二期）"""
    registry.register(SPEC, query_nutrition)
