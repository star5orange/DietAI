import logging
from sqlalchemy.orm import Session
from sqlalchemy import func
from shared.models.exercise_models import ExerciseRecord
from shared.models.user_models import UserProfile
from shared.models.food_models import DailyNutritionSummary
from shared.models.schemas.exercise import ExerciseRecordCreate
from datetime import date, timedelta
from typing import List, Optional

logger = logging.getLogger(__name__)

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


def calculate_calories(db: Session, user_id: int, exercise_type: str,
                       duration_minutes: int, intensity: int) -> float:
    """根据运动类型、时长、强度和用户体重估算热量消耗"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile or not profile.weight:
        return 0.0
    met = MET_VALUES.get(exercise_type, 5.0)
    intensity_factor = {1: 0.8, 2: 1.0, 3: 1.2}.get(intensity, 1.0)
    calories = met * float(profile.weight) * (duration_minutes / 60) * intensity_factor
    return round(calories, 2)


def create_exercise_record(db: Session, user_id: int,
                           record: ExerciseRecordCreate) -> ExerciseRecord:
    """创建运动记录，自动计算热量（如果未提供），并同步到每日营养汇总"""
    if record.calories_burned is None:
        record.calories_burned = calculate_calories(
            db, user_id, record.exercise_type, record.duration_minutes, record.intensity
        )
    db_record = ExerciseRecord(user_id=user_id, **record.dict())
    db.add(db_record)
    # 先 flush 确保记录写入，然后更新汇总
    db.flush()
    _recalc_daily_exercise(db, user_id, record.record_date)
    db.commit()
    db.refresh(db_record)
    return db_record


def get_exercise_records(
    db: Session, user_id: int,
    start_date: Optional[date] = None, end_date: Optional[date] = None,
    skip: int = 0, limit: int = 20
) -> List[ExerciseRecord]:
    """查询运动记录，支持日期范围"""
    query = db.query(ExerciseRecord).filter(ExerciseRecord.user_id == user_id)
    if start_date:
        query = query.filter(ExerciseRecord.record_date >= start_date)
    if end_date:
        query = query.filter(ExerciseRecord.record_date <= end_date)
    return query.order_by(ExerciseRecord.record_date.desc())\
                .offset(skip).limit(limit).all()


def update_exercise_record(db: Session, record_id: int, user_id: int,
                           record: ExerciseRecordCreate) -> ExerciseRecord:
    """更新运动记录，并重新计算当天每日营养汇总中的运动消耗"""
    db_record = db.query(ExerciseRecord).filter(
        ExerciseRecord.id == record_id, ExerciseRecord.user_id == user_id
    ).first()
    if not db_record:
        raise ValueError("运动记录不存在")

    old_date = db_record.record_date
    update_data = record.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_record, key, value)
    db.flush()

    # 重新计算当天汇总（始终基于数据库中当天全部记录求和）
    _recalc_daily_exercise(db, user_id, db_record.record_date)
    # 如果日期变了，旧日期的汇总也要重算
    if old_date != db_record.record_date:
        _recalc_daily_exercise(db, user_id, old_date)

    db.commit()
    db.refresh(db_record)
    return db_record


def delete_exercise_record(db: Session, record_id: int, user_id: int) -> None:
    """删除运动记录，并重新计算当天每日营养汇总中的运动消耗"""
    db_record = db.query(ExerciseRecord).filter(
        ExerciseRecord.id == record_id, ExerciseRecord.user_id == user_id
    ).first()
    if not db_record:
        raise ValueError("运动记录不存在")

    record_date = db_record.record_date
    db.delete(db_record)
    db.flush()

    # 删除后重算当天汇总
    _recalc_daily_exercise(db, user_id, record_date)

    db.commit()


def get_exercise_statistics(db: Session, user_id: int,
                            period: str = "7d") -> dict:
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
        "average_calories_per_session": round(total_calories / total_sessions, 2)
        if total_sessions else 0,
        "daily_breakdown": daily_breakdown
    }


# ==================== 内部辅助 ====================


def _recalc_daily_exercise(db: Session, user_id: int, record_date: date):
    """重新计算并更新指定日期的运动消耗汇总。

    使用 SELECT ... FOR UPDATE 防竞态条件。
    如果当天无汇总记录，自动创建。
    """
    # 1. 计算当天的总运动消耗（基于 exercise_records 表，而非 self 加减）
    total_burned = db.query(func.coalesce(func.sum(ExerciseRecord.calories_burned), 0)).filter(
        ExerciseRecord.user_id == user_id,
        ExerciseRecord.record_date == record_date
    ).scalar()

    # 2. 获取或创建每日营养汇总行（带行锁防竞态）
    summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date == record_date
    ).with_for_update().first()

    if summary:
        summary.exercise_calories = float(total_burned)
    else:
        # 自动创建
        summary = DailyNutritionSummary(
            user_id=user_id,
            summary_date=record_date,
            exercise_calories=float(total_burned),
            total_calories=0,
            total_protein=0,
            total_fat=0,
            total_carbohydrates=0,
            total_fiber=0,
            total_sodium=0,
            water_intake=0,
            meal_count=0,
        )
        db.add(summary)

    logger.debug(
        f"Recalculated daily exercise: user={user_id}, "
        f"date={record_date}, total={float(total_burned):.1f} kcal"
    )
