"""
Goal Tracking Agent State Schemas

Defines the state structures for the Goal Tracking Agent:
- GoalTrackingState: Full internal state
- GoalTrackingInput: Input schema (what the router sends)
- GoalTrackingOutput: Output schema (what the router receives)
"""

from typing import Dict, List, Optional, TypedDict, Literal
from datetime import datetime, date
from langchain_openai.chat_models.base import BaseChatOpenAI


class GoalTrackingState(TypedDict):
    """
    Goal Tracking Agent full internal state.

    Contains all data needed for goal tracking, BMR/TDEE calculation,
    progress tracking, and suggestion generation.
    """
    # Input
    user_id: int
    trigger: str  # "daily_check" | "after_meal" | "weight_update" | "goal_change"

    # Loaded from user.md or DB
    user_memory: Optional[str]  # Raw content from shared/user_memory.md
    goals_memory: Optional[str]  # Raw content from goal_tracking/user_goals.md

    # User profile data
    user_profile: Optional[Dict]  # height, weight, gender, age, activity_level
    active_goals: Optional[List[Dict]]  # Active health goals from DB

    # Nutrition data
    today_consumed: Optional[Dict]  # Today's consumed nutrition
    recent_nutrition: Optional[List[Dict]]  # Recent daily summaries

    # Weight tracking
    weight_history: Optional[List[Dict]]  # Recent weight records

    # Calculated values
    bmr: Optional[float]
    tdee: Optional[float]
    daily_calorie_target: Optional[float]
    macro_targets: Optional[Dict]  # {protein, carbs, fat}
    remaining_budget: Optional[Dict]  # Today's remaining

    # Progress tracking
    goal_progress: Optional[Dict]  # Progress toward weight goal

    # LLM-generated output
    suggestions: Optional[List[str]]
    warnings: Optional[List[str]]
    progress_summary: Optional[str]

    # Control
    current_step: str
    error_message: Optional[str]
    analysis_model: Optional[BaseChatOpenAI]


class GoalTrackingInput(TypedDict):
    """
    Input schema for Goal Tracking Agent.

    This is what the router/orchestrator sends to invoke the agent.
    """
    user_id: int
    trigger: str  # "daily_check" | "after_meal" | "weight_update" | "goal_change"
    include_suggestions: bool  # Whether to generate LLM suggestions


class GoalTrackingOutput(TypedDict):
    """
    Output schema for Goal Tracking Agent.

    This is what the agent returns to the router/orchestrator.
    """
    # Calculated targets
    bmr: Optional[float]
    tdee: Optional[float]
    daily_calorie_target: Optional[float]
    macro_targets: Optional[Dict]  # {protein, carbs, fat, calories}

    # Today's status
    today_consumed: Optional[Dict]  # {calories, protein, carbs, fat}
    remaining_budget: Optional[Dict]  # {calories, protein, carbs, fat}

    # Progress
    goal_progress: Optional[Dict]  # {percentage, trend, weight_change, etc.}

    # LLM-generated
    suggestions: Optional[List[str]]
    warnings: Optional[List[str]]
    progress_summary: Optional[str]

    # Meta
    current_step: str
    error_message: Optional[str]
