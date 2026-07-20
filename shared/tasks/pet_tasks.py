"""M3 宠物健康定时任务：疫苗/驱虫到期提醒 + 体重异常检测"""
import logging
from datetime import date, datetime, timedelta
from sqlalchemy.orm import Session
from shared.models.database import SessionLocal
from shared.models.pet_models import PetProfile, PetVaccineRecord, PetDewormingRecord, PetWeightRecord

logger = logging.getLogger(__name__)


def check_pet_vaccine_reminders():
    """每天检查疫苗/驱虫到期日期，到期前7天及已过期时创建提醒通知"""
    db = SessionLocal()
    try:
        today = date.today()
        # 检查未来7天内到期 + 已过期的
        alert_start = today
        alert_end = today + timedelta(days=7)

        # 疫苗到期检查：next_vaccination_date between [today, today+7] 或已过期
        vaccines = db.query(PetVaccineRecord).filter(
            PetVaccineRecord.next_vaccination_date.isnot(None),
            db.query(PetVaccineRecord).filter(
                PetVaccineRecord.next_vaccination_date <= alert_end
            ).exists()
        ).all()

        # 过滤掉今天之前且 >7天前已提醒过的（避免重复提醒已过期很久的）
        for v in vaccines:
            if v.next_vaccination_date is None:
                continue
            days_left = (v.next_vaccination_date - today).days
            if days_left < -60:
                continue  # 过期超过60天的不再提醒
            pet = db.query(PetProfile).filter(PetProfile.id == v.pet_id).first()
            if pet:
                if days_left < 0:
                    msg = f"{pet.name} 的疫苗「{v.vaccine_name}」已过期 {abs(days_left)} 天，请尽快安排接种。"
                elif days_left == 0:
                    msg = f"{pet.name} 的疫苗「{v.vaccine_name}」今日到期，请安排接种。"
                else:
                    msg = f"{pet.name} 的疫苗「{v.vaccine_name}」将于{days_left}天后到期，请及时安排接种。"
                _create_reminder(db, pet.user_id, pet.id, msg)

        # 驱虫到期检查
        dewormings = db.query(PetDewormingRecord).filter(
            PetDewormingRecord.next_treatment_date.isnot(None),
            PetDewormingRecord.next_treatment_date <= alert_end
        ).all()
        for d in dewormings:
            if d.next_treatment_date is None:
                continue
            days_left = (d.next_treatment_date - today).days
            if days_left < -60:
                continue
            pet = db.query(PetProfile).filter(PetProfile.id == d.pet_id).first()
            if pet:
                type_name = "体内驱虫" if d.deworming_type == "internal" else "体外驱虫"
                if days_left < 0:
                    msg = f"{pet.name} 的{type_name}已过期 {abs(days_left)} 天，请尽快处理。"
                elif days_left == 0:
                    msg = f"{pet.name} 的{type_name}今日到期，请处理。"
                else:
                    msg = f"{pet.name} 的{type_name}将于{days_left}天后到期，请及时处理。"
                _create_reminder(db, pet.user_id, pet.id, msg)

        total = (len([v for v in vaccines if v.next_vaccination_date and (v.next_vaccination_date - today).days >= -60]) +
                 len([d for d in dewormings if d.next_treatment_date and (d.next_treatment_date - today).days >= -60]))
        if total > 0:
            logger.info(f"Pet vaccine/deworming reminders created: {total} total")

    except Exception as e:
        logger.error(f"check_pet_vaccine_reminders error: {e}")
    finally:
        db.close()


def check_pet_weight_anomaly():
    """每天检查宠物体重变化，连续2周异常（增长/下降>5%）时生成预警"""
    db = SessionLocal()
    try:
        pets = db.query(PetProfile).filter(PetProfile.is_active.is_(True)).all()
        today = date.today()
        two_weeks_ago = today - timedelta(days=14)

        for pet in pets:
            records = db.query(PetWeightRecord).filter(
                PetWeightRecord.pet_id == pet.id,
                PetWeightRecord.measured_at >= two_weeks_ago
            ).order_by(PetWeightRecord.measured_at).all()

            if len(records) < 2:
                continue

            recent = float(records[-1].weight)
            oldest = float(records[0].weight)
            if oldest <= 0:
                continue

            change_pct = (recent - oldest) / oldest * 100
            if abs(change_pct) > 5:
                direction = "增长" if change_pct > 0 else "下降"
                _create_reminder(db, pet.user_id, pet.id,
                    f"⚠️ {pet.name} 近两周体重{direction}了 {abs(change_pct):.1f}%，建议关注宠物健康状况，必要时咨询兽医。")

    except Exception as e:
        logger.error(f"check_pet_weight_anomaly error: {e}")
    finally:
        db.close()


def _create_reminder(db: Session, user_id: int, pet_id: int, message: str):
    """通过 reminders 表创建宠物健康提醒

    利用现有 Reminder 模型（reminders 表）：
    - reminder_type='meal'（复用饮食类提醒通道）
    - title 存简短标题，description 存完整消息
    - remind_time 设为当前时间（即时提醒）
    """
    try:
        from shared.models.reminder_models import Reminder
        reminder = Reminder(
            user_id=user_id,
            reminder_type="meal",               # 复用「饮食」提醒通道
            remind_time=datetime.now().time(),   # 即时提醒
            repeat_days=0,                       # 不重复
            is_enabled=True,
            title="宠物健康提醒",
            description=message,                 # 完整消息体
        )
        db.add(reminder)
        db.commit()
    except Exception as e:
        logger.warning(f"Failed to create pet reminder: {e}")
        db.rollback()
