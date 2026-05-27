from pydantic import BaseModel, Field
from datetime import datetime, date
from typing import Optional


class WaterIntakeCreate(BaseModel):
    amount_ml: int = Field(..., gt=0, le=5000, description="饮水量（毫升）")
    record_time: datetime = Field(default_factory=datetime.now, description="喝水时间")
    drink_type: Optional[str] = Field("水", max_length=20, description="饮品类型：水/茶/咖啡/果汁等")


class WaterIntakeOut(BaseModel):
    id: int
    user_id: int
    amount_ml: int
    record_time: datetime
    drink_type: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class DailyWaterSummary(BaseModel):
    date: date
    total_intake_ml: int
    daily_goal_ml: int
    completion_rate: float  # 0.0 ~ 1.0
    records_count: int
    records: list[WaterIntakeOut]


class WaterStatistics(BaseModel):
    period: str  # 7d / 30d
    total_days: int
    goal_met_days: int
    compliance_rate: float
    average_daily_ml: float
    daily_data: list[dict]