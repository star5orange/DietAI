"""
Event-Triggered Memory Updates

Provides event handlers that update memory workspaces in response to
user actions. These are called asynchronously after database operations
to keep memory files in sync.

Events:
- on_food_record_created: Updates nutrition workspace after food analysis
- on_weight_recorded: Updates goal tracking workspace after weight entry
- on_goal_changed: Recalculates targets and updates goal workspace
- on_conversation_ended: Updates chat workspace with session summary
"""

import logging
import asyncio
from datetime import datetime
from typing import Dict, Any, Optional

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


async def on_food_record_created(
    user_id: int,
    food_record_id: int,
    nutrition_data: Dict[str, Any],
    db: Session
):
    try:
        from agent.memory.memory_manager import MemoryManager
        from agent.memory.sync_service import SyncService

        logger.info(f"Processing food record event for user {user_id}, record {food_record_id}")

        manager = MemoryManager(user_id)

        analysis_entry = {
            "date": datetime.now().date().isoformat(),
            "meal_type": nutrition_data.get("meal_type", "未分类"),
            "foods": nutrition_data.get("food_items", []),
            "calories": nutrition_data.get("total_calories", 0),
            "health_level": nutrition_data.get("health_level", "未知")
        }

        await manager.update_section(
            workspace="nutrition",
            section="recent_analyses",
            data={"new_analysis": analysis_entry}
        )

        sync_service = SyncService(db)
        await sync_service.sync_goal_tracking(user_id)

        logger.info(f"Food record event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process food record event for user {user_id}: {e}")


async def on_weight_recorded(
    user_id: int,
    weight: float,
    recorded_at: datetime,
    db: Session
):
    try:
        from agent.memory.memory_manager import MemoryManager
        from agent.memory.sync_service import SyncService

        logger.info(f"Processing weight record event for user {user_id}: {weight}kg")

        manager = MemoryManager(user_id)

        await manager.update_section(
            workspace="goal_tracking",
            section="weight_progress",
            data={
                "current_weight": weight,
                "current_date": recorded_at.date().isoformat()
            }
        )

        sync_service = SyncService(db)
        await sync_service.sync_goal_tracking(user_id)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Weight record event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process weight record event for user {user_id}: {e}")


async def on_goal_changed(
    user_id: int,
    goal_data: Dict[str, Any],
    db: Session
):
    try:
        from agent.memory.memory_manager import MemoryManager
        from agent.memory.sync_service import SyncService
        from shared.utils.nutrition_calc import (
            calculate_bmr,
            calculate_tdee,
            calculate_daily_targets
        )
        from shared.models.user_models import UserProfile

        logger.info(f"Processing goal change event for user {user_id}")

        profile = db.query(UserProfile).filter(
            UserProfile.user_id == user_id
        ).first()

        if profile:
            bmr = calculate_bmr(
                weight=float(profile.weight),
                height=float(profile.height),
                age=profile.age,
                gender=profile.gender
            )
            tdee = calculate_tdee(bmr, profile.activity_level)

            goal_type = goal_data.get("goal_type", 3)
            daily_targets = calculate_daily_targets(tdee, goal_type)

            logger.info(
                f"Recalculated for user {user_id}: "
                f"BMR={bmr:.0f}, TDEE={tdee:.0f}, "
                f"Target calories={daily_targets['calories']}"
            )

        sync_service = SyncService(db)
        await sync_service.sync_goal_tracking(user_id)

        logger.info(f"Goal change event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process goal change event for user {user_id}: {e}")


async def on_conversation_ended(
    user_id: int,
    session_id: str,
    session_summary: Dict[str, Any],
    db: Session
):
    try:
        from agent.memory.memory_manager import MemoryManager

        logger.info(f"Processing conversation end event for user {user_id}, session {session_id}")

        manager = MemoryManager(user_id)

        interaction = {
            "date": datetime.now().date().isoformat(),
            "session_id": session_id,
            "topic": session_summary.get("main_topic", "一般对话"),
            "user_question": session_summary.get("key_question", ""),
            "key_points": session_summary.get("key_points", [])
        }

        await manager.update_section(
            workspace="chat",
            section="recent_interactions",
            data={"new_interaction": interaction}
        )

        if session_summary.get("topics"):
            await manager.update_section(
                workspace="chat",
                section="frequent_topics",
                data={"topics": session_summary["topics"]}
            )

        logger.info(f"Conversation end event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process conversation end event for user {user_id}: {e}")


async def on_profile_updated(
    user_id: int,
    updated_fields: Dict[str, Any],
    db: Session
):
    try:
        from agent.memory.sync_service import SyncService

        logger.info(f"Processing profile update event for user {user_id}")

        sync_service = SyncService(db)

        await sync_service.sync_shared_memory(user_id)

        calc_fields = {"weight", "height", "age", "activity_level", "gender"}
        if calc_fields.intersection(updated_fields.keys()):
            await sync_service.sync_goal_tracking(user_id)
            logger.info(f"Goal workspace also updated due to profile change")

        logger.info(f"Profile update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process profile update event for user {user_id}: {e}")


async def on_allergy_updated(user_id: int, db: Session):
    try:
        from agent.memory.sync_service import SyncService

        logger.info(f"Processing allergy update event for user {user_id}")

        sync_service = SyncService(db)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Allergy update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process allergy update event for user {user_id}: {e}")


async def on_disease_updated(user_id: int, db: Session):
    try:
        from agent.memory.sync_service import SyncService

        logger.info(f"Processing disease update event for user {user_id}")

        sync_service = SyncService(db)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Disease update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process disease update event for user {user_id}: {e}")


def fire_and_forget(coro):
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            asyncio.create_task(coro)
        else:
            loop.run_until_complete(coro)
    except RuntimeError:
        asyncio.run(coro)
