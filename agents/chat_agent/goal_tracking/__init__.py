"""
Goal Tracking Agent Module

Provides:
- Goal Tracking Agent Graph definition
- BMR/TDEE calculation
- Daily target allocation
- Progress tracking
- LLM-powered suggestions generation
"""

from agents.chat_agent.goal_tracking.goal_agent import goal_graph
from agents.chat_agent.goal_tracking.states import (
    GoalTrackingState,
    GoalTrackingInput,
    GoalTrackingOutput
)

__all__ = [
    "goal_graph",
    "GoalTrackingState",
    "GoalTrackingInput",
    "GoalTrackingOutput"
]
