from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class NotificationResponseCreate(BaseModel):
    reminder_id: int = Field(..., description="关联的提醒ID")
    action_type: str = Field(..., pattern="^(drank|ate|snooze|skipped)$", description="响应类型")


class NotificationResponseOut(BaseModel):
    id: int
    user_id: int
    reminder_id: int
    responded_at: datetime
    action_type: str
    created_at: datetime

    class Config:
        from_attributes = True