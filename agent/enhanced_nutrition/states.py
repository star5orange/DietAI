"""
Enhanced Nutrition Agent State Schemas

Defines the state structures for the Enhanced Nutrition Agent:
- EnhancedNutritionState: Full internal state with memory context
- EnhancedInputState: Input schema (what the router sends)
- EnhancedOutputState: Output schema (what the router receives)

Key difference from original: Includes user memory context for personalized analysis.
"""

from typing import Dict, List, Optional, TypedDict
from langchain_openai.chat_models.base import BaseChatOpenAI

from agent.utils.sturcts import NutritionAnalysis, NutritionAdvice, AdviceDependencies


class EnhancedNutritionState(TypedDict):
    """
    Enhanced Nutrition Agent full internal state.

    Extends the original AgentState with memory context fields.
    """
    # Image input
    image_dir: Optional[str]
    image_data: Optional[str]

    # Memory context (NEW)
    user_id: Optional[int]
    user_memory_context: Optional[str]  # Content from shared/user_memory.md
    nutrition_memory_context: Optional[str]  # Content from nutrition/user_nutrition.md

    # User preferences (from memory or DB)
    user_preferences: Optional[Dict]  # allergies, diseases, food prefs

    # Analysis results
    image_analysis: Optional[str]
    nutrition_analysis: Optional[NutritionAnalysis]
    nutrition_advice: Optional[NutritionAdvice]
    advice_dependencies: Optional[AdviceDependencies]

    # RAG
    retrieved_documents: List[str]
    conversation_history: List[Dict]

    # Control
    current_step: str
    error_message: Optional[str]
    vision_model: BaseChatOpenAI
    analysis_model: BaseChatOpenAI


class EnhancedInputState(TypedDict):
    """
    Input schema for Enhanced Nutrition Agent.

    Extends original with user_id for memory loading.
    """
    image_data: Optional[str]
    user_id: Optional[int]  # NEW: For loading user memory
    user_preferences: Optional[Dict]  # Can be pre-populated by orchestrator


class EnhancedOutputState(TypedDict):
    """
    Output schema for Enhanced Nutrition Agent.

    Same as original - maintains backward compatibility.
    """
    nutrition_analysis: Optional[NutritionAnalysis]
    nutrition_advice: Optional[NutritionAdvice]
    advice_dependencies: Optional[AdviceDependencies]
    current_step: Optional[str]
    error_message: Optional[str]
