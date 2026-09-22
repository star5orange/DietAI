"""设备绑定相关 Pydantic schemas"""
from typing import Optional
from datetime import datetime

from pydantic import BaseModel, Field


# --- 请求 ---

class RequestPairingRequest(BaseModel):
    """ESP32 请求配对码"""
    device_key: str = Field(..., min_length=1, max_length=32, description="设备唯一标识 (MAC)")


class PollPairingRequest(BaseModel):
    """ESP32 轮询配对状态"""
    device_key: str = Field(..., min_length=1, max_length=32, description="设备唯一标识")


class ConfirmPairingRequest(BaseModel):
    """App 确认配对"""
    pairing_code: str = Field(..., min_length=6, max_length=6, description="6位配对码")


# --- 响应 ---

class PairingCodeResponse(BaseModel):
    pairing_code: str = Field(..., description="6位配对码")
    expires_in: int = Field(..., description="过期秒数")


class DeviceTokenResponse(BaseModel):
    device_token: str = Field(..., description="设备长期 JWT")
    user_id: int = Field(..., description="绑定的用户ID")


class DeviceStatusResponse(BaseModel):
    device_id: int
    device_key: str
    is_bound: bool
    user_id: Optional[int] = None
    last_seen_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
