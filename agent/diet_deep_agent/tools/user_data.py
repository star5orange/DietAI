"""
用户数据工具 - 从数据库查询用户档案、饮食历史、健康概要

供 DietDeepAgent 和 pattern-detector 子代理使用。
"""

import logging
from datetime import date, timedelta
from typing import Any

from langchain_core.tools import tool

logger = logging.getLogger(__name__)


def _get_db_session():
    """获取数据库会话"""
    from shared.models.database import SessionLocal
    return SessionLocal()


@tool
def get_user_profile(user_id: int) -> dict[str, Any]:
    """获取用户个人资料，包含基本信息、健康状况、过敏原、疾病等。

    Args:
        user_id: 用户 ID

    Returns:
        用户档案字典，包含 profile、allergies、diseases、active_goals
    """
    db = _get_db_session()
    try:
        from shared.models.user_models import (
            UserProfile, User, Disease, Allergy, HealthGoal
        )

        user = db.query(User).filter(User.id == user_id).first()
        profile = db.query(UserProfile).filter(
            UserProfile.user_id == user_id
        ).first()

        if not profile:
            return {"error": f"用户 {user_id} 档案不存在", "found": False}

        # 过敏原
        allergies = db.query(Allergy).filter(
            Allergy.user_id == user_id
        ).all()

        # 疾病
        diseases = db.query(Disease).filter(
            Disease.user_id == user_id
        ).all()

        # 当前活跃目标
        active_goals = db.query(HealthGoal).filter(
            HealthGoal.user_id == user_id,
            HealthGoal.current_status == 1
        ).all()

        from shared.utils.nutrition_calc import calculate_age

        return {
            "found": True,
            "profile": {
                "username": user.username if user else None,
                "gender": profile.gender,
                "height": float(profile.height) if profile.height else None,
                "weight": float(profile.weight) if profile.weight else None,
                "age": calculate_age(profile.birth_date) if profile.birth_date else None,
                "activity_level": profile.activity_level,
            },
            "allergies": [
                {"name": a.allergen_name, "severity": a.severity_level}
                for a in allergies
            ],
            "diseases": [
                {"name": d.disease_name, "severity": d.severity_level}
                for d in diseases
            ],
            "active_goals": [
                {
                    "type": g.goal_type,
                    "target_weight": float(g.target_weight) if g.target_weight else None,
                    "target_date": g.target_date.isoformat() if g.target_date else None,
                }
                for g in active_goals
            ],
        }
    except Exception as e:
        logger.error(f"get_user_profile failed: {e}")
        return {"error": str(e), "found": False}
    finally:
        db.close()


@tool
def get_diet_history(user_id: int, days: int = 7) -> dict[str, Any]:
    """获取用户近 N 天的饮食历史记录。

    Args:
        user_id: 用户 ID
        days: 查询天数（默认 7 天）

    Returns:
        饮食历史，包含每日营养汇总和食物记录
    """
    db = _get_db_session()
    try:
        from shared.models.food_models import (
            FoodRecord, NutritionDetail, DailyNutritionSummary
        )

        start_date = date.today() - timedelta(days=days)

        # 每日营养汇总
        daily_summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date >= start_date
        ).order_by(DailyNutritionSummary.summary_date.desc()).all()

        # 食物记录
        food_records = db.query(FoodRecord).filter(
            FoodRecord.user_id == user_id,
            FoodRecord.record_date >= start_date
        ).order_by(FoodRecord.record_date.desc()).limit(50).all()

        return {
            "period": f"近 {days} 天",
            "daily_summaries": [
                {
                    "date": s.summary_date.isoformat(),
                    "calories": float(s.total_calories) if s.total_calories else 0,
                    "protein": float(s.total_protein) if s.total_protein else 0,
                    "carbs": float(s.total_carbohydrates) if s.total_carbohydrates else 0,
                    "fat": float(s.total_fat) if s.total_fat else 0,
                    "meal_count": s.meal_count if hasattr(s, 'meal_count') else None,
                }
                for s in daily_summaries
            ],
            "food_records": [
                {
                    "date": r.record_date.isoformat() if r.record_date else None,
                    "meal_type": r.meal_type,
                    "food_name": r.food_name if hasattr(r, 'food_name') else None,
                    "analysis_status": r.analysis_status,
                }
                for r in food_records[:20]  # 限制返回数量
            ],
            "record_count": len(food_records),
        }
    except Exception as e:
        logger.error(f"get_diet_history failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()


@tool
def get_health_summary(user_id: int) -> dict[str, Any]:
    """获取用户健康概要，包含体重趋势、目标进度、营养均值。

    Args:
        user_id: 用户 ID

    Returns:
        健康概要字典
    """
    db = _get_db_session()
    try:
        from shared.models.user_models import (
            UserProfile, HealthGoal, WeightRecord
        )
        from shared.models.food_models import DailyNutritionSummary
        from shared.utils.nutrition_calc import (
            calculate_bmr, calculate_tdee, calculate_daily_targets,
            calculate_goal_progress, calculate_age, GoalType
        )

        profile = db.query(UserProfile).filter(
            UserProfile.user_id == user_id
        ).first()

        if not profile:
            return {"error": "用户档案不存在"}

        # BMR / TDEE
        age = calculate_age(profile.birth_date) if profile.birth_date else 30
        weight = float(profile.weight) if profile.weight else 70
        height = float(profile.height) if profile.height else 170
        gender = profile.gender or 1
        activity = profile.activity_level or 2

        bmr = calculate_bmr(weight, height, age, gender)
        tdee = calculate_tdee(bmr, activity)

        # 目标
        active_goal = db.query(HealthGoal).filter(
            HealthGoal.user_id == user_id,
            HealthGoal.current_status == 1
        ).first()

        goal_type = active_goal.goal_type if active_goal else GoalType.MAINTAIN
        targets = calculate_daily_targets(tdee, goal_type)

        # 体重趋势（近 30 天）
        weight_records = db.query(WeightRecord).filter(
            WeightRecord.user_id == user_id,
        ).order_by(WeightRecord.measured_at.desc()).limit(30).all()

        # 目标进度
        progress = None
        if active_goal and weight_records:
            starting_weight = weight  # HealthGoal 没有 starting_weight 字段，用当前体重兜底
            target_weight = (
                float(active_goal.target_weight)
                if active_goal.target_weight
                else weight
            )
            progress = calculate_goal_progress(
                starting_weight, weight, target_weight, goal_type
            )

        # 近 7 天营养均值
        week_ago = date.today() - timedelta(days=7)
        week_summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date >= week_ago
        ).all()

        if week_summaries:
            n = len(week_summaries)
            avg_nutrition = {
                "calories": round(sum(float(s.total_calories or 0) for s in week_summaries) / n),
                "protein": round(sum(float(s.total_protein or 0) for s in week_summaries) / n),
                "carbs": round(sum(float(s.total_carbohydrates or 0) for s in week_summaries) / n),
                "fat": round(sum(float(s.total_fat or 0) for s in week_summaries) / n),
                "days_tracked": n,
            }
        else:
            avg_nutrition = None

        return {
            "bmr": bmr,
            "tdee": tdee,
            "daily_targets": targets,
            "goal_progress": progress,
            "weight_trend": [
                {
                    "date": w.measured_at.isoformat() if w.measured_at else None,
                    "weight": float(w.weight) if w.weight else None,
                }
                for w in weight_records[:10]
            ],
            "weekly_avg_nutrition": avg_nutrition,
        }
    except Exception as e:
        logger.error(f"get_health_summary failed: {e}")
        return {"error": str(e)}
    finally:
        db.close()
