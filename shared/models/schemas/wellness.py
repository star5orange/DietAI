from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional


class WellnessKnowledgeOut(BaseModel):
    id: int
    category: str
    sub_category: Optional[str]
    title: str
    content: str
    recommended_foods: Optional[list]
    avoid_foods: Optional[list]
    applicable_constitutions: Optional[list]
    season: Optional[str]
    solar_term: Optional[str]

    class Config:
        from_attributes = True


class DailyWellnessRecommendation(BaseModel):
    current_solar_term: str
    current_season: str
    constitution_type: Optional[str]
    recommended_ingredients: list[str]
    recommended_recipes: list[dict]  # [{"name": "...", "description": "...", "benefits": "..."}, ...]
    wellness_tips: list[str]
    foods_to_avoid: list[str]


class SolarTermOut(BaseModel):
    name: str
    date: str
    description: Optional[str]
    is_current: bool = False