"""
提醒检查定时任务

每分钟检查 Reminder 表，触发到时的提醒通知。
修复要点：
1. 注册到 BackgroundScheduler (interval=1 分钟) → 在 scheduler.py 中注册
2. 数据库 session 正确打开/关闭 → 使用 try/finally 确保 close
3. 时间比较精确到分钟 → remind_time 和当前时间都截断到分钟
4. repeat_days bitmask 正确解析 → Python weekday() 0=Mon 映射到 bitmask 0=Sun
5. 防重复触发 → 使用已触发 ID 集合去重
6. FCM 推送 → 通过 firebase-admin 发送远程推送通知
"""

import asyncio
import logging
from datetime import datetime

from shared.models.database import SessionLocal
from shared.models.reminder_models import Reminder

logger = logging.getLogger(__name__)

# 同一分钟内已触发的提醒 ID 集合，防止重复触发
_triggered_this_minute: set = None
_triggered_minute_key: str = None


def _python_weekday_to_bitmask_index(weekday: int) -> int:
    """
    将 Python datetime.weekday() (0=Mon, 6=Sun) 转换为 Reminder.repeat_days 的 bit 位。
    repeat_days bitmask: bit 0=周日, bit 1=周一, ..., bit 6=周六
    """
    return (weekday + 1) % 7


def _send_fcm_notifications_sync(db, reminders):
    """同步包装器：在现有 event loop 中运行异步 FCM 推送"""
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # 在运行中的 event loop 中，使用 run_coroutine_threadsafe
            # 创建新的 event loop 在独立线程中运行
            import concurrent.futures
            def _run_in_thread():
                new_loop = asyncio.new_event_loop()
                asyncio.set_event_loop(new_loop)
                try:
                    return new_loop.run_until_complete(
                        _send_fcm_notifications(db, reminders)
                    )
                finally:
                    new_loop.close()

            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(_run_in_thread)
                future.result(timeout=30)
        else:
            loop.run_until_complete(_send_fcm_notifications(db, reminders))
    except Exception as e:
        logger.error(f"FCM 推送执行异常: {e}")


async def _send_fcm_notifications(db, reminders):
    """向所有匹配用户发送 FCM 推送通知"""
    from shared.services.push_service import send_push_to_user

    for rem in reminders:
        body = rem.description or (f"{rem.reminder_type} 提醒")

        # 构建附加数据，供前端通知点击时使用
        data_payload = {
            "reminder_type": rem.reminder_type,
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        }

        try:
            count = await send_push_to_user(
                db=db,
                user_id=rem.user_id,
                title=rem.title or "DietAI 提醒",
                body=body,
                data=data_payload,
                reminder_id=rem.id,
                reminder_type=rem.reminder_type,
            )
            if count > 0:
                logger.info(
                    f"[FCM推送成功] user={rem.user_id}, "
                    f"type={rem.reminder_type}, title={rem.title}, count={count}"
                )
        except Exception as e:
            logger.error(
                f"[FCM推送失败] user={rem.user_id}, "
                f"type={rem.reminder_type}, error={e}"
            )


def check_reminders():
    """
    检查并触发到时的提醒。

    每分钟执行一次：
    - 查询 is_enabled=True 且 remind_time 匹配当前时间（精确到分钟）的提醒
    - 根据 repeat_days bitmask 检查今天是否应该触发
    - 通过 FCM 向用户设备发送推送通知
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

        # 去重
        to_trigger = []
        for rem in reminders:
            dedup_key = (rem.user_id, rem.id)
            if dedup_key in _triggered_this_minute:
                logger.debug(f"跳过重复触发: user={rem.user_id}, reminder={rem.id}")
                continue
            _triggered_this_minute.add(dedup_key)
            to_trigger.append(rem)

        if not to_trigger:
            return

        logger.info(
            f"[提醒触发] 本轮匹配 {len(to_trigger)} 条提醒, "
            f"time={current_time}, weekday_bit={bit_index}"
        )

        for rem in to_trigger:
            logger.info(
                f"   -> user={rem.user_id}, type={rem.reminder_type}, "
                f"title={rem.title}"
            )

        # 发送 FCM 推送通知
        _send_fcm_notifications_sync(db, to_trigger)

    except Exception as e:
        logger.error(f"[提醒检查异常] {e}", exc_info=True)
    finally:
        db.close()
