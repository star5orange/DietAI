from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.reminder import ReminderCreate, ReminderUpdate, ReminderOut
from shared.services.reminder_service import (
    create_reminder, get_reminders, get_reminder, update_reminder, delete_reminder
)
from typing import List, Optional

router = APIRouter(prefix="/api/reminders", tags=["reminders"])


def _reminder_to_dict(r) -> dict:
    """将 Reminder ORM 对象转为可序列化的 dict"""
    return {
        "id": r.id,
        "user_id": r.user_id,
        "reminder_type": r.reminder_type,
        "remind_time": r.remind_time.isoformat() if hasattr(r.remind_time, 'isoformat') else str(r.remind_time),
        "repeat_days": r.repeat_days,
        "is_enabled": r.is_enabled,
        "title": r.title,
        "description": r.description,
        "message": getattr(r, 'message', None),
        "created_at": r.created_at.isoformat() if hasattr(r.created_at, 'isoformat') else str(r.created_at),
    }


@router.post("/")
def create(reminder: ReminderCreate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    db_record = create_reminder(db, user.id, reminder)
    return BaseResponse(
        success=True,
        message="创建提醒成功",
        data=_reminder_to_dict(db_record),
    )


@router.get("/")
def list_reminders(reminder_type: Optional[str] = None, db: Session = Depends(get_db), user=Depends(get_current_user)):
    reminders = get_reminders(db, user.id, reminder_type)
    return BaseResponse(
        success=True,
        message="获取提醒列表成功",
        data=[_reminder_to_dict(r) for r in reminders],
    )


@router.get("/{reminder_id}")
def get(reminder_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    reminder = get_reminder(db, reminder_id, user.id)
    if not reminder:
        raise HTTPException(status_code=404, detail="提醒不存在")
    return BaseResponse(
        success=True,
        message="获取提醒成功",
        data=_reminder_to_dict(reminder),
    )


@router.put("/{reminder_id}")
def update(reminder_id: int, reminder: ReminderUpdate, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        db_record = update_reminder(db, reminder_id, user.id, reminder)
        return BaseResponse(
            success=True,
            message="更新提醒成功",
            data=_reminder_to_dict(db_record),
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{reminder_id}")
def delete(reminder_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    try:
        delete_reminder(db, reminder_id, user.id)
        return BaseResponse(success=True, message="删除提醒成功")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
