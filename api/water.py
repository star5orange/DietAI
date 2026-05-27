from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.water import WaterIntakeCreate, WaterIntakeOut, DailyWaterSummary, WaterStatistics
from shared.services.water_service import (
    create_water_record, get_water_records, get_daily_water_summary, get_water_statistics
)
from datetime import date
from typing import List, Optional

router = APIRouter(prefix="/api/water", tags=["water"])


@router.post("/records", response_model=WaterIntakeOut)
def create(record: WaterIntakeCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return create_water_record(db, user.id, record)


@router.get("/records", response_model=List[WaterIntakeOut])
def list_records(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return get_water_records(db, user.id, start_date, end_date, skip, limit)


@router.get("/daily-summary/{target_date}", response_model=DailyWaterSummary)
def daily_summary(target_date: date, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return get_daily_water_summary(db, user.id, target_date)


@router.get("/statistics", response_model=WaterStatistics)
def statistics(period: str = "7d", db: Session = Depends(get_db), user=Depends(get_current_user)):
    return get_water_statistics(db, user.id, period)