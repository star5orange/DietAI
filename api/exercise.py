from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.exercise import ExerciseRecordCreate, ExerciseRecordOut, ExerciseStatistics
from shared.services.exercise_service import (
    create_exercise_record, get_exercise_records, update_exercise_record,
    delete_exercise_record, get_exercise_statistics,
)
from datetime import date
from typing import List, Optional

router = APIRouter(prefix="/api/exercises", tags=["exercises"])


@router.post("/records", response_model=ExerciseRecordOut)
def create(record: ExerciseRecordCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return create_exercise_record(db, user.id, record)


@router.get("/records", response_model=List[ExerciseRecordOut])
def list_records(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return get_exercise_records(db, user.id, start_date, end_date, skip, limit)


@router.put("/records/{record_id}", response_model=ExerciseRecordOut)
def update(record_id: int, record: ExerciseRecordCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        return update_exercise_record(db, record_id, user.id, record)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/records/{record_id}")
def delete(record_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        delete_exercise_record(db, record_id, user.id)
        return {"message": "删除成功"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/statistics", response_model=ExerciseStatistics)
def statistics(period: str = "7d", db: Session = Depends(get_db), user=Depends(get_current_user)):
    return get_exercise_statistics(db, user.id, period)