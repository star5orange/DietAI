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
    """
    Event handler: Called after a food record is created.

    Updates the nutrition workspace with the new analysis record
    and refreshes diet summary statistics.

    Args:
        user_id: User ID
        food_record_id: New food record ID
        nutrition_data: Nutrition analysis data from the agent
        db: Database session
    """
    try:
        from agents.chat_agent.memory.memory_manager import MemoryManager
        from agents.chat_agent.memory.sync_service import SyncService

        logger.info(f"Processing food record event for user {user_id}, record {food_record_id}")

        # Update nutrition workspace with new analysis
        manager = MemoryManager(user_id)

        # Prepare recent analysis entry
        analysis_entry = {
            "date": datetime.now().date().isoformat(),
            "meal_type": nutrition_data.get("meal_type", "未分类"),
            "foods": nutrition_data.get("food_items", []),
            "calories": nutrition_data.get("total_calories", 0),
            "health_level": nutrition_data.get("health_level", "未知")
        }

        # Update the recent analyses section
        await manager.update_section(
            workspace="nutrition",
            section="recent_analyses",
            data={"new_analysis": analysis_entry}
        )

        # Also update goal tracking if user has active goals
        # (to reflect today's consumption changes)
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
    """
    Event handler: Called after a weight record is created.

    Updates the goal tracking workspace with new weight data
    and recalculates progress percentages.

    Args:
        user_id: User ID
        weight: New weight in kg
        recorded_at: When the weight was recorded
        db: Database session
    """
    try:
        from agents.chat_agent.memory.memory_manager import MemoryManager
        from agents.chat_agent.memory.sync_service import SyncService

        logger.info(f"Processing weight record event for user {user_id}: {weight}kg")

        # Update goal tracking workspace
        manager = MemoryManager(user_id)

        # Update weight progress section
        await manager.update_section(
            workspace="goal_tracking",
            section="weight_progress",
            data={
                "current_weight": weight,
                "current_date": recorded_at.date().isoformat()
            }
        )

        # Full sync to recalculate progress
        sync_service = SyncService(db)
        await sync_service.sync_goal_tracking(user_id)

        # Also update shared memory (weight is part of basic info)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Weight record event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process weight record event for user {user_id}: {e}")


async def on_goal_changed(
    user_id: int,
    goal_data: Dict[str, Any],
    db: Session
):
    """
    Event handler: Called after a health goal is created or modified.

    Recalculates BMR/TDEE and daily targets, then updates the
    goal tracking workspace with new configuration.

    Args:
        user_id: User ID
        goal_data: New/updated goal configuration
        db: Database session
    """
    try:
        from agents.chat_agent.memory.memory_manager import MemoryManager
        from agents.chat_agent.memory.sync_service import SyncService
        from shared.utils.nutrition_calc import (
            calculate_bmr,
            calculate_tdee,
            calculate_daily_targets
        )
        from shared.models.user_models import UserProfile

        logger.info(f"Processing goal change event for user {user_id}")

        # Get user profile for calculations
        profile = db.query(UserProfile).filter(
            UserProfile.user_id == user_id
        ).first()

        if profile:
            # Recalculate BMR/TDEE
            bmr = calculate_bmr(
                weight=float(profile.weight),
                height=float(profile.height),
                age=profile.age,
                gender=profile.gender
            )
            tdee = calculate_tdee(bmr, profile.activity_level)

            # Calculate new daily targets
            goal_type = goal_data.get("goal_type", 3)  # Default: maintain
            daily_targets = calculate_daily_targets(tdee, goal_type)

            logger.info(
                f"Recalculated for user {user_id}: "
                f"BMR={bmr:.0f}, TDEE={tdee:.0f}, "
                f"Target calories={daily_targets['calories']}"
            )

        # Full sync of goal tracking workspace
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
    """
    Event handler: Called after a conversation session ends.

    Updates the chat workspace with session summary, including
    topics discussed, key questions, and any noted preferences.

    Args:
        user_id: User ID
        session_id: Conversation session ID
        session_summary: Summary of the conversation
        db: Database session
    """
    try:
        from agents.chat_agent.memory.memory_manager import MemoryManager

        logger.info(f"Processing conversation end event for user {user_id}, session {session_id}")

        manager = MemoryManager(user_id)

        # Prepare interaction summary
        interaction = {
            "date": datetime.now().date().isoformat(),
            "session_id": session_id,
            "topic": session_summary.get("main_topic", "一般对话"),
            "user_question": session_summary.get("key_question", ""),
            "key_points": session_summary.get("key_points", [])
        }

        # Update recent interactions section
        await manager.update_section(
            workspace="chat",
            section="recent_interactions",
            data={"new_interaction": interaction}
        )

        # Update frequent topics if provided
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
    """
    Event handler: Called after user profile is updated.

    Updates the shared memory workspace with new profile data.
    If weight, height, age, or activity level changed, also
    triggers goal recalculation.

    Args:
        user_id: User ID
        updated_fields: Dictionary of updated field names and values
        db: Database session
    """
    try:
        from agents.chat_agent.memory.sync_service import SyncService

        logger.info(f"Processing profile update event for user {user_id}")

        sync_service = SyncService(db)

        # Always sync shared memory
        await sync_service.sync_shared_memory(user_id)

        # If any calculation-relevant field changed, also sync goals
        calc_fields = {"weight", "height", "age", "activity_level", "gender"}
        if calc_fields.intersection(updated_fields.keys()):
            await sync_service.sync_goal_tracking(user_id)
            logger.info(f"Goal workspace also updated due to profile change")

        logger.info(f"Profile update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process profile update event for user {user_id}: {e}")


async def on_allergy_updated(user_id: int, db: Session):
    """
    Event handler: Called after allergy information is updated.

    Updates the shared memory workspace with new allergy data.

    Args:
        user_id: User ID
        db: Database session
    """
    try:
        from agents.chat_agent.memory.sync_service import SyncService

        logger.info(f"Processing allergy update event for user {user_id}")

        sync_service = SyncService(db)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Allergy update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process allergy update event for user {user_id}: {e}")


async def on_disease_updated(user_id: int, db: Session):
    """
    Event handler: Called after disease/medical condition is updated.

    Updates the shared memory workspace with new disease data.

    Args:
        user_id: User ID
        db: Database session
    """
    try:
        from agents.chat_agent.memory.sync_service import SyncService

        logger.info(f"Processing disease update event for user {user_id}")

        sync_service = SyncService(db)
        await sync_service.sync_shared_memory(user_id)

        logger.info(f"Disease update event processed successfully for user {user_id}")

    except Exception as e:
        logger.error(f"Failed to process disease update event for user {user_id}: {e}")


def fire_and_forget(coro):
    """
    Helper to run a coroutine in a fire-and-forget manner.

    Use this to trigger async event handlers without blocking
    the main request-response flow.

    Example:
        fire_and_forget(on_food_record_created(user_id, record_id, data, db))
    """
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            asyncio.create_task(coro)
        else:
            loop.run_until_complete(coro)
    except RuntimeError:
        # No event loop running, create new one
        asyncio.run(coro)
