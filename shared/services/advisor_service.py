"""AI顾问设置业务逻辑"""
import logging
from typing import Optional, Dict, Any

from sqlalchemy.orm import Session

from shared.models.advisor_models import AiAdvisorSettings

logger = logging.getLogger(__name__)

# 合法值白名单
VALID_ADVISOR_STYLES = ("nutritionist", "fitness_coach", "tcm_healer", "encouraging_friend")
VALID_FOCUS_GOALS = ("fat_loss", "muscle_gain", "sugar_control", "wellness", "balanced")
VALID_FOCUS_NUTRIENTS = ("calories", "protein", "carb", "fat", "micronutrient")
VALID_RESPONSE_STYLES = ("concise", "detailed", "example_rich")


def get_advisor_settings(db: Session, user_id: int) -> Dict[str, Any]:
    """获取用户 AI 顾问设置，不存在则创建默认设置"""
    settings = db.query(AiAdvisorSettings).filter(
        AiAdvisorSettings.user_id == user_id
    ).first()

    if not settings:
        settings = _create_default_settings(db, user_id)

    return {
        "advisor_style": settings.advisor_style,
        "focus_goal": settings.focus_goal,
        "focus_nutrient": settings.focus_nutrient,
        "response_style": settings.response_style,
    }


def update_advisor_settings(
    db: Session,
    user_id: int,
    advisor_style: Optional[str] = None,
    focus_goal: Optional[str] = None,
    focus_nutrient: Optional[str] = None,
    response_style: Optional[str] = None,
) -> Dict[str, Any]:
    """更新用户 AI 顾问设置"""
    settings = db.query(AiAdvisorSettings).filter(
        AiAdvisorSettings.user_id == user_id
    ).first()

    if not settings:
        settings = _create_default_settings(db, user_id)

    if advisor_style is not None:
        if advisor_style not in VALID_ADVISOR_STYLES:
            raise ValueError(f"无效的顾问风格: {advisor_style}，可选: {VALID_ADVISOR_STYLES}")
        settings.advisor_style = advisor_style

    if focus_goal is not None:
        if focus_goal not in VALID_FOCUS_GOALS:
            raise ValueError(f"无效的关注目标: {focus_goal}，可选: {VALID_FOCUS_GOALS}")
        settings.focus_goal = focus_goal

    if focus_nutrient is not None:
        if focus_nutrient not in VALID_FOCUS_NUTRIENTS:
            raise ValueError(f"无效的关注营养素: {focus_nutrient}，可选: {VALID_FOCUS_NUTRIENTS}")
        settings.focus_nutrient = focus_nutrient

    if response_style is not None:
        if response_style not in VALID_RESPONSE_STYLES:
            raise ValueError(f"无效的输出风格: {response_style}，可选: {VALID_RESPONSE_STYLES}")
        settings.response_style = response_style

    db.commit()
    db.refresh(settings)

    return {
        "advisor_style": settings.advisor_style,
        "focus_goal": settings.focus_goal,
        "focus_nutrient": settings.focus_nutrient,
        "response_style": settings.response_style,
    }


def _create_default_settings(db: Session, user_id: int) -> AiAdvisorSettings:
    """创建默认 AI 顾问设置"""
    settings = AiAdvisorSettings(
        user_id=user_id,
        advisor_style="nutritionist",
        focus_goal="balanced",
        focus_nutrient="calories",
        response_style="detailed",
    )
    db.add(settings)
    db.commit()
    db.refresh(settings)
    return settings
