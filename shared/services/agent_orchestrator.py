"""
Agent Orchestrator - Coordinates multiple independent agents.

Provides:
- analyze_food_with_goals: Combined food analysis + goal tracking
- get_daily_status: Get today's goal tracking status
- chat_with_context: Chat with memory context injection

The orchestrator handles:
1. Parallel agent calls where possible
2. Memory context loading
3. Result merging
4. Async memory updates
"""

import asyncio
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime, date

from langgraph_sdk import get_client
from sqlalchemy.orm import Session

from agent.memory.memory_manager import MemoryManager
from agent.memory.sync_service import SyncService
from shared.config.settings import get_settings
from shared.utils.nutrition_calc import calculate_meal_impact

logger = logging.getLogger(__name__)
settings = get_settings()


class AgentOrchestrator:
    """
    Orchestrates multiple independent LangGraph agents.

    Coordinates Goal Tracking Agent and Enhanced Nutrition Agent
    to provide combined analysis with goal context.
    """

    def __init__(self):
        """Initialize the orchestrator."""
        self.client = None
        self._ai_service_url = settings.ai_service_url

    async def _get_client(self):
        """Get or create LangGraph SDK client."""
        if self.client is None:
            self.client = get_client(url=self._ai_service_url)
        return self.client

    async def analyze_food_with_goals(
        self,
        user_id: int,
        image_data: str,
        db: Session
    ) -> Dict[str, Any]:
        """
        Orchestrated food analysis with goal tracking.

        Flow:
        1. Parallel: Load shared memory + Call Goal Agent (get today's status)
        2. Call Enhanced Nutrition Agent (analyze food)
        3. Backend: Calculate meal impact on goals
        4. Merge results
        5. Async: Trigger memory updates

        Args:
            user_id: User ID
            image_data: Base64 encoded food image
            db: Database session

        Returns:
            Combined analysis result with goal context
        """
        try:
            # Step 1: Parallel - Load memory and get goal status
            memory_task = self._load_user_memory(user_id)
            goal_task = self._call_goal_agent(user_id, trigger="after_meal", db=db)

            shared_memory, goal_data = await asyncio.gather(
                memory_task,
                goal_task,
                return_exceptions=True
            )

            # Handle any exceptions
            if isinstance(shared_memory, Exception):
                logger.warning(f"Memory load failed: {shared_memory}")
                shared_memory = None

            if isinstance(goal_data, Exception):
                logger.warning(f"Goal agent failed: {goal_data}")
                goal_data = self._get_default_goal_data()

            # Extract preferences from memory
            user_preferences = self._extract_preferences(shared_memory) if shared_memory else {}

            # Step 2: Call Enhanced Nutrition Agent
            nutrition_result = await self._call_nutrition_agent(
                user_id=user_id,
                image_data=image_data,
                user_preferences=user_preferences
            )

            # Step 3: Calculate goal impact
            goal_context = None
            if goal_data and nutrition_result.get("nutrition_analysis"):
                goal_context = self._calculate_goal_impact(
                    nutrition=nutrition_result["nutrition_analysis"],
                    goal_data=goal_data
                )

            # Step 4: Merge results
            result = {
                "nutrition_analysis": nutrition_result.get("nutrition_analysis"),
                "nutrition_advice": nutrition_result.get("nutrition_advice"),
                "advice_dependencies": nutrition_result.get("advice_dependencies"),
                "goal_context": goal_context,
                "analysis_status": "completed" if nutrition_result.get("nutrition_analysis") else "failed"
            }

            # Step 5: Async memory update (fire and forget)
            asyncio.create_task(
                self._trigger_memory_updates(user_id, nutrition_result, db)
            )

            return result

        except Exception as e:
            logger.error(f"Food analysis with goals failed: {e}")
            return {
                "nutrition_analysis": None,
                "nutrition_advice": None,
                "goal_context": None,
                "analysis_status": "failed",
                "error": str(e)
            }

    async def get_daily_status(
        self,
        user_id: int,
        db: Session
    ) -> Dict[str, Any]:
        """
        Get comprehensive daily goal tracking status.

        Args:
            user_id: User ID
            db: Database session

        Returns:
            Daily status including targets, consumption, remaining
        """
        try:
            # Ensure user has synced memory
            await self._ensure_user_memory(user_id, db)

            # Call Goal Agent
            goal_data = await self._call_goal_agent(
                user_id=user_id,
                trigger="daily_check",
                db=db
            )

            return {
                "success": True,
                "daily_targets": goal_data.get("macro_targets"),
                "today_consumed": goal_data.get("today_consumed"),
                "remaining_budget": goal_data.get("remaining_budget"),
                "goal_progress": goal_data.get("goal_progress"),
                "suggestions": goal_data.get("suggestions", []),
                "warnings": goal_data.get("warnings", []),
                "bmr": goal_data.get("bmr"),
                "tdee": goal_data.get("tdee")
            }

        except Exception as e:
            logger.error(f"Get daily status failed: {e}")
            return {
                "success": False,
                "error": str(e)
            }

    async def chat_with_memory_context(
        self,
        user_id: int,
        message: str,
        session_id: str,
        session_type: int,
        db: Session
    ) -> Dict[str, Any]:
        """
        Get memory context for chat (to be injected by chat_router).

        Args:
            user_id: User ID
            message: User message
            session_id: Chat session ID
            session_type: Session type (1-4)
            db: Database session

        Returns:
            Memory context to inject into chat
        """
        try:
            manager = MemoryManager(user_id)
            shared_memory = await manager.read_workspace("shared")

            return {
                "user_memory_context": shared_memory,
                "has_memory": shared_memory is not None
            }

        except Exception as e:
            logger.warning(f"Failed to load chat memory context: {e}")
            return {
                "user_memory_context": None,
                "has_memory": False
            }

    # ============== Private Methods ==============

    async def _load_user_memory(self, user_id: int) -> Optional[str]:
        """Load shared memory content for a user."""
        try:
            manager = MemoryManager(user_id)
            return await manager.read_workspace("shared")
        except Exception as e:
            logger.warning(f"Failed to load user memory: {e}")
            return None

    async def _call_goal_agent(
        self,
        user_id: int,
        trigger: str,
        db: Session
    ) -> Dict[str, Any]:
        """
        Call the Goal Tracking Agent.

        Note: In production, this would use the LangGraph SDK.
        For now, we use a simplified direct calculation.
        """
        try:
            # For MVP, use direct calculation instead of full agent call
            # This avoids the complexity of running two LangGraph servers

            from shared.models.user_models import UserProfile, HealthGoal, WeightRecord
            from shared.models.food_models import DailyNutritionSummary
            from shared.utils.nutrition_calc import (
                calculate_bmr, calculate_tdee, calculate_daily_targets,
                calculate_age, GoalType
            )

            # Get user profile
            profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not profile:
                return self._get_default_goal_data()

            # Calculate age
            age = calculate_age(profile.birth_date) if profile.birth_date else 30

            # Calculate BMR and TDEE
            bmr = calculate_bmr(
                weight=float(profile.weight) if profile.weight else 70,
                height=float(profile.height) if profile.height else 170,
                age=age,
                gender=profile.gender or 1
            )
            tdee = calculate_tdee(bmr, profile.activity_level or 2)

            # Get active goal
            active_goal = db.query(HealthGoal).filter(
                HealthGoal.user_id == user_id,
                HealthGoal.current_status == 1
            ).first()

            goal_type = active_goal.goal_type if active_goal else GoalType.MAINTAIN
            targets = calculate_daily_targets(tdee, goal_type)

            # Get today's consumption
            today = date.today()
            today_summary = db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == user_id,
                DailyNutritionSummary.summary_date == today
            ).first()

            today_consumed = {
                "calories": float(today_summary.total_calories) if today_summary and today_summary.total_calories else 0,
                "protein": float(today_summary.total_protein) if today_summary and today_summary.total_protein else 0,
                "carbs": float(today_summary.total_carbohydrates) if today_summary and today_summary.total_carbohydrates else 0,
                "fat": float(today_summary.total_fat) if today_summary and today_summary.total_fat else 0
            }

            # Calculate remaining
            remaining = {
                "calories": targets["calories"] - today_consumed["calories"],
                "protein": targets["protein"] - today_consumed["protein"],
                "carbs": targets["carbs"] - today_consumed["carbs"],
                "fat": targets["fat"] - today_consumed["fat"]
            }

            return {
                "bmr": bmr,
                "tdee": tdee,
                "macro_targets": targets,
                "today_consumed": today_consumed,
                "remaining_budget": remaining,
                "goal_progress": None,  # Would need weight history
                "suggestions": [],
                "warnings": []
            }

        except Exception as e:
            logger.error(f"Goal agent call failed: {e}")
            return self._get_default_goal_data()

    async def _call_nutrition_agent(
        self,
        user_id: int,
        image_data: str,
        user_preferences: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Call the Enhanced Nutrition Agent.

        Uses LangGraph SDK to invoke the agent.
        """
        try:
            client = await self._get_client()

            # Create assistant for enhanced nutrition agent
            assistant = await client.assistants.create(
                graph_id="enhanced_nutrition_agent",
                config={
                    "configurable": {
                        "vision_model_provider": "openai",
                        "vision_model": "gpt-4.1-nano-2025-04-14",
                        "analysis_model_provider": "openai",
                        "analysis_model": "o3-mini-2025-01-31"
                    }
                }
            )

            # Create thread
            thread = await client.threads.create()

            # Run the agent
            result = None
            async for chunk in client.runs.stream(
                assistant_id=assistant["assistant_id"],
                thread_id=thread["thread_id"],
                input={
                    "image_data": image_data,
                    "user_id": user_id,
                    "user_preferences": user_preferences
                },
                stream_mode="values"
            ):
                if chunk.data and chunk.data.get("current_step") == "completed":
                    result = chunk.data

            if result:
                return {
                    "nutrition_analysis": result.get("nutrition_analysis"),
                    "nutrition_advice": result.get("nutrition_advice"),
                    "advice_dependencies": result.get("advice_dependencies")
                }

            return {}

        except Exception as e:
            logger.error(f"Nutrition agent call failed: {e}")
            # Fallback: try original agent
            return await self._call_original_nutrition_agent(image_data, user_preferences)

    async def _call_original_nutrition_agent(
        self,
        image_data: str,
        user_preferences: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Fallback to original nutrition agent."""
        try:
            client = await self._get_client()

            assistant = await client.assistants.create(
                graph_id="nutrition_agent",
                config={
                    "configurable": {
                        "vision_model_provider": "openai",
                        "vision_model": "gpt-4.1-nano-2025-04-14",
                        "analysis_model_provider": "openai",
                        "analysis_model": "o3-mini-2025-01-31"
                    }
                }
            )

            thread = await client.threads.create()

            result = None
            async for chunk in client.runs.stream(
                assistant_id=assistant["assistant_id"],
                thread_id=thread["thread_id"],
                input={
                    "image_data": image_data,
                    "user_preferences": user_preferences
                },
                stream_mode="values"
            ):
                if chunk.data and chunk.data.get("current_step") == "completed":
                    result = chunk.data

            if result:
                return {
                    "nutrition_analysis": result.get("nutrition_analysis"),
                    "nutrition_advice": result.get("nutrition_advice"),
                    "advice_dependencies": result.get("advice_dependencies")
                }

            return {}

        except Exception as e:
            logger.error(f"Original nutrition agent also failed: {e}")
            return {}

    def _calculate_goal_impact(
        self,
        nutrition: Any,
        goal_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Calculate meal impact on daily goals."""
        try:
            daily_targets = goal_data.get("macro_targets", {})
            remaining_before = goal_data.get("remaining_budget", {})

            if not daily_targets or not hasattr(nutrition, 'total_calories'):
                return None

            meal_nutrition = {
                "calories": nutrition.total_calories,
                "protein": nutrition.macronutrients.protein if hasattr(nutrition, 'macronutrients') else 0,
                "carbs": nutrition.macronutrients.carbohydrates if hasattr(nutrition, 'macronutrients') else 0,
                "fat": nutrition.macronutrients.fat if hasattr(nutrition, 'macronutrients') else 0
            }

            impact = calculate_meal_impact(meal_nutrition, daily_targets, remaining_before)

            return {
                "daily_targets": daily_targets,
                "before_meal_remaining": remaining_before,
                "after_meal_remaining": impact["remaining_after"],
                "meal_percentage": impact["meal_percentage"],
                "fits_budget": impact["fits_budget"],
                "goal_suggestions": goal_data.get("suggestions", [])
            }

        except Exception as e:
            logger.warning(f"Failed to calculate goal impact: {e}")
            return None

    def _extract_preferences(self, memory_content: Optional[str]) -> Dict[str, Any]:
        """Extract user preferences from memory content."""
        if not memory_content:
            return {}

        prefs = {
            "allergies": [],
            "diseases": [],
            "dietary_restrictions": []
        }

        # Simple extraction - would use proper parsing in production
        lines = memory_content.split('\n')
        current_section = None

        for line in lines:
            if '### 过敏原' in line:
                current_section = 'allergies'
            elif '### 疾病' in line:
                current_section = 'diseases'
            elif '### 饮食限制' in line:
                current_section = 'restrictions'
            elif line.startswith('## '):
                current_section = None
            elif line.startswith('- ') and current_section:
                item = line[2:].split('(')[0].strip()
                if item and '暂无' not in item and '无' != item:
                    if current_section == 'allergies':
                        prefs["allergies"].append(item)
                    elif current_section == 'diseases':
                        prefs["diseases"].append(item)
                    elif current_section == 'restrictions':
                        prefs["dietary_restrictions"].append(item)

        return prefs

    def _get_default_goal_data(self) -> Dict[str, Any]:
        """Return default goal data when agent fails."""
        return {
            "bmr": 1600,
            "tdee": 2200,
            "macro_targets": {
                "calories": 2000,
                "protein": 100,
                "carbs": 250,
                "fat": 65
            },
            "today_consumed": {
                "calories": 0,
                "protein": 0,
                "carbs": 0,
                "fat": 0
            },
            "remaining_budget": {
                "calories": 2000,
                "protein": 100,
                "carbs": 250,
                "fat": 65
            },
            "goal_progress": None,
            "suggestions": [],
            "warnings": []
        }

    async def _ensure_user_memory(self, user_id: int, db: Session) -> None:
        """Ensure user has memory files, sync if needed."""
        manager = MemoryManager(user_id)
        if not await manager.workspace_exists("shared"):
            sync_service = SyncService(db)
            await sync_service.sync_shared_memory(user_id)

    async def _trigger_memory_updates(
        self,
        user_id: int,
        nutrition_result: Dict[str, Any],
        db: Session
    ) -> None:
        """Trigger async memory updates after analysis."""
        try:
            from shared.tasks.memory_events import on_food_record_created

            if nutrition_result.get("nutrition_analysis"):
                await on_food_record_created(
                    user_id=user_id,
                    nutrition_data={
                        "foods": nutrition_result["nutrition_analysis"].food_items,
                        "calories": nutrition_result["nutrition_analysis"].total_calories,
                        "timestamp": datetime.now().isoformat()
                    }
                )
        except Exception as e:
            logger.warning(f"Memory update trigger failed: {e}")


# Singleton instance
_orchestrator: Optional[AgentOrchestrator] = None


def get_orchestrator() -> AgentOrchestrator:
    """Get the singleton orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = AgentOrchestrator()
    return _orchestrator
