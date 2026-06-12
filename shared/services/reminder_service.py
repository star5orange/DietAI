from sqlalchemy.orm import Session
from shared.models.reminder_models import Reminder
from shared.models.schemas.reminder import ReminderCreate, ReminderUpdate
from typing import List, Dict
from datetime import time
import logging

logger = logging.getLogger(__name__)

# 默认提醒模板
DEFAULT_WATER_REMINDERS = [
    {"remind_time": time(8, 0), "title": "起床喝水", "description": "早晨起床后喝一杯温水，补充夜间流失的水分"},
    {"remind_time": time(10, 0), "title": "上午补水", "description": "工作间隙记得补充水分，保持身体水分平衡"},
    {"remind_time": time(12, 0), "title": "午餐前喝水", "description": "午餐前喝一杯水，有助消化和控制食量"},
    {"remind_time": time(15, 0), "title": "下午茶补水", "description": "下午茶时间来杯水，提神醒脑补充水分"},
    {"remind_time": time(18, 0), "title": "晚餐前喝水", "description": "晚餐前喝一杯水，有助消化和增加饱腹感"},
]

DEFAULT_MEAL_REMINDERS = [
    {"remind_time": time(8, 0), "title": "早餐时间", "description": "记得吃早餐，为新的一天补充能量"},
    {"remind_time": time(12, 0), "title": "午餐时间", "description": "午餐时间到了，适量摄入蛋白质和蔬菜"},
    {"remind_time": time(18, 0), "title": "晚餐时间", "description": "晚餐宜清淡，避免过量进食"},
]


def create_reminder(db: Session, user_id: int, reminder: ReminderCreate) -> Reminder:
    """创建提醒"""
    db_reminder = Reminder(user_id=user_id, **reminder.model_dump())
    db.add(db_reminder)
    db.commit()
    db.refresh(db_reminder)
    return db_reminder


def create_default_reminders(db: Session, user_id: int) -> Dict[str, int]:
    """为新用户创建默认提醒模板（5条喝水 + 3条吃饭）。
    幂等操作：如果该类型已存在提醒则跳过。
    返回创建数量统计。
    """
    created = {"water": 0, "meal": 0, "skipped": 0}

    existing_count = db.query(Reminder).filter(
        Reminder.user_id == user_id,
        Reminder.reminder_type == "water"
    ).count()

    if existing_count > 0:
        created["skipped"] += len(DEFAULT_WATER_REMINDERS)
        logger.info(f"用户 {user_id} 已有 {existing_count} 条喝水提醒，跳过默认创建")
    else:
        for tmpl in DEFAULT_WATER_REMINDERS:
            db_reminder = Reminder(
                user_id=user_id,
                reminder_type="water",
                remind_time=tmpl["remind_time"],
                repeat_days=127,
                is_enabled=True,
                title=tmpl["title"],
                description=tmpl["description"],
            )
            db.add(db_reminder)
            created["water"] += 1
        logger.info(f"为用户 {user_id} 创建了 {created['water']} 条默认喝水提醒")

    existing_meal = db.query(Reminder).filter(
        Reminder.user_id == user_id,
        Reminder.reminder_type == "meal"
    ).count()

    if existing_meal > 0:
        created["skipped"] += len(DEFAULT_MEAL_REMINDERS)
        logger.info(f"用户 {user_id} 已有 {existing_meal} 条吃饭提醒，跳过默认创建")
    else:
        for tmpl in DEFAULT_MEAL_REMINDERS:
            db_reminder = Reminder(
                user_id=user_id,
                reminder_type="meal",
                remind_time=tmpl["remind_time"],
                repeat_days=127,
                is_enabled=True,
                title=tmpl["title"],
                description=tmpl["description"],
            )
            db.add(db_reminder)
            created["meal"] += 1
        logger.info(f"为用户 {user_id} 创建了 {created['meal']} 条默认吃饭提醒")

    db.commit()
    return created


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
    update_data = reminder.model_dump(exclude_unset=True)
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