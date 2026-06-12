from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.exercise import ExerciseRecordCreate, ExerciseRecordOut, ExerciseStatistics
from shared.services.exercise_service import (
    create_exercise_record, get_exercise_records, update_exercise_record,
    delete_exercise_record, get_exercise_statistics,
)
from datetime import date
from typing import List, Optional

router = APIRouter(prefix="/api/exercises", tags=["exercises"])


def _record_to_dict(record) -> dict:
    """将 ExerciseRecord ORM 对象转为可序列化的 dict"""
    return {
        "id": record.id,
        "user_id": record.user_id,
        "exercise_type": record.exercise_type,
        "exercise_name": getattr(record, 'exercise_name', None),
        "duration_minutes": record.duration_minutes,
        "intensity": record.intensity,
        "calories_burned": record.calories_burned,
        "record_date": record.record_date.isoformat() if hasattr(record.record_date, 'isoformat') else str(record.record_date),
        "notes": record.notes,
        "created_at": record.created_at.isoformat() if hasattr(record.created_at, 'isoformat') else str(record.created_at),
    }


@router.post("/records")
def create(record: ExerciseRecordCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db_record = create_exercise_record(db, user.id, record)
    return BaseResponse(
        success=True,
        message="创建运动记录成功",
        data=_record_to_dict(db_record),
    )


@router.get("/records")
def list_records(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    records = get_exercise_records(db, user.id, start_date, end_date, skip, limit)
    return BaseResponse(
        success=True,
        message="获取运动记录成功",
        data=[_record_to_dict(r) for r in records],
    )


@router.put("/records/{record_id}")
def update(record_id: int, record: ExerciseRecordCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        db_record = update_exercise_record(db, record_id, user.id, record)
        return BaseResponse(
            success=True,
            message="更新运动记录成功",
            data=_record_to_dict(db_record),
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/records/{record_id}")
def delete(record_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        delete_exercise_record(db, record_id, user.id)
        return BaseResponse(success=True, message="删除运动记录成功")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/statistics")
def statistics(period: str = "7d", db: Session = Depends(get_db), user=Depends(get_current_user)):
    stats = get_exercise_statistics(db, user.id, period)
    return BaseResponse(
        success=True,
        message="获取运动统计成功",
        data=stats,
    )
