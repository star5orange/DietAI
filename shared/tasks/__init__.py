"""
Background Tasks Module

Provides:
- scheduler: APScheduler configuration and task definitions
- memory_events: Event-triggered memory updates
"""

from shared.tasks.scheduler import (
    setup_scheduler,
    shutdown_scheduler,
    run_task_now,
    get_scheduler
)
from shared.tasks.memory_events import (
    on_food_record_created,
    on_weight_recorded,
    on_goal_changed,
    on_conversation_ended,
    on_profile_updated,
    on_allergy_updated,
    on_disease_updated,
    fire_and_forget
)

__all__ = [
    "setup_scheduler",
    "shutdown_scheduler",
    "run_task_now",
    "get_scheduler",
    "on_food_record_created",
    "on_weight_recorded",
    "on_goal_changed",
    "on_conversation_ended",
    "on_profile_updated",
    "on_allergy_updated",
    "on_disease_updated",
    "fire_and_forget"
]
