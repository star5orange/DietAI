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
from typing import Dict, Any, Optional, List
from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.runnables import RunnableConfig
from langchain_core.documents import Document

from agent.enhanced_nutrition.states import EnhancedNutritionState
from agent.memory.memory_manager import MemoryManager
from agent.common_utils.model_utils import get_model
from agent.common_utils.rag_utils import rag_search_by_user_profile
from agent.utils.configuration import Configuration
from agent.utils.structs import NutritionAdvice

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

            # Extract crowd_tag and constitution_type from memory
            crowd_tag, constitution_type = _extract_profile_tags(shared_memory)
            if crowd_tag:
                state["user_preferences"]["crowd_tag"] = crowd_tag
            if constitution_type:
                state["user_preferences"]["constitution_type"] = constitution_type

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
    3. Uses crowd_tag/constitution_type for RAG precision retrieval
    4. Provides more personalized recommendations
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

        # Extract crowd_tag and constitution_type
        crowd_tag = user_prefs.get("crowd_tag", "")
        constitution_type = user_prefs.get("constitution_type", "")

        # RAG precision retrieval based on user profile
        rag_context = ""
        food_names = ", ".join(analysis.food_items) if analysis.food_items else ""
        try:
            rag_docs: List[Document] = []
            # Search by food name with user profile filtering
            if food_names:
                docs = rag_search_by_user_profile(
                    query=food_names,
                    k=3,
                    crowd=crowd_tag or None,
                    constitution=constitution_type or None,
                    data_type="food"
                )
                rag_docs.extend(docs)
            # Search seasonal advice
            from datetime import datetime as _dt
            month = _dt.now().month
            season_map = {1: "冬", 2: "冬", 3: "春", 4: "春", 5: "春", 6: "夏", 7: "夏", 8: "夏", 9: "秋", 10: "秋", 11: "秋", 12: "冬"}
            current_season = season_map.get(month, "")
            if current_season:
                season_docs = rag_search_by_user_profile(
                    query="节气饮食养生建议",
                    k=2,
                    season=current_season,
                    data_type="solar_term"
                )
                rag_docs.extend(season_docs)
            # Search special diet advice for this crowd
            if crowd_tag:
                diet_docs = rag_search_by_user_profile(
                    query="饮食建议营养方案",
                    k=2,
                    crowd=crowd_tag,
                    data_type="special_diet"
                )
                rag_docs.extend(diet_docs)

            if rag_docs:
                rag_context = "\n".join(
                    f"- [{doc.metadata.get('data_type', '未知')}] {doc.page_content[:200]}"
                    for doc in rag_docs[:8]
                )
        except Exception as e:
            logger.warning(f"RAG retrieval failed, continuing without: {e}")

        # Build crowd/constitution description
        crowd_desc = f"人群标签: {crowd_tag}" if crowd_tag else "人群标签: 普通日常"
        constitution_desc = f"体质类型: {constitution_type}" if constitution_type else "体质类型: 未设定"

        # Build enhanced prompt with memory context
        prompt = f"""
你是一位专业的营养师，请根据以下信息提供个性化的营养建议。

=== 用户长期画像 ===
{user_memory[:2000] if user_memory else "暂无用户画像数据"}

=== 用户人群与体质 ===
{crowd_desc}
{constitution_desc}

=== 近期饮食情况 ===
{nutrition_memory[:1500] if nutrition_memory else "暂无近期饮食数据"}

=== 本餐营养分析 ===
- 食物项目：{analysis.food_items}
- 总热量：{analysis.total_calories}大卡
- 宏量营养素：{analysis.macronutrients}
- 健康等级：{analysis.health_level}

=== 营养知识参考 ===
- 营养要点：{advice_dependencies.nutrition_facts if advice_dependencies else []}
- 健康指南：{advice_dependencies.health_guidelines if advice_dependencies else []}
- 食物相互作用：{advice_dependencies.food_interactions if advice_dependencies else []}

=== RAG 知识库精准检索 ===
{rag_context if rag_context else "暂无匹配知识"}

=== 用户饮食限制 ===
- 过敏原：{user_prefs.get('allergies', [])}
- 健康状况：{user_prefs.get('diseases', [])}
- 不喜欢的食物：{user_prefs.get('disliked_foods', [])}

请根据以上信息，特别注意用户的人群标签、体质类型、健康状况和饮食限制，提供：
1. 针对这餐的具体建议（结合用户人群标签和体质给出针对性建议）
2. 实用的饮食技巧（基于用户的体质和饮食习惯）
3. 需要注意的警告（如与疾病、体质相关的风险）
4. 替代食物建议（考虑用户的喜好和体质宜忌）
5. 当季养生建议（结合当前节气和体质）
6. 可执行行动项：给出2-4条用户可以立即执行的具体行动，每条标注优先级（high=紧急重要/medium=建议执行/low=可选优化）

请按照以下JSON格式返回建议：
{{
    "recommendations": ["具体建议1", "具体建议2", ...],
    "dietary_tips": ["饮食技巧1", "饮食技巧2", ...],
    "warnings": ["注意事项1", "注意事项2", ...],
    "alternative_foods": ["替代食物1", "替代食物2", ...],
    "action_items": [
        {{"action": "具体行动描述", "priority": "high/medium/low"}},
        ...
    ]
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

        # Hard rule: allergy cross-check
        _apply_allergy_hard_rule(state)

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


def _extract_profile_tags(memory_content: str) -> tuple:
    """
    Extract crowd_tag and constitution_type from memory markdown content.

    Looks for lines like:
    - 人群标签: 减脂,健身
    - 体质类型: 气虚
    """
    crowd_tag = None
    constitution_type = None

    for line in memory_content.split('\n'):
        line = line.strip()
        if line.startswith('- 人群标签:'):
            val = line.split(':', 1)[1].strip()
            if val and val != '未设定' and val != '暂无':
                crowd_tag = val
        elif line.startswith('- 体质类型:'):
            val = line.split(':', 1)[1].strip()
            if val and val != '未设定' and val != '暂无':
                constitution_type = val

    return crowd_tag, constitution_type


# ============== Allergy Cross-Reaction Knowledge ==============

# Common food allergy cross-reactions in Chinese diet
ALLERGY_CROSS_REACTIONS: Dict[str, Dict[str, Any]] = {
    "牛奶": {
        "aliases": ["牛奶", "鲜奶", "纯牛奶", "脱脂奶", "全脂奶", "奶油", "芝士", "奶酪", "黄油", "乳清", "炼乳", "奶粉"],
        "cross_react": ["羊奶", "马奶"],
        "hidden_in": ["蛋糕", "饼干", "面包", "冰淇淋", "拿铁", "奶茶", "奶黄包", "布丁", "酸奶"],
    },
    "鸡蛋": {
        "aliases": ["鸡蛋", "蛋", "蛋清", "蛋黄", "蛋白", "蛋液", "蛋粉"],
        "cross_react": ["鸭蛋", "鹅蛋", "鹌鹑蛋"],
        "hidden_in": ["蛋糕", "蛋挞", "布丁", "蛋黄酱", "沙拉酱", "松花蛋", "蛋炒饭"],
    },
    "花生": {
        "aliases": ["花生", "花生米", "花生酱", "花生油", "落花生"],
        "cross_react": ["大豆", "其他豆类"],
        "hidden_in": ["火锅底料", "麻辣烫", "宫保鸡丁", "花生糖", "麻酱", "辣条"],
    },
    "海鲜": {
        "aliases": ["海鲜", "虾", "蟹", "鱼", "贝", "牡蛎", "扇贝", "蛤蜊", "三文鱼", "鲈鱼", "带鱼", "鱿鱼", "墨鱼", "海参"],
        "cross_react": ["其他甲壳类", "其他贝类"],
        "hidden_in": ["鱼露", "虾酱", "蚝油", "海鲜酱油", "蟹棒", "鱼丸", "虾饺"],
    },
    "大豆": {
        "aliases": ["大豆", "黄豆", "豆浆", "豆腐", "豆皮", "腐竹", "豆干", "酱油", "豆瓣酱", "味噌"],
        "cross_react": ["花生", "绿豆", "豌豆"],
        "hidden_in": ["酱油", "豆瓣酱", "豆豉", "味噌汤", "素鸡", "素肉"],
    },
    "小麦": {
        "aliases": ["小麦", "面粉", "面条", "馒头", "包子", "饺子", "面包", "麦片", "麸质"],
        "cross_react": ["大麦", "黑麦", "燕麦"],
        "hidden_in": ["酱油", "醋", "啤酒", "炸鸡裹粉", "面筋", "烤麸"],
    },
    "坚果": {
        "aliases": ["坚果", "核桃", "杏仁", "腰果", "榛子", "开心果", "夏威夷果", "松子", "巴旦木"],
        "cross_react": ["花生", "其他树坚果"],
        "hidden_in": ["坚果酥", "五仁月饼", "坚果奶", "巧克力", "能量棒"],
    },
    "芒果": {
        "aliases": ["芒果", "芒果汁", "芒果干"],
        "cross_react": ["漆树科水果"],
        "hidden_in": ["芒果冰沙", "杨枝甘露", "芒果糯米饭"],
    },
}


def _apply_allergy_hard_rule(state: EnhancedNutritionState) -> None:
    """
    Hard rule: check AI-generated advice against user allergies.

    If any advice recommends a food that conflicts with user allergies,
    add a strong warning and flag the recommendation.
    """
    advice = state.get("nutrition_advice")
    if not advice:
        return

    user_prefs = state.get("user_preferences", {})
    user_allergies = user_prefs.get("allergies", [])
    if not user_allergies:
        return

    # Also check from nutrition analysis (food items in current meal)
    analysis = state.get("nutrition_analysis")
    current_foods = analysis.food_items if analysis else []

    # Build full allergy alias set
    allergy_aliases: Dict[str, str] = {}  # alias -> original allergy name
    for allergy_name in user_allergies:
        allergy_aliases[allergy_name] = allergy_name
        if allergy_name in ALLERGY_CROSS_REACTIONS:
            for alias in ALLERGY_CROSS_REACTIONS[allergy_name]["aliases"]:
                allergy_aliases[alias] = allergy_name
            for cross in ALLERGY_CROSS_REACTIONS[allergy_name].get("cross_react", []):
                allergy_aliases[cross] = allergy_name

    # Check all advice text fields for allergy conflicts
    all_text_fields = []
    if advice.recommendations:
        all_text_fields.extend(advice.recommendations)
    if advice.dietary_tips:
        all_text_fields.extend(advice.dietary_tips)
    if advice.alternative_foods:
        all_text_fields.extend(advice.alternative_foods)

    conflict_warnings = []
    for text in all_text_fields:
        for alias, original in allergy_aliases.items():
            if alias in text:
                conflict_warnings.append(f"[过敏硬规则] 检测到建议中包含过敏原相关食物'{alias}'（用户过敏：{original}），请勿食用！")
                break

    # Check current meal against allergies
    meal_warnings = []
    for food in current_foods:
        for alias, original in allergy_aliases.items():
            if alias in food:
                meal_warnings.append(f"[过敏硬规则] 当前餐食包含'{food}'，与您的过敏原'{original}'冲突，请立即停止食用！")
                break

    # Add warnings to advice
    if conflict_warnings or meal_warnings:
        existing_warnings = list(advice.warnings) if advice.warnings else []
        existing_warnings.extend(meal_warnings)
        existing_warnings.extend(conflict_warnings)
        advice.warnings = existing_warnings

    # Check hidden allergens in current meal
    hidden_warnings = []
    for allergy_name in user_allergies:
        if allergy_name in ALLERGY_CROSS_REACTIONS:
            hidden_foods = ALLERGY_CROSS_REACTIONS[allergy_name].get("hidden_in", [])
            for food in current_foods:
                for hidden in hidden_foods:
                    if hidden in food:
                        hidden_warnings.append(
                            f"[过敏硬规则] '{food}'可能含有隐藏的{allergy_name}成分，过敏体质请谨慎食用！"
                        )
                        break

    if hidden_warnings:
        existing_warnings = list(advice.warnings) if advice.warnings else []
        existing_warnings.extend(hidden_warnings)
        advice.warnings = existing_warnings
