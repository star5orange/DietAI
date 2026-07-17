"""AI 顾问风格设置数据库模型"""
from sqlalchemy import Column, Integer, String, DateTime, func, Index
from .database import Base


class AiAdvisorSettings(Base):
    """AI 顾问风格设置表"""
    __tablename__ = "ai_advisor_settings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    advisor_style = Column(String(50), nullable=False, default="nutritionist", comment="顾问风格: nutritionist/fitness_coach/tcm_healer/motivator")
    focus_goal = Column(String(255), nullable=True, comment="关注目标: weight_loss/muscle_gain/balanced_health等")
    focus_nutrient = Column(String(255), nullable=True, comment="关注营养素: protein/fiber/vitamin_c等")
    response_style = Column(String(50), nullable=True, default="professional", comment="回复风格: professional/friendly/motivating/detailed")
    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    __table_args__ = (
        Index("idx_ai_advisor_settings_user", "user_id", unique=True),
    )
