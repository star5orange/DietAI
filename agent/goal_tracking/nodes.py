"""
Goal Tracking Agent Nodes

Implements the workflow nodes for goal tracking:
1. load_user_context: Load user data from memory and DB
2. calculate_bmr_tdee: Calculate BMR and TDEE
3. calculate_daily_targets: Calculate daily nutrition targets
4. track_today_progress: Track today's consumption vs targets
5. generate_suggestions: Generate LLM-powered suggestions
6. save_to_goals_md: Update goals workspace file
7. format_output: Format final output
"""

import logging
from datetime import datetime, date, timedelta
from typing import Dict, Any, List, Optional
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.runnables import RunnableConfig

from agent.goal_tracking.states import GoalTrackingState
from agent.memory.memory_manager import MemoryManager
from agent.common_utils.model_utils import get_model
from agent.utils.configuration import Configuration
from shared.utils.nutrition_calc import (
    calculate_bmr,
    calculate_tdee,
    calculate_daily_targets,
    calculate_remaining_budget,
    calculate_goal_progress,
    calculate_age,
    get_goal_type_name,
    GoalType,
    ActivityLevel
)

logger = logging.getLogger(__name__)


async def load_user_context(state: GoalTrackingState, config: RunnableConfig) -> GoalTrackingState:
    """
    Load user context from memory files and database.

    Reads:
    - shared/user_memory.md for profile data
    - goal_tracking/user_goals.md for current goals state
    - Database for fresh consumption data
    """
    try:
        user_id = state["user_id"]
        configurable = Configuration.from_runnable_config(config)

        # Initialize analysis model
        state["analysis_model"] = get_model(
            model_provider=configurable.analysis_model_provider,
            model_name=configurable.analysis_model
        )

        # Load memory files
        manager = MemoryManager(user_id)

        shared_memory = await manager.read_workspace("shared")
        goals_memory = await manager.read_workspace("goal_tracking")

        state["user_memory"] = shared_memory
        state["goals_memory"] = goals_memory

        # If memory doesn't exist, we need to load from DB
        # This will be handled by sync service in production
        # For now, extract what we can from memory or use defaults

        if shared_memory:
            # Parse basic profile from memory (simplified)
            state["user_profile"] = _extract_profile_from_memory(shared_memory)
        else:
            # Will need to load from DB in orchestrator
            state["user_profile"] = None

        state["current_step"] = "context_loaded"
        logger.info(f"Loaded context for user {user_id}")

    except Exception as e:
        state["error_message"] = f"Failed to load user context: {str(e)}"
        logger.error(state["error_message"])

    return state


def calculate_bmr_tdee_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Calculate BMR and TDEE from user profile.

    Uses Mifflin-St Jeor equation for BMR.
    """
    try:
        profile = state.get("user_profile")

        if not profile:
            state["error_message"] = "Missing user profile for BMR calculation"
            return state

        # Extract profile values with defaults
        weight = profile.get("weight", 70)
        height = profile.get("height", 170)
        age = profile.get("age", 30)
        gender = profile.get("gender", 1)
        activity_level = profile.get("activity_level", ActivityLevel.LIGHT)

        # Calculate BMR
        bmr = calculate_bmr(weight, height, age, gender)
        state["bmr"] = bmr

        # Calculate TDEE
        tdee = calculate_tdee(bmr, activity_level)
        state["tdee"] = tdee

        state["current_step"] = "bmr_calculated"
        logger.info(f"Calculated BMR={bmr}, TDEE={tdee} for user {state['user_id']}")

    except Exception as e:
        state["error_message"] = f"BMR calculation failed: {str(e)}"
        logger.error(state["error_message"])

    return state


def calculate_daily_targets_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Calculate daily nutrition targets based on TDEE and goal type.
    """
    try:
        tdee = state.get("tdee")
        if not tdee:
            state["error_message"] = "Missing TDEE for target calculation"
            return state

        # Get goal type from active goals or default to maintain
        active_goals = state.get("active_goals", [])
        goal_type = GoalType.MAINTAIN

        if active_goals:
            goal = active_goals[0]  # Primary goal
            goal_type = goal.get("goal_type", GoalType.MAINTAIN)

        # Calculate targets
        targets = calculate_daily_targets(tdee, goal_type)

        state["daily_calorie_target"] = targets["calories"]
        state["macro_targets"] = {
            "protein": targets["protein"],
            "carbs": targets["carbs"],
            "fat": targets["fat"],
            "calories": targets["calories"]
        }

        state["current_step"] = "targets_calculated"
        logger.info(f"Calculated daily targets for user {state['user_id']}: {targets}")

    except Exception as e:
        state["error_message"] = f"Target calculation failed: {str(e)}"
        logger.error(state["error_message"])

    return state


def track_today_progress_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Track today's consumption against targets.
    """
    try:
        daily_targets = state.get("macro_targets")
        if not daily_targets:
            state["error_message"] = "Missing daily targets for progress tracking"
            return state

        # Get today's consumed values (from DB or passed in)
        today_consumed = state.get("today_consumed", {
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0
        })

        # Calculate remaining budget
        remaining = calculate_remaining_budget(daily_targets, today_consumed)
        state["remaining_budget"] = remaining

        # Calculate goal progress if we have weight data
        active_goals = state.get("active_goals", [])
        weight_history = state.get("weight_history", [])

        if active_goals and weight_history and len(weight_history) >= 2:
            goal = active_goals[0]
            target_weight = goal.get("target_weight")

            if target_weight:
                progress = calculate_goal_progress(
                    starting_weight=weight_history[0].get("weight", 0),
                    current_weight=weight_history[-1].get("weight", 0),
                    target_weight=target_weight,
                    goal_type=goal.get("goal_type", GoalType.MAINTAIN)
                )
                state["goal_progress"] = progress

        state["current_step"] = "progress_tracked"
        logger.info(f"Tracked progress for user {state['user_id']}: remaining={remaining}")

    except Exception as e:
        state["error_message"] = f"Progress tracking failed: {str(e)}"
        logger.error(state["error_message"])

    return state


async def generate_suggestions_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Generate personalized suggestions using LLM.
    """
    try:
        # Check if suggestions should be generated
        trigger = state.get("trigger", "daily_check")

        # Skip suggestions for certain triggers if not needed
        model = state.get("analysis_model")
        if not model:
            state["suggestions"] = ["暂无个性化建议"]
            state["warnings"] = []
            state["current_step"] = "suggestions_generated"
            return state

        # Build context for LLM
        context = _build_suggestion_context(state)

        # Generate suggestions
        system_prompt = """你是一位专业的营养师助手，负责根据用户的目标追踪数据提供个性化建议。

请根据用户的数据提供3-5条具体、可执行的建议。如果有需要警告的情况（如营养不足、超标等），也请指出。

回答格式：
建议：
1. [具体建议]
2. [具体建议]
...

警告（如有）：
- [警告内容]

进度总结：
[一句话总结当前进度]"""

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=context)
        ]

        response = model.invoke(messages)
        content = response.content

        # Parse response
        suggestions, warnings, summary = _parse_suggestion_response(content)

        state["suggestions"] = suggestions
        state["warnings"] = warnings
        state["progress_summary"] = summary
        state["current_step"] = "suggestions_generated"

        logger.info(f"Generated {len(suggestions)} suggestions for user {state['user_id']}")

    except Exception as e:
        state["suggestions"] = ["建议生成失败，请稍后重试"]
        state["warnings"] = []
        state["error_message"] = f"Suggestion generation failed: {str(e)}"
        logger.error(state["error_message"])

    return state


async def save_to_goals_md_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Update the goal tracking workspace file.
    """
    try:
        user_id = state["user_id"]
        manager = MemoryManager(user_id)

        # Update today's status section
        today_status = f"""- 已摄入卡路里: {state.get('today_consumed', {}).get('calories', 0)} kcal
- 剩余配额: {state.get('remaining_budget', {}).get('calories', 0)} kcal
- 蛋白质: {state.get('today_consumed', {}).get('protein', 0)}g / {state.get('macro_targets', {}).get('protein', 0)}g
- 碳水: {state.get('today_consumed', {}).get('carbs', 0)}g / {state.get('macro_targets', {}).get('carbs', 0)}g
- 脂肪: {state.get('today_consumed', {}).get('fat', 0)}g / {state.get('macro_targets', {}).get('fat', 0)}g
- 更新时间: {datetime.now().strftime('%Y-%m-%d %H:%M')}"""

        await manager.update_section("goal_tracking", "今日状态", today_status)

        # Update suggestions section if available
        if state.get("suggestions"):
            suggestions_content = "\n".join(f"- {s}" for s in state["suggestions"])
            await manager.update_section("goal_tracking", "Agent 生成的建议", suggestions_content)

        state["current_step"] = "saved_to_md"
        logger.info(f"Saved goals to MD for user {user_id}")

    except Exception as e:
        state["error_message"] = f"Failed to save to MD: {str(e)}"
        logger.error(state["error_message"])

    return state


def format_output_node(state: GoalTrackingState) -> GoalTrackingState:
    """
    Format the final output.
    """
    state["current_step"] = "completed"
    return state


# ============== Helper Functions ==============

def _extract_profile_from_memory(memory_content: str) -> Dict[str, Any]:
    """
    Extract user profile data from memory markdown content.
    """
    profile = {
        "weight": 70,
        "height": 170,
        "age": 30,
        "gender": 1,
        "activity_level": 2
    }

    # Simple parsing - in production would use proper markdown parsing
    lines = memory_content.split('\n')
    for line in lines:
        line = line.strip()

        # Parse basic info line: "- 性别: 男 | 年龄: 30 | 身高: 175cm | 体重: 75kg"
        if '身高:' in line and '体重:' in line:
            try:
                parts = line.split('|')
                for part in parts:
                    part = part.strip()
                    if '性别:' in part:
                        profile["gender"] = 1 if '男' in part else 2
                    elif '年龄:' in part:
                        age_str = part.split(':')[1].strip()
                        profile["age"] = int(''.join(filter(str.isdigit, age_str)) or 30)
                    elif '身高:' in part:
                        height_str = part.split(':')[1].strip()
                        profile["height"] = float(''.join(c for c in height_str if c.isdigit() or c == '.') or 170)
                    elif '体重:' in part:
                        weight_str = part.split(':')[1].strip()
                        profile["weight"] = float(''.join(c for c in weight_str if c.isdigit() or c == '.') or 70)
            except Exception:
                pass

        # Parse activity level: "- 活动水平: 轻度活动 (2)"
        if '活动水平:' in line:
            try:
                if '(1)' in line:
                    profile["activity_level"] = 1
                elif '(2)' in line:
                    profile["activity_level"] = 2
                elif '(3)' in line:
                    profile["activity_level"] = 3
                elif '(4)' in line:
                    profile["activity_level"] = 4
                elif '(5)' in line:
                    profile["activity_level"] = 5
            except Exception:
                pass

    return profile


def _build_suggestion_context(state: GoalTrackingState) -> str:
    """
    Build context string for LLM suggestion generation.
    """
    parts = []

    # Goal info
    active_goals = state.get("active_goals", [])
    if active_goals:
        goal = active_goals[0]
        goal_name = get_goal_type_name(goal.get("goal_type", 3))
        parts.append(f"当前目标: {goal_name}")
        if goal.get("target_weight"):
            parts.append(f"目标体重: {goal['target_weight']} kg")

    # Daily targets
    if state.get("macro_targets"):
        targets = state["macro_targets"]
        parts.append(f"\n每日目标:")
        parts.append(f"- 卡路里: {targets.get('calories', 0)} kcal")
        parts.append(f"- 蛋白质: {targets.get('protein', 0)}g")
        parts.append(f"- 碳水: {targets.get('carbs', 0)}g")
        parts.append(f"- 脂肪: {targets.get('fat', 0)}g")

    # Today's consumption
    today = state.get("today_consumed", {})
    parts.append(f"\n今日已摄入:")
    parts.append(f"- 卡路里: {today.get('calories', 0)} kcal")
    parts.append(f"- 蛋白质: {today.get('protein', 0)}g")
    parts.append(f"- 碳水: {today.get('carbs', 0)}g")
    parts.append(f"- 脂肪: {today.get('fat', 0)}g")

    # Remaining budget
    remaining = state.get("remaining_budget", {})
    parts.append(f"\n剩余配额:")
    parts.append(f"- 卡路里: {remaining.get('calories', 0)} kcal")
    parts.append(f"- 蛋白质: {remaining.get('protein', 0)}g")

    # Goal progress
    progress = state.get("goal_progress", {})
    if progress:
        parts.append(f"\n目标进度:")
        parts.append(f"- 进度: {progress.get('progress_percentage', 0)}%")
        parts.append(f"- 体重变化: {progress.get('weight_change', 0)} kg")
        parts.append(f"- 趋势: {progress.get('trend', 'stable')}")

    return "\n".join(parts)


def _parse_suggestion_response(content: str) -> tuple:
    """
    Parse LLM response to extract suggestions, warnings, and summary.
    """
    suggestions = []
    warnings = []
    summary = ""

    lines = content.split('\n')
    current_section = None

    for line in lines:
        line = line.strip()
        if not line:
            continue

        # Detect sections
        if '建议' in line and ':' in line:
            current_section = 'suggestions'
            continue
        elif '警告' in line and ':' in line:
            current_section = 'warnings'
            continue
        elif '进度总结' in line or '总结' in line:
            current_section = 'summary'
            continue

        # Parse content based on section
        if current_section == 'suggestions':
            # Remove list markers
            clean = line.lstrip('0123456789.-) ').strip()
            if clean and len(clean) > 5:
                suggestions.append(clean)
        elif current_section == 'warnings':
            clean = line.lstrip('0123456789.-) ⚠️').strip()
            if clean and len(clean) > 3:
                warnings.append(clean)
        elif current_section == 'summary':
            if line and not line.startswith('-'):
                summary = line

    # Ensure we have at least one suggestion
    if not suggestions:
        suggestions = ["继续保持良好的饮食习惯"]

    return suggestions, warnings, summary
