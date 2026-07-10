"""轻断食计划 ORM 模型"""
from sqlalchemy import Column, Integer, String, DateTime, Date, Boolean, Text, Numeric, ForeignKey, Index, Time
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


class FastingPlan(Base):
    """轻断食/辟谷计划表"""
    __tablename__ = "fasting_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # 计划类型
    plan_type = Column(String(20), nullable=False, comment="16_8/5_2/basic_fasting")
    target_weight = Column(Numeric(5, 2), nullable=True)
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)

    # 状态
    status = Column(String(20), nullable=False, default="active", comment="active/paused/stopped/completed")

    # 进食窗口
    eating_window_start = Column(Time, nullable=False, default="08:00")
    eating_window_end = Column(Time, nullable=False, default="16:00")

    # 安全确认
    disclaimer_accepted = Column(Boolean, nullable=False, default=False)
    disclaimer_accepted_at = Column(DateTime, nullable=True)

    # 禁忌筛查结果
    health_assessment = Column(JSONB, nullable=True)

    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

    # 关系
    checkins = relationship("FastingCheckin", back_populates="plan", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_fasting_plans_user", "user_id"),
        Index("idx_fasting_plans_status", "status", "user_id"),
        Index("idx_fasting_plans_date", "start_date", "end_date"),
    )


class FastingCheckin(Base):
    """轻断食每日打卡表"""
    __tablename__ = "fasting_checkins"

    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(Integer, ForeignKey("fasting_plans.id", ondelete="CASCADE"), nullable=False)

    # 打卡日期
    checkin_date = Column(Date, nullable=False)

    # 身体数据
    weight = Column(Numeric(5, 2), nullable=True)
    feeling = Column(String(30), nullable=False, default="normal", comment="good/normal/tired/uncomfortable")

    # 完成情况
    completed = Column(Boolean, nullable=False, default=False)

    # 不适症状
    discomfort = Column(JSONB, nullable=True)

    # 备注
    notes = Column(Text, nullable=True)

    created_at = Column(DateTime, nullable=False, default=func.now())

    # 关系
    plan = relationship("FastingPlan", back_populates="checkins")

    __table_args__ = (
        Index("idx_fasting_checkin_plan_date", "plan_id", "checkin_date", unique=True),
        Index("idx_fasting_checkin_discomfort", "discomfort"),
    )
