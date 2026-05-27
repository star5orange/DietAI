from sqlalchemy.orm import Session
from shared.models.reminder_models import Reminder
from shared.models.schemas.reminder import ReminderCreate, ReminderUpdate
from typing import List


def create_reminder(db: Session, user_id: int, reminder: ReminderCreate) -> Reminder:
    """创建提醒"""
    db_reminder = Reminder(user_id=user_id, **reminder.dict())
    db.add(db_reminder)
    db.commit()
    db.refresh(db_reminder)
    return db_reminder


def get_reminders(db: Session, user_id: int, reminder_type: str = None) -> List[Reminder]:
    """获取提醒列表"""
    query = db.query(Reminder).filter(Reminder.user_id == user_id)
    if reminder_type:
        query = query.filter(Reminder.reminder_type == reminder_type)
    return query.all()


def get_reminder(db: Session, reminder_id: int, user_id: int) -> Reminder:
    """获取单个提醒"""
    return db.query(Reminder).filter(Reminder.id == reminder_id, Reminder.user_id == user_id).first()


def update_reminder(db: Session, reminder_id: int, user_id: int, reminder: ReminderUpdate) -> Reminder:
    """更新提醒"""
    db_reminder = get_reminder(db, reminder_id, user_id)
    if not db_reminder:
        raise ValueError("提醒不存在")
    update_data = reminder.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_reminder, key, value)
    db.commit()
    db.refresh(db_reminder)
    return db_reminder


def delete_reminder(db: Session, reminder_id: int, user_id: int) -> None:
    """删除提醒"""
    db_reminder = get_reminder(db, reminder_id, user_id)
    if not db_reminder:
        raise ValueError("提醒不存在")
    db.delete(db_reminder)
    db.commit()