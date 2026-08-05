"""代记录模型 - Milestone 4 家庭健康管理"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from .database import Base


class ProxyRecord(Base):
    """代记录日志表"""
    __tablename__ = "proxy_records"

    id = Column(Integer, primary_key=True, index=True)
    recorded_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, comment="代记录发起人")
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, comment="被记录人")
    record_type = Column(String(20), nullable=False, comment="food|water|exercise|pet_feeding")
    record_id = Column(Integer, nullable=False, comment="指向实际记录表的ID")
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_proxy_record_by_user", "recorded_by_user_id"),
        Index("idx_proxy_record_target", "target_user_id"),
        Index("idx_proxy_record_type", "record_type"),
        Index("idx_proxy_record_created", "created_at"),
    )
