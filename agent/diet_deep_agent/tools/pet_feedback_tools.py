"""Pet feedback tool for DietDeepAgent"""
from langchain_core.tools import tool

from agent.diet_deep_agent.skills.pet_feedback.pet_feedback_generator import (
    PetFeedbackGenerator,
)

_pet_feedback = PetFeedbackGenerator()


@tool
def generate_pet_feedback_tool(
    diet_progress: float = 0.0,
    water_progress: float = 0.0,
    streak_days: int = 0,
    new_unlock: str = "",
    mood: str = "normal",
) -> str:
    """生成虚拟宠物反馈文案

    根据用户饮食/饮水达标率和连续打卡天数，生成宠物心情状态和反馈文案。
    可用于App端展示或聊天回复中引用。

    Args:
        diet_progress: 饮食达标率 0.0-1.0
        water_progress: 饮水达标率 0.0-1.0
        streak_days: 连续达标天数
        new_unlock: 新解锁内容名称（可选）
        mood: 强制指定心情状态（可选）

    Returns:
        宠物反馈文案
    """
    try:
        result = _pet_feedback.generate_feedback(
            diet_progress=diet_progress,
            water_progress=water_progress,
            streak_days=streak_days,
            new_unlock=new_unlock,
            mood=mood,
        )
        return str(result)
    except Exception as e:
        return f"生成宠物反馈失败: {str(e)}"


@tool
def generate_pet_reminder_tool(mood: str = "normal") -> str:
    """生成宠物提醒文案

    根据宠物当前心情生成提醒文案，用于通知或聊天回复中。

    Args:
        mood: 宠物心情 happy/normal/hungry/anxious/weak

    Returns:
        提醒文案
    """
    try:
        result = _pet_feedback.generate_mood_based_reminder(mood=mood)
        return str(result)
    except Exception as e:
        return f"生成宠物提醒失败: {str(e)}"


PET_FEEDBACK_TOOLS = [
    generate_pet_feedback_tool,
    generate_pet_reminder_tool,
]
