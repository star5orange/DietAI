"""硬件专用节点: 一步出结构化营养分析 + 生成简短建议 (适配 ESP32 480×320 小屏幕)"""

from agent.nutrition_agent.utils.prompts import create_nutrition_prompt
from agent.nutrition_agent.utils.states import AgentState
from agent.nutrition_agent.utils.structs import NutritionAdvice, ActionItem, NutritionAnalysis


def analyze_and_extract(state: AgentState) -> AgentState:
    """
    硬件专用前两步合并: 用户文字描述 → 结构化营养分析 (一次 LLM 调用)

    原流程 analyze_text(视觉模型产出"详细描述") → extract_nutrition_info(把描述再结构化)，
    中间那段描述只作为下一步输入、固件屏幕并不展示，两次串行 LLM 合并为一次；
    同时把模型从 vision_model(qwen3.7-plus) 换成更快的 analysis_model。
    """
    try:
        text_desc = state.get("text_description", "")
        if not text_desc:
            state["error_message"] = "未提供食物描述"
            return state

        # 把原 analyze_text 的分析要点与中式食物参考压进同一次调用，
        # 让模型在估算前先完成分量/烹饪方式推断，但不输出推断过程
        prompt = create_nutrition_prompt(
            f"""用户原始描述：{text_desc}

请先在心里完成以下推断（不要输出推断过程，只体现在最终 JSON 的估算值里）：
1. 具体的食物名称和种类（优先使用中文菜名）
2. 估计的分量和重量（1份≈多少克）
3. 烹饪方式（煎、炒、蒸、煮、炖、炸、凉拌等）
4. 可能的调料和配菜
5. 该食物的营养特点

中式食物参考：
- 米饭1碗≈150g，炒饭1份≈300g
- 面条1碗≈200g（煮后），炒面1份≈350g
- 鸡排1份≈150-200g（炸），鸡胸肉1份≈150g
- 蔬菜1份≈100-150g
- 炒菜用油约15-30g/份，炸制用油约20-40g/份"""
        )

        structured_model = state['analysis_model'].with_structured_output(
            NutritionAnalysis,
            method="json_mode",
        )
        nutrition_analysis = structured_model.invoke(prompt)
        state["nutrition_analysis"] = nutrition_analysis
        state["current_step"] = "nutrition_extracted"
        print(f"硬件营养分析：{nutrition_analysis}")

    except Exception as e:
        print(f"硬件营养分析失败: {str(e)}")
        state["error_message"] = f"文字营养分析失败: {str(e)}"

    return state


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
