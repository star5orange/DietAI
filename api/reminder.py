from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.reminder import ReminderCreate, ReminderUpdate, ReminderOut
from shared.services.reminder_service import (
    create_reminder, get_reminders, get_reminder, update_reminder, delete_reminder
)
from typing import List, Optional

router = APIRouter(prefix="/api/reminders", tags=["reminders"])


@router.post("/", response_model=ReminderOut)
def create(reminder: ReminderCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return create_reminder(db, user.id, reminder)


@router.get("/", response_model=List[ReminderOut])
def list_reminders(reminder_type: Optional[str] = None, db: Session = Depends(get_db), user=Depends(get_current_user)):
    return get_reminders(db, user.id, reminder_type)


@router.get("/{reminder_id}", response_model=ReminderOut)
def get(reminder_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    reminder = get_reminder(db, reminder_id, user.id)
    if not reminder:
        raise HTTPException(status_code=404, detail="提醒不存在")
    return reminder


@router.put("/{reminder_id}", response_model=ReminderOut)
def update(reminder_id: int, reminder: ReminderUpdate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        return update_reminder(db, reminder_id, user.id, reminder)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{reminder_id}")
def delete(reminder_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        delete_reminder(db, reminder_id, user.id)
        return {"message": "删除成功"}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))