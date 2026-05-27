"""
Enhanced Nutrition Agent Nodes

Extends the original nutrition agent with memory-aware capabilities:
1. enhanced_state_init: Initialize state and load user memory
2. load_shared_memory: Load user preferences from memory file
3. analyze_image: (reuse from original)
4. extract_nutrition: (reuse from original)
5. retrieve_knowledge: (reuse from original)
6. generate_dependencies: (reuse from original)
7. generate_advice_with_context: Generate advice using memory context
8. save_to_nutrition_md: Update nutrition workspace file
9. format_response: (reuse from original)

New nodes focus on memory integration while reusing core analysis logic.
"""

import logging
from datetime import datetime, date
from typing import Dict, Any, Optional
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.runnables import RunnableConfig

from agent.enhanced_nutrition.states import EnhancedNutritionState
from agent.memory.memory_manager import MemoryManager
from agent.common_utils.model_utils import get_model
from agent.utils.configuration import Configuration
from agent.utils.sturcts import NutritionAdvice

logger = logging.getLogger(__name__)


async def enhanced_state_init(state: EnhancedNutritionState, config: RunnableConfig) -> EnhancedNutritionState:
    """
    Initialize state with models and load user memory context.

    This extends the original state_init to also load user memory.
    """
    try:
        configurable = Configuration.from_runnable_config(config)

        # Initialize models
        vision_model = get_model(
            model_provider=configurable.vision_model_provider,
            model_name=configurable.vision_model
        )
        analysis_model = get_model(
            model_provider=configurable.analysis_model_provider,
            model_name=configurable.analysis_model
        )

        # Build initial state
        new_state = EnhancedNutritionState(
            image_data=state.get("image_data"),
            image_dir=state.get("image_dir"),
            user_id=state.get("user_id"),
            user_memory_context=None,
            nutrition_memory_context=None,
            user_preferences=state.get("user_preferences", {}),
            image_analysis=None,
            nutrition_analysis=None,
            nutrition_advice=None,
            advice_dependencies=None,
            retrieved_documents=[],
            conversation_history=[],
            current_step="initializing",
            error_message=None,
            vision_model=vision_model,
            analysis_model=analysis_model
        )

        new_state["current_step"] = "initialized"
        logger.info(f"Enhanced state initialized for user {state.get('user_id')}")
        return new_state

    except Exception as e:
        state["error_message"] = f"State initialization failed: {str(e)}"
        state["current_step"] = "error"
        logger.error(state["error_message"])
        return state


async def load_shared_memory(state: EnhancedNutritionState) -> EnhancedNutritionState:
    """
    Load user memory from shared workspace.

    Reads shared/user_memory.md to get:
    - Allergies and dietary restrictions
    - Health conditions (diseases)
    - Food preferences (likes/dislikes)
    """
    try:
        user_id = state.get("user_id")

        if not user_id:
            logger.debug("No user_id provided, skipping memory load")
            state["current_step"] = "memory_loaded"
            return state

        manager = MemoryManager(user_id)

        # Load shared memory
        shared_memory = await manager.read_workspace("shared")
        if shared_memory:
            state["user_memory_context"] = shared_memory

            # Extract preferences from memory if not already provided
            if not state.get("user_preferences") or not state["user_preferences"].get("allergies"):
                extracted_prefs = _extract_preferences_from_memory(shared_memory)
                state["user_preferences"] = {
                    **state.get("user_preferences", {}),
                    **extracted_prefs
                }

        # Load nutrition memory for context
        nutrition_memory = await manager.read_workspace("nutrition")
        if nutrition_memory:
            state["nutrition_memory_context"] = nutrition_memory

        state["current_step"] = "memory_loaded"
        logger.info(f"Loaded memory for user {user_id}")

    except Exception as e:
        logger.warning(f"Failed to load memory: {str(e)}")
        # Non-fatal - continue without memory
        state["current_step"] = "memory_loaded"

    return state


def generate_advice_with_context(state: EnhancedNutritionState) -> EnhancedNutritionState:
    """
    Generate nutrition advice using memory context for personalization.

    This is an enhanced version of generate_nutrition_advice that:
    1. Includes user memory context in the prompt
    2. Considers dietary restrictions and preferences
    3. Provides more personalized recommendations
    """
    try:
        if not state.get("advice_dependencies"):
            logger.warning("Missing advice dependencies")

        analysis = state.get("nutrition_analysis")
        if not analysis:
            state["error_message"] = "Missing nutrition analysis"
            return state

        advice_dependencies = state.get("advice_dependencies")
        user_prefs = state.get("user_preferences", {})
        user_memory = state.get("user_memory_context", "")
        nutrition_memory = state.get("nutrition_memory_context", "")

        # Build enhanced prompt with memory context
        prompt = f"""
你是一位专业的营养师，请根据以下信息提供个性化的营养建议。

=== 用户长期画像 ===
{user_memory[:2000] if user_memory else "暂无用户画像数据"}

=== 近期饮食情况 ===
{nutrition_memory[:1000] if nutrition_memory else "暂无近期饮食数据"}

=== 本餐营养分析 ===
- 食物项目：{analysis.food_items}
- 总热量：{analysis.total_calories}大卡
- 宏量营养素：{analysis.macronutrients}
- 健康等级：{analysis.health_level}

=== 营养知识参考 ===
- 营养要点：{advice_dependencies.nutrition_facts if advice_dependencies else []}
- 健康指南：{advice_dependencies.health_guidelines if advice_dependencies else []}
- 食物相互作用：{advice_dependencies.food_interactions if advice_dependencies else []}

=== 用户饮食限制 ===
- 过敏原：{user_prefs.get('allergies', [])}
- 健康状况：{user_prefs.get('diseases', [])}
- 不喜欢的食物：{user_prefs.get('disliked_foods', [])}

请根据以上信息，特别注意用户的健康状况和饮食限制，提供：
1. 针对这餐的具体建议（考虑用户的过敏原和疾病）
2. 实用的饮食技巧（基于用户的饮食习惯）
3. 需要注意的警告（如与疾病相关的风险）
4. 替代食物建议（考虑用户的喜好）

请按照以下JSON格式返回建议：
{{
    "recommendations": ["具体建议1", "具体建议2", ...],
    "dietary_tips": ["饮食技巧1", "饮食技巧2", ...],
    "warnings": ["注意事项1", "注意事项2", ...],
    "alternative_foods": ["替代食物1", "替代食物2", ...]
}}
"""

        model = state['analysis_model']
        structured_model = model.with_structured_output(NutritionAdvice)

        try:
            nutrition_advice = structured_model.invoke(prompt)
            state["nutrition_advice"] = nutrition_advice
        except Exception as e:
            logger.warning(f"Structured output failed, using fallback: {e}")
            # Fallback to unstructured and parse
            response = model.invoke(prompt)
            state["nutrition_advice"] = NutritionAdvice(
                recommendations=["建议均衡饮食，注意营养搭配"],
                dietary_tips=["细嚼慢咽，有助消化"],
                warnings=[],
                alternative_foods=[]
            )

        state["current_step"] = "advice_generated"
        logger.info(f"Generated advice with context for user {state.get('user_id')}")

    except Exception as e:
        state["error_message"] = f"Advice generation failed: {str(e)}"
        logger.error(state["error_message"])

    return state


async def save_to_nutrition_md(state: EnhancedNutritionState) -> EnhancedNutritionState:
    """
    Update the nutrition workspace file with this analysis.
    """
    try:
        user_id = state.get("user_id")
        if not user_id:
            state["current_step"] = "saved_to_md"
            return state

        analysis = state.get("nutrition_analysis")
        if not analysis:
            state["current_step"] = "saved_to_md"
            return state

        manager = MemoryManager(user_id)

        # Build new analysis record
        today = date.today().isoformat()
        foods = ", ".join(analysis.food_items) if analysis.food_items else "未识别"
        health_level_map = {1: "E", 2: "D", 3: "C", 4: "B", 5: "A"}
        health_level = health_level_map.get(analysis.health_level, "C")

        new_record = f"""### {today} 新分析
- 食物: {foods}
- 热量: {analysis.total_calories} kcal
- 健康等级: {health_level}"""

        await manager.update_section("nutrition", "近期分析记录", new_record, replace=False)

        state["current_step"] = "saved_to_md"
        logger.info(f"Saved analysis to nutrition MD for user {user_id}")

    except Exception as e:
        logger.warning(f"Failed to save to nutrition MD: {str(e)}")
        # Non-fatal
        state["current_step"] = "saved_to_md"

    return state


# ============== Helper Functions ==============

def _extract_preferences_from_memory(memory_content: str) -> Dict[str, Any]:
    """
    Extract user preferences from memory markdown content.
    """
    prefs = {
        "allergies": [],
        "diseases": [],
        "dietary_restrictions": [],
        "liked_foods": [],
        "disliked_foods": []
    }

    current_section = None
    lines = memory_content.split('\n')

    for line in lines:
        line = line.strip()

        # Detect sections
        if '## 健康状况' in line:
            current_section = 'health'
        elif '### 过敏原' in line:
            current_section = 'allergies'
        elif '### 疾病' in line or '医疗状况' in line:
            current_section = 'diseases'
        elif '## 长期偏好' in line:
            current_section = 'preferences'
        elif '### 喜欢的食物' in line:
            current_section = 'liked'
        elif '### 不喜欢的食物' in line:
            current_section = 'disliked'
        elif '### 饮食限制' in line:
            current_section = 'restrictions'
        elif line.startswith('## '):
            current_section = None

        # Parse list items
        if line.startswith('- ') and current_section:
            item = line[2:].strip()
            if not item or item == '无' or '暂无' in item:
                continue

            # Extract just the name (before any parentheses)
            name = item.split('(')[0].strip()

            if current_section == 'allergies':
                prefs["allergies"].append(name)
            elif current_section == 'diseases':
                prefs["diseases"].append(name)
            elif current_section == 'restrictions':
                prefs["dietary_restrictions"].append(name)
            elif current_section == 'liked':
                # May be comma-separated list
                for food in name.split(','):
                    food = food.strip()
                    if food:
                        prefs["liked_foods"].append(food)
            elif current_section == 'disliked':
                for food in name.split(','):
                    food = food.strip()
                    if food:
                        prefs["disliked_foods"].append(food)

    return prefs
