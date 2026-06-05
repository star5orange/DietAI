from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.notification import NotificationResponseCreate, NotificationResponseOut
from shared.services.notification_service import create_notification_response

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.post("/responses", response_model=NotificationResponseOut)
def create_response(response: NotificationResponseCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return create_notification_response(db, user.id, response)
