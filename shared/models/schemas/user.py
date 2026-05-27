from pydantic import BaseModel, Field, EmailStr, validator
from typing import Optional, List, Dict, Any
from datetime import datetime, date


class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="用户名")
    email: EmailStr = Field(..., description="邮箱")
    password: str = Field(..., min_length=8, description="密码")
    phone: Optional[str] = Field(None, max_length=20, description="手机号")

    @validator('password')
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('密码长度至少8位')
        return v


class UserLogin(BaseModel):
    username: str = Field(..., description="用户名或邮箱")
    password: str = Field(..., description="密码")


class UserResponse(BaseModel):
    id: int
    username: str
    email: Optional[str]
    phone: Optional[str]
    avatar_url: Optional[str]
    status: int
    created_at: datetime
    last_login_at: Optional[datetime]

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str = Field(..., description="访问令牌")
    refresh_token: str = Field(..., description="刷新令牌")
    token_type: str = Field(default="bearer", description="令牌类型")
    expires_in: int = Field(..., description="过期时间（秒）")


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(..., description="刷新令牌")


class PasswordChangeRequest(BaseModel):
    old_password: str = Field(..., description="旧密码")
    new_password: str = Field(..., min_length=8, description="新密码")


class UserProfileUpdate(BaseModel):
    real_name: Optional[str] = Field(None, max_length=100, description="真实姓名")
    gender: Optional[int] = Field(None, ge=1, le=3, description="性别：1男2女3其他")
    birth_date: Optional[date] = Field(None, description="出生日期")
    height: Optional[float] = Field(None, gt=0, le=300, description="身高(cm)")
    weight: Optional[float] = Field(None, gt=0, le=1000, description="体重(kg)")
    activity_level: Optional[int] = Field(None, ge=1, le=5, description="活动级别1-5")
    occupation: Optional[str] = Field(None, max_length=100, description="职业")
    region: Optional[str] = Field(None, max_length=100, description="地区")
    dietary_preferences: Optional[List[str]] = Field(None, description="饮食偏好")
    food_dislikes: Optional[List[str]] = Field(None, description="不喜欢的食物")
    wake_up_time: Optional[str] = Field(None, description="起床时间")
    sleep_time: Optional[str] = Field(None, description="睡觉时间")
    meal_times: Optional[Dict[str, str]] = Field(None, description="用餐时间")
    health_status: Optional[int] = Field(None, ge=1, le=3, description="健康状态1-3")
    onboarding_step: Optional[int] = Field(None, ge=0, description="引导步骤")
    onboarding_completed: Optional[bool] = Field(None, description="引导完成状态")
    # Milestone 1 新增字段
    crowd_tag: Optional[str] = Field(None, description="人群标签：减脂/健身/普通日常")
    constitution_type: Optional[str] = Field(None, description="体质类型")
    daily_water_goal: Optional[int] = Field(2000, ge=500, le=5000, description="每日饮水目标(ml)")


class OnboardingStepUpdate(BaseModel):
    step: int = Field(..., ge=0, le=10, description="当前步骤")
    data: Optional[Dict[str, Any]] = Field(None, description="步骤数据")
    completed: Optional[bool] = Field(None, description="是否完成")


class OnboardingDataRequest(BaseModel):
    basic_info: Optional[Dict[str, Any]] = Field(None, description="基本信息")
    physical_data: Optional[Dict[str, Any]] = Field(None, description="身体数据")
    health_goals: Optional[List[Dict[str, Any]]] = Field(None, description="健康目标")
    dietary_preferences: Optional[List[str]] = Field(None, description="饮食偏好")
    medical_conditions: Optional[List[Dict[str, Any]]] = Field(None, description="疾病信息")
    allergies: Optional[List[Dict[str, Any]]] = Field(None, description="过敏信息")
    lifestyle_habits: Optional[Dict[str, Any]] = Field(None, description="生活习惯")


class UserProfileResponse(BaseModel):
    id: int
    user_id: int
    real_name: Optional[str]
    gender: Optional[int]
    birth_date: Optional[date]
    height: Optional[float]
    weight: Optional[float]
    bmi: Optional[float]
    activity_level: int
    occupation: Optional[str]
    region: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class HealthGoalCreate(BaseModel):
    goal_type: int = Field(..., ge=1, le=5, description="目标类型：1减重2增重3维持4增肌5减脂")
    target_weight: Optional[float] = Field(None, gt=0, description="目标体重")
    target_date: Optional[date] = Field(None, description="目标日期")


class HealthGoalResponse(BaseModel):
    id: int
    user_id: int
    goal_type: int
    target_weight: Optional[float]
    target_date: Optional[date]
    current_status: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class DiseaseCreate(BaseModel):
    disease_code: Optional[str] = Field(None, max_length=20, description="疾病编码")
    disease_name: str = Field(..., max_length=200, description="疾病名称")
    severity_level: Optional[int] = Field(None, ge=1, le=3, description="严重程度1-3")
    diagnosed_date: Optional[date] = Field(None, description="诊断日期")
    notes: Optional[str] = Field(None, description="备注")


class DiseaseResponse(BaseModel):
    id: int
    user_id: int
    disease_code: Optional[str]
    disease_name: str
    severity_level: Optional[int]
    diagnosed_date: Optional[date]
    is_current: bool
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class AllergyCreate(BaseModel):
    allergen_type: int = Field(..., ge=1, le=4, description="过敏原类型：1食物2药物3环境4其他")
    allergen_name: str = Field(..., max_length=100, description="过敏原名称")
    severity_level: Optional[int] = Field(None, ge=1, le=3, description="严重程度1-3")
    reaction_description: Optional[str] = Field(None, description="反应描述")


class AllergyResponse(BaseModel):
    id: int
    user_id: int
    allergen_type: int
    allergen_name: str
    severity_level: Optional[int]
    reaction_description: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class WeightRecordCreate(BaseModel):
    weight: float = Field(..., gt=0, description="体重(kg)")
    body_fat_percentage: Optional[float] = Field(None, ge=0, le=100, description="体脂率")
    muscle_mass: Optional[float] = Field(None, gt=0, description="肌肉量")
    measured_at: Optional[datetime] = Field(None, description="测量时间")
    notes: Optional[str] = Field(None, description="备注")
    device_type: Optional[str] = Field(None, max_length=50, description="设备类型")


class WeightRecordResponse(BaseModel):
    id: int
    user_id: int
    weight: float
    body_fat_percentage: Optional[float]
    muscle_mass: Optional[float]
    bmi: Optional[float]
    measured_at: datetime
    notes: Optional[str]
    device_type: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True