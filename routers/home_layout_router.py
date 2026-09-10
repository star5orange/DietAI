"""首页模块布局路由

- GET  /api/home/layout   获取解析后的首页布局（含模块注册表、可见性、顺序、变体）
- PUT  /api/home/layout   保存用户定制（隐藏模块 / 顺序），支持 reset 恢复默认
"""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from typing import List, Optional

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.models.user_models import User
from shared.services.home_layout_service import build_layout, save_layout
from shared.utils.auth import get_current_user

router = APIRouter(prefix="/home", tags=["首页布局"])


class HomeLayoutUpdateRequest(BaseModel):
    """首页布局定制请求；reset=True 时忽略其他字段"""

    hidden_modules: Optional[List[str]] = Field(
        None, description="需要隐藏的模块ID列表（锁定模块会被忽略）"
    )
    module_order: Optional[List[str]] = Field(
        None, description="模块展示顺序（模块ID列表）；空列表表示使用默认顺序"
    )
    preferences: Optional[dict] = Field(
        None,
        description=(
            "引导问卷偏好，决定模块显示与优先级。"
            "结构：{focus: fat_loss|fitness|balanced, "
            "interests: [cost|wellness|exam|water|pet]}"
        ),
    )
    reset: Optional[bool] = Field(False, description="是否恢复默认（按画像自动布局）")


@router.get("/layout", response_model=BaseResponse)
async def get_home_layout(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取首页布局

    返回：模块注册表 modules、最终顺序 order、隐藏列表 hidden、
    展示变体 variants（如 exam_entry=compact）、分群信号 signals。
    """
    try:
        return BaseResponse(
            success=True,
            message="获取首页布局成功",
            data=build_layout(db, current_user.id),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取首页布局失败: {str(e)}",
        )


@router.put("/layout", response_model=BaseResponse)
async def update_home_layout(
    request: HomeLayoutUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """保存首页布局定制（隐藏模块 / 排序），reset 可恢复默认"""
    try:
        layout = save_layout(
            db,
            current_user.id,
            hidden_modules=request.hidden_modules,
            module_order=request.module_order,
            preferences=request.preferences,
            reset=bool(request.reset),
        )
        return BaseResponse(
            success=True,
            message="首页布局已更新",
            data=layout,
        )
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新首页布局失败: {str(e)}",
        )
