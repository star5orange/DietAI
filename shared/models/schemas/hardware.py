from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class QuickButton(BaseModel):
    index: int
    type: str  # water/meal/food
    label: str
    amount_ml: Optional[int] = None
    meal_type: Optional[str] = None
    food_name: Optional[str] = None
    calories: Optional[int] = None
    protein: Optional[float] = None
    amount: Optional[int] = None


class QuickButtonsResponse(BaseModel):
    user_id: int
    buttons: List[QuickButton]


class OfflineWaterRecord(BaseModel):
    type: str = Field("water", literal="water")
    amount_ml: int = Field(..., gt=0)
    timestamp: datetime


class OfflineFoodRecord(BaseModel):
    type: str = Field("food", literal="food")
    food_name: str
    calories: int = 0
    protein: float = 0
    meal_type: Optional[int] = Field(None, ge=1, le=5, description="1-5: breakfast/lunch/dinner/snack/supper")
    timestamp: datetime


class OfflineSyncRequest(BaseModel):
    user_id: int
    records: List[dict]  # Each dict has "type": "water" or "food" plus corresponding fields


class OfflineSyncResponse(BaseModel):
    synced: int
    failed: int
