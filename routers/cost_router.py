"""消费统计路由"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.cost_service import get_cost_stats, get_cost_trend, set_monthly_budget

router = APIRouter(prefix="/foods", tags=["消费统计"])


@router.get("/cost-stats", response_model=BaseResponse)
async def cost_statistics(
    period: str = Query("week", description="统计周期: week | month"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取本周/本月消费统计数据

    - **period**: week（本周）或 month（本月）
    - 返回总消费、日均、最贵单笔、按餐次/来源分类、每元热量、预算剩余
    """
    if period not in ("week", "month"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="period 参数必须是 week 或 month"
        )

    try:
        stats = get_cost_stats(db, current_user.id, period)
        return BaseResponse(
            success=True,
            message="获取消费统计成功",
            data=stats
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取消费统计失败: {str(e)}"
        )


@router.get("/cost-trend", response_model=BaseResponse)
async def cost_trend(
    days: int = Query(7, ge=1, le=365, description="天数（7 或 30）"),
    source_tag: Optional[str] = Query(None, description="按来源筛选: canteen/delivery/home/restaurant/snack/other"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取近 N 天消费趋势

    - **days**: 天数（默认 7，常用 7/30）
    - **source_tag**: 可选，按来源标签筛选
    - 返回每日消费金额、记录数、总计、均值
    """
    try:
        trend_data = get_cost_trend(db, current_user.id, days, source_tag)
        return BaseResponse(
            success=True,
            message="获取消费趋势成功",
            data=trend_data
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取消费趋势失败: {str(e)}"
        )


class SetBudgetRequest(BaseModel):
    budget: float = Field(..., ge=0, description="月度饮食预算（元）")


@router.post("/cost-budget", response_model=BaseResponse)
async def set_budget(
    request: SetBudgetRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """设置月度饮食预算

    用于消费统计中的预算对比和提醒
    """
    try:
        result = set_monthly_budget(db, current_user.id, request.budget)
        return BaseResponse(
            success=True,
            message="预算设置成功",
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
            detail=f"设置预算失败: {str(e)}"
        )
