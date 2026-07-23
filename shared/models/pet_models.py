"""宠物相关 ORM 模型（M2 虚拟宠物 + M3 真实宠物 + 硬件）"""
from sqlalchemy import Column, Integer, String, DateTime, Date, Boolean, Text, Numeric, ForeignKey, Index, Time
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


# ============================================================
# M2: 虚拟宠物养成
# ============================================================

class VirtualPetState(Base):
    """用户虚拟宠物状态表"""
    __tablename__ = "virtual_pet_states"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    mood = Column(String(20), nullable=False, default="normal")
    level = Column(Integer, nullable=False, default=1)
    exp = Column(Integer, nullable=False, default=0)
    current_skin = Column(String(50), nullable=False, default="default")
    unlocked_skins = Column(JSONB, nullable=False, default=list)
    habit_score = Column(Integer, nullable=False, default=0)
    version = Column(Integer, nullable=False, default=1)
    pet_name = Column(String(50), nullable=True)
    custom_messages = Column(JSONB, nullable=True, default=dict)
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
    unlock_type = Column(String(20), nullable=False)
    unlock_key = Column(String(50), nullable=False, unique=True)
    name = Column(String(100), nullable=False)
    description = Column(String(500), nullable=True)
    required_level = Column(Integer, nullable=True)
    required_streak = Column(Integer, nullable=True)
    required_habit_score = Column(Integer, nullable=True)
    asset_url = Column(String(255), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, nullable=False, default=func.now())


# ============================================================
# 硬件快捷按钮 & 离线同步
# ============================================================

class HardwareQuickButton(Base):
    """硬件快捷按钮配置"""
    __tablename__ = "hardware_quick_buttons"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id"), nullable=True)
    button_index = Column(Integer, nullable=False)
    button_type = Column(String(20), nullable=False)
    label = Column(String(100), nullable=False)
    amount_ml = Column(Integer, nullable=True)
    meal_type = Column(String(20), nullable=True)
    food_name = Column(String(100), nullable=True)
    calories = Column(Numeric(8, 2), nullable=True)
    protein = Column(Numeric(6, 2), nullable=True)
    amount = Column(Integer, nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_hw_buttons_user", "user_id", "button_index", unique=True),
    )


class OfflineSyncLog(Base):
    """硬件离线同步日志"""
    __tablename__ = "offline_sync_log"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    target_type = Column(String(20), nullable=False, default="human")
    sync_type = Column(String(20), nullable=False)
    payload = Column(JSONB, nullable=False)
    synced_at = Column(DateTime, nullable=False, default=func.now())
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_offline_sync_user", "user_id", "synced_at"),
    )


# ============================================================
# M3: 真实宠物健康管理 — P0 表
# ============================================================

class PetProfile(Base):
    """真实宠物档案"""
    __tablename__ = "pet_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(50), nullable=False)
    species = Column(String(20), nullable=False, comment="cat/dog/other")
    breed = Column(String(100), nullable=True)
    gender = Column(String(10), nullable=True, comment="male/female")
    birth_date = Column(Date, nullable=True)
    is_neutered = Column(Boolean, default=False)
    avatar_url = Column(Text, nullable=True, comment="AI生成的头像URL（签名URL可能超2000字符）")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    # 关系
    weight_records = relationship("PetWeightRecord", back_populates="pet", cascade="all, delete-orphan")
    vaccine_records = relationship("PetVaccineRecord", back_populates="pet", cascade="all, delete-orphan")
    deworming_records = relationship("PetDewormingRecord", back_populates="pet", cascade="all, delete-orphan")
    feeding_records = relationship("PetFeedingRecord", back_populates="pet", cascade="all, delete-orphan")
    water_records = relationship("PetWaterRecord", back_populates="pet", cascade="all, delete-orphan")
    daily_summaries = relationship("PetDailySummary", back_populates="pet", cascade="all, delete-orphan")
    avatar = relationship("PetAvatar", back_populates="pet", uselist=False, cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_pet_profiles_user", "user_id", "is_active"),
    )


class PetWeightRecord(Base):
    """宠物体重记录"""
    __tablename__ = "pet_weight_records"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    weight = Column(Numeric(5, 2), nullable=False)
    measured_at = Column(DateTime, nullable=False, default=func.now())
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())

    pet = relationship("PetProfile", back_populates="weight_records")

    __table_args__ = (
        Index("idx_pet_weight_pet_time", "pet_id", "measured_at"),
    )


class PetVaccineRecord(Base):
    """宠物疫苗记录"""
    __tablename__ = "pet_vaccine_records"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    vaccine_name = Column(String(100), nullable=False)
    vaccinated_at = Column(Date, nullable=False)
    expiry_date = Column(Date, nullable=True)
    next_vaccination_date = Column(Date, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())

    pet = relationship("PetProfile", back_populates="vaccine_records")

    __table_args__ = (
        Index("idx_pet_vaccine_next_date", "next_vaccination_date"),
    )


class PetFeedingRecord(Base):
    """宠物饮食记录"""
    __tablename__ = "pet_feeding_records"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    food_name = Column(String(200), nullable=True)
    amount_grams = Column(Numeric(8, 2), nullable=True)
    calories = Column(Numeric(8, 2), nullable=True)
    protein = Column(Numeric(6, 2), nullable=True)
    fat = Column(Numeric(6, 2), nullable=True)
    carbs = Column(Numeric(6, 2), nullable=True)
    record_time = Column(DateTime, nullable=False, default=func.now())
    from_source = Column(String(20), default="manual", comment="hardware/manual")
    created_at = Column(DateTime, nullable=False, default=func.now())

    pet = relationship("PetProfile", back_populates="feeding_records")

    __table_args__ = (
        Index("idx_pet_feeding_pet_time", "pet_id", "record_time"),
    )


class PetWaterRecord(Base):
    """宠物饮水记录"""
    __tablename__ = "pet_water_records"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    amount_ml = Column(Integer, nullable=False)
    record_time = Column(DateTime, nullable=False, default=func.now())
    from_source = Column(String(20), default="manual", comment="hardware/manual")
    created_at = Column(DateTime, nullable=False, default=func.now())

    pet = relationship("PetProfile", back_populates="water_records")

    __table_args__ = (
        Index("idx_pet_water_pet_time", "pet_id", "record_time"),
    )


class PetDailySummary(Base):
    """宠物每日营养汇总"""
    __tablename__ = "pet_daily_summaries"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    summary_date = Column(Date, nullable=False)
    total_calories = Column(Numeric(8, 2), default=0)
    total_protein = Column(Numeric(6, 2), default=0)
    total_fat = Column(Numeric(6, 2), default=0)
    total_carbs = Column(Numeric(6, 2), default=0)
    total_water_ml = Column(Integer, default=0)
    meal_count = Column(Integer, default=0)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    pet = relationship("PetProfile", back_populates="daily_summaries")

    __table_args__ = (
        Index("idx_pet_daily_summary_date", "pet_id", "summary_date", unique=True),
    )


class PetAvatar(Base):
    """AI 生成宠物形象"""
    __tablename__ = "pet_avatars"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), unique=True, nullable=False)
    status = Column(String(20), nullable=False, default="none", comment="none/processing/done/failed")
    error_message = Column(Text, nullable=True)
    base_image_url = Column(String(2000), nullable=True)
    emotion_happy_url = Column(String(2000), nullable=True)
    emotion_normal_url = Column(String(2000), nullable=True)
    emotion_hungry_url = Column(String(2000), nullable=True)
    emotion_weak_url = Column(String(2000), nullable=True)
    generation_seed = Column(Integer, nullable=True)
    has_gif = Column(Boolean, default=False)
    gif_url = Column(String(2000), nullable=True)
    prompt_used = Column(Text, nullable=True)
    ai_model = Column(String(50), nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    pet = relationship("PetProfile", back_populates="avatar")


# ============================================================
# M3: P1 表（驱虫记录 + 食品库）
# ============================================================

class PetDewormingRecord(Base):
    """宠物驱虫记录"""
    __tablename__ = "pet_deworming_records"

    id = Column(Integer, primary_key=True, index=True)
    pet_id = Column(Integer, ForeignKey("pet_profiles.id", ondelete="CASCADE"), nullable=False)
    deworming_type = Column(String(20), nullable=False, comment="internal/external")
    treated_at = Column(Date, nullable=False)
    next_treatment_date = Column(Date, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())

    pet = relationship("PetProfile", back_populates="deworming_records")

    __table_args__ = (
        Index("idx_pet_deworming_next", "next_treatment_date"),
    )


class PetFoodDatabase(Base):
    """宠物食品营养库（每个用户独立的食品库，通过拍照识别添加）"""
    __tablename__ = "pet_food_database"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    food_name = Column(String(200), nullable=False)
    brand = Column(String(100), nullable=True)
    category = Column(String(20), nullable=True, comment="dry_food/wet_food/snack/fresh")
    suitable_species = Column(String(20), nullable=True, comment="cat/dog")
    calories_per_100g = Column(Numeric(8, 2), nullable=True)
    protein_per_100g = Column(Numeric(6, 2), nullable=True)
    fat_per_100g = Column(Numeric(6, 2), nullable=True)
    carbs_per_100g = Column(Numeric(6, 2), nullable=True)
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_pet_food_db_species", "suitable_species", "category"),
    )
