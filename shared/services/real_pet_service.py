"""M3 真实宠物健康管理业务逻辑"""
import logging
import random
from datetime import date, datetime, timedelta
from typing import Optional, Dict, Any, List

from sqlalchemy.orm import Session
from sqlalchemy import func, and_

from shared.models.pet_models import (
    PetProfile, PetWeightRecord, PetVaccineRecord, PetDewormingRecord,
    PetFeedingRecord, PetWaterRecord, PetDailySummary, PetAvatar,
    PetFoodDatabase,
)

logger = logging.getLogger(__name__)

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
        "英短": "https://minio.example.com/pet_avatars/presets/cat_british_shorthair.png",
        "布偶": "https://minio.example.com/pet_avatars/presets/cat_ragdoll.png",
        "暹罗": "https://minio.example.com/pet_avatars/presets/cat_siamese.png",
        "橘猫": "https://minio.example.com/pet_avatars/presets/cat_orange.png",
        "default": "https://minio.example.com/pet_avatars/presets/cat_default.png",
    },
    "dog": {
        "泰迪": "https://minio.example.com/pet_avatars/presets/dog_poodle.png",
        "柯基": "https://minio.example.com/pet_avatars/presets/dog_corgi.png",
        "金毛": "https://minio.example.com/pet_avatars/presets/dog_golden.png",
        "default": "https://minio.example.com/pet_avatars/presets/dog_default.png",
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
# AI 形象生成（简化实现，后续接入 DashScope）
# ============================================================

def generate_avatar(db: Session, pet_id: int, user_id: int,
                    mode: str, photo: Optional[str] = None,
                    description: Optional[str] = None) -> str:
    """触发 AI 生成宠物形象，返回 task_id"""
    pet = get_pet(db, pet_id, user_id)
    if not pet:
        raise ValueError("宠物不存在")

    task_id = f"gen_{pet_id}_{int(datetime.utcnow().timestamp())}"

    # 检查是否已有记录
    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        avatar = PetAvatar(pet_id=pet_id)
        db.add(avatar)

    # 兜底：使用预设品种形象
    species_map = PRESET_AVATARS.get(pet.species, PRESET_AVATARS.get("cat", {}))
    preset_url = species_map.get(pet.breed, species_map.get("default",
        "https://minio.example.com/pet_avatars/presets/default.png"))

    avatar.base_image_url = preset_url
    avatar.emotion_happy_url = preset_url
    avatar.emotion_normal_url = preset_url
    avatar.emotion_hungry_url = preset_url
    avatar.emotion_weak_url = preset_url
    avatar.generation_seed = pet_id * 10000
    avatar.prompt_used = f"mode={mode}, breed={pet.breed}"
    avatar.ai_model = "preset_fallback"

    db.commit()
    return task_id


def get_generation_task(db: Session, task_id: str) -> dict:
    """查询生成任务状态"""
    try:
        pet_id = int(task_id.split("_")[1])
    except (IndexError, ValueError):
        return {"task_id": task_id, "status": "not_found"}

    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if not avatar:
        return {"task_id": task_id, "status": "not_found"}

    return {
        "task_id": task_id,
        "status": "done",
        "result": {
            "base_image_url": avatar.base_image_url,
            "emotions": {
                "happy": avatar.emotion_happy_url,
                "normal": avatar.emotion_normal_url,
                "hungry": avatar.emotion_hungry_url,
                "weak": avatar.emotion_weak_url,
            },
            "seed": avatar.generation_seed,
            "has_gif": avatar.has_gif,
        },
    }


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
    return {
        "id": f.id, "food_name": f.food_name, "brand": f.brand,
        "category": f.category, "suitable_species": f.suitable_species,
        "calories_per_100g": float(f.calories_per_100g) if f.calories_per_100g else None,
        "protein_per_100g": float(f.protein_per_100g) if f.protein_per_100g else None,
        "fat_per_100g": float(f.fat_per_100g) if f.fat_per_100g else None,
        "carbs_per_100g": float(f.carbs_per_100g) if f.carbs_per_100g else None,
    }
