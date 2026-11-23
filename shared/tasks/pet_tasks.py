"""M3 宠物健康定时任务：疫苗/驱虫到期提醒 + 体重异常检测"""
import logging
from datetime import date, timedelta

from shared.models.database import SessionLocal
from shared.models.pet_models import PetProfile, PetVaccineRecord, PetDewormingRecord, PetWeightRecord

logger = logging.getLogger(__name__)


def _send_push_sync(user_id: int, title: str, body: str):
    """从同步任务中发送 FCM 推送（在独立线程的事件循环中运行异步函数）"""
    import asyncio
    import concurrent.futures

    def _run():
        new_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(new_loop)
        db = SessionLocal()
        try:
            from shared.services.push_service import send_push_to_user
            count = new_loop.run_until_complete(
                send_push_to_user(
                    db=db,
                    user_id=user_id,
                    title=title,
                    body=body,
                    data={
                        "reminder_type": "pet_health",
                        "click_action": "FLUTTER_NOTIFICATION_CLICK",
                    },
                    reminder_type="pet_health",
                )
            )
            if count > 0:
                logger.info(f"[FCM推送成功] user={user_id}, type=pet_health, title={title}")
        except Exception as e:
            logger.error(f"[FCM推送失败] user={user_id}, error={e}")
        finally:
            new_loop.close()
            db.close()

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_run)
            future.result(timeout=30)
    except Exception as e:
        logger.error(f"FCM 推送线程异常: {e}")


def check_pet_vaccine_reminders():
    """每天检查疫苗/驱虫到期日期，到期前7天及已过期时直接发送 FCM 推送"""
    db = SessionLocal()
    try:
        today = date.today()
        alert_end = today + timedelta(days=7)

        # 疫苗到期检查
        vaccines = db.query(PetVaccineRecord).filter(
            PetVaccineRecord.next_vaccination_date.isnot(None),
            PetVaccineRecord.next_vaccination_date <= alert_end
        ).all()

        push_count = 0
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
                _send_push_sync(pet.user_id, "宠物疫苗提醒", msg)
                push_count += 1

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
                _send_push_sync(pet.user_id, "宠物驱虫提醒", msg)
                push_count += 1

        if push_count > 0:
            logger.info(f"Pet vaccine/deworming push notifications sent: {push_count} total")
        else:
            logger.info("No pet vaccine/deworming reminders to send today")

    except Exception as e:
        logger.error(f"check_pet_vaccine_reminders error: {e}", exc_info=True)
    finally:
        db.close()


def check_pet_weight_anomaly():
    """每天检查宠物体重变化，连续2周异常（增长/下降>5%）时发送 FCM 推送"""
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
                msg = f"⚠ {pet.name} 近两周体重{direction}了 {abs(change_pct):.1f}%，建议关注宠物健康状况，必要时咨询兽医。"
                _send_push_sync(pet.user_id, "宠物体重预警", msg)

    except Exception as e:
        logger.error(f"check_pet_weight_anomaly error: {e}", exc_info=True)
    finally:
        db.close()
