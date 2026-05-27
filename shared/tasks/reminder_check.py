from datetime import datetime, date
from shared.models.database import SessionLocal
from shared.models.reminder_models import Reminder


def check_reminders():
    now = datetime.now()
    current_time = now.time().replace(second=0, microsecond=0)
    current_weekday = now.weekday()  # 0=周一, 6=周日

    db = SessionLocal()
    try:
        reminders = db.query(Reminder).filter(
            Reminder.is_enabled == True,
            Reminder.remind_time == current_time,
            Reminder.repeat_days.op('&')(1 << current_weekday) > 0
        ).all()

        for rem in reminders:
            # 这里先简单打印日志，后续可以接入推送
            print(f"[提醒触发] 用户: {rem.user_id}, 类型: {rem.reminder_type}, 标题: {rem.title}, 时间: {now}")
    except Exception as e:
        print(f"[提醒检查失败] {e}")
    finally:
        db.close()