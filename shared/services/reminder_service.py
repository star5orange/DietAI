from sqlalchemy.orm import Session
from shared.models.reminder_models import Reminder
from shared.models.schemas.reminder import ReminderCreate, ReminderUpdate
from shared.models.user_models import UserProfile
from typing import List, Dict, Optional
from datetime import time
import logging

logger = logging.getLogger(__name__)

# ==================== 默认提醒模板 ====================

# 通用模板
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

# 减脂人群差异化模板
FAT_LOSS_WATER_REMINDERS = [
    {"remind_time": time(7, 30), "title": "晨起温水", "description": "起床后喝一杯温水，促进新陈代谢"},
    {"remind_time": time(10, 0), "title": "上午补水", "description": "工作间隙喝水，有时口渴会被误认为饥饿"},
    {"remind_time": time(11, 30), "title": "餐前喝水", "description": "午餐前30分钟喝水，增加饱腹感减少进食量"},
    {"remind_time": time(14, 30), "title": "下午补水", "description": "下午补充水分，避免因口渴而吃零食"},
    {"remind_time": time(17, 30), "title": "晚餐前喝水", "description": "晚餐前喝水，帮助控制晚餐食量"},
    {"remind_time": time(20, 0), "title": "晚间少量饮水", "description": "睡前1小时少量饮水，避免夜间饥饿感"},
]

FAT_LOSS_MEAL_REMINDERS = [
    {"remind_time": time(7, 30), "title": "早餐时间", "description": "高蛋白早餐启动代谢，推荐鸡蛋+全麦面包+蔬菜"},
    {"remind_time": time(12, 0), "title": "午餐时间", "description": "先吃蔬菜再吃主食，控制碳水摄入量"},
    {"remind_time": time(18, 0), "title": "晚餐时间", "description": "晚餐宜清淡低卡，七分饱即可"},
    {"remind_time": time(21, 0), "title": "避免宵夜", "description": "夜间进食易囤积脂肪，如饥饿可喝温水或吃少量坚果"},
]

# 健身人群差异化模板
FITNESS_WATER_REMINDERS = [
    {"remind_time": time(7, 0), "title": "晨起补水", "description": "起床后补充水分，为训练做准备"},
    {"remind_time": time(9, 0), "title": "训练前补水", "description": "训练前30分钟补充300-500ml水"},
    {"remind_time": time(11, 0), "title": "训练中补水", "description": "训练中每15-20分钟小口补水"},
    {"remind_time": time(13, 0), "title": "午后补水", "description": "午后持续补充水分，促进蛋白质代谢"},
    {"remind_time": time(16, 0), "title": "下午补水", "description": "下午训练前再次补充水分"},
    {"remind_time": time(19, 0), "title": "晚间补水", "description": "晚间持续补水，肌肉恢复需要充足水分"},
]

FITNESS_MEAL_REMINDERS = [
    {"remind_time": time(7, 0), "title": "早餐时间", "description": "高蛋白早餐：鸡蛋+燕麦+牛奶，为训练储备能量"},
    {"remind_time": time(10, 0), "title": "加餐时间", "description": "训练前1小时加餐：香蕉+坚果，提供训练能量"},
    {"remind_time": time(12, 0), "title": "午餐时间", "description": "充足碳水+高蛋白：鸡胸肉+糙米+蔬菜"},
    {"remind_time": time(15, 30), "title": "训练后补充", "description": "训练后30分钟内补充蛋白质和碳水，促进肌肉恢复"},
    {"remind_time": time(18, 30), "title": "晚餐时间", "description": "高蛋白晚餐：鱼肉/牛肉+蔬菜+适量碳水"},
    {"remind_time": time(21, 0), "title": "睡前加餐", "description": "缓释蛋白：酪蛋白/牛奶，夜间持续为肌肉供能"},
]

# 人群标签到模板的映射
CROWD_TEMPLATES = {
    "减脂": {
        "water": FAT_LOSS_WATER_REMINDERS,
        "meal": FAT_LOSS_MEAL_REMINDERS,
    },
    "健身": {
        "water": FITNESS_WATER_REMINDERS,
        "meal": FITNESS_MEAL_REMINDERS,
    },
}


def _get_crowd_tag(db: Session, user_id: int) -> Optional[str]:
    """获取用户的人群标签"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if profile and profile.crowd_tag:
        # 取第一个标签（可能多选，如"减脂,健身"）
        tags = [t.strip() for t in profile.crowd_tag.split(",")]
        for tag in tags:
            if tag in CROWD_TEMPLATES:
                return tag
    return None


def create_reminder(db: Session, user_id: int, reminder: ReminderCreate) -> Reminder:
    """创建提醒"""
    db_reminder = Reminder(user_id=user_id, **reminder.model_dump())
    db.add(db_reminder)
    db.commit()
    db.refresh(db_reminder)
    return db_reminder


def create_default_reminders(db: Session, user_id: int) -> Dict[str, int]:
    """为新用户创建默认提醒模板。
    根据用户人群标签选择差异化模板：
    - 减脂：增加"避免宵夜"提醒，餐前喝水强调饱腹感
    - 健身：增加"训练后补充蛋白质"提醒，加餐提醒
    - 普通：标准三餐+喝水提醒

    幂等操作：如果该类型已存在提醒则跳过。
    返回创建数量统计。
    """
    created = {"water": 0, "meal": 0, "skipped": 0}

    # 根据人群标签选择模板
    crowd_tag = _get_crowd_tag(db, user_id)
    if crowd_tag and crowd_tag in CROWD_TEMPLATES:
        water_templates = CROWD_TEMPLATES[crowd_tag]["water"]
        meal_templates = CROWD_TEMPLATES[crowd_tag]["meal"]
        logger.info(f"用户 {user_id} 使用'{crowd_tag}'人群差异化提醒模板")
    else:
        water_templates = DEFAULT_WATER_REMINDERS
        meal_templates = DEFAULT_MEAL_REMINDERS

    existing_count = db.query(Reminder).filter(
        Reminder.user_id == user_id,
        Reminder.reminder_type == "water"
    ).count()

    if existing_count > 0:
        created["skipped"] += len(water_templates)
        logger.info(f"用户 {user_id} 已有 {existing_count} 条喝水提醒，跳过默认创建")
    else:
        for tmpl in water_templates:
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
        created["skipped"] += len(meal_templates)
        logger.info(f"用户 {user_id} 已有 {existing_meal} 条吃饭提醒，跳过默认创建")
    else:
        for tmpl in meal_templates:
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