"""
Goal Tracking API Router

Provides endpoints for:
- GET /api/goals/daily-status: Get today's goal tracking status
- GET /api/goals/progress: Get overall goal progress
- POST /api/goals/recalculate: Force recalculate daily targets
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.agent_orchestrator import get_orchestrator

router = APIRouter(prefix="/goals", tags=["目标追踪"])


@router.get("/daily-status", response_model=BaseResponse)
async def get_daily_goal_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    获取今日目标追踪状态

    返回:
    - daily_targets: 每日营养目标 {calories, protein, carbs, fat}
    - today_consumed: 今日已摄入
    - remaining_budget: 剩余配额
    - goal_progress: 目标进度 (如适用)
    - suggestions: 个性化建议
    - bmr/tdee: 基础代谢和每日消耗
    """
    try:
        orchestrator = get_orchestrator()
        result = await orchestrator.get_daily_status(
            user_id=current_user.id,
            db=db
        )

        if not result.get("success", False):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=result.get("error", "获取目标状态失败")
            )

        return BaseResponse(
            success=True,
            message="获取每日目标状态成功",
            data={
                "daily_targets": result.get("daily_targets"),
                "today_consumed": result.get("today_consumed"),
                "remaining_budget": result.get("remaining_budget"),
                "goal_progress": result.get("goal_progress"),
                "suggestions": result.get("suggestions", []),
                "warnings": result.get("warnings", []),
                "bmr": result.get("bmr"),
                "tdee": result.get("tdee"),
                "timestamp": datetime.now().isoformat()
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取目标状态失败: {str(e)}"
        )


@router.get("/progress", response_model=BaseResponse)
async def get_goal_progress(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    获取目标总体进度

    返回:
    - active_goal: 当前活跃目标
    - weight_progress: 体重进度
    - milestones: 里程碑列表
    """
    try:
        from shared.models.user_models import HealthGoal, WeightRecord, UserProfile
        from shared.utils.nutrition_calc import calculate_goal_progress, get_goal_type_name

        # Get active goal
        active_goal = db.query(HealthGoal).filter(
            HealthGoal.user_id == current_user.id,
            HealthGoal.current_status == 1
        ).first()

        if not active_goal:
            return BaseResponse(
                success=True,
                message="暂无活跃目标",
                data={
                    "has_active_goal": False,
                    "active_goal": None,
                    "weight_progress": None
                }
            )

        # Get weight records
        weight_records = db.query(WeightRecord).filter(
            WeightRecord.user_id == current_user.id
        ).order_by(WeightRecord.measured_at.asc()).all()

        weight_progress = None
        if weight_records and len(weight_records) >= 1 and active_goal.target_weight:
            first_weight = float(weight_records[0].weight)
            current_weight = float(weight_records[-1].weight)
            target_weight = float(active_goal.target_weight)

            progress = calculate_goal_progress(
                starting_weight=first_weight,
                current_weight=current_weight,
                target_weight=target_weight,
                goal_type=active_goal.goal_type
            )
            weight_progress = progress

        goal_data = {
            "id": active_goal.id,
            "goal_type": active_goal.goal_type,
            "goal_type_name": get_goal_type_name(active_goal.goal_type),
            "target_weight": float(active_goal.target_weight) if active_goal.target_weight else None,
            "target_date": active_goal.target_date.isoformat() if active_goal.target_date else None,
            "status": "进行中"
        }

        return BaseResponse(
            success=True,
            message="获取目标进度成功",
            data={
                "has_active_goal": True,
                "active_goal": goal_data,
                "weight_progress": weight_progress,
                "weight_records_count": len(weight_records)
            }
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取目标进度失败: {str(e)}"
        )


@router.post("/recalculate", response_model=BaseResponse)
async def recalculate_targets(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    强制重新计算每日营养配额

    在以下情况调用:
    - 体重更新后
    - 目标变更后
    - 活动水平变更后

    同时会更新用户的 goal_tracking/user_goals.md 文件
    """
    try:
        from agent.memory.sync_service import SyncService

        # Sync goal tracking workspace
        sync_service = SyncService(db)
        success = await sync_service.sync_goal_tracking(current_user.id)

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="目标重算失败"
            )

        # Get fresh status
        orchestrator = get_orchestrator()
        result = await orchestrator.get_daily_status(
            user_id=current_user.id,
            db=db
        )

        return BaseResponse(
            success=True,
            message="每日配额已重新计算",
            data={
                "daily_targets": result.get("daily_targets"),
                "bmr": result.get("bmr"),
                "tdee": result.get("tdee"),
                "recalculated_at": datetime.now().isoformat()
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"重算失败: {str(e)}"
        )


@router.post("/sync-memory", response_model=BaseResponse)
async def sync_user_memory(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    手动同步用户记忆文件

    从数据库重新生成所有工作区的 MD 文件:
    - shared/user_memory.md
    - goal_tracking/user_goals.md
    - nutrition/user_nutrition.md
    - chat/user_chat.md
    """
    try:
        from agent.memory.sync_service import SyncService

        sync_service = SyncService(db)
        success = await sync_service.full_sync(current_user.id)

        if not success:
            return BaseResponse(
                success=False,
                message="部分工作区同步失败",
                data={"partial_success": True}
            )

        return BaseResponse(
            success=True,
            message="用户记忆已同步",
            data={
                "synced_workspaces": ["shared", "goal_tracking", "nutrition", "chat"],
                "synced_at": datetime.now().isoformat()
            }
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"同步失败: {str(e)}"
        )
