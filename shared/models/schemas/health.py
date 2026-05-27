from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime


class HealthAnalysisRequest(BaseModel):
    analysis_type: str = Field(..., description="分析类型：bmr,tdee,nutrition_balance,health_level")
    date_range: Optional[Dict[str, str]] = Field(None, description="日期范围")
    parameters: Optional[Dict[str, Any]] = Field(None, description="额外参数")


class HealthAnalysisResponse(BaseModel):
    analysis_type: str
    result: Dict[str, Any]
    recommendations: Optional[List[str]]
    timestamp: datetime