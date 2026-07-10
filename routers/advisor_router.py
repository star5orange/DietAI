"""AI顾问设置路由"""
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
        None, description="顾问风格: nutritionist/fitness_coach/tcm_healer/encouraging_friend"
    )
    focus_goal: Optional[str] = Field(
        None, description="关注目标: fat_loss/muscle_gain/sugar_control/wellness/balanced"
    )
    focus_nutrient: Optional[str] = Field(
        None, description="关注营养素: calories/protein/carb/fat/micronutrient"
    )
    response_style: Optional[str] = Field(
        None, description="输出风格: concise/detailed/example_rich"
    )


@router.get("/settings", response_model=BaseResponse)
async def get_settings(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户 AI 顾问风格设置

    返回当前用户的顾问风格、关注目标、关注营养素、输出风格
    """
    try:
        data = get_advisor_settings(db, current_user.id)
        return BaseResponse(
            success=True,
            message="获取AI顾问设置成功",
            data=data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取AI顾问设置失败: {str(e)}"
        )


@router.put("/settings", response_model=BaseResponse)
async def update_settings(
    request: AdvisorSettingsUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新用户 AI 顾问风格设置

    只需传入要修改的字段，未传入的字段保持不变
    """
    # 至少需要修改一个字段
    if all(v is None for v in [request.advisor_style, request.focus_goal, request.focus_nutrient, request.response_style]):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="至少需要提供一个要修改的字段"
        )

    try:
        updated = update_advisor_settings(
            db,
            current_user.id,
            advisor_style=request.advisor_style,
            focus_goal=request.focus_goal,
            focus_nutrient=request.focus_nutrient,
            response_style=request.response_style,
        )
        return BaseResponse(
            success=True,
            message="AI 顾问风格已更新，下次对话生效",
            data=updated
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新AI顾问设置失败: {str(e)}"
        )
