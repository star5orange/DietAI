from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.wellness import DailyWellnessRecommendation, SolarTermOut
from shared.services.wellness_service import get_daily_wellness_recommendation, get_solar_terms
from typing import Optional, List

router = APIRouter(prefix="/api/wellness", tags=["wellness"])


@router.get("/daily-recommendation", response_model=DailyWellnessRecommendation)
def daily_recommendation(
    solar_term: str = "小满",
    season: str = "夏季",
    constitution_type: Optional[str] = None,
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    return get_daily_wellness_recommendation(db, solar_term, season, constitution_type)


@router.get("/solar-terms", response_model=List[SolarTermOut])
def solar_terms(year: int = 2026, db: Session = Depends(get_db)):
    return get_solar_terms(db, year)
