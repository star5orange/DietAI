"""
提醒检查定时任务

每分钟检查 Reminder 表，触发到时的提醒通知。
修复要点：
1. 注册到 BackgroundScheduler (interval=1 分钟) → 在 scheduler.py 中注册
2. 数据库 session 正确打开/关闭 → 使用 try/finally 确保 close
3. 时间比较精确到分钟 → remind_time 和当前时间都截断到分钟
4. repeat_days bitmask 正确解析 → Python weekday() 0=Mon 映射到 bitmask 0=Sun
5. 防重复触发 → 使用已触发 ID 集合去重
6. 日志输出 → 使用标准 logger 而非 print
"""

import logging
from datetime import datetime, time as dt_time

from shared.models.database import SessionLocal
from shared.models.reminder_models import Reminder

logger = logging.getLogger(__name__)

# 同一分钟内已触发的提醒 ID 集合，防止重复触发
# key: (user_id, reminder_id)，每分钟清空
_triggered_this_minute: set = None
_triggered_minute_key: str = None


def _python_weekday_to_bitmask_index(weekday: int) -> int:
    """
    将 Python datetime.weekday() (0=Mon, 6=Sun) 转换为 Reminder.repeat_days 的 bit 位。
    repeat_days bitmask: bit 0=周日, bit 1=周一, ..., bit 6=周六
    """
    return (weekday + 1) % 7


def check_reminders():
    """
    检查并触发到时的提醒。

    每分钟执行一次：
    - 查询 is_enabled=True 且 remind_time 匹配当前时间（精确到分钟）的提醒
    - 根据 repeat_days bitmask 检查今天是否应该触发
    - 触发后记录日志（后续可接入 FCM/APNs 推送）
    """
    now = datetime.now()
    current_time = now.time().replace(second=0, microsecond=0)
    # Python weekday: 0=Mon...6=Sun → bitmask: 0=Sun...6=Sat
    current_weekday = now.weekday()
    bit_index = _python_weekday_to_bitmask_index(current_weekday)
    bit_value = 1 << bit_index

    # 防重复：同一分钟内同一分钟 key 不清空
    global _triggered_this_minute, _triggered_minute_key
    minute_key = f"{now.strftime('%Y%m%d%H%M')}"
    if _triggered_minute_key != minute_key:
        _triggered_this_minute = set()
        _triggered_minute_key = minute_key

    db = SessionLocal()
    try:
        reminders = db.query(Reminder).filter(
            Reminder.is_enabled == True,
            Reminder.remind_time == current_time,
            Reminder.repeat_days.op('&')(bit_value) > 0
        ).all()

        triggered_count = 0
        for rem in reminders:
            dedup_key = (rem.user_id, rem.id)
            if dedup_key in _triggered_this_minute:
                logger.debug(f"跳过重复触发: user={rem.user_id}, reminder={rem.id}")
                continue

            _triggered_this_minute.add(dedup_key)
            triggered_count += 1

            logger.info(
                f"[提醒触发] user_id={rem.user_id}, "
                f"type={rem.reminder_type}, "
                f"title={rem.title}, "
                f"time={current_time}, "
                f"weekday_bit={bit_index}(bit={bit_value})"
            )

            # TODO: 接入消息推送 (FCM/APNs)
            # await push_notification(rem.user_id, rem.title, rem.description)

        if triggered_count > 0:
            logger.info(f"本轮触发 {triggered_count} 条提醒，共检查到 {len(reminders)} 条匹配")

    except Exception as e:
        logger.error(f"[提醒检查异常] {e}", exc_info=True)
    finally:
        db.close()
