"""硬件设备模型 — 配对码绑定"""
from datetime import datetime, timedelta

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, func, Index
from .database import Base


class Device(Base):
    """硬件设备表 — ESP32 等物联网设备"""
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
                      comment="绑定的用户ID, 绑定前为 null")
    device_key = Column(String(32), unique=True, nullable=False,
                         comment="设备唯一标识 (MAC 地址)")
    pairing_code = Column(String(6), nullable=True, index=True,
                          comment="6位配对码, 5分钟过期")
    pairing_expires_at = Column(DateTime, nullable=True,
                                comment="配对码过期时间")
    device_token = Column(String(500), unique=True, nullable=True,
                          comment="绑定后颁发的长期 JWT")
    is_bound = Column(Boolean, default=False, comment="是否已绑定用户")
    last_seen_at = Column(DateTime, nullable=True, comment="设备最后在线时间")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_devices_user", "user_id"),
        Index("idx_devices_pairing", "pairing_code", "pairing_expires_at"),
    )
