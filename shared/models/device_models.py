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

    # V6 设备管理（契约 C6，PRD 15.9.2）
    device_type = Column(String(16), nullable=True,
                         comment="设备形态: clock(一人一机)/robot(一家一机)")
    name = Column(String(32), nullable=True, comment="用户自定义设备名")
    current_member_id = Column(Integer, ForeignKey("family_members.id"), nullable=True,
                               comment="设备当前成员（C4 双向同步，云端权威值）")
    locked_member_id = Column(Integer, ForeignKey("family_members.id"), nullable=True,
                              comment="锁定成员：时钟必填恒归属；空=可切换（机器人）")
    firmware_version = Column(String(32), nullable=True,
                              comment="固件版本，sync 上报经 X-Firmware-Version 头携带")
    home_user_id = Column(Integer, ForeignKey("users.id"), nullable=True,
                          comment="设备归属家庭主账号（由 user_id 换算，绑定前为空）")

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_devices_user", "user_id"),
        Index("idx_devices_pairing", "pairing_code", "pairing_expires_at"),
        Index("idx_devices_home", "home_user_id"),
    )
