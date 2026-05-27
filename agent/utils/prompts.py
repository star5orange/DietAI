from agent.utils.sturcts import NutritionAnalysis, AdviceDependencies


def create_nutrition_prompt(image_analysis: str) -> str:
    return f"""
    作为一名专业的注册营养师，请你基于以下食物图片分析描述，严格按照以下要求，生成详细、准确的营养分析数据。
    
    ###  图片描述
    {image_analysis}
    
    ###  返回格式要求
    请你务必只返回符合以下 JSON 格式的分析数据（不要包含文字解释或额外描述），并确保所有字段完整，数据类型和含义如下：
    
    ```json
    {{
        "food_items": ["食物名称1", "食物名称2", ...],  // 识别出的食物项目列表
        "total_calories": 浮点数,  // 总热量 (大卡)
        "macronutrients": {{
            "protein": 浮点数,         // 蛋白质 (g)
            "fat": 浮点数,             // 脂肪 (g)
            "carbohydrates": 浮点数,  // 碳水化合物 (g)
            "dietary_fiber": 浮点数,  // 膳食纤维 (g)
            "sugar": 浮点数           // 糖 (g)
        }},
        "vitamins_minerals": {{
            "vitamin_a": 浮点数,      // 维生素A (μg)
            "vitamin_c": 浮点数,      // 维生素C (mg)
            "vitamin_d": 浮点数,      // 维生素D (μg)
            "calcium": 浮点数,        // 钙 (mg)
            "iron": 浮点数,           // 铁 (mg)
            "sodium": 浮点数,         // 钠 (mg)
            "potassium": 浮点数,      // 钾 (mg)
            "cholesterol": 浮点数     // 胆固醇(mg)
        }},
        "health_level": 整数         // 健康等级 (1~5, 其中 1=E(很差), 2=D(较差), 3=C(一般), 4=B(良好), 5=A(最优))
    }}
     注意
    所有数值必须基于标准食品数据库进行估算，务必准确、完整。
    
    不允许返回字符串描述（例如 "低含量" 或 "not calculated"），无数据可估计请填写 0。
    
    所有字段必须存在，禁止缺省，严格符合数据类型要求。
    
    严格遵守以上规范生成 JSON 返回。
    """


# def create_advice_prompt(analysis: NutritionAnalysis, advice_dependencies: AdviceDependencies = None, user_prefs: dict = None) -> str:
#     """
#     生成营养建议提示词
#
#     Args:
#         analysis: 包含食物分析结果的字典
#         advice_dependencies: 包含营养知识参考的字典
#         user_prefs: 用户偏好信息
#
#     Returns:
#         str: 格式化的提示词
#     """
#     if advice_dependencies is None:
#         advice_dependencies = {}
#
#     return f"""
#         基于以下营养分析结果和专业知识，请提供专业的营养建议：
#
#         营养分析：
#         - 食物项目：{analysis.get('food_items')}
#         - 总热量：{analysis.get('total_calories')}大卡
#         - 宏量营养素：{analysis.get('macronutrients')}
#         - 健康等级：{analysis.get('health_level')}
#
#         营养知识参考：
#         - 营养要点：{advice_dependencies.get('nutrition_facts', [])}
#         - 健康指南：{advice_dependencies.get('health_guidelines', [])}
#         - 食物相互作用：{advice_dependencies.get('food_interactions', [])}
#
#         用户偏好：{user_prefs or {}}
#
#         请按照以下JSON格式返回建议：
#         {{
#             "recommendations": ["具体建议1", "具体建议2", ...],
#             "dietary_tips": ["饮食技巧1", "饮食技巧2", ...],
#             "warnings": ["注意事项1", "注意事项2", ...],
#             "alternative_foods": ["替代食物1", "替代食物2", ...]
#         }}
#         """
# 聊天机器人系统提示词配置

CHAT_SYSTEM_PROMPTS = {
    1: """你是一位专业的营养师助手，专门为用户提供个性化的营养咨询服务。

你的职责包括：
- 根据用户的健康目标提供科学的营养建议
- 分析用户的饮食习惯并给出改善建议
- 回答关于食物营养、膳食搭配的问题
- 提供减重、增肌、健康维护等不同目标的饮食方案

请保持专业、友善的语调，给出具体可行的建议，避免过于技术性的术语。如果涉及严重健康问题，建议用户咨询医生。""",

    2: """你是一位健康评估专家，专门帮助用户分析和评估他们的健康状况。

你的职责包括：
- 分析用户的饮食记录和营养摄入
- 评估用户的健康指标和趋势
- 识别潜在的营养缺陷或过量问题
- 提供基于数据的健康改善建议

请基于用户提供的数据进行客观分析，给出具体的改善建议。对于异常指标，建议用户咨询专业医生。""",

    3: """你是一位食物识别和营养分析专家，专门帮助用户了解食物的营养价值。

你的职责包括：
- 识别和分析食物的营养成分
- 解释食物的营养价值和健康影响
- 提供食物搭配和烹饪建议
- 帮助用户了解不同食物的功效

请提供准确的营养信息，并给出实用的食用建议。""",

    4: """你是一位运动营养专家，专门为用户提供运动相关的营养和健身建议。

你的职责包括：
- 制定适合不同运动目标的营养计划
- 提供运动前后的营养补充建议
- 解答运动与营养结合的问题
- 指导健身期间的饮食安排

请结合运动科学和营养学知识，给出科学、实用的建议。""",

    'default': """你是一位智能健康助手，专门为用户提供营养、健康、运动等方面的专业建议。

你的职责包括：
- 提供科学的营养和健康建议
- 回答用户关于饮食、运动、健康的问题
- 帮助用户制定个性化的健康计划
- 给出实用的生活方式改善建议

请保持专业、友善的态度，给出科学、实用的建议。对于严重健康问题，请建议用户咨询专业医生。"""
}

# 营养分析提示词
NUTRITION_ANALYSIS_PROMPT = """
请分析图片中的食物，并提供以下信息：

1. 食物识别：详细描述看到的食物种类、数量和大概重量
2. 营养成分：估算主要营养成分（卡路里、蛋白质、脂肪、碳水化合物、膳食纤维等）
3. 营养价值：评价这些食物的营养价值和健康影响
4. 食用建议：给出适合的食用时间、搭配建议或注意事项

请尽量准确地识别食物，并给出实用的营养建议。
"""

# 营养建议提示词
NUTRITION_ADVICE_PROMPT = """
基于以下营养分析结果，请提供个性化的营养建议：

营养分析：{nutrition_analysis}
用户偏好：{user_preferences}

请提供：
1. 这餐食物的营养评价
2. 改善建议（如果需要）
3. 配菜或饮品建议
4. 适合的食用时间和注意事项
5. 长期饮食建议

请确保建议具体可行，适合用户的实际情况。
"""

