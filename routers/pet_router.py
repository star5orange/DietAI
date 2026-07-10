"""虚拟宠物路由"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.pet_service import (
    get_pet_status, get_device_status, interact_pet, get_unlockables
)

router = APIRouter(prefix="/virtual-pet", tags=["虚拟宠物"])


class InteractRequest(BaseModel):
    action: str = Field(..., description="互动类型: feed | play | pet")
    item_id: Optional[str] = Field(None, description="互动物品ID（喂食时可选）")


@router.get("/status", response_model=BaseResponse)
async def pet_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取 App 端宠物完整状态

    返回 mood、level、exp、当前皮肤、已解锁皮肤、习惯分数、连续达标天数
    """
    try:
        status_data = get_pet_status(db, current_user.id)
        return BaseResponse(
            success=True,
            message="获取宠物状态成功",
            data=status_data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取宠物状态失败: {str(e)}"
        )


@router.get("/status-for-device", response_model=BaseResponse)
async def pet_status_for_device(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """硬件端获取宠物精简状态（每 30 秒轮询）

    返回 mood、level、skin、version（用于判断是否需要刷新）
    """
    try:
        device_status = get_device_status(db, current_user.id)
        return BaseResponse(
            success=True,
            message="获取设备状态成功",
            data=device_status
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取设备状态失败: {str(e)}"
        )


@router.post("/interact", response_model=BaseResponse)
async def pet_interact(
    request: InteractRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """用户与宠物互动

    - **action**: feed（喂食）| play（玩耍）| pet（抚摸）
    - **item_id**: 可选，喂食时指定食物物品ID
    """
    if request.action not in ("feed", "play", "pet"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="action 必须是 feed、play 或 pet"
        )

    try:
        result = interact_pet(db, current_user.id, request.action, request.item_id)
        return BaseResponse(
            success=True,
            message="互动成功",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"宠物互动失败: {str(e)}"
        )


@router.get("/unlockables", response_model=BaseResponse)
async def pet_unlockables(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取可解锁内容列表及用户进度

    返回所有可解锁项及当前用户的解锁进度
    """
    try:
        data = get_unlockables(db, current_user.id)
        return BaseResponse(
            success=True,
            message="获取可解锁内容成功",
            data=data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取可解锁内容失败: {str(e)}"
        )
