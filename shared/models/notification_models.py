from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func
from .database import Base

class NotificationResponse(Base):
    __tablename__ = "notification_responses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reminder_id = Column(Integer, ForeignKey("reminders.id"), nullable=False)
    responded_at = Column(DateTime, nullable=False)
    action_type = Column(String(20))                     # drank/ate/snooze/skipped
    created_at = Column(DateTime, server_default=func.now())