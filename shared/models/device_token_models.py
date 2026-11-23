from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, func, Index
from .database import Base


class DeviceToken(Base):
    """用户设备 FCM Token"""

    __tablename__ = "device_tokens"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    token = Column(String(500), nullable=False, unique=True, comment="FCM device token")
    platform = Column(String(10), nullable=True, comment="android / ios")
    is_active = Column(Boolean, default=True, comment="是否有效")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_device_tokens_user_active", "user_id", "is_active"),
    )
