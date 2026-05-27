from sqlalchemy.orm import Session
from sqlalchemy import func
from shared.models.exercise_models import ExerciseRecord
from shared.models.user_models import UserProfile
from shared.models.food_models import DailyNutritionSummary
from shared.models.schemas.exercise import ExerciseRecordCreate
from datetime import date, timedelta
from typing import List, Optional

MET_VALUES = {
    "跑步": 8.0,
    "游泳": 6.0,
    "力量训练": 5.0,
    "骑行": 7.5,
    "跳绳": 10.0,
    "瑜伽": 3.0,
    "快走": 4.5,
    "篮球": 6.5,
    "足球": 7.0,
    "羽毛球": 5.5,
    "其他": 5.0,
}


def calculate_calories(db: Session, user_id: int, exercise_type: str, duration_minutes: int, intensity: int) -> float:
    """根据运动类型、时长、强度和用户体重估算热量消耗"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile or not profile.weight:
        return 0.0
    met = MET_VALUES.get(exercise_type, 5.0)
    intensity_factor = {1: 0.8, 2: 1.0, 3: 1.2}.get(intensity, 1.0)
    calories = met * profile.weight * (duration_minutes / 60) * intensity_factor
    return round(calories, 2)


def create_exercise_record(db: Session, user_id: int, record: ExerciseRecordCreate) -> ExerciseRecord:
    """创建运动记录，若热量未提供则自动计算"""
    if record.calories_burned is None:
        record.calories_burned = calculate_calories(
            db, user_id, record.exercise_type, record.duration_minutes, record.intensity
        )
    db_record = ExerciseRecord(user_id=user_id, **record.dict())
    db.add(db_record)
    db.flush()
    # 更新每日营养汇总表中的运动消耗
    _update_daily_summary_exercise(db, user_id, record.record_date)
    db.commit()
    db.refresh(db_record)
    return db_record


def get_exercise_records(
    db: Session, user_id: int, start_date: Optional[date] = None, end_date: Optional[date] = None,
    skip: int = 0, limit: int = 20
) -> List[ExerciseRecord]:
    """查询运动记录，支持日期范围"""
    query = db.query(ExerciseRecord).filter(ExerciseRecord.user_id == user_id)
    if start_date:
        query = query.filter(ExerciseRecord.record_date >= start_date)
    if end_date:
        query = query.filter(ExerciseRecord.record_date <= end_date)
    return query.order_by(ExerciseRecord.record_date.desc()).offset(skip).limit(limit).all()


def update_exercise_record(db: Session, record_id: int, user_id: int, record: ExerciseRecordCreate) -> ExerciseRecord:
    """更新运动记录"""
    db_record = db.query(ExerciseRecord).filter(ExerciseRecord.id == record_id, ExerciseRecord.user_id == user_id).first()
    if not db_record:
        raise ValueError("运动记录不存在")
    update_data = record.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_record, key, value)
    db.commit()
    db.refresh(db_record)
    return db_record


def delete_exercise_record(db: Session, record_id: int, user_id: int) -> None:
    """删除运动记录"""
    db_record = db.query(ExerciseRecord).filter(ExerciseRecord.id == record_id, ExerciseRecord.user_id == user_id).first()
    if not db_record:
        raise ValueError("运动记录不存在")
    db.delete(db_record)
    db.commit()


def get_exercise_statistics(db: Session, user_id: int, period: str = "7d") -> dict:
    """获取运动统计数据"""
    days = int(period.replace("d", ""))
    start_date = date.today() - timedelta(days=days - 1)
    records = db.query(ExerciseRecord).filter(
        ExerciseRecord.user_id == user_id,
        ExerciseRecord.record_date >= start_date
    ).all()

    total_calories = sum(r.calories_burned for r in records)
    total_duration = sum(r.duration_minutes for r in records)
    total_sessions = len(records)

    daily_breakdown = {}
    for r in records:
        key = str(r.record_date)
        if key not in daily_breakdown:
            daily_breakdown[key] = {"calories": 0, "duration": 0}
        daily_breakdown[key]["calories"] += r.calories_burned
        daily_breakdown[key]["duration"] += r.duration_minutes

    return {
        "total_calories": total_calories,
        "total_duration": total_duration,
        "total_sessions": total_sessions,
        "average_calories_per_session": round(total_calories / total_sessions, 2) if total_sessions else 0,
        "daily_breakdown": daily_breakdown
    }


def _update_daily_summary_exercise(db: Session, user_id: int, record_date: date):
    """更新每日营养汇总表中的运动消耗"""
    summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date == record_date
    ).first()
    if summary:
        total_burned = db.query(func.sum(ExerciseRecord.calories_burned)).filter(
            ExerciseRecord.user_id == user_id,
            ExerciseRecord.record_date == record_date
        ).scalar() or 0.0
        summary.exercise_calories = total_burned