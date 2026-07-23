"""AI 顾问风格设置路由"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.advisor_service import get_advisor_settings, update_advisor_settings

router = APIRouter(prefix="/ai-advisor", tags=["AI顾问设置"])


class AdvisorSettingsUpdate(BaseModel):
    advisor_style: Optional[str] = Field(
        None, description="顾问风格: nutritionist / fitness_coach / tcm_healer / encouraging_friend"
    )
    focus_goal: Optional[str] = Field(
        None, description="关注目标: fat_loss / muscle_gain / sugar_control / wellness / balanced"
    )
    focus_nutrient: Optional[str] = Field(
        None, description="关注营养素: calories / protein / carb / fat / micronutrient"
    )
    response_style: Optional[str] = Field(
        None, description="回复风格: concise / detailed / example_rich"
    )


@router.get("/settings", response_model=BaseResponse)
async def get_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取用户 AI 顾问风格设置

    返回当前用户的顾问风格、关注目标、关注营养素、回复风格
    """
    try:
        settings = get_advisor_settings(db, current_user.id)
        return BaseResponse(
            success=True,
            message="获取AI顾问设置成功",
            data=settings,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取AI顾问设置失败: {str(e)}",
        )


@router.put("/settings", response_model=BaseResponse)
async def update_settings(
    request: AdvisorSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """更新用户 AI 顾问风格设置

    只需传入要修改的字段，未传入的保持不变
    """
    # 校验 advisor_style 值
    valid_styles = {"nutritionist", "fitness_coach", "tcm_healer", "encouraging_friend"}
    if request.advisor_style is not None and request.advisor_style not in valid_styles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"无效的顾问风格，可选值: {', '.join(valid_styles)}",
        )

    try:
        settings = update_advisor_settings(
            db,
            current_user.id,
            advisor_style=request.advisor_style,
            focus_goal=request.focus_goal,
            focus_nutrient=request.focus_nutrient,
            response_style=request.response_style,
        )
        return BaseResponse(
            success=True,
            message="AI顾问设置已更新，下次对话生效",
            data=settings,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新AI顾问设置失败: {str(e)}",
        )


@router.get("/templates", response_model=BaseResponse)
async def get_templates():
    """获取所有可用的AI顾问风格模板

    无需登录，返回预设的风格模板列表
    """
    templates = [
        {
            "advisor_style": "nutritionist",
            "name": "营养师",
            "description": "专业、数据驱动，专注于营养科学和膳食规划",
            "focus_goal": "balanced",
            "focus_nutrient": "calories",
            "response_style": "detailed",
        },
        {
            "advisor_style": "fitness_coach",
            "name": "健身教练",
            "description": "严格、激励，专注于运动营养和体能训练",
            "focus_goal": "muscle_gain",
            "focus_nutrient": "protein",
            "response_style": "concise",
        },
        {
            "advisor_style": "tcm_healer",
            "name": "中医养生师",
            "description": "温和、传统，专注于节气养生和体质调理",
            "focus_goal": "wellness",
            "focus_nutrient": "micronutrient",
            "response_style": "example_rich",
        },
        {
            "advisor_style": "encouraging_friend",
            "name": "鼓励型伙伴",
            "description": "友善、温暖，专注于生活习惯和可持续改变",
            "focus_goal": "fat_loss",
            "focus_nutrient": "calories",
            "response_style": "detailed",
        },
    ]
    return BaseResponse(
        success=True,
        message="获取模板成功",
        data={"templates": templates},
    )


@router.get("/styles", response_model=BaseResponse)
async def get_styles():
    """获取 AI 顾问风格枚举列表

    无需登录，返回所有可选的顾问风格
    """
    items = [
        {"id": "nutritionist", "name": "营养师"},
        {"id": "fitness_coach", "name": "健身教练"},
        {"id": "tcm_healer", "name": "中医养生师"},
        {"id": "encouraging_friend", "name": "鼓励型伙伴"},
    ]
    return BaseResponse(
        success=True,
        message="获取顾问风格成功",
        data={"items": items},
    )


@router.get("/goals", response_model=BaseResponse)
async def get_goals():
    """获取 AI 顾问关注目标枚举列表

    无需登录，返回所有可选的关注目标
    """
    items = [
        {"id": "fat_loss", "name": "减脂塑形"},
        {"id": "muscle_gain", "name": "增肌增重"},
        {"id": "sugar_control", "name": "控糖稳糖"},
        {"id": "wellness", "name": "养生调理"},
        {"id": "balanced", "name": "均衡健康"},
    ]
    return BaseResponse(
        success=True,
        message="获取关注目标成功",
        data={"items": items},
    )


@router.get("/nutrients", response_model=BaseResponse)
async def get_nutrients():
    """获取 AI 顾问关注营养素枚举列表

    无需登录，返回所有可选的关注营养素
    """
    items = [
        {"id": "calories", "name": "热量"},
        {"id": "protein", "name": "蛋白质"},
        {"id": "carbs", "name": "碳水化合物"},
        {"id": "fat", "name": "脂肪"},
        {"id": "micronutrient", "name": "微量元素"},
    ]
    return BaseResponse(
        success=True,
        message="获取营养素成功",
        data={"items": items},
    )


@router.get("/response-styles", response_model=BaseResponse)
async def get_response_styles():
    """获取 AI 顾问回复风格枚举列表

    无需登录，返回所有可选的回复风格
    """
    items = [
        {"id": "professional", "name": "专业严谨"},
        {"id": "friendly", "name": "亲切友好"},
        {"id": "motivating", "name": "激励鼓舞"},
        {"id": "detailed", "name": "详尽细致"},
    ]
    return BaseResponse(
        success=True,
        message="获取回复风格成功",
        data={"items": items},
    )
