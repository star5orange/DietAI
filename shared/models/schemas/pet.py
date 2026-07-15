from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class PetStateResponse(BaseModel):
    mood: str
    level: int
    exp: int
    exp_to_next: int
    current_skin: str
    unlocked_skins: List[str]
    habit_score: int
    last_interact_at: Optional[datetime] = None
    streak_days: int
    pet_type: str
    pet_name: str
    is_visible: bool


class PetStatusForDevice(BaseModel):
    """Simplified pet status for hardware polling"""
    mood: str
    level: int
    skin: str
    version: int
    has_new_unlock: bool


class PetInteractRequest(BaseModel):
    action: str = Field(..., pattern="^(feed|play|pet|train)$", description="Interaction action")
    item_id: Optional[str] = Field(None, description="Optional item ID for feed action")


class PetInteractResponse(BaseModel):
    mood: str
    exp_gained: int
    feedback_text: str
    new_unlock: Optional[dict] = None


class PetRenameRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=20, description="New pet name")


class PetTypeChangeRequest(BaseModel):
    pet_type: str = Field(..., pattern="^(cat|dog|rabbit|bear)$", description="Pet type")


class PetVisibilityRequest(BaseModel):
    is_visible: bool


class UnlockableItem(BaseModel):
    unlock_type: str
    unlock_key: str
    name: str
    description: Optional[str] = None
    required_level: Optional[int] = None
    required_streak: Optional[int] = None
    is_unlocked: bool
    progress: Optional[dict] = None


class UnlockablesResponse(BaseModel):
    unlockables: List[UnlockableItem]


class UnlockRequest(BaseModel):
    unlock_type: str
    unlock_key: str
