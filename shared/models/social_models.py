"""社交关系模型 - Milestone 4 家庭健康管理"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class UserRelationship(Base):
    """用户关系表"""
    __tablename__ = "user_relationships"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    related_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    relationship_type = Column(String(10), nullable=False, comment="family|friend")
    status = Column(String(10), nullable=False, default="pending", comment="pending|accepted|blocked")
    note_from_user = Column(String(50), nullable=True, comment="user_id 对 related_user_id 的关系称谓（如：妈妈）")
    note_from_related = Column(String(50), nullable=True, comment="related_user_id 对 user_id 的关系称谓")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_user_relationship_unique", "user_id", "related_user_id", unique=True),
        Index("idx_user_relationship_user", "user_id"),
        Index("idx_user_relationship_related", "related_user_id"),
        Index("idx_user_relationship_type", "relationship_type"),
        Index("idx_user_relationship_status", "status"),
    )


class DataPermission(Base):
    """数据权限表 - 家人可设置哪些数据对谁可见"""
    __tablename__ = "data_permissions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    target_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    visible_fields = Column(JSONB, nullable=False, default=list, comment="可见字段列表")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_data_permission_unique", "user_id", "target_user_id", unique=True),
        Index("idx_data_permission_user", "user_id"),
        Index("idx_data_permission_target", "target_user_id"),
    )
