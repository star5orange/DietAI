from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional

from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.notification import NotificationResponseCreate, NotificationResponseOut
from shared.models.schemas.base import BaseResponse
from shared.services.notification_service import create_notification_response, get_response_stats
from shared.models.user_models import User

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.post("/responses", response_model=BaseResponse)
def create_response(
    response: NotificationResponseCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """记录提醒响应。

    - drank: 自动创建喝水记录(250ml)，更新当日饮水汇总
    - ate: 记录吃饭响应
    - snooze: 记录延迟
    - skipped: 记录跳过
    """
    try:
        result = create_notification_response(db, user.id, response)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))

    return BaseResponse(
        success=True,
        message=f"提醒响应记录成功: {response.action_type}",
        data={
            "id": result.id,
            "user_id": result.user_id,
            "reminder_id": result.reminder_id,
            "responded_at": result.responded_at.isoformat(),
            "action_type": result.action_type,
            "created_at": result.created_at.isoformat(),
        },
    )


@router.get("/responses/stats", response_model=BaseResponse)
def get_stats(
    days: int = Query(7, ge=1, le=90, description="统计天数"),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """获取提醒响应统计：各类型的响应率、连续响应天数等"""
    stats = get_response_stats(db, user.id, days)
    return BaseResponse(
        success=True,
        message=f"近{days}天提醒响应统计",
        data=stats,
    )
