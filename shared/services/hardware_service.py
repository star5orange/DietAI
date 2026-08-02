import logging
from sqlalchemy.orm import Session
from sqlalchemy import func
from shared.models.pet_models import HardwareQuickButton, OfflineSyncLog
from shared.models.water_models import WaterIntakeRecord
from shared.models.food_models import FoodRecord
from shared.models.user_models import UserProfile
from shared.models.schemas.water import WaterIntakeCreate
from shared.services.water_service import create_water_record
from shared.services.pet_service import update_streak
from datetime import datetime, date, timedelta
from typing import List, Optional

logger = logging.getLogger(__name__)

# Default quick button configuration
DEFAULT_BUTTONS = [
    {"index": 0, "type": "water", "label": "💧 饮水", "amount_ml": 250},
    {"index": 1, "type": "meal", "label": "🌅 早餐", "meal_type": "breakfast"},
    {"index": 2, "type": "meal", "label": "☀️ 午餐", "meal_type": "lunch"},
    {"index": 3, "type": "meal", "label": "🌙 晚餐", "meal_type": "dinner"},
    {"index": 4, "type": "food", "label": "🥚 鸡蛋", "food_name": "鸡蛋", "calories": 78, "protein": 6.3, "amount": 1},
    {"index": 5, "type": "food", "label": "🍚 米饭", "food_name": "米饭", "calories": 116, "protein": 2.6, "amount": 1},
]

# Personalized food suggestions based on crowd_tag
CROWD_FOOD_MAP = {
    "减脂": [
        {"label": "🥚 鸡蛋", "food_name": "鸡蛋", "calories": 78, "protein": 6.3, "amount": 1},
        {"label": "🥦 西兰花花", "food_name": "西兰花", "calories": 34, "protein": 2.8, "amount": 1},
        {"label": "🍗 鸡胸肉", "food_name": "鸡胸肉", "calories": 133, "protein": 25.0, "amount": 1},
    ],
    "健身": [
        {"label": "🥩 牛肉", "food_name": "牛肉", "calories": 250, "protein": 26.0, "amount": 1},
        {"label": "🍌 香蕉", "food_name": "香蕉", "calories": 89, "protein": 1.1, "amount": 1},
        {"label": "🥛 牛奶", "food_name": "牛奶", "calories": 42, "protein": 3.4, "amount": 1},
    ],
}

def get_quick_buttons(db: Session, user_id: int) -> dict:
    """Get quick button config for hardware, auto-generate if not exists"""
    buttons = db.query(HardwareQuickButton).filter(
        HardwareQuickButton.user_id == user_id
    ).order_by(HardwareQuickButton.button_index).all()

    if not buttons:
        buttons = _generate_default_buttons(db, user_id)

    return {
        "user_id": user_id,
        "buttons": [
            {
                "index": b.button_index,
                "type": b.button_type,
                "label": b.label,
                "amount_ml": b.amount_ml,
                "meal_type": b.meal_type,
                "food_name": b.food_name,
                "calories": b.calories,
                "protein": float(b.protein) if b.protein else None,
                "amount": b.amount,
            }
            for b in buttons
        ]
    }

def _generate_default_buttons(db: Session, user_id: int) -> list:
    """Generate default quick buttons based on user profile"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    crowd_tag = profile.crowd_tag if profile and profile.crowd_tag else None

    # Buttons 0-3 are always the same (water + 3 meals)
    buttons = []
    for i in range(4):
        d = DEFAULT_BUTTONS[i]
        btn = HardwareQuickButton(user_id=user_id, button_index=d["index"], button_type=d["type"], label=d["label"],
                                   amount_ml=d.get("amount_ml"), meal_type=d.get("meal_type"))
        buttons.append(btn)
        db.add(btn)

    # Buttons 4-5 are personalized
    custom_foods = CROWD_FOOD_MAP.get(crowd_tag, [
        {"label": "🥚 鸡蛋", "food_name": "鸡蛋", "calories": 78, "protein": 6.3, "amount": 1},
        {"label": "🍚 米饭", "food_name": "米饭", "calories": 116, "protein": 2.6, "amount": 1},
    ])

    for idx, food in enumerate(custom_foods[:2]):
        from decimal import Decimal
        btn = HardwareQuickButton(
            user_id=user_id, button_index=4 + idx, button_type="food", label=food["label"],
            food_name=food["food_name"], calories=food["calories"],
            protein=Decimal(str(food["protein"])), amount=food["amount"]
        )
        buttons.append(btn)
        db.add(btn)

    db.commit()
    for b in buttons:
        db.refresh(b)
    return buttons

def sync_offline_records(db: Session, user_id: int, records: List[dict]) -> dict:
    """Sync offline records from hardware device"""
    synced = 0
    failed = 0
    details = []

    for record in records:
        try:
            record_type = record.get("type")
            timestamp_str = record.get("timestamp")
            timestamp = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00")) if timestamp_str else datetime.now()

            if record_type == "water":
                amount_ml = record.get("amount_ml", 250)
                water_create = WaterIntakeCreate(amount_ml=amount_ml, record_time=timestamp, drink_type="水")
                create_water_record(db, user_id, water_create)
                synced += 1
                details.append({"type": "water", "status": "ok"})

            elif record_type == "food":
                food_name = record.get("food_name", "未知食物")
                meal_type = record.get("meal_type", 1)
                # Create a simple food record via traditional endpoint
                from shared.models.food_models import NutritionDetail
                from decimal import Decimal

                food_record = FoodRecord(
                    user_id=user_id,
                    record_date=timestamp.date() if hasattr(timestamp, 'date') else date.today(),
                    record_time=timestamp,
                    meal_type=meal_type,
                    food_name=food_name,
                    recording_method=1,
                    analysis_status=3,
                    from_source="hardware",
                )
                db.add(food_record)
                db.flush()

                nutrition = NutritionDetail(
                    food_record_id=food_record.id,
                    calories=Decimal(str(record.get("calories", 0))),
                    protein=Decimal(str(record.get("protein", 0))),
                )
                db.add(nutrition)
                db.commit()
                synced += 1
                details.append({"type": "food", "status": "ok"})
            else:
                failed += 1
                details.append({"type": record_type, "status": "unknown_type"})
        except Exception as e:
            logger.error(f"Failed to sync record: {e}")
            failed += 1
            details.append({"type": record.get("type", "unknown"), "status": "error", "error": str(e)})

    # Update streak
    try:
        update_streak(db, user_id)
    except Exception:
        pass

    # Log sync
    log = OfflineSyncLog(
        user_id=user_id, target_type="human",
        sync_type="batch", payload={"synced": synced, "failed": failed, "details": details}
    )
    db.add(log)
    db.commit()

    return {"synced": synced, "failed": failed}


# ============================================================
# M3: 真实宠物硬件同步
# ============================================================

def sync_pet_feeding(db: Session, data: dict) -> dict:
    """硬件投粮后同步：写入宠物饮食记录并更新每日汇总"""
    from shared.models.pet_models import PetFeedingRecord
    from datetime import datetime

    record = PetFeedingRecord(
        pet_id=data["pet_id"],
        food_name=data.get("food_name", "未知食物"),
        amount_grams=data.get("amount_grams"),
        calories=data.get("calories"),
        protein=data.get("protein"),
        fat=data.get("fat"),
        carbs=data.get("carbs"),
        record_time=datetime.fromisoformat(data["timestamp"]) if data.get("timestamp") else datetime.utcnow(),
        from_source="hardware",
    )
    db.add(record)
    db.flush()

    # 更新每日汇总
    try:
        from shared.services.real_pet_service import _upsert_pet_daily_summary
        _upsert_pet_daily_summary(db, data["pet_id"], record.record_time.date())
    except Exception:
        pass

    db.commit()
    db.refresh(record)
    return {"id": record.id, "type": "feeding", "status": "ok"}


def sync_pet_water(db: Session, data: dict) -> dict:
    """硬件放水后同步：写入宠物饮水记录并更新每日汇总"""
    from shared.models.pet_models import PetWaterRecord
    from datetime import datetime

    record = PetWaterRecord(
        pet_id=data["pet_id"],
        amount_ml=data.get("amount_ml", 0),
        record_time=datetime.fromisoformat(data["timestamp"]) if data.get("timestamp") else datetime.utcnow(),
        from_source="hardware",
    )
    db.add(record)
    db.flush()

    try:
        from shared.services.real_pet_service import _upsert_pet_daily_summary
        _upsert_pet_daily_summary(db, data["pet_id"], record.record_time.date())
    except Exception:
        pass

    db.commit()
    db.refresh(record)
    return {"id": record.id, "type": "water", "status": "ok"}


def get_pet_quick_buttons(db: Session, user_id: int) -> dict:
    """获取宠物专用快捷按钮"""
    from shared.models.pet_models import PetProfile, HardwareQuickButton
    pets = db.query(PetProfile).filter(
        PetProfile.user_id == user_id, PetProfile.is_active.is_(True)
    ).all()
    buttons = db.query(HardwareQuickButton).filter(
        HardwareQuickButton.user_id == user_id,
        HardwareQuickButton.pet_id.isnot(None)
    ).order_by(HardwareQuickButton.button_index).all()

    return {
        "user_id": user_id,
        "pets": [{"id": p.id, "name": p.name, "species": p.species} for p in pets],
        "buttons": [{
            "button_index": b.button_index, "button_type": b.button_type,
            "label": b.label, "pet_id": b.pet_id,
            "food_name": b.food_name, "calories": float(b.calories) if b.calories else None,
        } for b in buttons],
    }


def get_pet_feeding_plan_for_hardware(db: Session, pet_id: int) -> dict:
    """硬件查询当日喂食计划"""
    from shared.services.real_pet_service import get_feeding_plan, get_pet
    pet = get_pet(db, pet_id, None)  # 硬件调用不走用户验证
    if not pet:
        return {"error": "宠物不存在"}
    return get_feeding_plan(db, pet_id, pet.user_id)
>>>>>>> origin/frontend
