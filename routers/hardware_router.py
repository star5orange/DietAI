from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.hardware import OfflineSyncRequest
from shared.services.hardware_service import (
    get_quick_buttons, sync_offline_records,
    sync_pet_feeding, sync_pet_water,
    get_pet_quick_buttons, get_pet_feeding_plan_for_hardware,
)
from routers.family_member_router import _resolve_request_context

router = APIRouter(prefix="/api/hardware", tags=["hardware"])


@router.get("/quick-buttons/{user_id}")
def get_quick_buttons_endpoint(user_id: int,
                                target_type: Optional[str] = Query(None, description="human 或 pet，不传默认 human"),
                                db: Session = Depends(get_db), user=Depends(get_current_user)):
    if user.id != user_id:
        return BaseResponse(success=False, message="无权访问其他用户的配置", data=None)

    # M3: 宠物快捷按钮
    if target_type == "pet":
        result = get_pet_quick_buttons(db, user_id)
        return BaseResponse(success=True, message="获取宠物快捷按钮配置成功", data=result)

    result = get_quick_buttons(db, user_id)
    return BaseResponse(success=True, message="获取快捷按钮配置成功", data=result)


@router.post("/sync")
def sync_offline_records_endpoint(request: OfflineSyncRequest, http_request: Request, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """Sync offline records. Supports target_type=human(default) and target_type=pet.

    V6（C2）：user_id 可省略——device_token 场景由令牌解析家庭；
    显式传入时必须与令牌归属一致，否则拒绝（防串号）。
    """
    if not hasattr(request, 'target_type') or request.target_type in (None, "human"):
        ctx = _resolve_request_context(http_request, user, db)
        home_user_id = ctx["home_user_id"]
        if request.user_id is not None and request.user_id != home_user_id:
            return BaseResponse(success=False, message="用户ID不匹配", data=None)
        result = sync_offline_records(db, home_user_id, request.records, device=ctx["device"])
        return BaseResponse(success=True, message="同步完成", data=result)

    # M3: pet branch
    if request.target_type == "pet":
        results = []
        for r in request.records:
            rtype = r.get("type") if isinstance(r, dict) else getattr(r, "type", None)
            try:
                if rtype == "feeding":
                    data = r if isinstance(r, dict) else r.dict()
                    results.append(sync_pet_feeding(db, data))
                elif rtype == "water":
                    data = r if isinstance(r, dict) else r.dict()
                    results.append(sync_pet_water(db, data))
                else:
                    results.append({"type": rtype, "status": "unknown"})
            except Exception as e:
                results.append({"type": rtype, "status": "error", "error": str(e)})
        return BaseResponse(success=True, message="宠物同步完成", data={"results": results})

    return BaseResponse(success=False, message="未知 target_type", data=None)


# M3: 宠物硬件专用端点
@router.get("/pet-feeding-plan/{pet_id}")
def get_pet_feeding_plan_hw(pet_id: int, db: Session = Depends(get_db), user=Depends(get_current_user)):
    """硬件查询当日喂食计划"""
    plan = get_pet_feeding_plan_for_hardware(db, pet_id)
    if "error" in plan:
        raise HTTPException(status_code=404, detail=plan["error"])
    return BaseResponse(success=True, message="获取喂食计划成功", data=plan)
