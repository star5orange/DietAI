"""AI 顾问设置 ORM 模型"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from .database import Base


class AiAdvisorSettings(Base):
    """AI 顾问风格设置表"""
    __tablename__ = "ai_advisor_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # 风格设置
    advisor_style = Column(
        String(30), nullable=False, default="nutritionist",
        comment="nutritionist/fitness_coach/tcm_healer/encouraging_friend"
    )
    focus_goal = Column(
        String(30), nullable=True,
        comment="fat_loss/muscle_gain/sugar_control/wellness/balanced"
    )
    focus_nutrient = Column(
        String(30), nullable=True,
        comment="calories/protein/carb/fat/micronutrient"
    )
    response_style = Column(
        String(30), nullable=False, default="detailed",
        comment="concise/detailed/example_rich"
    )

    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_advisor_settings_user", "user_id", unique=True),
    )
