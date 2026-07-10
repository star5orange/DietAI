"""消费统计业务逻辑"""
import logging
from datetime import date, datetime, timedelta
from typing import Optional, List, Dict, Any

from sqlalchemy.orm import Session
from sqlalchemy import func

from shared.models.food_models import FoodRecord
from shared.models.user_models import UserProfile

logger = logging.getLogger(__name__)

# 餐次映射
MEAL_TYPE_MAP = {1: "breakfast", 2: "lunch", 3: "dinner", 4: "snack", 5: "late_night"}

# 来源标签白名单
VALID_SOURCE_TAGS = ["canteen", "delivery", "home", "restaurant", "snack", "other"]


def get_cost_stats(db: Session, user_id: int, period: str = "week") -> Dict[str, Any]:
    """获取本周/本月消费统计数据

    Args:
        db: 数据库会话
        user_id: 用户ID
        period: 统计周期 week | month

    Returns:
        消费统计数据字典
    """
    today = date.today()

    if period == "month":
        start_date = today.replace(day=1)
    else:
        # 本周一为起始
        start_date = today - timedelta(days=today.weekday())

    # 查询周期内所有有消费金额的记录
    records = db.query(FoodRecord).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date >= start_date,
        FoodRecord.record_date <= today,
        FoodRecord.cost.isnot(None)
    ).all()

    if not records:
        return {
            "period": period,
            "total_cost": 0,
            "daily_avg": 0,
            "max_single": 0,
            "record_count": 0,
            "by_meal_time": {},
            "by_source": {},
            "calorie_per_yuan": 0,
            "budget_remaining": None,
        }

    total_cost = sum(float(r.cost) for r in records if r.cost is not None)
    record_count = len(records)
    max_single = max(float(r.cost) for r in records if r.cost is not None)

    # 日均消费
    days_in_period = (today - start_date).days + 1
    daily_avg = round(total_cost / days_in_period, 2)

    # 按餐次分类
    by_meal_time: Dict[str, float] = {}
    for r in records:
        if r.cost is not None:
            meal_key = MEAL_TYPE_MAP.get(r.meal_type, "other")
            by_meal_time[meal_key] = round(by_meal_time.get(meal_key, 0) + float(r.cost), 2)

    # 按来源分类
    by_source: Dict[str, float] = {}
    for r in records:
        if r.cost is not None:
            tag = r.source_tag if r.source_tag in VALID_SOURCE_TAGS else "other"
            by_source[tag] = round(by_source.get(tag, 0) + float(r.cost), 2)

    # 每元热量（需要关联 nutrition_details 表）
    from shared.models.food_models import NutritionDetail
    calorie_per_yuan = _calc_calorie_per_yuan(db, user_id, start_date, today, total_cost)

    # 预算剩余
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    budget = float(profile.monthly_food_budget) if profile and profile.monthly_food_budget else 0
    budget_remaining = round(budget - total_cost, 2) if budget > 0 and period == "month" else None

    return {
        "period": period,
        "total_cost": round(total_cost, 2),
        "daily_avg": daily_avg,
        "max_single": round(max_single, 2),
        "record_count": record_count,
        "by_meal_time": by_meal_time,
        "by_source": by_source,
        "calorie_per_yuan": calorie_per_yuan,
        "budget_remaining": budget_remaining,
    }


def get_cost_trend(
    db: Session,
    user_id: int,
    days: int = 7,
    source_tag: Optional[str] = None
) -> Dict[str, Any]:
    """获取近 N 天消费趋势

    Args:
        db: 数据库会话
        user_id: 用户ID
        days: 天数（7 或 30）
        source_tag: 按来源筛选

    Returns:
        趋势数据字典
    """
    today = date.today()
    start_date = today - timedelta(days=days - 1)

    query = db.query(FoodRecord).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date >= start_date,
        FoodRecord.record_date <= today,
        FoodRecord.cost.isnot(None)
    )

    if source_tag:
        query = query.filter(FoodRecord.source_tag == source_tag)

    records = query.order_by(FoodRecord.record_date).all()

    # 按日期聚合
    daily_data: Dict[str, Dict[str, Any]] = {}
    for r in records:
        key = r.record_date.isoformat()
        if key not in daily_data:
            daily_data[key] = {"date": key, "cost": 0, "records": 0}
        daily_data[key]["cost"] = round(daily_data[key]["cost"] + float(r.cost or 0), 2)
        daily_data[key]["records"] += 1

    # 填充所有日期（包括无记录的日期）
    trend = []
    total_cost = 0
    for i in range(days):
        d = start_date + timedelta(days=i)
        key = d.isoformat()
        if key in daily_data:
            trend.append(daily_data[key])
            total_cost += daily_data[key]["cost"]
        else:
            trend.append({"date": key, "cost": 0, "records": 0})

    return {
        "trend": trend,
        "total": round(total_cost, 2),
        "avg": round(total_cost / days, 2) if days > 0 else 0,
        "source_tag": source_tag,
    }


# ========== 内部辅助 ==========

def _calc_calorie_per_yuan(
    db: Session,
    user_id: int,
    start_date: date,
    end_date: date,
    total_cost: float
) -> float:
    """计算每元热量（kcal/元）"""
    if total_cost <= 0:
        return 0

    from shared.models.food_models import NutritionDetail
    total_calories = db.query(
        func.coalesce(func.sum(NutritionDetail.calories), 0)
    ).select_from(FoodRecord).join(
        NutritionDetail, FoodRecord.id == NutritionDetail.food_record_id
    ).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date >= start_date,
        FoodRecord.record_date <= end_date,
        FoodRecord.cost.isnot(None)
    ).scalar()

    return round(float(total_calories) / total_cost, 1)
