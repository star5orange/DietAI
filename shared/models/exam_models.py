"""体检报告模型 - Milestone 4 体检报告管理"""
from sqlalchemy import Column, Integer, String, DateTime, Date, Text, Numeric, Boolean, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class ExamReport(Base):
    """体检报告表"""
    __tablename__ = "exam_reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exam_date = Column(Date, nullable=False, comment="体检日期")
    report_date = Column(Date, nullable=True, comment="报告出具日期")
    hospital_name = Column(String(200), nullable=True, comment="体检机构")
    report_type = Column(String(50), nullable=True, comment="full|routine|specific")
    photo_url = Column(Text, nullable=True, comment="原始报告照片（MinIO，首张）")
    photo_urls = Column(JSONB, nullable=True, comment="多页报告照片 URL 列表（MinIO）")
    followup_date = Column(Date, nullable=True, comment="建议复查日期（AI解析复查周期）")
    abnormal_count = Column(Integer, nullable=False, default=0, comment="异常指标数量")
    summary = Column(Text, nullable=True, comment="AI生成的体检综述")
    doctor_advice = Column(Text, nullable=True, comment="医生建议（提取或AI总结）")
    compared_to_last = Column(JSONB, nullable=True, comment="与上次对比 {'血糖': '↑ 0.8', ...}")
    created_at = Column(DateTime, nullable=False, default=func.now())
    created_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, comment="代上传者（家人代传）")

    __table_args__ = (
        Index("idx_exam_report_user", "user_id"),
        Index("idx_exam_report_date", "exam_date"),
    )


class ExamMetric(Base):
    """体检指标明细表"""
    __tablename__ = "exam_metrics"

    id = Column(Integer, primary_key=True, index=True)
    report_id = Column(Integer, ForeignKey("exam_reports.id", ondelete="CASCADE"), nullable=False)
    category = Column(String(50), nullable=True, comment="blood_routine|lipids|glucose|liver|kidney|blood_pressure|physical")
    metric_name = Column(String(100), nullable=False, comment="指标中文名")
    metric_value = Column(Numeric(10, 2), nullable=True, comment="数值")
    unit = Column(String(20), nullable=True, comment="单位")
    reference_range = Column(String(50), nullable=True, comment="参考范围 '3.9-6.1'")
    reference_min = Column(Numeric(10, 2), nullable=True, comment="参考下限")
    reference_max = Column(Numeric(10, 2), nullable=True, comment="参考上限")
    status = Column(String(10), nullable=True, comment="normal|high|low|abnormal")
    is_abnormal = Column(Boolean, nullable=False, default=False)
    ai_confidence = Column(Numeric(3, 2), nullable=True, comment="AI提取置信度")
    raw_text = Column(Text, nullable=True, comment="原始文字（用于人工复核）")

    __table_args__ = (
        Index("idx_exam_metric_report", "report_id"),
        Index("idx_exam_metric_category", "category"),
        Index("idx_exam_metric_abnormal", "is_abnormal"),
    )
