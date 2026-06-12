from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.water import WaterIntakeCreate
from shared.services.water_service import (
    create_water_record, get_water_records, get_daily_water_summary, get_water_statistics
)
from datetime import date
from typing import List, Optional

router = APIRouter(prefix="/api/water", tags=["water"])


def _water_record_to_dict(record) -> dict:
    """将 WaterIntakeRecord ORM 对象转为可序列化的 dict"""
    return {
        "id": record.id,
        "user_id": record.user_id,
        "amount_ml": record.amount_ml,
        "record_time": record.record_time.isoformat() if hasattr(record.record_time, 'isoformat') else str(record.record_time),
        "drink_type": record.drink_type,
        "created_at": record.created_at.isoformat() if hasattr(record.created_at, 'isoformat') else str(record.created_at),
        # fields that the frontend WaterIntakeRecord model also expects (aliased)
        "notes": record.drink_type,
        "recorded_at": record.record_time.isoformat() if hasattr(record.record_time, 'isoformat') else str(record.record_time),
    }


@router.post("/records")
def create(record: WaterIntakeCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db_record = create_water_record(db, user.id, record)
    return BaseResponse(
        success=True,
        message="添加饮水记录成功",
        data=_water_record_to_dict(db_record),
    )


@router.get("/records")
def list_records(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(get_current_user),
):
    records = get_water_records(db, user.id, start_date, end_date, skip, limit)
    return BaseResponse(
        success=True,
        message="获取饮水记录成功",
        data=[_water_record_to_dict(r) for r in records],
    )


@router.get("/daily-summary/{target_date}")
def daily_summary(target_date: date, db: Session = Depends(get_db), user=Depends(get_current_user)):
    summary = get_daily_water_summary(db, user.id, target_date)
    return BaseResponse(
        success=True,
        message="获取每日饮水汇总成功",
        data={
            "date": str(summary["date"]),
            "total_intake_ml": summary["total_intake_ml"],
            "daily_goal_ml": summary["daily_goal_ml"],
            "completion_rate": summary["completion_rate"],
            "records_count": summary["records_count"],
        },
    )


@router.get("/statistics")
def statistics(period: str = "7d", db: Session = Depends(get_db), user=Depends(get_current_user)):
    stats = get_water_statistics(db, user.id, period)
    return BaseResponse(
        success=True,
        message="获取饮水统计成功",
        data=stats,
    )


@router.delete("/records/{record_id}")
def delete_record(record_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    from shared.models.water_models import WaterIntakeRecord
    from shared.services.water_service import _recalc_daily_water
    record = db.query(WaterIntakeRecord).filter(
        WaterIntakeRecord.id == record_id,
        WaterIntakeRecord.user_id == user.id,
    ).first()
    if not record:
        raise HTTPException(status_code=404, detail="饮水记录不存在")
    record_date = record.record_time.date()
    db.delete(record)
    _recalc_daily_water(db, user.id, record_date)
    db.commit()
    return BaseResponse(success=True, message="饮水记录已删除")
