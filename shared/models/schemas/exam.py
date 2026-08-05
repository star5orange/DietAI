"""体检报告 Pydantic 模型 - Milestone 4"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, date
from decimal import Decimal
from enum import Enum


class ReportType(str, Enum):
    """体检报告类型"""
    FULL = "full"
    ROUTINE = "routine"
    SPECIFIC = "specific"


class MetricStatus(str, Enum):
    """指标状态"""
    NORMAL = "normal"
    HIGH = "high"
    LOW = "low"
    ABNORMAL = "abnormal"


# ============================================================
# 体检报告上传
# ============================================================

class ExamReportUpload(BaseModel):
    """体检报告上传请求"""
    user_id: int = Field(..., description="体检用户ID")
    exam_date: Optional[date] = Field(None, description="体检日期（AI可自动提取）")
    hospital_name: Optional[str] = Field(None, max_length=200, description="体检机构")
    report_type: Optional[ReportType] = Field(ReportType.FULL, description="报告类型")


class ExamReportUploadResponse(BaseModel):
    """体检报告上传响应"""
    report_id: int
    photo_url: Optional[str] = None
    exam_date: Optional[date] = None
    hospital_name: Optional[str] = None
    abnormal_count: int = 0
    status: str = Field("processing", description="processing|completed|failed")


# ============================================================
# 体检报告响应
# ============================================================

class ExamReportResponse(BaseModel):
    """体检报告响应"""
    id: int
    user_id: int
    exam_date: date
    report_date: Optional[date] = None
    hospital_name: Optional[str] = None
    report_type: Optional[str] = None
    photo_url: Optional[str] = None
    abnormal_count: int = 0
    summary: Optional[str] = None
    doctor_advice: Optional[str] = None
    compared_to_last: Optional[Dict[str, Any]] = None
    created_at: datetime
    created_by: Optional[int] = None

    class Config:
        from_attributes = True


class ExamReportListResponse(BaseModel):
    """体检报告列表响应"""
    reports: List[ExamReportResponse]
    total: int


# ============================================================
# 体检指标
# ============================================================

class ExamMetricResponse(BaseModel):
    """体检指标响应"""
    id: int
    report_id: int
    category: Optional[str] = None
    metric_name: str
    metric_value: Optional[Decimal] = None
    unit: Optional[str] = None
    reference_range: Optional[str] = None
    reference_min: Optional[Decimal] = None
    reference_max: Optional[Decimal] = None
    status: Optional[str] = None
    is_abnormal: bool = False
    ai_confidence: Optional[Decimal] = None
    raw_text: Optional[str] = None

    class Config:
        from_attributes = True


class ExamMetricUpdate(BaseModel):
    """体检指标修正"""
    metric_value: Optional[Decimal] = Field(None, description="修正后的数值")
    status: Optional[MetricStatus] = Field(None, description="修正后的状态")
    is_abnormal: Optional[bool] = Field(None, description="是否异常")


# ============================================================
# 指标趋势
# ============================================================

class MetricTrendPoint(BaseModel):
    """指标趋势点"""
    exam_date: date
    metric_value: Decimal
    unit: Optional[str] = None
    report_id: int


class MetricTrendResponse(BaseModel):
    """指标趋势响应"""
    metric_name: str
    category: Optional[str] = None
    unit: Optional[str] = None
    reference_min: Optional[Decimal] = None
    reference_max: Optional[Decimal] = None
    trend: List[MetricTrendPoint]
    trend_direction: Optional[str] = Field(None, description="up|down|stable")
    change_summary: Optional[str] = Field(None, description="变化摘要：'三年累计上升 1.6 mmol/L'")


# ============================================================
# 体检摘要（家庭看板用）
# ============================================================

class ExamSummaryResponse(BaseModel):
    """体检摘要响应（家庭看板用）"""
    user_id: int
    latest_exam_date: Optional[date] = None
    abnormal_count: int = 0
    abnormal_metrics: List[str] = Field(default_factory=list, description="异常指标名称列表")
    has_trend_warning: bool = Field(False, description="是否有趋势预警")
    next_checkup_date: Optional[date] = Field(None, description="建议下次体检日期")


# ============================================================
# AI 健康建议
# ============================================================

class ExamAdviceResponse(BaseModel):
    """体检报告AI健康建议"""
    report_id: int
    advice: str = Field(..., description="AI生成的健康建议")
    diet_recommendations: List[str] = Field(default_factory=list, description="饮食建议")
    exercise_recommendations: List[str] = Field(default_factory=list, description="运动建议")
    followup_reminder: Optional[str] = Field(None, description="复查提醒")
