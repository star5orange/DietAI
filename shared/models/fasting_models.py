"""轻断食/辟谷 ORM 模型"""
from sqlalchemy import Column, Integer, String, DateTime, Date, Boolean, Text, Numeric, ForeignKey, Time, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class FastingPlan(Base):
    """轻断食/辟谷计划表"""
    __tablename__ = "fasting_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # 计划类型
    plan_type = Column(String(20), nullable=False, comment="16_8 / 5_2 / basic_fasting")

    # 目标与周期
    target_weight = Column(Numeric(5, 2), nullable=True)
    start_weight = Column(Numeric(5, 2), nullable=True, comment="计划开始时的体重(kg)")
    start_date = Column(Date, nullable=False)
    end_date = Column(Date, nullable=True)

    # 状态
    status = Column(String(20), nullable=False, default="active", comment="active / paused / stopped / completed")

    # 进食窗口
    eating_window_start = Column(Time, nullable=False, default=func.time("08:00"))
    eating_window_end = Column(Time, nullable=False, default=func.time("16:00"))

    # 安全确认
    disclaimer_accepted = Column(Boolean, nullable=False, default=False)
    disclaimer_accepted_at = Column(DateTime, nullable=True)

    # 禁忌筛查结果
    health_assessment = Column(JSONB, nullable=True)

    # 断食日配置
    fasting_days = Column(JSONB, nullable=True, comment="断食日列表，如[0,2]表示周一、周三")

    created_at = Column(DateTime, nullable=False, default=func.now())
    updated_at = Column(DateTime, nullable=False, default=func.now(), onupdate=func.now())

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
    feeling = Column(String(30), nullable=False, default="normal", comment="good / normal / tired / uncomfortable")

    # 完成情况
    completed = Column(Boolean, nullable=False, default=False)

    # 不适症状（用于风险预警）
    discomfort = Column(JSONB, nullable=True)

    # 备注
    notes = Column(Text, nullable=True)

    # 断食日标记
    is_fasting_day = Column(Boolean, nullable=False, default=True, comment="当天是否是断食日")

    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_fasting_checkin_plan_date", "plan_id", "checkin_date", unique=True),
        Index("idx_fasting_checkin_discomfort", "discomfort"),
    )
