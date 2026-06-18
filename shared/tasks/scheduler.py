"""
APScheduler Configuration for Background Tasks

Provides periodic tasks for memory synchronization:
- Daily: Regenerate shared user memories for active users
- Daily: Update goal tracking workspaces
- Weekly: Generate nutrition workspace summaries
- Weekly: Generate chat workspace summaries
- Daily: Check solar term change and notify users
"""

import logging
from datetime import datetime, timedelta, date
from typing import List, Optional

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

# Global scheduler instance
_scheduler: Optional[AsyncIOScheduler] = None

# 缓存上一次检测到的节气，用于判断是否切换
_last_solar_term: Optional[str] = None


def get_scheduler() -> Optional[AsyncIOScheduler]:
    """Get the global scheduler instance."""
    return _scheduler


async def regenerate_shared_memories():
    """
    Daily task: Regenerate shared/user_memory.md for active users.

    Active users are those who have logged in within the last 7 days
    or have food records in the last 3 days.
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import User
    from agent.memory.sync_service import SyncService

    logger.info("Starting daily shared memory regeneration task")

    db = SessionLocal()
    try:
        # Find active users (logged in within 7 days)
        cutoff_date = datetime.now() - timedelta(days=7)
        active_users = db.query(User).filter(
            User.last_login >= cutoff_date
        ).all()

        sync_service = SyncService(db)
        success_count = 0
        error_count = 0

        for user in active_users:
            try:
                result = await sync_service.sync_shared_memory(user.id)
                if result:
                    success_count += 1
                else:
                    error_count += 1
            except Exception as e:
                logger.error(f"Failed to sync shared memory for user {user.id}: {e}")
                error_count += 1

        logger.info(
            f"Shared memory regeneration completed: "
            f"{success_count} success, {error_count} errors"
        )

    except Exception as e:
        logger.error(f"Shared memory regeneration task failed: {e}")
    finally:
        db.close()


async def update_goal_workspaces():
    """
    Daily task: Update goal_tracking/user_goals.md for users with active goals.

    Recalculates daily targets and progress for all users with active goals.
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import HealthGoal
    from agent.memory.sync_service import SyncService

    logger.info("Starting daily goal workspace update task")

    db = SessionLocal()
    try:
        # Find users with active goals
        active_goals = db.query(HealthGoal).filter(
            HealthGoal.current_status == 1
        ).all()

        user_ids = list(set(goal.user_id for goal in active_goals))

        sync_service = SyncService(db)
        success_count = 0
        error_count = 0

        for user_id in user_ids:
            try:
                result = await sync_service.sync_goal_tracking(user_id)
                if result:
                    success_count += 1
                else:
                    error_count += 1
            except Exception as e:
                logger.error(f"Failed to sync goal workspace for user {user_id}: {e}")
                error_count += 1

        logger.info(
            f"Goal workspace update completed: "
            f"{success_count} success, {error_count} errors"
        )

    except Exception as e:
        logger.error(f"Goal workspace update task failed: {e}")
    finally:
        db.close()


async def generate_weekly_nutrition_summary():
    """
    Weekly task: Update nutrition/user_nutrition.md with weekly summaries.

    Generates nutrition trends, frequent foods analysis for the past week.
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import User
    from shared.models.food_models import FoodRecord
    from agent.memory.sync_service import SyncService

    logger.info("Starting weekly nutrition summary generation task")

    db = SessionLocal()
    try:
        # Find users with food records in the last week
        cutoff_date = datetime.now() - timedelta(days=7)
        users_with_records = db.query(FoodRecord.user_id).filter(
            FoodRecord.created_at >= cutoff_date
        ).distinct().all()

        user_ids = [r[0] for r in users_with_records]

        sync_service = SyncService(db)
        success_count = 0
        error_count = 0

        for user_id in user_ids:
            try:
                result = await sync_service.sync_nutrition_workspace(user_id)
                if result:
                    success_count += 1
                else:
                    error_count += 1
            except Exception as e:
                logger.error(f"Failed to sync nutrition workspace for user {user_id}: {e}")
                error_count += 1

        logger.info(
            f"Nutrition summary generation completed: "
            f"{success_count} success, {error_count} errors"
        )

    except Exception as e:
        logger.error(f"Nutrition summary generation task failed: {e}")
    finally:
        db.close()


async def generate_chat_summary():
    """
    Weekly task: Update chat/user_chat.md with conversation summaries.

    Generates frequent topics, interaction patterns for the past week.
    """
    from shared.models.database import SessionLocal
    from shared.models.conversation_models import ConversationSession
    from agent.memory.sync_service import SyncService

    logger.info("Starting weekly chat summary generation task")

    db = SessionLocal()
    try:
        # Find users with chat sessions in the last week
        cutoff_date = datetime.now() - timedelta(days=7)
        users_with_sessions = db.query(ConversationSession.user_id).filter(
            ConversationSession.updated_at >= cutoff_date
        ).distinct().all()

        user_ids = [r[0] for r in users_with_sessions]

        sync_service = SyncService(db)
        success_count = 0
        error_count = 0

        for user_id in user_ids:
            try:
                result = await sync_service.sync_chat_workspace(user_id)
                if result:
                    success_count += 1
                else:
                    error_count += 1
            except Exception as e:
                logger.error(f"Failed to sync chat workspace for user {user_id}: {e}")
                error_count += 1

        logger.info(
            f"Chat summary generation completed: "
            f"{success_count} success, {error_count} errors"
        )

    except Exception as e:
        logger.error(f"Chat summary generation task failed: {e}")
    finally:
        db.close()


async def check_solar_term_change():
    """
    Daily task: Check if solar term has changed and notify active users.

    Compares current solar term with cached value. If changed,
    creates a notification for all active users about the new solar term
    and its wellness tips.

    Also checks for upcoming solar terms (within 3 days) and sends
    advance dietary adjustment reminders.
    """
    global _last_solar_term

    from agent.common_utils.solar_term_utils import get_current_solar_term, get_upcoming_solar_term

    logger.info("Checking solar term change")

    try:
        current_info = get_current_solar_term()
        current_term = current_info["name"]

        if _last_solar_term is None:
            _last_solar_term = current_term
            logger.info(f"Solar term initialized: {current_term}")
        elif current_term != _last_solar_term:
            logger.info(
                f"Solar term changed: {_last_solar_term} -> {current_term}"
            )
            _last_solar_term = current_term

            # 通知所有活跃用户
            from shared.models.database import SessionLocal
            from shared.models.user_models import User

            db = SessionLocal()
            try:
                cutoff_date = datetime.now() - timedelta(days=7)
                active_users = db.query(User).filter(
                    User.last_login >= cutoff_date
                ).all()

                season = current_info.get("season", "")
                wellness = current_info.get("wellness", "")
                next_term = current_info.get("next_term", "")

                for user in active_users:
                    try:
                        logger.info(
                            f"[节气通知] user_id={user.id}: "
                            f"节气切换至{current_term}({season}), "
                            f"养生要点: {wellness}"
                        )
                    except Exception as e:
                        logger.error(
                            f"Failed to notify user {user.id} about solar term: {e}"
                        )

                logger.info(
                    f"Solar term change notification sent to {len(active_users)} users"
                )
            finally:
                db.close()
        else:
            logger.debug(f"Solar term unchanged: {current_term}")

        # 检查即将到来的节气（3天内），发送饮食调整提醒
        upcoming = get_upcoming_solar_term(days_ahead=3)
        if upcoming:
            logger.info(
                f"[节气预告] {upcoming['days_ahead']}天后进入{upcoming['name']}({upcoming['season']}), "
                f"养生要点: {upcoming['wellness']}"
            )
            from shared.models.database import SessionLocal
            from shared.models.user_models import User

            db = SessionLocal()
            try:
                cutoff_date = datetime.now() - timedelta(days=7)
                active_users = db.query(User).filter(
                    User.last_login >= cutoff_date
                ).all()

                for user in active_users:
                    logger.info(
                        f"[节气预告通知] user_id={user.id}: "
                        f"{upcoming['days_ahead']}天后进入{upcoming['name']}, "
                        f"建议提前调整饮食: {upcoming['wellness']}"
                    )

                logger.info(
                    f"Solar term upcoming notification sent to {len(active_users)} users"
                )
            finally:
                db.close()

    except Exception as e:
        logger.error(f"Solar term check failed: {e}")


def setup_scheduler() -> AsyncIOScheduler:
    """
    Initialize and configure the APScheduler.

    Schedule:
    - 02:00 daily: Regenerate shared memories
    - 02:30 daily: Update goal workspaces
    - 03:00 Sunday: Generate nutrition summaries
    - 03:30 Sunday: Generate chat summaries

    Returns:
        Configured scheduler instance
    """
    global _scheduler

    if _scheduler is not None:
        logger.warning("Scheduler already initialized")
        return _scheduler

    _scheduler = AsyncIOScheduler()

    # Daily task: Regenerate shared memories at 02:00
    _scheduler.add_job(
        regenerate_shared_memories,
        trigger=CronTrigger(hour=2, minute=0),
        id="daily_shared_memory_sync",
        name="Daily Shared Memory Regeneration",
        replace_existing=True
    )

    # Daily task: Update goal workspaces at 02:30
    _scheduler.add_job(
        update_goal_workspaces,
        trigger=CronTrigger(hour=2, minute=30),
        id="daily_goal_sync",
        name="Daily Goal Workspace Update",
        replace_existing=True
    )

    # Weekly task: Generate nutrition summaries on Sunday at 03:00
    _scheduler.add_job(
        generate_weekly_nutrition_summary,
        trigger=CronTrigger(day_of_week='sun', hour=3, minute=0),
        id="weekly_nutrition_summary",
        name="Weekly Nutrition Summary",
        replace_existing=True
    )

    # Weekly task: Generate chat summaries on Sunday at 03:30
    _scheduler.add_job(
        generate_chat_summary,
        trigger=CronTrigger(day_of_week='sun', hour=3, minute=30),
        id="weekly_chat_summary",
        name="Weekly Chat Summary",
        replace_existing=True
    )

    # Minute task: Check and trigger reminders every 60 seconds
    from shared.tasks.reminder_check import check_reminders
    _scheduler.add_job(
        check_reminders,
        trigger=IntervalTrigger(minutes=1),
        id="check_reminders",
        name="Reminder Check",
        replace_existing=True,
        misfire_grace_time=30  # 30s 宽限期，避免堆积
    )
    logger.info("Reminder check task registered (interval=1min)")

    # Daily task: Check solar term change at 00:05
    _scheduler.add_job(
        check_solar_term_change,
        trigger=CronTrigger(hour=0, minute=5),
        id="check_solar_term_change",
        name="Solar Term Change Check",
        replace_existing=True,
    )
    logger.info("Solar term change check task registered (daily 00:05)")

    _scheduler.start()
    logger.info("Background task scheduler started")

    return _scheduler


def shutdown_scheduler():
    """Shutdown the scheduler gracefully."""
    global _scheduler

    if _scheduler is not None:
        _scheduler.shutdown(wait=True)
        _scheduler = None
        logger.info("Background task scheduler shutdown")


async def run_task_now(task_name: str) -> bool:
    """
    Manually trigger a specific task to run immediately.

    Args:
        task_name: One of "shared_memory", "goal_tracking", "nutrition", "chat"

    Returns:
        True if task was triggered successfully
    """
    from shared.tasks.reminder_check import check_reminders
    task_mapping = {
        "shared_memory": regenerate_shared_memories,
        "goal_tracking": update_goal_workspaces,
        "nutrition": generate_weekly_nutrition_summary,
        "chat": generate_chat_summary,
        "check_reminders": check_reminders,
    }

    task_func = task_mapping.get(task_name)
    if task_func is None:
        logger.error(f"Unknown task: {task_name}")
        return False

    try:
        await task_func()
        return True
    except Exception as e:
        logger.error(f"Manual task execution failed: {e}")
        return False
