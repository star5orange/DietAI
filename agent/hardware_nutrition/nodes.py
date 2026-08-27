"""硬件专用节点: 生成简短营养建议 (适配 ESP32 480×320 小屏幕)"""

from agent.nutrition_agent.utils.states import AgentState
from agent.nutrition_agent.utils.structs import NutritionAdvice, ActionItem


def generate_hardware_advice(state: AgentState) -> AgentState:
    """
    硬件专用建议生成:
    - 仅 1 条推荐, 1 条 tips, 1 条 warning
    - 每条 ≤ 30 中文字 (适配小屏幕)
    - 口语化、简洁
    """
    try:
        analysis = state.get("nutrition_analysis")
        if not analysis:
            state["nutrition_advice"] = None
            state["current_step"] = "advice_generated"
            return state

        food_str = "、".join(analysis.food_items)
        cal = analysis.total_calories
        protein = analysis.macronutrients.protein
        fat = analysis.macronutrients.fat
        carbs = analysis.macronutrients.carbohydrates
        health = analysis.health_level

        prompt = f"""你是营养师。用户吃了{food_str}。分析数据: 热量{cal:.0f}kcal, 蛋白质{protein:.0f}g, 脂肪{fat:.0f}g, 碳水{carbs:.0f}g, 健康等级{health}/5。

请用**口头聊天语气**给出建议。recommendations 放1条实用建议(30-50字), dietary_tips 放1条饮食小窍门(15-25字)。
只返回JSON:
{{
    "recommendations": ["1条核心建议, 口语化, 30-50字"],
    "dietary_tips": ["1条小贴士, 15-25字"],
    "warnings": [],
    "alternative_foods": [],
    "action_items": []
}}"""

        model = state['analysis_model']

        structured_model = model.with_structured_output(
            NutritionAdvice,
            method="json_mode",
        )

        nutrition_advice = structured_model.invoke(prompt)
        state["nutrition_advice"] = nutrition_advice
        state["current_step"] = "advice_generated"

    except Exception as e:
        print(f"硬件建议生成失败: {str(e)}")
        state["nutrition_advice"] = None

    return state
