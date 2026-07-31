"""轻断食模块路由"""
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional, Dict, Any, List
from datetime import date, time
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.fasting_service import (
    create_fasting_plan, get_fasting_plans, update_fasting_plan,
    stop_fasting_plan, delete_fasting_plan, create_checkin, get_checkins,
    get_progress, get_refeed_guide, health_assessment_check
)

router = APIRouter(prefix="/fasting", tags=["轻断食"])
logger = logging.getLogger(__name__)


@router.get("/plan-types", response_model=BaseResponse)
async def get_plan_types():
    """获取轻断食计划类型列表

    返回 3 种断食计划类型及说明
    """
    types = [
        {
            "id": "16_8",
            "name": "16:8 轻断食",
            "description": "每日禁食16小时，进食8小时",
        },
        {
            "id": "5_2",
            "name": "5:2 轻断食",
            "description": "每周5天正常吃，2天低热量",
        },
        {
            "id": "basic_fasting",
            "name": "基础断食",
            "description": "每周1-2天24小时断食",
        },
    ]

    return BaseResponse(
        success=True,
        message="获取计划类型成功",
        data={"items": types},
    )


# ========== 请求模型 ==========

class HealthAssessment(BaseModel):
    bmi: Optional[float] = Field(None, description="BMI")
    has_diabetes: Optional[bool] = Field(False, description="是否有糖尿病")
    is_pregnant: Optional[bool] = Field(False, description="是否怀孕")
    is_breastfeeding: Optional[bool] = Field(False, description="是否哺乳期")
    is_minor: Optional[bool] = Field(False, description="是否未成年人")
    has_eating_disorder: Optional[bool] = Field(False, description="是否有进食障碍")


class CreateFastingPlanRequest(BaseModel):
    plan_type: str = Field(..., description="计划类型: 16_8/5_2/basic_fasting")
    target_weight: Optional[float] = Field(None, ge=20, le=300, description="目标体重(kg)")
    start_date: date = Field(..., description="开始日期")
    eating_window_start: str = Field("08:00", description="进食窗口开始 HH:MM")
    eating_window_end: str = Field("16:00", description="进食窗口结束 HH:MM")
    fasting_days: Optional[List[int]] = Field(None, description="断食日列表，5:2需要2天，basic_fasting需要1-2天 (1=周一)")
    health_assessment: Optional[HealthAssessment] = Field(None, description="健康评估数据")
    disclaimer_accepted: bool = Field(False, description="是否已接受免责声明")


class UpdateFastingPlanRequest(BaseModel):
    target_weight: Optional[float] = Field(None, ge=20, le=300, description="目标体重(kg)")
    eating_window_start: Optional[str] = Field(None, description="进食窗口开始")
    eating_window_end: Optional[str] = Field(None, description="进食窗口结束")
    end_date: Optional[date] = Field(None, description="计划结束日期")


class CreateCheckinRequest(BaseModel):
    plan_id: int = Field(..., description="计划ID")
    checkin_date: date = Field(..., description="打卡日期")
    weight: Optional[float] = Field(None, ge=20, le=300, description="体重(kg)")
    feeling: str = Field("normal", description="体感: good/normal/tired/uncomfortable")
    completed: bool = Field(False, description="是否完成当日计划")
    discomfort: Optional[Dict[str, bool]] = Field(
        None,
        description="不适症状: dizziness/low_sugar/palpitation"
    )
    notes: Optional[str] = Field(None, description="备注")


# ========== 路由 ==========

@router.post("/plans", response_model=BaseResponse)
async def create_plan(
    request: CreateFastingPlanRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建轻断食/辟谷计划

    创建前需完成健康评估并接受免责声明。
    禁忌人群无法启用辟谷模式（basic_fasting）。
    """
    if request.plan_type not in ("16_8", "5_2", "basic_fasting"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="plan_type 必须是 16_8、5_2 或 basic_fasting"
        )

    try:
        health_data = request.health_assessment.model_dump() if request.health_assessment else None
        result = create_fasting_plan(
            db,
            current_user.id,
            plan_type=request.plan_type,
            start_date=request.start_date,
            health_assessment=health_data,
            disclaimer_accepted=request.disclaimer_accepted,
            target_weight=request.target_weight,
            eating_window_start=request.eating_window_start,
            eating_window_end=request.eating_window_end,
            fasting_days=request.fasting_days,
        )
        return BaseResponse(
            success=True,
            message="断食计划创建成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建断食计划失败: {str(e)}"
        )


@router.get("/plans", response_model=BaseResponse)
async def list_plans(
    status_filter: Optional[str] = Query(None, alias="status", description="按状态筛选: active/completed/stopped"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户断食计划列表

    - **status**: 可选，按状态筛选
    """
    try:
        result = get_fasting_plans(db, current_user.id, status_filter)
        return BaseResponse(
            success=True,
            message="获取计划列表成功",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取计划列表失败: {str(e)}"
        )


@router.put("/plans/{plan_id}", response_model=BaseResponse)
async def update_plan(
    plan_id: int,
    request: UpdateFastingPlanRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新断食计划

    只能修改进行中或暂停的计划。
    """
    try:
        result = update_fasting_plan(
            db,
            plan_id,
            current_user.id,
            target_weight=request.target_weight,
            eating_window_start=request.eating_window_start,
            eating_window_end=request.eating_window_end,
            end_date=request.end_date,
        )
        return BaseResponse(
            success=True,
            message="计划更新成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新计划失败: {str(e)}"
        )


@router.put("/plans/{plan_id}/stop", response_model=BaseResponse)
async def stop_plan(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """停止断食计划

    停止后进入复食指导阶段，计划状态变为 stopped。
    """
    try:
        result = stop_fasting_plan(db, plan_id, current_user.id)
        return BaseResponse(
            success=True,
            message="计划已停止",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"停止计划失败: {str(e)}"
        )


@router.delete("/plans/{plan_id}", response_model=BaseResponse)
async def delete_plan(
    plan_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除断食计划

    级联删除计划及其所有打卡记录。
    """
    try:
        result = delete_fasting_plan(db, plan_id, current_user.id)
        return BaseResponse(
            success=True,
            message="计划已删除",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"删除计划失败: {str(e)}"
        )


@router.post("/checkins", response_model=BaseResponse)
async def add_checkin(
    request: CreateCheckinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """每日断食打卡

    记录每日体重、体感、完成情况、不适症状。
    如有不适症状系统会自动生成预警。
    """
    if request.feeling not in ("good", "normal", "tired", "uncomfortable"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="feeling 必须是 good/normal/tired/uncomfortable"
        )

    try:
        result = create_checkin(
            db,
            plan_id=request.plan_id,
            user_id=current_user.id,
            checkin_date=request.checkin_date,
            weight=request.weight,
            feeling=request.feeling,
            completed=request.completed,
            discomfort=request.discomfort,
            notes=request.notes,
        )
        return BaseResponse(
            success=True,
            message="打卡成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"打卡失败: {str(e)}"
        )


@router.get("/checkins", response_model=BaseResponse)
async def list_checkins(
    plan_id: int = Query(..., description="计划ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取打卡记录列表"""
    try:
        result = get_checkins(db, plan_id, current_user.id)
        return BaseResponse(
            success=True,
            message="获取打卡记录成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取打卡记录失败: {str(e)}"
        )


@router.get("/progress", response_model=BaseResponse)
async def plan_progress(
    plan_id: int = Query(..., description="计划ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取计划进度与体重变化趋势"""
    try:
        result = get_progress(db, plan_id, current_user.id)
        return BaseResponse(
            success=True,
            message="获取进度成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取进度失败: {str(e)}"
        )


@router.get("/refeed-guide", response_model=BaseResponse)
async def refeed_guide(
    plan_id: int = Query(..., description="计划ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取复食指导方案

    根据计划类型返回分阶段复食建议。
    """
    try:
        result = get_refeed_guide(db, plan_id, current_user.id)
        return BaseResponse(
            success=True,
            message="获取复食指导成功",
            data=result
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取复食指导失败: {str(e)}"
        )
