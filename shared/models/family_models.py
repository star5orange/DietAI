"""家庭成员模型 — V6 多成员归属（PRD §5.1）"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Index, func

from .database import Base


class FamilyMember(Base):
    """家庭成员表 — 成员不等于登录账号，老人/儿童可无账号

    member_type: 0 成人 / 1 老人 / 2 儿童 / 3 其他
    停用语义：is_active=False 后历史记录保留，不可再新增归属
    上限 8 人/家庭（由接口层校验，不在数据库层约束）
    """
    __tablename__ = "family_members"

    id = Column(Integer, primary_key=True, index=True)
    home_user_id = Column(Integer, ForeignKey("users.id"), nullable=False,
                          comment="家庭主账号ID")
    display_name = Column(String(32), nullable=False, comment="显示名")
    alias = Column(String(128), nullable=True, comment="别名，逗号分隔（语音匹配用）")
    avatar = Column(String(256), nullable=True, comment="头像 URL")
    birth_year = Column(Integer, nullable=True, comment="出生年")
    member_type = Column(Integer, nullable=False, default=0,
                         comment="0 成人 / 1 老人 / 2 儿童 / 3 其他")
    is_managed = Column(Boolean, nullable=False, default=True,
                        comment="是否由主账号代管（无账号成员为 true）")
    is_active = Column(Boolean, nullable=False, default=True, comment="停用标记")
    sort_order = Column(Integer, nullable=False, default=0, comment="设备端展示顺序")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_family_members_home", "home_user_id"),
    )
