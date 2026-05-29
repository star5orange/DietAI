from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, date

from shared.models.schemas import DateRangeParams


class FoodRecordCreate(BaseModel):
    record_date: date = Field(..., description="记录日期")
    meal_type: int = Field(..., ge=1, le=5, description="餐次类型：1早餐2午餐3晚餐4加餐5夜宵")
    food_name: Optional[str] = Field(None, max_length=200, description="食物名称")
    description: Optional[str] = Field(None, description="描述")
    image_url: Optional[str] = Field(None, max_length=500, description="图片URL")
    recording_method: Optional[int] = Field(1, ge=1, le=3, description="记录方式：1手动2拍照3语音")
    # Milestone 1 新增
    from_source: Optional[str] = Field("camera", description="记录来源：camera/manual/voice/barcode/saved_meal/suggestion")


class FoodRecordResponse(BaseModel):
    id: int
    user_id: int
    record_date: date
    meal_type: int
    food_name: Optional[str]
    description: Optional[str]
    image_url: Optional[str]
    recording_method: int
    analysis_status: int
    from_source: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class NutritionDetailCreate(BaseModel):
    food_record_id: Optional[int] = Field(None, description="食物记录ID")
    calories: Optional[float] = Field(0, ge=0, description="热量(kcal)")
    protein: Optional[float] = Field(0, ge=0, description="蛋白质(g)")
    fat: Optional[float] = Field(0, ge=0, description="脂肪(g)")
    carbohydrates: Optional[float] = Field(0, ge=0, description="碳水化合物(g)")
    dietary_fiber: Optional[float] = Field(0, ge=0, description="膳食纤维(g)")
    sugar: Optional[float] = Field(0, ge=0, description="糖类(g)")
    sodium: Optional[float] = Field(0, ge=0, description="钠(mg)")
    cholesterol: Optional[float] = Field(0, ge=0, description="胆固醇(mg)")
    vitamin_a: Optional[float] = Field(0, ge=0, description="维生素A(μg)")
    vitamin_c: Optional[float] = Field(0, ge=0, description="维生素C(mg)")
    vitamin_d: Optional[float] = Field(0, ge=0, description="维生素D(μg)")
    calcium: Optional[float] = Field(0, ge=0, description="钙(mg)")
    iron: Optional[float] = Field(0, ge=0, description="铁(mg)")
    potassium: Optional[float] = Field(0, ge=0, description="钾(mg)")
    confidence_score: Optional[float] = Field(None, ge=0, le=1, description="置信度")
    analysis_method: Optional[str] = Field(None, max_length=50, description="分析方法")


class NutritionDetailResponse(BaseModel):
    id: int
    food_record_id: int
    calories: float
    protein: float
    fat: float
    carbohydrates: float
    dietary_fiber: float
    sugar: float
    sodium: float
    cholesterol: float
    vitamin_a: float
    vitamin_c: float
    vitamin_d: float
    calcium: float
    iron: float
    potassium: float
    confidence_score: Optional[float]
    analysis_method: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class DailyNutritionSummaryResponse(BaseModel):
    id: int
    user_id: int
    summary_date: date
    total_calories: float
    total_protein: float
    total_fat: float
    total_carbohydrates: float
    total_fiber: float
    total_sodium: float
    meal_count: int
    water_intake: float
    exercise_calories: float
    health_score: Optional[float]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class NutritionTrendParams(DateRangeParams):
    metrics: Optional[List[str]] = Field(None, description="指标列表")