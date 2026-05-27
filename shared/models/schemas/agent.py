from pydantic import BaseModel, Field
from typing import Optional, List
from enum import IntEnum


class Macronutrients(BaseModel):
    protein: float = Field(..., ge=0, description="蛋白质(g)")
    fat: float = Field(..., ge=0, description="脂肪(g)")
    carbohydrates: float = Field(..., ge=0, description="碳水化合物(g)")
    dietary_fiber: float = Field(..., ge=0, description="膳食纤维(g)")
    sugar: float = Field(..., ge=0, description="糖(g)")


class VitaminsMinerals(BaseModel):
    vitamin_a: float = Field(..., ge=0, description="维生素A(μg)")
    vitamin_c: float = Field(..., ge=0, description="维生素C(mg)")
    vitamin_d: float = Field(..., ge=0, description="维生素D(μg)")
    calcium: float = Field(..., ge=0, description="钙(mg)")
    iron: float = Field(..., ge=0, description="铁(mg)")
    sodium: float = Field(..., ge=0, description="钠(mg)")
    potassium: float = Field(..., ge=0, description="钾(mg)")
    cholesterol: float = Field(..., ge=0, description="胆固醇(mg)")


class HealthLevelEnum(IntEnum):
    E = 1
    D = 2
    C = 3
    B = 4
    A = 5


class NutritionFacts(BaseModel):
    food_items: List[str]
    total_calories: float
    macronutrients: Macronutrients
    vitamins_minerals: VitaminsMinerals
    health_level: HealthLevelEnum = Field(..., description="健康等级：A最优，B良好，C一般，D较差，E很差")


class Recommendations(BaseModel):
    recommendations: List[str]
    dietary_tips: List[str]
    warnings: List[str]
    alternative_foods: List[str]


class AgentAnalysisData(BaseModel):
    current_step: str
    image_description: Optional[str]
    nutrition_facts: Optional[NutritionFacts]
    recommendations: Optional[Recommendations]


class AdviceDependencies(BaseModel):
    nutrition_facts: List[str] = Field(default_factory=list, description="相关营养知识要点")
    health_guidelines: List[str] = Field(default_factory=list, description="健康指南建议")
    food_interactions: List[str] = Field(default_factory=list, description="食物之间的相互作用")