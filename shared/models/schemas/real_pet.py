"""M3 真实宠物管理 Pydantic Schemas"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, date


# ========== 宠物档案 ==========

class PetProfileCreate(BaseModel):
    name: str = Field(..., max_length=50)
    species: str = Field(..., description="cat/dog/other")
    breed: Optional[str] = Field(None, max_length=100)
    gender: Optional[str] = Field(None, description="male/female")
    birth_date: Optional[date] = None
    is_neutered: bool = False
    avatar_url: Optional[str] = Field(None, max_length=500)


class PetProfileUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=50)
    species: Optional[str] = None
    breed: Optional[str] = Field(None, max_length=100)
    gender: Optional[str] = None
    birth_date: Optional[date] = None
    is_neutered: Optional[bool] = None
    avatar_url: Optional[str] = Field(None, max_length=500)


# ========== 体重 ==========

class PetWeightCreate(BaseModel):
    weight: float = Field(..., gt=0, le=200)
    measured_at: Optional[datetime] = None
    notes: Optional[str] = None


class PetWeightUpdate(BaseModel):
    weight: Optional[float] = Field(None, gt=0, le=200)
    measured_at: Optional[datetime] = None
    notes: Optional[str] = None


# ========== 疫苗 ==========

class PetVaccineCreate(BaseModel):
    vaccine_name: str = Field(..., max_length=100)
    vaccinated_at: date
    expiry_date: Optional[date] = None
    next_vaccination_date: Optional[date] = None
    notes: Optional[str] = None


class PetVaccineUpdate(BaseModel):
    vaccine_name: Optional[str] = Field(None, max_length=100)
    vaccinated_at: Optional[date] = None
    expiry_date: Optional[date] = None
    next_vaccination_date: Optional[date] = None
    notes: Optional[str] = None


# ========== 驱虫 ==========

class PetDewormingCreate(BaseModel):
    deworming_type: str = Field(..., description="internal/external")
    treated_at: date
    next_treatment_date: Optional[date] = None
    notes: Optional[str] = None


class PetDewormingUpdate(BaseModel):
    deworming_type: Optional[str] = Field(None, description="internal/external")
    treated_at: Optional[date] = None
    next_treatment_date: Optional[date] = None
    notes: Optional[str] = None


# ========== 饮食 ==========

class PetFeedingCreate(BaseModel):
    food_name: Optional[str] = Field(None, max_length=200)
    amount_grams: Optional[float] = Field(None, ge=0)
    calories: Optional[float] = Field(None, ge=0)
    protein: Optional[float] = Field(None, ge=0)
    fat: Optional[float] = Field(None, ge=0)
    carbs: Optional[float] = Field(None, ge=0)
    record_time: Optional[datetime] = None
    from_source: str = Field("manual", description="hardware/manual")


# ========== 饮水 ==========

class PetWaterCreate(BaseModel):
    amount_ml: int = Field(..., gt=0)
    record_time: Optional[datetime] = None
    from_source: str = Field("manual", description="hardware/manual")


# ========== AI 建议 ==========

class PetAIAdviceRequest(BaseModel):
    topic: Optional[str] = Field("general", description="咨询主题")


# ========== 食品包装OCR ==========

class PetFoodOCRRequest(BaseModel):
    image_base64: str = Field(..., description="Base64 编码的宠物食品包装照片")


class PetFoodOCRResult(BaseModel):
    brand: Optional[str] = None
    food_name: Optional[str] = None
    calories_per_100g: Optional[float] = None
    protein_per_100g: Optional[float] = None
    fat_per_100g: Optional[float] = None
    carbs_per_100g: Optional[float] = None
    raw_text: Optional[str] = None


# ========== AI 形象生成 ==========

class GenerateAvatarRequest(BaseModel):
    mode: str = Field(..., description="photo/description")
    photo: Optional[str] = Field(None, description="Base64 编码的宠物照片")
    description: Optional[str] = Field(None, description="文字描述")


class RegenerateEmotionRequest(BaseModel):
    emotion: str = Field(..., description="happy/normal/hungry/weak")
