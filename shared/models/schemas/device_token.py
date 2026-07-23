from pydantic import BaseModel, Field
from typing import Optional


class DeviceTokenCreate(BaseModel):
    """注册/更新设备 token"""
    token: str = Field(..., min_length=1, max_length=500, description="FCM device token")
    platform: Optional[str] = Field(None, pattern="^(android|ios)$", description="设备平台")


class DeviceTokenOut(BaseModel):
    """设备 token 响应"""
    id: int
    user_id: int
    token: str
    platform: Optional[str]
    is_active: bool

    class Config:
        from_attributes = True
