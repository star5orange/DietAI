from sqlalchemy import Column, Integer, String, Boolean, Time, Text, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSON
from .database import Base

class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reminder_type = Column(String(10), nullable=False)   # water / meal
    remind_time = Column(Time, nullable=False)
    repeat_days = Column(Integer, default=127)           # bitmask 0=周日...6=周六，全选为127
    is_enabled = Column(Boolean, default=True)
    title = Column(String(100))
    description = Column(Text)
    virtual_pet_status = Column(JSON, nullable=True)     # 预留
    created_at = Column(DateTime, server_default=func.now())