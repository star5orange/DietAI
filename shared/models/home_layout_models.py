from sqlalchemy import Column, Integer, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSONB

from .database import Base


class UserHomeLayout(Base):
    """用户首页模块布局偏好（隐藏模块 + 自定义顺序）

    为空表示"未自定义"，此时由后端按用户画像规则自动决定布局。
    """

    __tablename__ = "user_home_layouts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    hidden_modules = Column(
        JSONB, nullable=False, default=list, server_default="[]",
        comment="用户手动隐藏的模块ID列表",
    )
    module_order = Column(
        JSONB, nullable=True,
        comment="用户自定义模块顺序（模块ID列表）；NULL 表示使用默认顺序",
    )
    preferences = Column(
        JSONB, nullable=True,
        comment="引导问卷偏好：{focus: fat_loss/fitness/balanced, interests: [cost/wellness/exam/water/pet]}",
    )
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())
