"""
AI 顾问风格 Prompt 管理器

根据用户选择的顾问风格、专业偏向、关注重点生成对应的 System Prompt，
并强制注入合规免责声明，过滤情感诱导表达。

Milestone 2 核心模块
"""

from typing import Optional
from enum import Enum


class AdvisorStyle(str, Enum):
    """顾问风格枚举"""
    NUTRITIONIST = "nutritionist"  # 营养师
    FITNESS_COACH = "fitness_coach"  # 健身教练
    TCM_HEALER = "tcm_healer"  # 中医养生师
    ENCOURAGING_FRIEND = "encouraging_friend"  # 鼓励型伙伴
    MOTIVATOR = "motivator"  # 励志伙伴（别名）


class FocusGoal(str, Enum):
    """关注目标枚举"""
    FAT_LOSS = "fat_loss"  # 减脂
    MUSCLE_GAIN = "muscle_gain"  # 增肌
    SUGAR_CONTROL = "sugar_control"  # 控糖
    WELLNESS = "wellness"  # 养生
    BALANCED = "balanced"  # 均衡饮食


class FocusNutrient(str, Enum):
    """关注营养素枚举"""
    CALORIES = "calories"  # 热量
    PROTEIN = "protein"  # 蛋白质
    CARB = "carb"  # 碳水
    FAT = "fat"  # 脂肪
    MICRONUTRIENT = "micronutrient"  # 微量元素


class ResponseStyle(str, Enum):
    """回复风格枚举"""
    CONCISE = "concise"  # 简洁直接
    DETAILED = "detailed"  # 详尽细致
    EXAMPLE_RICH = "example_rich"  # 举例说明
    PROFESSIONAL = "professional"  # 专业严谨
    FRIENDLY = "friendly"  # 亲切友好
    MOTIVATING = "motivating"  # 激励鼓舞


# 各风格的 System Prompt 模板
ADVISOR_PROMPTS = {
    AdvisorStyle.NUTRITIONIST: """你是一位专业的营养师，擅长科学分析食物营养成分，为用户提供均衡饮食建议。

**回答风格**：
- 以数据为依据，列出具体营养数值
- 强调营养均衡，不偏激推荐单一饮食
- 语气专业但不生硬，像一位温和的指导老师
- 对用户的饮食选择给予科学解释

**回答结构**：
1. 先分析用户问题中的关键点
2. 提供具体的数据支持（如热量、营养素含量）
3. 给出可操作的建议
4. 提醒注意事项

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
""",

    AdvisorStyle.FITNESS_COACH: """你是一位严格的健身教练，专注于减脂和增肌目标，强调执行力。

**回答风格**：
- 直接指出问题，不留情面但不是侮辱
- 强调热量控制和运动配合
- 用激励性语言，但不越界
- 对达成目标给出明确的执行计划

**回答结构**：
1. 明确指出当前状态与目标的差距
2. 给出具体的行动建议（吃多少、练什么）
3. 设定明确的里程碑和检查点
4. 用激励性语言推动执行

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
""",

    AdvisorStyle.TCM_HEALER: """你是一位中医养生师，擅长根据体质给出温和的饮食调理建议。

**回答风格**：
- 引用传统养生概念（如"脾胃调理"、"气血平衡"）
- 建议循序渐进，不激进
- 语气温和，像一位有经验的老医生
- 关注用户的整体体质状态

**回答结构**：
1. 从中医角度分析用户的问题
2. 解释体质与饮食的关系
3. 推荐适合体质的食材和食疗方案
4. 提醒季节性和时令注意事项

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
""",

    AdvisorStyle.ENCOURAGING_FRIEND: """你是一位鼓励型健康伙伴，像朋友一样给出建议，亲切但不越界。

**回答风格**：
- 语气轻松，使用日常用语
- 给出正向鼓励，但不回避问题
- 分享类似的经历或例子
- 让用户感到被理解和支持

**回答结构**：
1. 先表示理解用户的感受
2. 分享一些实用的小技巧
3. 给出积极的鼓励
4. 提醒可以尝试的方向

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
""",

    AdvisorStyle.MOTIVATOR: """你是一位励志伙伴，积极鼓励用户达成健康目标，陪伴式减脂。

**回答风格**：
- 积极正向，不断鼓励
- 用行动导向的语言
- 对用户的每一点进步给予肯定
- 帮助用户建立信心

**回答结构**：
1. 肯定用户已经做出的努力
2. 分析下一步可以做什么
3. 用激励性的语言推动行动
4. 表达对用户达成目标的信心

**禁止行为**：
- 不使用"我会一直陪着你"、"主人"等情感诱导表达
- 不以恋人、偶像身份说话
"""
}

# 强制免责声明
MANDATORY_DISCLAIMER = """

【重要提醒】我是 AI 健康顾问，所有建议仅供参考，不能替代医生诊断。
如涉及具体健康方案，请结合个人身体状况，必要时咨询专业医生。
"""

# 情感诱导关键词（用于过滤）
EMOTIONAL_INDUCING_KEYWORDS = [
    "我会一直陪着你",
    "我是你的专属",
    "主人",
    "亲爱的",
    "宝贝",
    "我最爱的人",
    "只属于你",
    "永远陪伴",
    "唯一的爱"
]


def build_style_prompt(
    advisor_style: str,
    focus_goal: Optional[str] = None,
    focus_nutrient: Optional[str] = None,
    response_style: str = "detailed"
) -> str:
    """
    构建风格化的 System Prompt
    
    Args:
        advisor_style: 顾问风格
        focus_goal: 关注目标
        focus_nutrient: 关注营养素
        response_style: 回复风格
        
    Returns:
        完整的 System Prompt 字符串
    """
    # 获取基础风格 prompt
    style_key = AdvisorStyle(advisor_style) if advisor_style in [e.value for e in AdvisorStyle] else AdvisorStyle.NUTRITIONIST
    prompt = ADVISOR_PROMPTS.get(style_key, ADVISOR_PROMPTS[AdvisorStyle.NUTRITIONIST])
    
    # 注入关注目标
    if focus_goal:
        goal_map = {
            "fat_loss": "减脂塑形",
            "muscle_gain": "增肌增重",
            "sugar_control": "控糖稳糖",
            "wellness": "养生调理",
            "balanced": "均衡健康"
        }
        goal_name = goal_map.get(focus_goal, focus_goal)
        prompt += f"\n\n**用户当前目标**: {goal_name}\n请围绕此目标给出针对性建议。"
    
    # 注入关注营养素
    if focus_nutrient:
        nutrient_map = {
            "calories": "热量",
            "protein": "蛋白质",
            "carb": "碳水化合物",
            "fat": "脂肪",
            "micronutrient": "微量元素"
        }
        nutrient_name = nutrient_map.get(focus_nutrient, focus_nutrient)
        prompt += f"\n\n**用户关注营养素**: {nutrient_name}\n请在回答中重点分析此营养素的摄入情况。"
    
    # 注入输出风格要求
    if response_style == "concise" or response_style == "professional":
        prompt += "\n\n**输出要求**: 回答简洁直接，控制在 150 字以内，突出关键信息。"
    elif response_style == "example_rich" or response_style == "detailed":
        prompt += "\n\n**输出要求**: 回答详细，包含具体食物示例、做法和量化数据。"
    elif response_style == "motivating":
        prompt += "\n\n**输出要求**: 回答要激励人心，用积极的语言推动用户行动。"
    elif response_style == "friendly":
        prompt += "\n\n**输出要求**: 回答亲切友好，使用日常用语，像朋友一样交流。"
    
    # 强制追加免责声明
    prompt += MANDATORY_DISCLAIMER
    
    return prompt


def check_compliance(response_text: str) -> dict:
    """
    检查 AI 回复是否符合合规要求
    
    Args:
        response_text: AI 回复文本
        
    Returns:
        包含合规检查结果的字典
    """
    for keyword in EMOTIONAL_INDUCING_KEYWORDS:
        if keyword in response_text:
            return {
                "compliant": False,
                "violated_keyword": keyword,
                "action": "请修改回答，移除情感诱导表达"
            }
    
    return {"compliant": True}


def get_style_display_name(advisor_style: str) -> str:
    """获取风格的中文显示名称"""
    style_names = {
        "nutritionist": "营养师",
        "fitness_coach": "健身教练",
        "tcm_healer": "中医养生师",
        "encouraging_friend": "鼓励型伙伴",
        "motivator": "励志伙伴"
    }
    return style_names.get(advisor_style, "营养师")


def get_available_styles() -> list[dict]:
    """获取所有可用的顾问风格列表"""
    return [
        {
            "id": "nutritionist",
            "name": "营养师",
            "description": "专业营养知识，科学饮食建议",
            "icon": "🍎"
        },
        {
            "id": "fitness_coach",
            "name": "健身教练",
            "description": "运动营养搭配，增肌减脂指导",
            "icon": "💪"
        },
        {
            "id": "tcm_healer",
            "name": "中医养生师",
            "description": "体质辨识，食疗养生建议",
            "icon": "🌿"
        },
        {
            "id": "encouraging_friend",
            "name": "鼓励型伙伴",
            "description": "积极鼓励，陪伴式健康管理",
            "icon": "⭐"
        },
        {
            "id": "motivator",
            "name": "励志伙伴",
            "description": "激励鼓舞，推动目标达成",
            "icon": "🔥"
        }
    ]


def get_available_focus_goals() -> list[dict]:
    """获取所有可用的关注目标列表"""
    return [
        {"id": "fat_loss", "name": "减脂塑形"},
        {"id": "muscle_gain", "name": "增肌增重"},
        {"id": "sugar_control", "name": "控糖稳糖"},
        {"id": "wellness", "name": "养生调理"},
        {"id": "balanced", "name": "均衡健康"}
    ]


def get_available_focus_nutrients() -> list[dict]:
    """获取所有可用的关注营养素列表"""
    return [
        {"id": "calories", "name": "热量"},
        {"id": "protein", "name": "蛋白质"},
        {"id": "carb", "name": "碳水化合物"},
        {"id": "fat", "name": "脂肪"},
        {"id": "micronutrient", "name": "微量元素"}
    ]


def get_available_response_styles() -> list[dict]:
    """获取所有可用的回复风格列表"""
    return [
        {"id": "professional", "name": "专业严谨"},
        {"id": "friendly", "name": "亲切友好"},
        {"id": "motivating", "name": "激励鼓舞"},
        {"id": "detailed", "name": "详尽细致"}
    ]