"""
宠物数据工具 - 从数据库查询宠物档案、体重趋势、饮食记录

供 DietDeepAgent 和宠物健康相关 Skill 使用。
"""

import logging
from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import Any

from langchain_core.tools import tool
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def _get_db_session() -> Session:
    """获取数据库会话"""
    from shared.models.database import SessionLocal
    return SessionLocal()


# ==================== 品种营养标准（业务常量） ====================
# 每公斤体重每日需求，品种级校准

_BREED_NUTRITION_STANDARDS: dict[str, dict] = {
    "cat": {
        "default": {"calories_per_kg": 50, "protein_per_kg": 4.0, "fat_per_kg": 2.0},
        "橘猫": {"calories_per_kg": 55, "protein_per_kg": 4.5, "fat_per_kg": 2.2},
        "英短": {"calories_per_kg": 45, "protein_per_kg": 4.0, "fat_per_kg": 1.8},
        "布偶": {"calories_per_kg": 48, "protein_per_kg": 4.2, "fat_per_kg": 2.0},
        "暹罗": {"calories_per_kg": 55, "protein_per_kg": 4.5, "fat_per_kg": 2.2},
    },
    "dog": {
        "default": {"calories_per_kg": 40, "protein_per_kg": 3.0, "fat_per_kg": 1.5},
        "泰迪": {"calories_per_kg": 42, "protein_per_kg": 3.2, "fat_per_kg": 1.6},
        "柯基": {"calories_per_kg": 38, "protein_per_kg": 2.8, "fat_per_kg": 1.4},
        "金毛": {"calories_per_kg": 35, "protein_per_kg": 2.5, "fat_per_kg": 1.2},
    },
}


def _get_pet_latest_weight(db: Session, pet_id: int) -> float | None:
    """获取宠物最新体重记录"""
    from shared.models.pet_models import PetWeightRecord
    record = (
        db.query(PetWeightRecord.weight)
        .filter(PetWeightRecord.pet_id == pet_id)
        .order_by(PetWeightRecord.measured_at.desc())
        .first()
    )
    return float(record.weight) if record and record.weight else None


def _build_pet_dict(pet: Any, db: Session = None) -> dict[str, Any]:
    """将 PetProfile ORM 对象转为字典"""
    weight = None
    if db is not None:
        weight = _get_pet_latest_weight(db, pet.id)
    return {
        "id": pet.id,
        "user_id": pet.user_id,
        "name": pet.name,
        "species": pet.species,
        "breed": pet.breed or "",
        "gender": pet.gender or "male",
        "birth_date": pet.birth_date.isoformat() if pet.birth_date else "",
        "is_neutered": pet.is_neutered or False,
        "weight_kg": weight,
        "avatar_url": pet.avatar_url or "",
    }


def _compute_age(birth_date_val: Any) -> int:
    """根据出生日期计算年龄"""
    if not birth_date_val:
        return 0
    if isinstance(birth_date_val, str):
        birth_date_val = date.fromisoformat(birth_date_val)
    return (date.today() - birth_date_val).days // 365


# ==================== 工具函数 ====================


@tool
def get_pet_profile(pet_id: int) -> dict[str, Any]:
    """获取宠物档案，包含基本信息、品种、年龄、体重等。

    Args:
        pet_id: 宠物 ID

    Returns:
        宠物档案字典，包含 name, species, breed, age, weight_kg 等
    """
    from shared.models.pet_models import PetProfile

    db = _get_db_session()
    try:
        pet = db.query(PetProfile).filter(
            PetProfile.id == pet_id,
            PetProfile.is_active == True,
        ).first()

        if not pet:
            return {"error": f"宠物 {pet_id} 不存在", "found": False}

        age = _compute_age(pet.birth_date)
        weight = _get_pet_latest_weight(db, pet_id)

        return {
            "found": True,
            "pet_id": pet_id,
            "name": pet.name or "",
            "species": pet.species or "",
            "breed": pet.breed or "",
            "gender": pet.gender or "male",
            "age": age,
            "is_neutered": pet.is_neutered or False,
            "weight_kg": weight or 0,
            "avatar_url": pet.avatar_url or "",
            "user_id": pet.user_id,
        }
    except Exception as e:
        logger.error(f"查询宠物档案失败: {e}")
        return {"error": str(e), "found": False}
    finally:
        db.close()


@tool
def get_user_pets(user_id: int) -> dict[str, Any]:
    """获取用户的所有宠物列表。

    Args:
        user_id: 用户 ID

    Returns:
        宠物列表
    """
    from shared.models.pet_models import PetProfile

    db = _get_db_session()
    try:
        pets = db.query(PetProfile).filter(
            PetProfile.user_id == user_id,
            PetProfile.is_active == True,
        ).order_by(PetProfile.created_at.desc()).all()

        pet_list = [
            {
                "id": pet.id,
                "name": pet.name,
                "species": pet.species,
                "breed": pet.breed or "",
                "weight_kg": _get_pet_latest_weight(db, pet.id),
                "avatar_url": pet.avatar_url or "",
            }
            for pet in pets
        ]

        return {
            "found": True,
            "count": len(pet_list),
            "pets": pet_list,
        }
    except Exception as e:
        logger.error(f"查询用户宠物列表失败: {e}")
        return {"error": str(e), "found": False, "pets": []}
    finally:
        db.close()


@tool
def get_pet_weight_trend(pet_id: int, days: int = 30) -> dict[str, Any]:
    """获取宠物体重趋势记录。

    Args:
        pet_id: 宠物 ID
        days: 查询天数（默认 30 天）

    Returns:
        体重趋势数据，包含记录列表和变化分析
    """
    from shared.models.pet_models import PetWeightRecord

    db = _get_db_session()
    try:
        cutoff = datetime.utcnow() - timedelta(days=days)
        records = db.query(PetWeightRecord).filter(
            PetWeightRecord.pet_id == pet_id,
            PetWeightRecord.measured_at >= cutoff,
        ).order_by(PetWeightRecord.measured_at.asc()).all()

        if not records:
            return {"error": f"宠物 {pet_id} 暂无比重记录", "pet_id": pet_id}

        weights_data = [
            {
                "date": r.measured_at.strftime("%Y-%m-%d"),
                "weight": float(r.weight) if r.weight else 0,
                "notes": r.notes or "",
            }
            for r in records
        ]

        weights = [d["weight"] for d in weights_data]
        weight_change = weights[-1] - weights[0] if len(weights) >= 2 else 0

        return {
            "pet_id": pet_id,
            "period_days": days,
            "records": weights_data,
            "latest_weight_kg": weights[-1],
            "weight_change_kg": round(weight_change, 2),
            "trend": "增加" if weight_change > 0 else "减少" if weight_change < 0 else "稳定",
        }
    except Exception as e:
        logger.error(f"查询体重趋势失败: {e}")
        return {"error": str(e), "pet_id": pet_id}
    finally:
        db.close()


@tool
def get_pet_feeding_records(pet_id: int, days: int = 7) -> dict[str, Any]:
    """获取宠物饮食记录。

    Args:
        pet_id: 宠物 ID
        days: 查询天数（默认 7 天）

    Returns:
        饮食记录，包含每日摄入和营养汇总
    """
    from shared.models.pet_models import PetFeedingRecord

    db = _get_db_session()
    try:
        cutoff = datetime.utcnow() - timedelta(days=days)
        records = db.query(PetFeedingRecord).filter(
            PetFeedingRecord.pet_id == pet_id,
            PetFeedingRecord.record_time >= cutoff,
        ).order_by(PetFeedingRecord.record_time.desc()).all()

        feeding_list = []
        total_calories = 0.0
        total_protein = 0.0
        total_fat = 0.0
        total_carbs = 0.0

        for r in records:
            cal = float(r.calories) if r.calories else 0
            pro = float(r.protein) if r.protein else 0
            fat = float(r.fat) if r.fat else 0
            carbs = float(r.carbs) if r.carbs else 0

            feeding_list.append({
                "date": r.record_time.strftime("%Y-%m-%d"),
                "time": r.record_time.strftime("%H:%M"),
                "food_name": r.food_name or "",
                "amount_grams": float(r.amount_grams) if r.amount_grams else 0,
                "calories": cal,
                "protein": pro,
                "fat": fat,
                "carbs": carbs,
                "source": r.from_source or "manual",
            })
            total_calories += cal
            total_protein += pro
            total_fat += fat
            total_carbs += carbs

        return {
            "pet_id": pet_id,
            "period_days": days,
            "records": feeding_list,
            "daily_summary": {
                "total_calories": round(total_calories),
                "total_protein": round(total_protein, 1),
                "total_fat": round(total_fat, 1),
                "total_carbs": round(total_carbs, 1),
                "meal_count": len(feeding_list),
            },
        }
    except Exception as e:
        logger.error(f"查询饮食记录失败: {e}")
        return {"error": str(e), "pet_id": pet_id, "records": []}
    finally:
        db.close()


@tool
def calculate_pet_nutrition_target(pet_id: int) -> dict[str, Any]:
    """根据宠物品种、体重、年龄计算每日营养目标。

    Args:
        pet_id: 宠物 ID

    Returns:
        每日营养目标，包含热量、蛋白质、脂肪目标
    """
    from shared.models.pet_models import PetProfile

    db = _get_db_session()
    try:
        pet = db.query(PetProfile).filter(
            PetProfile.id == pet_id,
            PetProfile.is_active == True,
        ).first()

        if not pet:
            return {"error": f"宠物 {pet_id} 不存在"}

        weight = _get_pet_latest_weight(db, pet_id)
        if weight is None:
            return {"error": f"宠物 {pet.name} 体重未设置，无法计算营养目标"}

        species = pet.species or "cat"
        breed = pet.breed or ""
        weight = float(weight)

        # 获取品种营养标准
        species_standards = _BREED_NUTRITION_STANDARDS.get(species.lower(), {})
        standard = species_standards.get(breed, species_standards.get("default", {}))

        calories_per_kg = standard.get("calories_per_kg", 50)
        protein_per_kg = standard.get("protein_per_kg", 4.0)
        fat_per_kg = standard.get("fat_per_kg", 2.0)

        # 绝育调整（减少10-15%热量需求）
        if pet.is_neutered:
            calories_per_kg = round(calories_per_kg * 0.85)

        target_calories = round(weight * calories_per_kg)
        target_protein = round(weight * protein_per_kg, 1)
        target_fat = round(weight * fat_per_kg, 1)
        ideal_weight_min = round(weight * 0.85, 1)
        ideal_weight_max = round(weight * 1.15, 1)

        return {
            "pet_id": pet_id,
            "pet_name": pet.name,
            "species": species,
            "breed": breed,
            "current_weight_kg": weight,
            "is_neutered": pet.is_neutered or False,
            "ideal_weight_range": {"min": ideal_weight_min, "max": ideal_weight_max},
            "daily_targets": {
                "calories_kcal": target_calories,
                "protein_g": target_protein,
                "fat_g": target_fat,
            },
            "calculation_basis": f"基于{breed or species}标准：每公斤体重 {calories_per_kg} kcal/天"
            + ("（已按绝育状态调整）" if pet.is_neutered else ""),
        }
    except Exception as e:
        logger.error(f"计算营养目标失败: {e}")
        return {"error": str(e)}
    finally:
        db.close()


@tool
def get_pet_daily_summary(pet_id: int, days: int = 7) -> dict[str, Any]:
    """获取宠物每日营养汇总（聚合视图）。

    将喂食记录按天聚合为每日热量/蛋白质/脂肪总计。

    Args:
        pet_id: 宠物 ID
        days: 汇总天数，默认7天

    Returns:
        每日营养汇总列表和数据统计
    """
    from shared.models.pet_models import PetProfile, PetFeedingRecord

    db = _get_db_session()
    try:
        pet = db.query(PetProfile).filter(
            PetProfile.id == pet_id,
            PetProfile.is_active == True,
        ).first()

        if not pet:
            return {"error": f"宠物 {pet_id} 不存在"}

        cutoff = datetime.utcnow() - timedelta(days=days)
        records = db.query(PetFeedingRecord).filter(
            PetFeedingRecord.pet_id == pet_id,
            PetFeedingRecord.record_time >= cutoff,
        ).all()

        # 按天聚合
        daily_totals: dict[str, dict] = defaultdict(
            lambda: {"calories": 0.0, "protein": 0.0, "fat": 0.0, "meals": 0}
        )

        for r in records:
            day = r.record_time.strftime("%Y-%m-%d")
            daily_totals[day]["calories"] += float(r.calories or 0)
            daily_totals[day]["protein"] += float(r.protein or 0)
            daily_totals[day]["fat"] += float(r.fat or 0)
            daily_totals[day]["meals"] += 1

        daily_summaries = [
            {
                "date": day,
                "total_calories": round(data["calories"]),
                "total_protein": round(data["protein"], 1),
                "total_fat": round(data["fat"], 1),
                "meal_count": data["meals"],
            }
            for day, data in sorted(daily_totals.items())[-days:]
        ]

        # 营养目标
        target = calculate_pet_nutrition_target(pet_id)
        target_cal = target.get("daily_targets", {}).get("calories_kcal", 0)

        total_calories = sum(s["total_calories"] for s in daily_summaries)
        avg_calories = total_calories / len(daily_summaries) if daily_summaries else 0
        on_target_days = sum(
            1 for s in daily_summaries
            if target_cal > 0 and 0.85 <= s["total_calories"] / target_cal <= 1.15
        )

        return {
            "pet_id": pet_id,
            "pet_name": pet.name or "",
            "days": len(daily_summaries),
            "daily_summaries": daily_summaries,
            "stats": {
                "total_calories": round(total_calories),
                "avg_calories_per_day": round(avg_calories),
                "target_calories_per_day": target_cal,
                "on_target_days": on_target_days,
                "on_target_rate": round(on_target_days / len(daily_summaries) * 100) if daily_summaries else 0,
            },
        }
    except Exception as e:
        logger.error(f"查询每日汇总失败: {e}")
        return {"error": str(e)}
    finally:
        db.close()
