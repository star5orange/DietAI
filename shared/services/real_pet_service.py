"""M3 真实宠物健康管理业务逻辑"""
import logging
import os
import random
from datetime import date, datetime, timedelta
from typing import Optional, Dict, Any, List

import httpx
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from shared.models.pet_models import (
    PetProfile, PetWeightRecord, PetVaccineRecord, PetDewormingRecord,
    PetFeedingRecord, PetWaterRecord, PetDailySummary, PetAvatar,
    PetFoodDatabase,
)
from shared.config.settings import get_settings

# 加载 .env 文件，使 os.getenv 可读取 DASHSCOPE_API_KEY 等变量
load_dotenv(".env", override=True, encoding="utf-8")
load_dotenv(".env.dev", override=True, encoding="utf-8")

logger = logging.getLogger(__name__)

# DashScope 通义万相 API 配置
WANX_CREATE_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
WANX_TASK_URL = "https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
# 使用Settings类读取API Key
_settings = get_settings()
DASHSCOPE_API_KEY = _settings.dashscope_api_key or os.getenv("DASHSCOPE_API_KEY", "")

# ============================================================
# 品种数据（兜底用）
# ============================================================

BREED_INFO = {
    "英国短毛猫": {"species": "cat", "avg_weight": 5.0, "daily_cal_per_kg": 50},
    "布偶猫": {"species": "cat", "avg_weight": 6.2, "daily_cal_per_kg": 45},
    "暹罗猫": {"species": "cat", "avg_weight": 4.0, "daily_cal_per_kg": 55},
    "中华田园猫": {"species": "cat", "avg_weight": 4.5, "daily_cal_per_kg": 50},
    "橘猫": {"species": "cat", "avg_weight": 5.5, "daily_cal_per_kg": 48},
    "美短": {"species": "cat", "avg_weight": 5.0, "daily_cal_per_kg": 50},
    "波斯猫": {"species": "cat", "avg_weight": 4.5, "daily_cal_per_kg": 45},
    "无毛猫": {"species": "cat", "avg_weight": 3.5, "daily_cal_per_kg": 60},
    "泰迪": {"species": "dog", "avg_weight": 4.0, "daily_cal_per_kg": 55},
    "柯基": {"species": "dog", "avg_weight": 12.0, "daily_cal_per_kg": 40},
    "金毛": {"species": "dog", "avg_weight": 30.0, "daily_cal_per_kg": 35},
    "柴犬": {"species": "dog", "avg_weight": 10.0, "daily_cal_per_kg": 45},
    "哈士奇": {"species": "dog", "avg_weight": 22.0, "daily_cal_per_kg": 40},
}

PRESET_AVATARS = {
    "cat": {
        "英短": "https://placehold.co/400x400/BBDEFB/1565C0?text=British+Shorthair",
        "布偶": "https://placehold.co/400x400/E1BEE7/7B1FA2?text=Ragdoll",
        "暹罗": "https://placehold.co/400x400/FFE0B2/E65100?text=Siamese",
        "橘猫": "https://placehold.co/400x400/FFCC80/EF6C00?text=Orange+Cat",
        "default": "https://placehold.co/400x400/E8EAF6/3949AB?text=Cat",
    },
    "dog": {
        "泰迪": "https://placehold.co/400x400/F8BBD0/C2185B?text=Poodle",
        "柯基": "https://placehold.co/400x400/FFCC80/EF6C00?text=Corgi",
        "金毛": "https://placehold.co/400x400/FFE082/F57F17?text=Golden",
        "default": "https://placehold.co/400x400/E8EAF6/3949AB?text=Dog",
    },
}


# ============================================================
# 宠物档案 CRUD
# ============================================================

def create_pet(db: Session, user_id: int, data: dict) -> PetProfile:
    """创建宠物档案"""
    pet = PetProfile(user_id=user_id, **data)
    db.add(pet)
    db.commit()
    db.refresh(pet)
    return pet


def get_pets(db: Session, user_id: int) -> List[PetProfile]:
    return db.query(PetProfile).filter(
        PetProfile.user_id == user_id,
        PetProfile.is_active.is_(True)
    ).order_by(PetProfile.created_at).all()


def get_pet(db: Session, pet_id: int, user_id: int) -> Optional[PetProfile]:
    return db.query(PetProfile).filter(
        PetProfile.id == pet_id,
        PetProfile.user_id == user_id,
        PetProfile.is_active.is_(True)
    ).first()


def update_pet(db: Session, pet_id: int, user_id: int, data: dict) -> PetProfile:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    for k, v in data.items():
        if v is not None:
            setattr(pet, k, v)
    db.commit()
    db.refresh(pet)
    return pet


def delete_pet(db: Session, pet_id: int, user_id: int):
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    pet.is_active = False
    db.commit()


# ============================================================
# 体重记录
# ============================================================

def add_weight(db: Session, pet_id: int, user_id: int, data: dict) -> PetWeightRecord:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = PetWeightRecord(pet_id=pet_id, **data)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def get_weight_records(db: Session, pet_id: int, user_id: int) -> List[PetWeightRecord]:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    return db.query(PetWeightRecord).filter(
        PetWeightRecord.pet_id == pet_id
    ).order_by(PetWeightRecord.measured_at.desc()).limit(100).all()


def get_weight_trend(db: Session, pet_id: int, user_id: int, days: int = 30) -> dict:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    start = date.today() - timedelta(days=days - 1)
    records = db.query(PetWeightRecord).filter(
        PetWeightRecord.pet_id == pet_id,
        func.date(PetWeightRecord.measured_at) >= start
    ).order_by(PetWeightRecord.measured_at).all()

    chart = [{"date": r.measured_at.isoformat() if hasattr(r.measured_at, 'isoformat') else str(r.measured_at),
              "weight": float(r.weight)} for r in records]

    # 品种标准体重
    info = BREED_INFO.get(pet.breed or "", {})
    ideal_min = float(info.get("avg_weight", 5)) * 0.85
    ideal_max = float(info.get("avg_weight", 5)) * 1.15

    return {
        "pet_id": pet_id,
        "days": days,
        "chart": chart,
        "ideal_range": {"min": round(ideal_min, 1), "max": round(ideal_max, 1)},
    }


def delete_weight_record(db: Session, record_id: int, pet_id: int, user_id: int):
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetWeightRecord).filter(
        PetWeightRecord.id == record_id,
        PetWeightRecord.pet_id == pet_id
    ).first()
    if not record:
        raise ValueError("体重记录不存在")
    db.delete(record)
    db.commit()


# ============================================================
# 疫苗/驱虫
# ============================================================

def add_vaccine(db: Session, pet_id: int, user_id: int, data: dict) -> PetVaccineRecord:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = PetVaccineRecord(pet_id=pet_id, **data)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def update_vaccine(db: Session, record_id: int, pet_id: int, user_id: int, data: dict) -> PetVaccineRecord:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetVaccineRecord).filter(
        PetVaccineRecord.id == record_id,
        PetVaccineRecord.pet_id == pet_id,
    ).first()
    if not record:
        raise ValueError("疫苗记录不存在")
    for k, v in data.items():
        if v is not None:
            setattr(record, k, v)
    db.commit()
    db.refresh(record)
    return record


def delete_vaccine(db: Session, record_id: int, pet_id: int, user_id: int):
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetVaccineRecord).filter(
        PetVaccineRecord.id == record_id,
        PetVaccineRecord.pet_id == pet_id,
    ).first()
    if not record:
        raise ValueError("疫苗记录不存在")
    db.delete(record)
    db.commit()


def get_due_vaccines(db: Session, user_id: int, within_days: int = 30) -> List[Dict]:
    """获取用户所有宠物即将到期/已过期的疫苗"""
    pets = db.query(PetProfile).filter(
        PetProfile.user_id == user_id,
        PetProfile.is_active.is_(True),
    ).all()
    if not pets:
        return []
    pet_ids = [p.id for p in pets]
    today = date.today()
    cutoff = today + timedelta(days=within_days)
    records = db.query(PetVaccineRecord).filter(
        PetVaccineRecord.pet_id.in_(pet_ids),
        PetVaccineRecord.next_vaccination_date.isnot(None),
        PetVaccineRecord.next_vaccination_date <= cutoff,
    ).order_by(PetVaccineRecord.next_vaccination_date).all()
    result = []
    for r in records:
        pet = next((p for p in pets if p.id == r.pet_id), None)
        days_left = (r.next_vaccination_date - today).days
        if days_left < 0:
            status = "overdue"
            status_cn = f"已过期 {abs(days_left)} 天"
        elif days_left == 0:
            status = "today"
            status_cn = "今日到期"
        elif days_left <= 7:
            status = "urgent"
            status_cn = f"即将到期（{days_left}天）"
        else:
            status = "upcoming"
            status_cn = f"{days_left}天后到期"
        result.append({
            "id": r.id,
            "pet_id": r.pet_id,
            "pet_name": pet.name if pet else "",
            "vaccine_name": r.vaccine_name,
            "vaccinated_at": r.vaccinated_at.isoformat() if r.vaccinated_at else None,
            "next_vaccination_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else None,
            "days_left": days_left,
            "status": status,
            "status_cn": status_cn,
            "notes": r.notes,
        })
    return result


def get_vaccine_records(db: Session, pet_id: int, user_id: int) -> List[Dict]:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    records = db.query(PetVaccineRecord).filter(
        PetVaccineRecord.pet_id == pet_id
    ).order_by(PetVaccineRecord.vaccinated_at.desc()).all()
    return [_vaccine_to_dict(r) for r in records]


def add_deworming(db: Session, pet_id: int, user_id: int, data: dict) -> PetDewormingRecord:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = PetDewormingRecord(pet_id=pet_id, **data)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def get_deworming_records(db: Session, pet_id: int, user_id: int) -> List[Dict]:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    records = db.query(PetDewormingRecord).filter(
        PetDewormingRecord.pet_id == pet_id
    ).order_by(PetDewormingRecord.treated_at.desc()).all()
    return [_deworming_to_dict(r) for r in records]


def update_deworming(db: Session, record_id: int, pet_id: int, user_id: int, data: dict) -> PetDewormingRecord:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetDewormingRecord).filter(
        PetDewormingRecord.id == record_id,
        PetDewormingRecord.pet_id == pet_id,
    ).first()
    if not record:
        raise ValueError("驱虫记录不存在")
    for k, v in data.items():
        if v is not None:
            setattr(record, k, v)
    db.commit()
    db.refresh(record)
    return record


def delete_deworming(db: Session, record_id: int, pet_id: int, user_id: int):
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetDewormingRecord).filter(
        PetDewormingRecord.id == record_id,
        PetDewormingRecord.pet_id == pet_id,
    ).first()
    if not record:
        raise ValueError("驱虫记录不存在")
    db.delete(record)
    db.commit()


# ============================================================
# 饮食记录
# ============================================================

def add_feeding(db: Session, pet_id: int, data: dict) -> PetFeedingRecord:
    record = PetFeedingRecord(pet_id=pet_id, **data)
    db.add(record)
    db.flush()
    _upsert_pet_daily_summary(db, pet_id, record.record_time.date())
    db.commit()
    db.refresh(record)
    return record


def get_feeding_records(db: Session, pet_id: int, skip: int = 0, limit: int = 50) -> List[PetFeedingRecord]:
    return db.query(PetFeedingRecord).filter(
        PetFeedingRecord.pet_id == pet_id
    ).order_by(PetFeedingRecord.record_time.desc()).offset(skip).limit(limit).all()


def delete_feeding(db: Session, pet_id: int, record_id: int) -> bool:
    record = db.query(PetFeedingRecord).filter(
        PetFeedingRecord.id == record_id,
        PetFeedingRecord.pet_id == pet_id,
    ).first()
    if not record:
        return False
    target_date = record.record_time.date()
    db.delete(record)
    db.flush()
    _upsert_pet_daily_summary(db, pet_id, target_date)
    db.commit()
    return True


def get_pet_daily_summary(db: Session, pet_id: int, target_date: date) -> dict:
    summary = db.query(PetDailySummary).filter(
        PetDailySummary.pet_id == pet_id,
        PetDailySummary.summary_date == target_date
    ).first()
    if not summary:
        return {"pet_id": pet_id, "summary_date": target_date.isoformat(),
                "total_calories": 0, "total_protein": 0, "total_fat": 0,
                "total_carbs": 0, "total_water_ml": 0, "meal_count": 0}
    return {
        "pet_id": summary.pet_id, "summary_date": summary.summary_date.isoformat(),
        "total_calories": float(summary.total_calories), "total_protein": float(summary.total_protein),
        "total_fat": float(summary.total_fat), "total_carbs": float(summary.total_carbs),
        "total_water_ml": summary.total_water_ml, "meal_count": summary.meal_count,
    }


def get_feeding_plan(db: Session, pet_id: int, user_id: int) -> dict:
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    info = BREED_INFO.get(pet.breed or "", {})
    species = pet.species or "cat"

    avg_weight = float(info.get("avg_weight", 5.0)) if info else 5.0
    cal_per_kg = float(info.get("daily_cal_per_kg", 50)) if info else 50

    daily_cal = avg_weight * cal_per_kg
    meals = 2 if species == "dog" else 3

    return {
        "pet_id": pet_id, "pet_name": pet.name, "species": species,
        "breed": pet.breed,
        "daily_calories": round(daily_cal),
        "recommended_meals": meals,
        "grams_per_meal": round(daily_cal / meals / 3.8, 0),
        "suggestions": ["定时定量喂养", "保持新鲜饮水", "避免人类食物"],
    }


# ============================================================
# 饮水记录
# ============================================================

def add_water(db: Session, pet_id: int, data: dict) -> PetWaterRecord:
    record = PetWaterRecord(pet_id=pet_id, **data)
    db.add(record)
    db.flush()
    _upsert_pet_daily_summary(db, pet_id, record.record_time.date())
    db.commit()
    db.refresh(record)
    return record


def get_water_records(db: Session, pet_id: int, skip: int = 0, limit: int = 50) -> List[PetWaterRecord]:
    return db.query(PetWaterRecord).filter(
        PetWaterRecord.pet_id == pet_id
    ).order_by(PetWaterRecord.record_time.desc()).offset(skip).limit(limit).all()


def delete_water_record(db: Session, record_id: int, pet_id: int, user_id: int):
    """删除饮水记录"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    record = db.query(PetWaterRecord).filter(
        PetWaterRecord.id == record_id,
        PetWaterRecord.pet_id == pet_id
    ).first()
    if not record:
        raise ValueError("饮水记录不存在")
    db.delete(record)
    db.commit()


# ============================================================
# 宠物食品库
# ============================================================

def search_food_database(db: Session, species: Optional[str] = None,
                         category: Optional[str] = None,
                         keyword: Optional[str] = None) -> List[Dict]:
    query = db.query(PetFoodDatabase)
    if species:
        query = query.filter(PetFoodDatabase.suitable_species == species)
    if category:
        query = query.filter(PetFoodDatabase.category == category)
    if keyword:
        query = query.filter(
            PetFoodDatabase.food_name.ilike(f"%{keyword}%")
        )
    foods = query.order_by(PetFoodDatabase.food_name).limit(50).all()
    return [_food_to_dict(f) for f in foods]


# ============================================================
# AI 建议（规则兜底）
# ============================================================

def get_ai_advice(db: Session, pet_id: int, user_id: int, use_ai: bool = True) -> dict:
    """获取宠物 AI 健康建议（基于真实数据 + 可选 AI 增强）"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")

    # ---- 1. 营养目标 ----
    from shared.services.pet_nutrition_calc import (
        calculate_daily_targets, get_weekly_nutrition_analysis,
    )
    targets = calculate_daily_targets(pet)
    nutrition = get_weekly_nutrition_analysis(db, pet_id)

    # ---- 2. 体重趋势 ----
    weights = db.query(PetWeightRecord).filter(
        PetWeightRecord.pet_id == pet_id
    ).order_by(PetWeightRecord.measured_at.desc()).limit(14).all()

    weight_alert = None
    if len(weights) >= 2:
        recent = float(weights[0].weight)
        oldest = float(weights[-1].weight)
        if oldest > 0:
            change_pct = abs(recent - oldest) / oldest * 100
            if change_pct > 5:
                direction = "增长" if recent > oldest else "下降"
                weight_alert = f"近两周体重{direction}了 {change_pct:.1f}%（从 {oldest}kg → {recent}kg），建议关注宠物健康状况。"

    # 理想体重范围
    breed_info = targets
    ideal_min = round(breed_info["avg_weight_kg"] * 0.85, 1)
    ideal_max = round(breed_info["avg_weight_kg"] * 1.15, 1)
    weight_ideal = f"{ideal_min}–{ideal_max} kg"

    # ---- 3. 年龄 ----
    age_years = targets["age_years"]
    life_stage = targets["life_stage"]
    life_stage_cn = {"kitten": "幼猫", "puppy": "幼犬", "adult": "成年", "senior": "老年"}.get(life_stage, "成年")

    # ---- 4. 基于真实数据的建议生成 ----
    general_advice = [
        f"每日推荐热量约 {targets['daily_calories']} kcal，蛋白质约 {targets['daily_protein_g']}g。",
        f"当前生命阶段：{life_stage_cn}，" + ("需注意控制体重避免肥胖。" if pet.is_neutered else "保持正常喂食即可。"),
        "确保每日定时定量喂食，避免自由采食导致肥胖。",
        "保持新鲜充足的饮水，每日更换。",
        "定期进行体内外驱虫（每3-6个月一次）。",
        "每年至少进行一次体检和疫苗接种。",
    ]

    nutrition_tips = []
    avg_cal = nutrition.get("avg_calories_pct", 0)
    avg_pro = nutrition.get("avg_protein_pct", 0)

    if nutrition.get("data_days", 0) >= 3:
        if avg_cal >= 90:
            nutrition_tips.append(f"近7天热量摄入达标率 {avg_cal}%，表现优秀！")
        elif avg_cal >= 70:
            nutrition_tips.append(f"近7天热量摄入达标率 {avg_cal}%，基本达标，可适当调整。")
        else:
            nutrition_tips.append(f"近7天热量摄入仅达目标 {avg_cal}%，建议增加每日喂食量约 {targets['daily_calories'] - int(targets['daily_calories'] * avg_cal / 100)} kcal。")

        if avg_pro >= 90:
            nutrition_tips.append(f"近7天蛋白质摄入达标率 {avg_pro}%，蛋白质摄入充足。")
        elif avg_pro < 70:
            nutrition_tips.append(f"近7天蛋白质摄入不足（仅 {avg_pro}%），建议选择蛋白质含量更高的主粮或补充优质蛋白。")
    else:
        nutrition_tips.append("近7天饮食记录不足，无法生成趋势分析。请坚持每日记录宠物饮食。")

    # 营养缺口
    for gap in nutrition.get("gaps", []):
        nutrition_tips.append(gap)

    nutrition_tips.append(f"推荐选择适合{pet.species}{life_stage_cn}阶段的优质主粮。")
    nutrition_tips.append("避免喂食巧克力、洋葱、葡萄等对宠物有毒的食物。")

    # ---- 5. 尝试 AI 增强 ----
    ai_enhanced = None
    if use_ai:
        try:
            ai_enhanced = _call_ai_for_pet_advice(pet, targets, nutrition, weight_alert)
        except Exception as e:
            logger.warning(f"AI pet advice failed, using rule-based: {e}")

    advice = {
        "pet_name": pet.name,
        "breed": pet.breed or "未知品种",
        "species": pet.species,
        "age": age_years,
        "life_stage": life_stage_cn,
        "daily_targets": {
            "calories": targets["daily_calories"],
            "protein_g": targets["daily_protein_g"],
            "fat_g": targets["daily_fat_g"],
        },
        "ideal_weight_range": weight_ideal,
        "nutrition_trend": {
            "avg_calories_pct": nutrition.get("avg_calories_pct", 0),
            "avg_protein_pct": nutrition.get("avg_protein_pct", 0),
            "data_days": nutrition.get("data_days", 0),
            "trend_summary": nutrition.get("trend_summary", ""),
        },
        "weight_alert": weight_alert,
        "general_advice": general_advice,
        "nutrition_tips": nutrition_tips,
        "ai_enhanced": ai_enhanced,
        "disclaimer": "我是 AI 助手，以上建议仅供参考。宠物健康问题请咨询专业兽医。如宠物出现呕吐、腹泻、不吃不喝超24小时，请立即就医。",
    }

    return advice


def _call_ai_for_pet_advice(pet, targets: dict, nutrition: dict, weight_alert: Optional[str]) -> Optional[str]:
    """调用 AI 生成个性化宠物健康建议，失败返回 None"""
    import os
    api_key = os.environ.get("DASHSCOPE_API_KEY", "") or os.environ.get("DEEPSEEK_API_KEY", "")
    if not api_key:
        return None

    prompt = f"""你是一位专业兽医助手。请根据以下宠物数据，生成一段 150 字以内的健康建议：

宠物：{pet.name}，{pet.breed or '未知品种'}，{pet.species}
年龄：{targets['age_years']}岁（{targets['life_stage']}），绝育：{'是' if pet.is_neutered else '否'}
每日推荐：{targets['daily_calories']} kcal，蛋白质 {targets['daily_protein_g']}g
近7天营养：热量达标率 {nutrition.get('avg_calories_pct', 'N/A')}%，蛋白质达标率 {nutrition.get('avg_protein_pct', 'N/A')}%
趋势：{nutrition.get('trend_summary', '')}
体重预警：{weight_alert or '无'}

要求：基于数据给出针对性建议，语气专业温和。结尾必须加"建议仅供参考，请咨询兽医"。"""

    try:
        import requests as http_requests
        # 尝试 DeepSeek（项目已有配置）
        resp = http_requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json={"model": "deepseek-chat", "messages": [{"role": "user", "content": prompt}],
                  "max_tokens": 300, "temperature": 0.7},
            timeout=15,
        )
        if resp.status_code == 200:
            return resp.json()["choices"][0]["message"]["content"]
    except Exception:
        pass
    return None


# ============================================================
# 换粮建议
# ============================================================

def compare_pet_foods(db: Session, pet_id: int, user_id: int,
                      current_food_id: int, new_food_id: int) -> dict:
    """对比两份宠物食品并生成7天渐进过渡方案"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")

    current_food = db.query(PetFoodDatabase).filter(PetFoodDatabase.id == current_food_id).first()
    new_food = db.query(PetFoodDatabase).filter(PetFoodDatabase.id == new_food_id).first()
    if not current_food:
        raise ValueError(f"当前食品(ID={current_food_id})不存在")
    if not new_food:
        raise ValueError(f"新食品(ID={new_food_id})不存在")

    # 对比差异
    def _val(f, attr, default=0):
        return float(getattr(f, attr) or default)

    current_kcal = _val(current_food, "calories_per_100g")
    new_kcal = _val(new_food, "calories_per_100g")
    current_protein = _val(current_food, "protein_per_100g")
    new_protein = _val(new_food, "protein_per_100g")
    current_fat = _val(current_food, "fat_per_100g")
    new_fat = _val(new_food, "fat_per_100g")

    comparison = {
        "current_food": {"id": current_food.id, "name": current_food.food_name, "brand": current_food.brand,
                         "calories_per_100g": current_kcal, "protein_per_100g": current_protein, "fat_per_100g": current_fat},
        "new_food": {"id": new_food.id, "name": new_food.food_name, "brand": new_food.brand,
                     "calories_per_100g": new_kcal, "protein_per_100g": new_protein, "fat_per_100g": new_fat},
        "differences": {
            "calories_change": round(new_kcal - current_kcal, 1),
            "calories_change_pct": round((new_kcal - current_kcal) / current_kcal * 100, 1) if current_kcal > 0 else 0,
            "protein_change": round(new_protein - current_protein, 1),
            "fat_change": round(new_fat - current_fat, 1),
        },
    }

    # 7天渐进过渡方案
    transition_plan = [
        {"day": "1-2", "current_ratio": "75%", "new_ratio": "25%",
         "description": f"每餐 {current_food.food_name} 占 3/4，{new_food.food_name} 占 1/4"},
        {"day": "3-4", "current_ratio": "50%", "new_ratio": "50%",
         "description": f"每餐两种粮各一半，观察宠物粪便和精神状态"},
        {"day": "5-6", "current_ratio": "25%", "new_ratio": "75%",
         "description": f"每餐 {new_food.food_name} 占 3/4，{current_food.food_name} 占 1/4"},
        {"day": "7", "current_ratio": "0%", "new_ratio": "100%",
         "description": f"完全切换为 {new_food.food_name}，继续观察宠物适应情况"},
    ]

    # 注意事项
    warnings = [
        "换粮期间密切观察宠物粪便情况，如出现软便/腹泻，减缓过渡速度。",
        "新旧猫粮/狗粮热量不同，注意调整每日喂食总量。",
    ]
    if abs(comparison["differences"]["calories_change_pct"]) > 20:
        warnings.append(f"新旧食品热量差异较大（{comparison['differences']['calories_change_pct']}%），换粮后需按新食品的热量标准调整喂食克数。")
    if new_protein < current_protein * 0.8:
        warnings.append("新食品蛋白质含量明显降低，如宠物处于生长期需注意补充蛋白质。")
    if new_fat > current_fat * 1.5:
        warnings.append("新食品脂肪含量显著升高，肥胖/胰腺炎史宠物需谨慎。")

    return {
        "pet_id": pet_id,
        "pet_name": pet.name,
        "comparison": comparison,
        "transition_plan": transition_plan,
        "warnings": warnings,
        "disclaimer": "换粮建议仅供参考。每只宠物体质不同，换粮过程中如出现持续不适，请暂停过渡并咨询兽医。",
    }


# ============================================================
# 宠物健康评分
# ============================================================

def calculate_health_score(db: Session, pet_id: int, user_id: int) -> dict:
    """综合多维度计算宠物健康评分 0-100"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")

    from shared.services.pet_nutrition_calc import calculate_daily_targets, get_weekly_nutrition_analysis

    targets = calculate_daily_targets(pet)
    nutrition = get_weekly_nutrition_analysis(db, pet_id)

    # ---- 维度1：饮食达标率（40分） ----
    avg_cal = nutrition.get("avg_calories_pct", 0)
    avg_pro = nutrition.get("avg_protein_pct", 0)
    diet_score = min(40, round((avg_cal + avg_pro) / 2 / 100 * 40))

    # ---- 维度2：体重管理（30分） ----
    weight_score = 15  # 默认中等
    weights = db.query(PetWeightRecord).filter(
        PetWeightRecord.pet_id == pet_id
    ).order_by(PetWeightRecord.measured_at.desc()).limit(1).all()

    if weights:
        latest = float(weights[0].weight)
        ideal_min = targets["avg_weight_kg"] * 0.85
        ideal_max = targets["avg_weight_kg"] * 1.15
        if ideal_min <= latest <= ideal_max:
            weight_score = 30  # 理想范围
        elif ideal_min * 0.85 <= latest <= ideal_max * 1.15:
            weight_score = 20  # 轻微偏离
        else:
            weight_score = 10  # 明显偏离
            weight_detail = f"体重 {latest}kg 偏离理想范围（{round(ideal_min,1)}–{round(ideal_max,1)} kg）"
    else:
        weight_detail = "暂无体重记录"

    # ---- 维度3：疫苗状态（20分） ----
    from shared.models.pet_models import PetVaccineRecord
    today = date.today()
    vaccines = db.query(PetVaccineRecord).filter(
        PetVaccineRecord.pet_id == pet_id,
        PetVaccineRecord.next_vaccination_date.isnot(None)
    ).all()

    if not vaccines:
        vaccine_score = 10  # 无记录
        vaccine_detail = "暂无疫苗记录"
    else:
        all_valid = all(
            v.next_vaccination_date and v.next_vaccination_date > today
            for v in vaccines
        )
        if all_valid:
            vaccine_score = 20
            vaccine_detail = "所有疫苗在有效期内"
        else:
            expired = [v.vaccine_name for v in vaccines if v.next_vaccination_date and v.next_vaccination_date <= today]
            vaccine_score = 5 if expired else 12
            vaccine_detail = f"以下疫苗已过期或即将到期: {', '.join(expired)}" if expired else "部分疫苗临近到期"

    # ---- 维度4：活跃度（10分） ----
    recent_days_with_records = nutrition.get("data_days", 0)
    activity_score = min(10, recent_days_with_records)
    activity_detail = f"近7天有 {recent_days_with_records} 天饮食记录"

    total_score = diet_score + weight_score + vaccine_score + activity_score

    # 改进建议
    suggestions = []
    if diet_score < 30:
        suggestions.append("饮食达标率偏低，建议坚持每日定时定量喂食并记录。")
    if weight_score < 20:
        suggestions.append(weight_detail if 'weight_detail' in dir() else "建议关注体重变化，调整喂食量至理想范围。")
    if vaccine_score < 15:
        suggestions.append("建议检查疫苗接种状态，及时补种到期疫苗。")
    if activity_score < 5:
        suggestions.append("饮食记录较少，坚持记录有助于更好地监控宠物健康。")

    return {
        "pet_id": pet_id,
        "pet_name": pet.name,
        "total_score": total_score,
        "level": "优秀" if total_score >= 80 else "良好" if total_score >= 60 else "一般" if total_score >= 40 else "需关注",
        "dimensions": {
            "diet_compliance": {"score": diet_score, "max": 40, "detail": f"近7天热量达标率 {avg_cal}%，蛋白质达标率 {avg_pro}%"},
            "weight_management": {"score": weight_score, "max": 30, "detail": weight_detail if 'weight_detail' in dir() else "暂无体重记录"},
            "vaccine_status": {"score": vaccine_score, "max": 20, "detail": vaccine_detail},
            "activity": {"score": activity_score, "max": 10, "detail": activity_detail},
        },
        "suggestions": suggestions,
    }


# ============================================================
# AI 形象生成（DashScope 通义万相 API + 预设兜底）
# ============================================================

# 风格 prompt 后缀
_STYLE_PROMPTS = {
    "cartoon": "卡通风格，Q版，可爱，柔和色调",
    "anime": "动漫风格，日系，精美",
    "realistic": "写实风格，细节丰富",
}

# 情绪表情 prompt
_EMOTION_PROMPTS = {
    "happy": "开心快乐的表情，眼睛弯弯，嘴角上扬",
    "normal": "平静放松的表情，自然状态",
    "hungry": "饥饿想吃东西的表情，可怜巴巴的眼神",
    "weak": "疲惫虚弱的姿态，趴着或躺着的姿势",
}


def _build_avatar_prompt(description: str, style: str = "cartoon",
                         emotion: str = "normal") -> str:
    """构建通义万相图片生成 prompt"""
    style_suffix = _STYLE_PROMPTS.get(style, _STYLE_PROMPTS["cartoon"])
    emotion_suffix = _EMOTION_PROMPTS.get(emotion, _EMOTION_PROMPTS["normal"])
    return f"一只{description}的宠物，{style_suffix}，{emotion_suffix}，透明背景，全身照，面向镜头"


def _call_wanx_api(prompt: str, style: str = "cartoon") -> Optional[str]:
    """调用通义万相 API (wanx-v1，异步任务，带重试)"""
    if not DASHSCOPE_API_KEY:
        logger.warning("DASHSCOPE_API_KEY 未配置，无法调用通义万相")
        return None

    import time as _time
    model = _settings.dashscope_image_model or "wanx-v1"

    # 整体重试 3 次，应对间歇性 SSL 错误（requests 库在此环境比 httpx 更稳定）
    for retry in range(3):
        try:
            logger.info(f"[Wanx API] Submit attempt {retry+1}/3: model={model}, prompt={prompt[:50]}...")
            import requests as _requests
            from requests.adapters import HTTPAdapter as _HTTPAdapter
            from urllib3.util.retry import Retry as _Retry
            import urllib3 as _urllib3
            _urllib3.disable_warnings()

            _session = _requests.Session()
            _session.verify = False
            _session.trust_env = False  # 禁用系统代理，避免 ProxyError
            _session.mount("https://", _HTTPAdapter(max_retries=_Retry(total=1, backoff_factor=0.5)))

            response = _session.post(
                "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis",
                headers={
                    "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
                    "Content-Type": "application/json",
                    "X-DashScope-Async": "enable",
                },
                json={
                    "model": model,
                    "input": {"prompt": prompt},
                    "parameters": {"size": "1024*1024", "n": 1},
                },
                timeout=30,
            )

            if response.status_code != 200:
                logger.error(f"[Wanx API] Submit failed: {response.status_code} - {response.text[:200]}")
                continue  # retry

            data = response.json()
            task_id = data.get("output", {}).get("task_id", "")
            if not task_id:
                logger.error(f"[Wanx API] No task_id in response: {str(data)[:200]}")
                continue

            logger.info(f"[Wanx API] Task created: {task_id}, polling...")

            # 轮询等待任务完成（最多 2 分钟，共 40 次 * 3 秒）
            task_url = f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}"
            for attempt in range(40):
                _time.sleep(3)
                try:
                    tr = _session.get(
                        task_url,
                        headers={"Authorization": f"Bearer {DASHSCOPE_API_KEY}"},
                        timeout=15,
                    )
                    if tr.status_code != 200:
                        logger.warning(f"[Wanx API] Poll {attempt+1}: HTTP {tr.status_code}")
                        continue

                    td = tr.json()
                    task_status = td.get("output", {}).get("task_status", "")
                    logger.info(f"[Wanx API] Poll {attempt+1}: {task_status}")

                    if task_status == "SUCCEEDED":
                        results = td.get("output", {}).get("results", [])
                        if results:
                            img_url = results[0].get("url", "")
                            if img_url:
                                logger.info(f"[Wanx API] Got image URL: {img_url[:60]}...")
                                return img_url
                        logger.error(f"[Wanx API] No results in succeeded task")
                        return None
                    elif task_status == "FAILED":
                        logger.error(f"[Wanx API] Task failed: {td.get('output', {}).get('message', '')}")
                        return None
                except Exception as e:
                    logger.warning(f"[Wanx API] Poll error: {e}")

            logger.error(f"[Wanx API] Task timed out: {task_id}")
            return None

        except Exception as e:
            logger.warning(f"[Wanx API] Attempt {retry+1}/3 failed: {e}")
            if retry < 2:
                _time.sleep(2)  # 短暂等待后重试

    logger.error(f"[Wanx API] All 3 attempts failed")
    return None


def _poll_wanx_task(dashscope_task_id: str) -> Optional[str]:
    """轮询通义万相任务结果，返回图片 URL"""
    if not DASHSCOPE_API_KEY:
        return None

    url = WANX_TASK_URL.format(task_id=dashscope_task_id)
    try:
        response = httpx.get(
            url,
            headers={"Authorization": f"Bearer {DASHSCOPE_API_KEY}"},
            timeout=15.0,
        )

        if response.status_code != 200:
            logger.warning(f"通义万相任务查询失败: status={response.status_code}")
            return None

        result = response.json()
        task_status = result.get("output", {}).get("task_status", "")

        if task_status == "SUCCEEDED":
            # 提取第一张图片 URL
            results = result.get("output", {}).get("results", [])
            if results:
                img_url = results[0].get("url", "")
                logger.info(f"通义万相任务完成: {dashscope_task_id}, url={img_url[:80]}...")
                return img_url

        logger.info(f"通义万相任务状态: {dashscope_task_id} -> {task_status}")
        return None

    except Exception as e:
        logger.error(f"轮询通义万相任务失败: {e}")
        return None


def _get_preset_url(pet: PetProfile) -> str:
    """获取预设品种占位图 URL"""
    species_map = PRESET_AVATARS.get(pet.species, PRESET_AVATARS.get("cat", {}))
    return species_map.get(pet.breed, species_map.get("default",
        "https://placehold.co/400x400/FFE0B2/555555?text=Pet"))


def generate_avatar(db: Session, pet_id: int, user_id: int,
                    mode: str, photo: Optional[str] = None,
                    description: Optional[str] = None) -> str:
    """AI 生成宠物形象（异步后台执行，立即返回 task_id）

    后台线程调用通义万相 API，API 不可用时降级为预设占位图。
    前端应通过 GET /generation-tasks/{task_id} 轮询结果。
    """
    import threading
    from shared.models.database import SessionLocal

    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")

    local_task_id = f"gen_{pet_id}_{int(datetime.utcnow().timestamp())}"

    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        avatar = PetAvatar(pet_id=pet_id, status="none")
        db.add(avatar)

    avatar.status = "processing"
    avatar.error_message = None
    db.commit()

    desc = (description or "").strip()
    if not desc and photo:
        desc = f"{pet.breed or ''} {pet.species or ''}".strip()
    if not desc:
        desc = f"{pet.breed or '宠物'}"

    # 提前捕获宠物数据（原 db session 在线程中不可用）
    _pet_breed = pet.breed
    _pet_species = pet.species
    _pet_id = pet.id

    prompt = _build_avatar_prompt(desc, "cartoon", "normal")

    def _run_generation():
        """后台线程执行 AI 生成"""
        bg_db = SessionLocal()
        try:
            logger.info(f"[Avatar] Background generation started for pet_id={_pet_id}")
            img_url = _call_wanx_api(prompt, "cartoon")

            bg_avatar = bg_db.query(PetAvatar).filter(PetAvatar.pet_id == _pet_id).first()
            if not bg_avatar:
                logger.error(f"[Avatar] Avatar record not found for pet_id={_pet_id}")
                return

            if img_url:
                bg_avatar.status = "done"
                bg_avatar.base_image_url = img_url
                bg_avatar.emotion_normal_url = img_url
                bg_avatar.emotion_happy_url = img_url
                bg_avatar.emotion_hungry_url = img_url
                bg_avatar.emotion_weak_url = img_url
                bg_avatar.generation_seed = _pet_id * 10000
                bg_avatar.ai_model = _settings.dashscope_image_model or "wanx-v1"
                bg_avatar.prompt_used = desc
                bg_avatar.error_message = None
                logger.info(f"[Avatar] AI generated successfully for pet_id={_pet_id}")
            else:
                # 降级为预设占位图
                from shared.models.pet_models import PetProfile
                species_map = PRESET_AVATARS.get(_pet_species, PRESET_AVATARS.get("cat", {}))
                preset = species_map.get(_pet_breed, species_map.get("default",
                    "https://placehold.co/400x400/FFE0B2/555555?text=Pet"))

                bg_avatar.status = "done"
                bg_avatar.base_image_url = preset
                bg_avatar.emotion_happy_url = preset
                bg_avatar.emotion_normal_url = preset
                bg_avatar.emotion_hungry_url = preset
                bg_avatar.emotion_weak_url = preset
                bg_avatar.generation_seed = _pet_id * 10000
                bg_avatar.prompt_used = desc
                bg_avatar.ai_model = "preset_fallback"
                bg_avatar.error_message = None
                logger.warning(f"[Avatar] Fallback to preset for pet_id={_pet_id}")

            bg_db.commit()
        except Exception as e:
            logger.error(f"[Avatar] Generation failed for pet_id={_pet_id}: {e}")
            try:
                bg_avatar = bg_db.query(PetAvatar).filter(PetAvatar.pet_id == _pet_id).first()
                if bg_avatar:
                    bg_avatar.status = "failed"
                    bg_avatar.error_message = str(e)
                    bg_db.commit()
            except Exception:
                bg_db.rollback()
        finally:
            bg_db.close()

    thread = threading.Thread(target=_run_generation, daemon=True)
    thread.start()

    logger.info(f"[Avatar] Background task started: pet_id={_pet_id}, task_id={local_task_id}")
    return local_task_id


def get_generation_task(db: Session, task_id: str) -> dict:
    """查询生成任务状态（自动轮询 DashScope 任务）"""
    try:
        pet_id = int(task_id.split("_")[1])
    except (IndexError, ValueError):
        return {"task_id": task_id, "status": "not_found"}

    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        return {"task_id": task_id, "status": "not_found"}

    # 如果是 processing 状态且有 dashscope task_ids，尝试轮询
    if avatar.status == "processing":
        import json
        try:
            extra = json.loads(avatar.prompt_used or "{}")
            dashscope_tasks = extra.get("dashscope_tasks", {})
        except (json.JSONDecodeError, TypeError):
            dashscope_tasks = {}

        if dashscope_tasks:
            completed_count = 0
            for emotion, ds_task_id in dashscope_tasks.items():
                img_url = _poll_wanx_task(ds_task_id)
                if img_url:
                    emotion_map = {
                        "happy": "emotion_happy_url",
                        "normal": "emotion_normal_url",
                        "hungry": "emotion_hungry_url",
                        "weak": "emotion_weak_url",
                    }
                    attr = emotion_map.get(emotion)
                    if attr:
                        setattr(avatar, attr, img_url)
                        completed_count += 1

            if completed_count > 0:
                # 用 normal 情绪作为基础图
                base = avatar.emotion_normal_url or avatar.emotion_happy_url or \
                       avatar.emotion_hungry_url or avatar.emotion_weak_url
                if base:
                    avatar.base_image_url = base

                if completed_count >= len(dashscope_tasks):
                    avatar.status = "done"

                db.commit()

    # 检查 avatar 状态后，如果 prompts_used 是 JSON 格式，提取原始描述
    description = ""
    try:
        import json
        extra = json.loads(avatar.prompt_used or "{}")
        if isinstance(extra, dict):
            description = extra.get("description", "")
    except (json.JSONDecodeError, TypeError):
        description = avatar.prompt_used or ""

    result = {
        "task_id": task_id,
        "status": avatar.status,
        "base_image_url": avatar.base_image_url,
        "emotions": {
            "happy": avatar.emotion_happy_url,
            "normal": avatar.emotion_normal_url,
            "hungry": avatar.emotion_hungry_url,
            "weak": avatar.emotion_weak_url,
        },
        "seed": avatar.generation_seed,
        "has_gif": avatar.has_gif,
    }
    if description:
        result["description"] = description
    return result


def regenerate_emotion(db: Session, pet_id: int, user_id: int, emotion: str) -> dict:
    """重新生成单个情绪变体"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        raise ValueError("尚未生成形象，请先生成基础形象")

    # 兜底：使用预设
    species_map = PRESET_AVATARS.get(pet.species, PRESET_AVATARS.get("cat", {}))
    preset_url = species_map.get(pet.breed, species_map.get("default",
        "https://placehold.co/400x400/FFE0B2/555555?text=Pet"))

    emotion_map = {
        "happy": "emotion_happy_url",
        "normal": "emotion_normal_url",
        "hungry": "emotion_hungry_url",
        "weak": "emotion_weak_url",
    }
    attr = emotion_map.get(emotion)
    if attr:
        setattr(avatar, attr, preset_url)

    avatar.ai_model = "preset_fallback"
    db.commit()
    return {"status": "done", "emotion": emotion, "url": preset_url}


def upgrade_to_gif(db: Session, pet_id: int, user_id: int) -> dict:
    """触发 GIF 生成（目前返回已有情绪变体作为帧）"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")
    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        raise ValueError("尚未生成形象")

    # GIF 用 base_image_url 替代
    avatar.has_gif = True
    avatar.gif_url = avatar.base_image_url
    db.commit()
    return {"status": "done", "gif_url": avatar.gif_url, "has_gif": True}


# ============================================================
# 内部辅助
# ============================================================

def _upsert_pet_daily_summary(db: Session, pet_id: int, target_date: date):
    """更新或创建宠物每日营养汇总"""
    # 汇总当日喂食
    stats = db.query(
        func.coalesce(func.sum(PetFeedingRecord.calories), 0),
        func.coalesce(func.sum(PetFeedingRecord.protein), 0),
        func.coalesce(func.sum(PetFeedingRecord.fat), 0),
        func.coalesce(func.sum(PetFeedingRecord.carbs), 0),
        func.count(PetFeedingRecord.id),
    ).filter(
        PetFeedingRecord.pet_id == pet_id,
        func.date(PetFeedingRecord.record_time) == target_date
    ).first()

    total_water = db.query(
        func.coalesce(func.sum(PetWaterRecord.amount_ml), 0)
    ).filter(
        PetWaterRecord.pet_id == pet_id,
        func.date(PetWaterRecord.record_time) == target_date
    ).scalar()

    summary = db.query(PetDailySummary).filter(
        PetDailySummary.pet_id == pet_id,
        PetDailySummary.summary_date == target_date
    ).first()

    if not summary:
        summary = PetDailySummary(pet_id=pet_id, summary_date=target_date)
        db.add(summary)

    summary.total_calories = stats[0]
    summary.total_protein = stats[1]
    summary.total_fat = stats[2]
    summary.total_carbs = stats[3]
    summary.meal_count = stats[4]
    summary.total_water_ml = int(total_water or 0)


def _vaccine_to_dict(r: PetVaccineRecord) -> dict:
    return {
        "id": r.id, "pet_id": r.pet_id, "vaccine_name": r.vaccine_name,
        "vaccinated_at": r.vaccinated_at.isoformat() if r.vaccinated_at else None,
        "expiry_date": r.expiry_date.isoformat() if r.expiry_date else None,
        "next_vaccination_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else None,
        "notes": r.notes,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


def _deworming_to_dict(r: PetDewormingRecord) -> dict:
    return {
        "id": r.id, "pet_id": r.pet_id, "deworming_type": r.deworming_type,
        "treated_at": r.treated_at.isoformat() if r.treated_at else None,
        "next_treatment_date": r.next_treatment_date.isoformat() if r.next_treatment_date else None,
        "notes": r.notes,
        "created_at": r.created_at.isoformat() if r.created_at else None,
    }


def _food_to_dict(f: PetFoodDatabase) -> dict:
    # 英文分类 → 中文显示
    _category_map = {
        "dry_food": "干粮", "wet_food": "罐头", "snack": "零食",
        "fresh": "鲜食", "干粮": "干粮", "湿粮": "湿粮",
        "罐头": "罐头", "鲜食": "鲜食", "零食": "零食",
    }
    category_cn = _category_map.get(f.category, f.category or "其他")
    species_cn = "猫" if f.suitable_species == "cat" else "狗" if f.suitable_species == "dog" else "通用"
    return {
        "id": f.id, "name": f.food_name, "food_name": f.food_name,
        "brand": f.brand or "",
        "category": category_cn,
        "species": species_cn, "suitable_species": f.suitable_species,
        "calories": float(f.calories_per_100g) if f.calories_per_100g else 0,
        "calories_per_100g": float(f.calories_per_100g) if f.calories_per_100g else 0,
        "protein": float(f.protein_per_100g) if f.protein_per_100g else 0,
        "protein_per_100g": float(f.protein_per_100g) if f.protein_per_100g else 0,
        "fat": float(f.fat_per_100g) if f.fat_per_100g else 0,
        "fat_per_100g": float(f.fat_per_100g) if f.fat_per_100g else 0,
        "carbs_per_100g": float(f.carbs_per_100g) if f.carbs_per_100g else 0,
    }


# ============================================================
# 食品包装 OCR 解析
# ============================================================

def parse_pet_food_label(image_base64: str) -> dict:
    """使用 DashScope OCR 解析宠物食品包装营养成分表

    Args:
        image_base64: Base64 编码的食品包装背面照片

    Returns:
        dict with brand, food_name, calories_per_100g, protein_per_100g, etc.
    """
    import re
    import json
    import os
    from openai import OpenAI

    api_key = os.getenv("DASHSCOPE_API_KEY", "")
    if not api_key:
        # Fallback: parse with regex from raw OCR text
        return _parse_food_label_local(image_base64)

    try:
        client = OpenAI(
            api_key=api_key,
            base_url="https://dashscope.aliyuncs.com/compatible-mode/v1",
        )

        # 使用 qwen-vl 进行 OCR + 结构化提取
        response = client.chat.completions.create(
            model="qwen-vl-plus",
            messages=[{
                "role": "user",
                "content": [
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
                    },
                    {
                        "type": "text",
                        "text": (
                            "请识别这张宠物食品包装照片上的营养成分信息，提取以下内容并以JSON格式返回：\n"
                            "{\n"
                            '  "brand": "品牌名称（如 皇家、冠能、麦富迪等）",\n'
                            '  "food_name": "产品名称（如 室内成猫粮、幼犬粮等）",\n'
                            '  "calories_per_100g": 每100克热量数值,\n'
                            '  "protein_per_100g": 每100克蛋白质克数,\n'
                            '  "fat_per_100g": 每100克脂肪克数,\n'
                            '  "carbs_per_100g": 每100克碳水化合物克数\n'
                            "}\n"
                            "只返回JSON，不要其他内容。如果某个字段无法识别，设为null。"
                        )
                    }
                ]
            }],
            max_tokens=500,
            temperature=0.1,
        )

        content = response.choices[0].message.content or ""
        # 提取 JSON
        json_match = re.search(r'\{[\s\S]*\}', content)
        if json_match:
            result = json.loads(json_match.group(0))
            result["raw_text"] = content
            return result

        return {"raw_text": content}

    except Exception as e:
        logger.warning(f"DashScope OCR failed: {e}, falling back to local parse")
        return _parse_food_label_local(image_base64)


def _parse_food_label_local(_image_base64: str) -> dict:
    """本地兜底：返回空结果提示需要手动输入"""
    return {
        "brand": None,
        "food_name": None,
        "calories_per_100g": None,
        "protein_per_100g": None,
        "fat_per_100g": None,
        "carbs_per_100g": None,
        "raw_text": "OCR服务不可用，请手动输入营养信息",
    }
