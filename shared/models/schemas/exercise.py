from pydantic import BaseModel, Field
from datetime import date, datetime
from typing import Optional


class ExerciseRecordCreate(BaseModel):
    exercise_type: str = Field(..., max_length=50, description="运动类型：跑步/游泳/力量训练等")
    duration_minutes: int = Field(..., gt=0, description="运动时长（分钟）")
    intensity: int = Field(..., ge=1, le=3, description="强度：1=低，2=中，3=高")
    calories_burned: Optional[float] = Field(None, ge=0, description="消耗热量，不传则自动计算")
    record_date: date = Field(..., description="运动日期")
    notes: Optional[str] = Field(None, description="备注")


class ExerciseRecordOut(BaseModel):
    id: int
    user_id: int
    exercise_type: str
    duration_minutes: int
    intensity: int
    calories_burned: float
    record_date: date
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class ExerciseStatistics(BaseModel):
    total_calories: float
    total_duration: int
    total_sessions: int
    average_calories_per_session: float
    daily_breakdown: list[dict]  # [{"date": "2026-05-01", "calories": 500, "duration": 60}, ...]