"""健康家庭成就模型 - Milestone 4 家庭健康管理"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class HealthAchievement(Base):
    """健康成就表（家庭健康日等）"""
    __tablename__ = "health_achievements"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    achievement_type = Column(String(50), nullable=False, comment="成就类型，如 health_family_day")
    title = Column(String(100), nullable=False, comment="成就标题，如 健康家庭")
    # 列名保持 "metadata"，类属性名避开 SQLAlchemy Declarative API 保留字
    achievement_metadata = Column("metadata", JSONB, nullable=True, comment="成就附加信息（JSON）")
    unlocked_at = Column(DateTime, nullable=False, default=func.now(), comment="解锁时间")

    __table_args__ = (
        Index("idx_health_achievement_user_type", "user_id", "achievement_type"),
    )
