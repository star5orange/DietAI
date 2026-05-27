from sqlalchemy.orm import Session
from shared.models.notification_models import NotificationResponse
from shared.models.schemas.notification import NotificationResponseCreate
from datetime import datetime


def create_notification_response(db: Session, user_id: int, response: NotificationResponseCreate) -> NotificationResponse:
    """记录提醒响应"""
    db_resp = NotificationResponse(
        user_id=user_id,
        reminder_id=response.reminder_id,
        action_type=response.action_type,
        responded_at=datetime.now()
    )
    db.add(db_resp)
    db.commit()
    db.refresh(db_resp)
    return db_resp