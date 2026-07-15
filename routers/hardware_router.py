from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.hardware import OfflineSyncRequest
from shared.services.hardware_service import get_quick_buttons, sync_offline_records

router = APIRouter(prefix="/api/hardware", tags=["hardware"])


@router.get("/quick-buttons/{user_id}")
def get_quick_buttons_endpoint(user_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Get quick button configuration for hardware device.

    Note: user_id in path must match authenticated user for security.
    """
    if user.id != user_id:
        return BaseResponse(success=False, message="无权访问其他用户的配置", data=None)
    result = get_quick_buttons(db, user_id)
    return BaseResponse(success=True, message="获取快捷按钮配置成功", data=result)


@router.post("/sync")
def sync_offline_records_endpoint(request: OfflineSyncRequest, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Sync offline records from hardware device.

    Accepts a batch of water/food records collected while offline.
    """
    if user.id != request.user_id:
        return BaseResponse(success=False, message="用户ID不匹配", data=None)
    result = sync_offline_records(db, request.user_id, request.records)
    return BaseResponse(success=True, message="同步完成", data=result)
