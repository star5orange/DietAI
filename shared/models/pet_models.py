"""虚拟宠物状态 ORM 模型"""
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class VirtualPetState(Base):
    """用户虚拟宠物状态表"""
    __tablename__ = "virtual_pet_states"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # 状态字段
    mood = Column(String(20), nullable=False, default="normal", comment="normal/happy/hungry/anxious/weak")
    level = Column(Integer, nullable=False, default=1)
    exp = Column(Integer, nullable=False, default=0)

    # 外观字段
    current_skin = Column(String(50), nullable=False, default="default")
    pet_name = Column(String(50), nullable=False, default="桌宠一", comment="用户自定义的桌宠名称（已废弃，使用pet_names）")
    pet_names = Column(JSONB, nullable=False, default=dict, comment="每个桌宠皮肤的独立命名，格式: {\"default\": \"桌宠一\", \"christine\": \"桌宠二\"}")
    unlocked_skins = Column(JSONB, nullable=False, default=list)

    # 计算字段
    habit_score = Column(Integer, nullable=False, default=0)
    version = Column(Integer, nullable=False, default=1, comment="状态版本号，硬件轮询用")

    # 时间字段
    last_interact_at = Column(DateTime, nullable=False, default=func.now())
    last_feed_at = Column(DateTime, nullable=True)
    last_play_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_pet_state_user", "user_id", unique=True),
        Index("idx_pet_state_mood", "mood"),
        Index("idx_pet_state_updated", "updated_at"),
    )


class PetUnlockable(Base):
    """宠物可解锁内容定义表"""
    __tablename__ = "pet_unlockables"

    id = Column(Integer, primary_key=True, index=True)
    unlock_type = Column(String(20), nullable=False, comment="skin/action/effect")
    unlock_key = Column(String(50), nullable=False, unique=True)
    name = Column(String(100), nullable=False)
    description = Column(String(500), nullable=True)
    required_level = Column(Integer, nullable=True)
    required_streak = Column(Integer, nullable=True)
    required_habit_score = Column(Integer, nullable=True)
    asset_url = Column(String(255), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=func.now())
