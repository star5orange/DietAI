from sqlalchemy.orm import Session
from sqlalchemy import func
from shared.models.water_models import WaterIntakeRecord
from shared.models.user_models import UserProfile
from shared.models.schemas.water import WaterIntakeCreate
from datetime import date, datetime, timedelta
from typing import List, Optional


def create_water_record(db: Session, user_id: int, record: WaterIntakeCreate) -> WaterIntakeRecord:
    """创建喝水记录"""
    db_record = WaterIntakeRecord(user_id=user_id, **record.dict())
    db.add(db_record)
    db.commit()
    db.refresh(db_record)
    return db_record


def get_water_records(
    db: Session, user_id: int, start_date: Optional[date] = None, end_date: Optional[date] = None,
    skip: int = 0, limit: int = 20
) -> List[WaterIntakeRecord]:
    """查询喝水记录"""
    query = db.query(WaterIntakeRecord).filter(WaterIntakeRecord.user_id == user_id)
    if start_date:
        query = query.filter(func.date(WaterIntakeRecord.record_time) >= start_date)
    if end_date:
        query = query.filter(func.date(WaterIntakeRecord.record_time) <= end_date)
    return query.order_by(WaterIntakeRecord.record_time.desc()).offset(skip).limit(limit).all()


def get_daily_water_summary(db: Session, user_id: int, target_date: Optional[date] = None) -> dict:
    """获取指定日期的喝水汇总"""
    if target_date is None:
        target_date = date.today()
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    daily_goal = profile.daily_water_goal if profile else 2000
    records = db.query(WaterIntakeRecord).filter(
        WaterIntakeRecord.user_id == user_id,
        func.date(WaterIntakeRecord.record_time) == target_date
    ).all()
    total_ml = sum(r.amount_ml for r in records)
    return {
        "date": target_date,
        "total_intake_ml": total_ml,
        "daily_goal_ml": daily_goal,
        "completion_rate": min(total_ml / daily_goal, 1.0) if daily_goal > 0 else 0.0,
        "records_count": len(records),
        "records": records
    }


def get_water_statistics(db: Session, user_id: int, period: str = "7d") -> dict:
    """获取喝水统计"""
    days = int(period.replace("d", ""))
    start_date = date.today() - timedelta(days=days - 1)
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    daily_goal = profile.daily_water_goal if profile else 2000

    records = db.query(WaterIntakeRecord).filter(
        WaterIntakeRecord.user_id == user_id,
        func.date(WaterIntakeRecord.record_time) >= start_date
    ).all()

    daily_data = {}
    for r in records:
        key = str(r.record_time.date())
        if key not in daily_data:
            daily_data[key] = 0
        daily_data[key] += r.amount_ml

    goal_met_days = sum(1 for v in daily_data.values() if v >= daily_goal)
    total_days = days
    total_intake = sum(daily_data.values())

    return {
        "period": period,
        "total_days": total_days,
        "goal_met_days": goal_met_days,
        "compliance_rate": round(goal_met_days / total_days, 2) if total_days else 0,
        "average_daily_ml": round(total_intake / total_days, 2) if total_days else 0,
        "daily_data": daily_data
    }