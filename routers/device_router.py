"""设备绑定路由 — 配对码绑定流程"""
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas import BaseResponse
from shared.models.schemas.device import (
    RequestPairingRequest, PollPairingRequest, ConfirmPairingRequest,
    PairingCodeResponse, DeviceTokenResponse, DeviceStatusResponse,
)
from shared.services.device_service import (
    request_pairing, confirm_pairing, poll_pairing,
    get_device_status, unbind_device,
    AlreadyBoundError,
)
from shared.models.user_models import User

router = APIRouter(prefix="/api/device", tags=["device"])
logger = logging.getLogger(__name__)


@router.post("/request-pairing", summary="ESP32 请求配对码")
async def request_pairing_endpoint(
    req: RequestPairingRequest,
    db: Session = Depends(get_db),
):
    """
    ESP32 发送 device_key, 获取 6 位配对码。
    无需认证（设备尚未绑定）。
    """
    try:
        code, expires_in = request_pairing(db, req.device_key)
        return BaseResponse(
            success=True,
            message="配对码已生成",
            data={"pairing_code": code, "expires_in": expires_in},
        )
    except AlreadyBoundError as e:
        # 设备已绑定, 直接返回 device_token (ESP32 NVS 可能被清空了)
        return BaseResponse(
            success=True,
            message="设备已绑定",
            data={"bound": True, "device_token": e.device_token},
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"[Device] request-pairing error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="配对码生成失败")


@router.post("/poll-pairing", summary="ESP32 轮询配对状态")
async def poll_pairing_endpoint(
    req: PollPairingRequest,
    db: Session = Depends(get_db),
):
    """
    ESP32 轮询是否已被绑定。
    已绑定 → 返回 device_token; 未绑定 → 返回空。
    无需认证。
    """
    device_token = poll_pairing(db, req.device_key)

    if device_token:
        return BaseResponse(
            success=True,
            message="设备已绑定",
            data={"device_token": device_token, "bound": True},
        )
    else:
        return BaseResponse(
            success=True,
            message="等待配对",
            data={"bound": False},
        )


@router.post("/confirm-pairing", summary="App 确认配对")
async def confirm_pairing_endpoint(
    req: ConfirmPairingRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    用户在 App 输入 6 位配对码, 完成设备绑定。
    需要用户 JWT 认证。
    """
    try:
        device = confirm_pairing(db, current_user.id, req.pairing_code)
        return BaseResponse(
            success=True,
            message="设备绑定成功",
            data={
                "device_id": device.id,
                "device_token": device.device_token,
            },
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"[Device] confirm-pairing error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="绑定失败")


@router.get("/status", summary="查询绑定设备状态")
async def device_status_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """查询当前用户绑定的设备信息"""
    device = get_device_status(db, current_user.id)

    if not device:
        return BaseResponse(
            success=True,
            message="未绑定设备",
            data=None,
        )

    return BaseResponse(
        success=True,
        message="已绑定设备",
        data={
            "device_id": device.id,
            "device_key": device.device_key,
            "last_seen_at": device.last_seen_at.isoformat() if device.last_seen_at else None,
            "created_at": device.created_at.isoformat() if device.created_at else None,
        },
    )


@router.post("/unbind", summary="解绑设备")
async def unbind_device_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """解绑当前用户的设备"""
    ok = unbind_device(db, current_user.id)
    if ok:
        return BaseResponse(success=True, message="设备已解绑", data=None)
    else:
        raise HTTPException(status_code=404, detail="未找到绑定的设备")
