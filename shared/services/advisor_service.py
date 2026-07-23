"""AI 顾问风格设置业务逻辑"""
import logging
from typing import Optional, Dict, Any

from sqlalchemy.orm import Session

from shared.models.advisor_models import AiAdvisorSettings

logger = logging.getLogger(__name__)


def get_advisor_settings(db: Session, user_id: int) -> Dict[str, Any]:
    """获取用户 AI 顾问风格设置，不存在时自动创建默认设置

    Args:
        db: 数据库会话
        user_id: 用户ID

    Returns:
        顾问设置字典（含人类和宠物字段）
    """
    settings = db.query(AiAdvisorSettings).filter(
        AiAdvisorSettings.user_id == user_id
    ).first()

    if not settings:
        settings = AiAdvisorSettings(
            user_id=user_id,
            advisor_style="nutritionist",
            response_style="detailed",
            pet_advisor_style="vet_assistant",
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
        logger.info(f"Created default AI advisor settings for user {user_id}")

    return {
        "advisor_style": settings.advisor_style,
        "focus_goal": settings.focus_goal,
        "focus_nutrient": settings.focus_nutrient,
        "response_style": settings.response_style,
        "pet_advisor_style": settings.pet_advisor_style,
        "pet_focus_goal": settings.pet_focus_goal,
    }


def update_advisor_settings(
    db: Session,
    user_id: int,
    advisor_style: Optional[str] = None,
    focus_goal: Optional[str] = None,
    focus_nutrient: Optional[str] = None,
    response_style: Optional[str] = None,
    pet_advisor_style: Optional[str] = None,
    pet_focus_goal: Optional[str] = None,
) -> Dict[str, Any]:
    """更新用户 AI 顾问风格设置（含宠物字段）

    Args:
        db: 数据库会话
        user_id: 用户ID
        advisor_style: 人类顾问风格
        focus_goal: 人类关注目标
        focus_nutrient: 人类关注营养素
        response_style: 回复风格
        pet_advisor_style: 宠物顾问风格
        pet_focus_goal: 宠物关注目标

    Returns:
        更新后的设置字典
    """
    settings = db.query(AiAdvisorSettings).filter(
        AiAdvisorSettings.user_id == user_id
    ).first()

    if not settings:
        settings = AiAdvisorSettings(user_id=user_id)
        db.add(settings)

    if advisor_style is not None:
        settings.advisor_style = advisor_style
    if focus_goal is not None:
        settings.focus_goal = focus_goal
    if focus_nutrient is not None:
        settings.focus_nutrient = focus_nutrient
    if response_style is not None:
        settings.response_style = response_style
    if pet_advisor_style is not None:
        settings.pet_advisor_style = pet_advisor_style
    if pet_focus_goal is not None:
        settings.pet_focus_goal = pet_focus_goal

    db.commit()
    db.refresh(settings)
    logger.info(f"Updated AI advisor settings for user {user_id}")

    return {
        "advisor_style": settings.advisor_style,
        "focus_goal": settings.focus_goal,
        "focus_nutrient": settings.focus_nutrient,
        "response_style": settings.response_style,
        "pet_advisor_style": settings.pet_advisor_style,
        "pet_focus_goal": settings.pet_focus_goal,
    }
