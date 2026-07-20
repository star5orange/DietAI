"""虚拟宠物路由"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.pet_service import (
    get_pet_status, get_device_status, interact_pet, get_unlockables,
    update_pet_settings, add_pet_exp, get_pet_growth
)

router = APIRouter(prefix="/virtual-pet", tags=["虚拟宠物"])


class InteractRequest(BaseModel):
    action: str = Field(..., description="互动类型: feed | play | pet")
    item_id: Optional[str] = Field(None, description="互动物品ID（喂食时可选）")


class PetSettingsRequest(BaseModel):
    visible: Optional[bool] = Field(None, description="宠物可见性")
    pet_type: Optional[str] = Field(None, description="宠物类型(cat/dog)")
    pet_name: Optional[str] = Field(None, description="宠物名称")


class AddExpRequest(BaseModel):
    amount: int = Field(..., ge=1, le=1000, description="经验值数量")


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


@router.post("/settings", response_model=BaseResponse)
async def pet_settings(
    request: PetSettingsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新宠物设置（可见性、类型、名称）

    只需传入要修改的字段，未传入的保持不变
    """
    try:
        result = update_pet_settings(
            db,
            current_user.id,
            visible=request.visible,
            pet_type=request.pet_type,
            pet_name=request.pet_name,
        )
        return BaseResponse(
            success=True,
            message="宠物设置更新成功",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新宠物设置失败: {str(e)}"
        )


@router.post("/exp/add", response_model=BaseResponse)
async def add_exp(
    request: AddExpRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """增加宠物经验值

    用于手动增加经验（如完成特定任务奖励）
    """
    try:
        result = add_pet_exp(db, current_user.id, request.amount)
        return BaseResponse(
            success=True,
            message="经验值增加成功",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"增加经验值失败: {str(e)}"
        )


@router.get("/breeds", response_model=BaseResponse)
async def get_breeds(species: Optional[str] = Query(None, description="物种: cat/dog, 不传则返回全部")):
    """获取猫狗品种列表

    可传入 species 参数筛选: cat / dog，不传则返回全部
    """
    cat_breeds = [
        "橘猫", "英短（英国短毛猫）", "布偶猫", "暹罗猫",
        "美短（美国短毛猫）", "波斯猫", "缅因猫", "金吉拉",
        "中华田园猫", "狸花猫", "玄猫", "三花猫", "混血（串串）", "其他",
    ]
    dog_breeds = [
        "泰迪（贵宾犬）", "柯基", "金毛", "拉布拉多", "哈士奇", "博美",
        "比熊", "萨摩耶", "边境牧羊犬", "德国牧羊犬", "雪纳瑞",
        "法斗（法国斗牛犬）", "柴犬", "中华田园犬", "混血（串串）", "其他",
    ]

    if species == "cat":
        data = {"cat": cat_breeds}
    elif species == "dog":
        data = {"dog": dog_breeds}
    else:
        data = {"cat": cat_breeds, "dog": dog_breeds}

    return BaseResponse(success=True, message="获取品种列表成功", data=data)


@router.get("/growth", response_model=BaseResponse)
async def pet_growth(
    start_date: Optional[str] = Query(None, description="开始日期 YYYY-MM-DD"),
    end_date: Optional[str] = Query(None, description="结束日期 YYYY-MM-DD"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取宠物成长数据

    返回经验值、等级变化趋势数据
    """
    try:
        data = get_pet_growth(db, current_user.id, start_date, end_date)
        return BaseResponse(
            success=True,
            message="获取宠物成长数据成功",
            data=data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取宠物成长数据失败: {str(e)}"
        )
