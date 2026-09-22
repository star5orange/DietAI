"""
目标追踪工具 - 计算 BMR/TDEE、每日目标、今日状态

封装 shared/utils/nutrition_calc.py 的计算函数。
"""

import logging
from datetime import date
from typing import Any, cast

from langchain_core.tools import tool

logger = logging.getLogger(__name__)


@tool
def get_daily_status(user_id: int) -> dict[str, Any]:
    """获取用户今日的营养摄入状态和剩余配额。

    返回今日已摄入的热量、蛋白质、碳水、脂肪，以及剩余的配额。

    Args:
        user_id: 用户 ID

    Returns:
        今日状态，包含 daily_targets、today_consumed、remaining_budget
    """
    from shared.models.database import SessionLocal
    db = SessionLocal()
    try:
        from shared.models.user_models import UserProfile, HealthGoal
        from shared.models.food_models import DailyNutritionSummary
        from shared.utils.nutrition_calc import (
            calculate_bmr, calculate_tdee, calculate_daily_targets,
            calculate_remaining_budget, calculate_age, GoalType
        )

        profile = db.query(UserProfile).filter(
            UserProfile.user_id == user_id
        ).first()

        if not profile:
            return {"error": "用户档案不存在"}

        age = calculate_age(cast(date, profile.birth_date)) if profile.birth_date else 30
        weight = float(cast(float, profile.weight)) if profile.weight else 70.0
        height = float(cast(float, profile.height)) if profile.height else 170.0
        gender = cast(int, profile.gender) if profile.gender else 1
        activity = cast(int, profile.activity_level) if profile.activity_level else 2

        bmr = calculate_bmr(weight, height, age, gender)
        tdee = calculate_tdee(bmr, activity)

        active_goal = db.query(HealthGoal).filter(
            HealthGoal.user_id == user_id,
            HealthGoal.current_status == 1
        ).first()

        goal_type = cast(int, active_goal.goal_type) if active_goal else GoalType.MAINTAIN
        targets = calculate_daily_targets(tdee, goal_type)

        # 今日摄入
        today = date.today()
        summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date == today
        ).first()

        consumed = {
            "calories": float(summary.total_calories) if summary and summary.total_calories else 0,
            "protein": float(summary.total_protein) if summary and summary.total_protein else 0,
            "carbs": float(summary.total_carbohydrates) if summary and summary.total_carbohydrates else 0,
            "fat": float(summary.total_fat) if summary and summary.total_fat else 0,
        }

        remaining = calculate_remaining_budget(targets, consumed)

        return {
            "bmr": bmr,
            "tdee": tdee,
            "daily_targets": targets,
            "today_consumed": consumed,
            "remaining_budget": remaining,
        }
    except Exception as e:
        logger.error(f"get_daily_status failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


@tool
def calculate_targets(
    weight: float,
    height: float,
    age: int,
    gender: int,
    activity_level: int,
    goal_type: int,
) -> dict[str, Any]:
    """计算用户的 BMR、TDEE 和每日营养目标。

    Args:
        weight: 体重（kg）
        height: 身高（cm）
        age: 年龄
        gender: 性别（1=男 2=女）
        activity_level: 活动水平（1-5）
        goal_type: 目标类型（1=减重 2=增重 3=维持 4=增肌 5=减脂）

    Returns:
        BMR、TDEE 和每日宏量营养素目标
    """
    from shared.utils.nutrition_calc import calculate_full_nutrition_profile

    return calculate_full_nutrition_profile(
        weight, height, age, gender, activity_level, goal_type
    )
