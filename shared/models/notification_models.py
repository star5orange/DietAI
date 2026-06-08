from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, func, Index
from .database import Base

class NotificationResponse(Base):
    __tablename__ = "notification_responses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reminder_id = Column(Integer, ForeignKey("reminders.id"), nullable=False)
    responded_at = Column(DateTime, nullable=False)
    action_type = Column(String(20))                     # drank/ate/snooze/skipped
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        Index('idx_notif_resp_user_reminder', 'user_id', 'reminder_id'),
        Index('idx_notif_resp_user_time', 'user_id', 'responded_at'),
    )