"""M3 宠物营养目标计算

根据品种/年龄/体重/绝育状态计算每日推荐热量和蛋白质。
参考 AAFCO/FEDIAF 宠物营养标准简化实现。
"""
import json
import logging
import os
from datetime import date, timedelta
from typing import Dict, Any, Optional, Tuple

from sqlalchemy.orm import Session
from sqlalchemy import func

from shared.models.pet_models import PetProfile, PetDailySummary, PetFeedingRecord

logger = logging.getLogger(__name__)

# 加载品种配置
_breeds_path = os.path.join(os.path.dirname(__file__), "..", "config", "pet_breeds.json")
_BREEDS_DATA: Dict[str, Any] = {}
try:
    with open(_breeds_path, "r", encoding="utf-8") as f:
        _BREEDS_DATA = json.load(f)
except Exception:
    logger.warning(f"Failed to load pet_breeds.json from {_breeds_path}")

# 活动水平系数
ACTIVITY_FACTORS = {
    "low": 0.8,       # 老年/室内懒猫
    "moderate": 1.0,   # 正常室内
    "high": 1.2,       # 户外/活跃
}

# 蛋白质推荐比例（占热量百分比）
PROTEIN_CAL_RATIO = {
    "cat": 0.26,  # 猫需要更高蛋白
    "dog": 0.18,
    "other": 0.20,
}

# 绝育热量调整系数（绝育后代谢降低）
NEUTERED_ADJUSTMENT = 0.85


def get_breed_info(breed_name: str, species: str) -> Dict[str, Any]:
    """从品种配置中查询信息（支持模糊匹配）"""
    species_data = _BREEDS_DATA.get("species", {}).get(species, {})
    breeds = species_data.get("breeds", [])
    if not breeds:
        logger.warning(f"未找到物种 [{species}] 的品种配置，使用默认值 5.0kg/50kcal")
        return {"name": "未知品种", "avg_weight_kg": {"male": 5.0, "female": 4.0}, "daily_calories_per_kg": 50}

    if not breed_name:
        logger.info(f"品种名为空，使用物种 [{species}] 第一个品种作为默认: {breeds[0].get('name')}")
        return breeds[0]

    # 1. 精确匹配
    for b in breeds:
        if b.get("name") == breed_name:
            return b

    # 2. 字符重叠匹配（中文品种名缩写场景："英短" 匹配 "英国短毛猫"）
    for b in breeds:
        name = b.get("name", "")
        # 所有输入字符都出现在标准名中
        if breed_name and name and all(ch in name for ch in breed_name):
            logger.info(f"品种模糊匹配: '{breed_name}' -> '{name}'")
            return b
    # 反向：标准名所有字符都出现在输入中（如 "柯基" 匹配 "柯基犬"）
    for b in breeds:
        name = b.get("name", "")
        if breed_name and name and all(ch in breed_name for ch in name):
            logger.info(f"品种模糊匹配: '{breed_name}' -> '{name}'")
            return b

    # 3. 未匹配，使用物种第一个品种作为默认
    logger.warning(f"品种 [{breed_name}] 未在配置中找到，使用物种 [{species}] 第一个品种作为默认: {breeds[0].get('name')}")
    return breeds[0]


def calc_pet_age(pet: PetProfile) -> Tuple[float, str]:
    """计算宠物年龄（年）和生命阶段"""
    if not pet.birth_date:
        return 3.0, "adult"
    age_days = (date.today() - pet.birth_date).days
    age_years = age_days / 365.25
    if pet.species == "cat":
        if age_years < 1:
            stage = "kitten"
        elif age_years < 7:
            stage = "adult"
        else:
            stage = "senior"
    else:  # dog
        if age_years < 1:
            stage = "puppy"
        elif age_years < 7:
            stage = "adult"
        else:
            stage = "senior"
    return round(age_years, 1), stage


def calculate_daily_targets(pet: PetProfile, activity_level: str = "moderate") -> Dict[str, Any]:
    """计算每日推荐热量和蛋白质目标

    Args:
        pet: 宠物档案
        activity_level: 活动水平 low/moderate/high

    Returns:
        {calories: 250, protein: 20, fat: 12, carbs: 30, ...}
    """
    breed_info = get_breed_info(pet.breed or "", pet.species or "cat")
    age_years, life_stage = calc_pet_age(pet)

    # 根据性别获取平均体重
    gender = pet.gender or "male"
    avg_weight = float(breed_info.get("avg_weight_kg", {}).get(gender, 5.0))
    cal_per_kg = float(breed_info.get("daily_calories_per_kg", 50))

    # 基础热量 = 体重 × 每公斤热量
    base_calories = avg_weight * cal_per_kg

    # 生命阶段调整
    stage_multipliers = {"kitten": 2.0, "puppy": 2.0, "adult": 1.0, "senior": 0.8}
    stage_mult = stage_multipliers.get(life_stage, 1.0)

    # 绝育调整
    neuter_mult = NEUTERED_ADJUSTMENT if pet.is_neutered else 1.0

    # 活动水平
    activity_mult = ACTIVITY_FACTORS.get(activity_level, 1.0)

    daily_calories = base_calories * stage_mult * neuter_mult * activity_mult

    # 蛋白质(g) = 热量 × 蛋白质热量占比 / 4 kcal/g
    protein_ratio = PROTEIN_CAL_RATIO.get(pet.species or "cat", 0.20)
    daily_protein = (daily_calories * protein_ratio) / 4.0

    # 脂肪 ~30% 热量
    daily_fat = (daily_calories * 0.30) / 9.0

    return {
        "pet_id": pet.id,
        "breed": pet.breed,
        "species": pet.species,
        "age_years": age_years,
        "life_stage": life_stage,
        "avg_weight_kg": avg_weight,
        "is_neutered": pet.is_neutered,
        "activity_level": activity_level,
        "daily_calories": round(daily_calories),
        "daily_protein_g": round(daily_protein, 1),
        "daily_fat_g": round(daily_fat, 1),
    }


def check_daily_completion(db: Session, pet_id: int, target_date: Optional[date] = None) -> Dict[str, Any]:
    """检查当日摄入是否达标

    Args:
        db: 数据库会话
        pet_id: 宠物ID
        target_date: 目标日期，默认今天

    Returns:
        {calories_pct: 85, protein_pct: 90, is_adequate: true, details: {...}}
    """
    if target_date is None:
        target_date = date.today()

    pet = db.query(PetProfile).filter(PetProfile.id == pet_id).first()
    if not pet:
        return {"error": "宠物不存在"}

    targets = calculate_daily_targets(pet)
    target_cal = targets["daily_calories"]
    target_protein = targets["daily_protein_g"]

    # 查询当日汇总
    summary = db.query(PetDailySummary).filter(
        PetDailySummary.pet_id == pet_id,
        PetDailySummary.summary_date == target_date
    ).first()

    if not summary:
        return {
            "pet_id": pet_id,
            "date": target_date.isoformat(),
            "target_calories": target_cal,
            "target_protein_g": target_protein,
            "actual_calories": 0,
            "actual_protein_g": 0,
            "calories_pct": 0,
            "protein_pct": 0,
            "is_adequate": False,
            "message": "今日暂无饮食记录",
        }

    actual_cal = float(summary.total_calories or 0)
    actual_protein = float(summary.total_protein or 0)

    cal_pct = round(min(actual_cal / target_cal * 100, 200), 1) if target_cal > 0 else 0
    pro_pct = round(min(actual_protein / target_protein * 100, 200), 1) if target_protein > 0 else 0

    is_adequate = cal_pct >= 80 and pro_pct >= 80

    return {
        "pet_id": pet_id,
        "date": target_date.isoformat(),
        "target_calories": target_cal,
        "target_protein_g": target_protein,
        "actual_calories": round(actual_cal, 1),
        "actual_protein_g": round(actual_protein, 1),
        "calories_pct": cal_pct,
        "protein_pct": pro_pct,
        "is_adequate": is_adequate,
        "message": "今日营养摄入达标" if is_adequate else f"热量{'超标' if cal_pct > 120 else '不足'}，建议调整喂食量",
    }


def get_weekly_nutrition_analysis(db: Session, pet_id: int) -> Dict[str, Any]:
    """分析近7天的营养趋势

    Returns:
        {daily_data: [...], avg_calories_pct, avg_protein_pct, gaps: [...], trend_summary: "..."}
    """
    pet = db.query(PetProfile).filter(PetProfile.id == pet_id).first()
    if not pet:
        return {"error": "宠物不存在"}

    targets = calculate_daily_targets(pet)
    target_cal = targets["daily_calories"]
    target_protein = targets["daily_protein_g"]

    today = date.today()
    start = today - timedelta(days=6)

    summaries = db.query(PetDailySummary).filter(
        PetDailySummary.pet_id == pet_id,
        PetDailySummary.summary_date >= start,
        PetDailySummary.summary_date <= today
    ).order_by(PetDailySummary.summary_date).all()

    daily_data = []
    gaps: list = []
    cal_pcts: list = []
    pro_pcts: list = []

    for s in summaries:
        cal = float(s.total_calories or 0)
        pro = float(s.total_protein or 0)
        cp = round(cal / target_cal * 100, 1) if target_cal > 0 else 0
        pp = round(pro / target_protein * 100, 1) if target_protein > 0 else 0
        cal_pcts.append(cp)
        pro_pcts.append(pp)
        daily_data.append({
            "date": s.summary_date.isoformat(),
            "calories": round(cal, 1),
            "calories_pct": cp,
            "protein_g": round(pro, 1),
            "protein_pct": pp,
            "meal_count": s.meal_count,
        })

    # 分析营养缺口
    if len(cal_pcts) >= 3:
        # 连续 3 天不足
        low_streak = 0
        for cp in cal_pcts[-3:]:
            if cp < 70:
                low_streak += 1
        if low_streak >= 3:
            gaps.append(f"连续 3 天热量摄入低于目标 70%（当前均值 {round(sum(cal_pcts[-3:])/3)}%），建议增加喂食量")
        if len(pro_pcts) >= 3:
            pro_streak = sum(1 for pp in pro_pcts[-3:] if pp < 70)
            if pro_streak >= 3:
                gaps.append(f"连续 3 天蛋白质摄入低于目标 70%（当前均值 {round(sum(pro_pcts[-3:])/3)}%），建议补充高蛋白食品")

    avg_cal = round(sum(cal_pcts) / len(cal_pcts), 1) if cal_pcts else 0
    avg_pro = round(sum(pro_pcts) / len(pro_pcts), 1) if pro_pcts else 0

    # 趋势总结
    if avg_cal >= 90 and avg_pro >= 90:
        trend = "优秀：近7天营养摄入全面达标，继续保持！"
    elif avg_cal >= 70 and avg_pro >= 70:
        trend = "良好：近7天营养摄入基本达标，仍有优化空间。"
    elif avg_cal < 50 or avg_pro < 50:
        trend = "需关注：近7天营养摄入明显不足，建议调整喂食计划。"
    else:
        trend = "一般：近7天营养摄入波动较大，建议稳定喂食时间和份量。"

    return {
        "pet_id": pet_id,
        "target_calories": target_cal,
        "target_protein_g": target_protein,
        "daily_data": daily_data,
        "data_days": len(daily_data),
        "avg_calories_pct": avg_cal,
        "avg_protein_pct": avg_pro,
        "gaps": gaps,
        "trend_summary": trend,
    }
