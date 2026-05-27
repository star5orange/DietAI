from pydantic import BaseModel, Field
from datetime import time, datetime
from typing import Optional


class ReminderCreate(BaseModel):
    reminder_type: str = Field(..., pattern="^(water|meal)$", description="提醒类型：water/meal")
    remind_time: time = Field(..., description="提醒时间 HH:MM")
    repeat_days: int = Field(127, ge=0, le=127, description="重复日 bitmask，默认127=每天")
    is_enabled: bool = Field(True, description="是否启用")
    title: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = Field(None)


class ReminderUpdate(BaseModel):
    reminder_type: Optional[str] = Field(None, pattern="^(water|meal)$")
    remind_time: Optional[time] = None
    repeat_days: Optional[int] = Field(None, ge=0, le=127)
    is_enabled: Optional[bool] = None
    title: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None


class ReminderOut(BaseModel):
    id: int
    user_id: int
    reminder_type: str
    remind_time: time
    repeat_days: int
    is_enabled: bool
    title: Optional[str]
    description: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True