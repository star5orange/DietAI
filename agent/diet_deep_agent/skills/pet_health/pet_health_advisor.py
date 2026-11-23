"""
宠物健康建议 Skill

基于宠物体重、品种、年龄、饮食历史生成健康建议。
所有建议必须包含兽医免责声明。
"""

import logging
from typing import Any

from langchain_core.tools import tool

logger = logging.getLogger(__name__)

# 兽医免责声明
VET_DISCLAIMER = """
⚠️ 免责声明：我是AI助手，建议仅供参考，宠物健康问题请咨询专业兽医。
"""

# 需要立即就医的关键词（不需要时长判断）
EMERGENCY_KEYWORDS_IMMEDIATE = [
    "抽搐", "呼吸困难", "高烧", "出血不止", "中毒",
    "车祸", "被车撞", "摔伤", "骨折", "休克", "昏迷", "瘫痪",
]

# 需要结合时长判断的关键词（超过24小时才紧急）
EMERGENCY_KEYWORDS_DURATION = [
    "呕吐", "腹泻", "拉稀", "不吃不喝", "绝食", "精神萎靡",
    "不吃饭", "不喝水", "持续呕吐", "持续腹泻",
]


@tool
def generate_pet_health_advice(
    pet_id: int,
    weight_kg: float,
    breed: str,
    species: str,
    age: int,
    is_neutered: bool = False,
    recent_calories: float = 0,
    target_calories: float = 0,
) -> dict[str, Any]:
    """根据宠物档案生成健康建议。

    Args:
        pet_id: 宠物 ID
        weight_kg: 当前体重（kg）
        breed: 品种
        species: 物种（cat/dog）
        age: 年龄
        is_neutered: 是否绝育
        recent_calories: 近期日均热量摄入
        target_calories: 目标热量

    Returns:
        健康建议字典，包含体重评估、营养建议、注意事项
    """
    # 理想体重范围（基于品种标准，简化处理）
    ideal_weight_min = weight_kg * 0.85
    ideal_weight_max = weight_kg * 1.15

    # 体重状态评估
    if weight_kg < ideal_weight_min:
        weight_status = "偏轻"
        weight_advice = "建议适当增加喂食量，确保营养充足。如持续偏轻，建议检查是否有健康问题。"
    elif weight_kg > ideal_weight_max:
        weight_status = "偏重"
        weight_advice = "建议控制饮食量，增加运动量。避免高热量零食。"
    else:
        weight_status = "正常"
        weight_advice = "体重保持良好，继续保持当前喂养习惯。"

    # 营养达标分析
    nutrition_advice = ""
    if target_calories > 0 and recent_calories > 0:
        ratio = recent_calories / target_calories
        if ratio < 0.7:
            nutrition_advice = f"近期热量摄入不足（仅为目标的{int(ratio*100)}%），建议适当增加喂食量。"
        elif ratio > 1.2:
            nutrition_advice = f"近期热量摄入偏高（达目标的{int(ratio*100)}%），建议控制饮食量。"
        else:
            nutrition_advice = "营养摄入达标，继续保持。"
    else:
        nutrition_advice = "暂无足够数据进行分析。"

    # 年龄相关建议
    age_advice = ""
    if age < 1:
        age_advice = "幼年期需要高蛋白、高热量饮食，建议选择幼宠专用粮。"
    elif age >= 7:
        age_advice = "进入老年期，建议选择老年专用粮，定期体检。"

    # 绝育相关
    neuter_advice = ""
    if is_neutered:
        neuter_advice = "已绝育宠物新陈代谢可能降低，注意控制热量摄入，避免肥胖。"

    # 组合建议
    advice_parts = [
        f"### 🐱 宠物健康报告\n",
        f"**品种**: {breed}\n",
        f"**年龄**: {age}岁\n",
        f"**体重**: {weight_kg}kg（理想范围：{ideal_weight_min:.1f}-{ideal_weight_max:.1f}kg）\n",
        f"**体重状态**: {weight_status}\n\n",
        f"#### 健康建议\n",
        f"1. **体重管理**: {weight_advice}\n",
        f"2. **营养摄入**: {nutrition_advice}\n",
    ]

    if age_advice:
        advice_parts.append(f"3. **年龄关怀**: {age_advice}\n")
    if neuter_advice:
        advice_parts.append(f"4. **绝育注意**: {neuter_advice}\n")

    advice_parts.append(f"\n{VET_DISCLAIMER}")

    return {
        "pet_id": pet_id,
        "weight_status": weight_status,
        "ideal_weight_range": {
            "min": ideal_weight_min,
            "max": ideal_weight_max,
        },
        "nutrition_ratio": recent_calories / target_calories if target_calories > 0 else None,
        "advice_text": "".join(advice_parts),
        "has_warning": weight_status != "正常",
    }


@tool
def check_pet_emergency(description: str, duration_hours: int = 0) -> dict[str, Any]:
    """检查宠物症状是否需要紧急就医。

    区分两类紧急情况：
    1. 立即就医：抽搐、呼吸困难、出血不止、中毒、外伤等——不管时长
    2. 需判断时长：呕吐、腹泻、不吃不喝——超过24小时才强制建议就医

    Args:
        description: 用户描述的症状
        duration_hours: 症状持续时长（小时），默认0表示未知

    Returns:
        紧急程度评估和建议
    """
    # 检查立即就医关键词
    immediate_found = [kw for kw in EMERGENCY_KEYWORDS_IMMEDIATE if kw in description]

    if immediate_found:
        return {
            "is_emergency": True,
            "severity": "critical",
            "found_keywords": immediate_found,
            "reason": "检测到需要立即处理的危险症状",
            "advice": (
                f"🚨 检测到需要紧急处理的情况：{', '.join(immediate_found)}\n\n"
                f"请立即联系兽医或带宠物去最近的动物医院！不要等待！\n\n"
                f"{VET_DISCLAIMER}"
            ),
        }

    # 检查需时长判断的关键词
    duration_found = [kw for kw in EMERGENCY_KEYWORDS_DURATION if kw in description]

    if duration_found and duration_hours >= 24:
        return {
            "is_emergency": True,
            "severity": "high",
            "found_keywords": duration_found,
            "duration_hours": duration_hours,
            "reason": f"症状已持续 {duration_hours} 小时，超过24小时警戒线",
            "advice": (
                f"⚠️ 检测到持续症状：{', '.join(duration_found)}，已持续 {duration_hours} 小时。\n\n"
                f"症状超过24小时未缓解，强烈建议尽快就医检查！\n\n"
                f"{VET_DISCLAIMER}"
            ),
        }

    if duration_found:
        return {
            "is_emergency": False,
            "severity": "medium",
            "found_keywords": duration_found,
            "duration_hours": duration_hours,
            "reason": f"症状持续时间不足24小时（当前{duration_hours}小时），暂时观察",
            "advice": (
                f"检测到症状：{', '.join(duration_found)}，当前持续 {duration_hours} 小时。\n\n"
                f"建议密切观察宠物状态。如症状持续超过24小时或加重，请及时就医。\n"
                f"确保宠物有充足饮水，提供易消化的食物。\n\n"
                f"{VET_DISCLAIMER}"
            ),
        }

    return {
        "is_emergency": False,
        "severity": "low",
        "found_keywords": [],
        "advice": (
            f"未检测到紧急症状。请继续观察宠物状态，如有异常请及时咨询兽医。\n\n"
            f"{VET_DISCLAIMER}"
        ),
    }


@tool
def get_feeding_recommendation(
    species: str,
    breed: str,
    weight_kg: float,
    age: int,
    activity_level: str = "normal",
) -> dict[str, Any]:
    """获取宠物喂食量建议。

    Args:
        species: 物种（cat/dog）
        breed: 品种
        weight_kg: 体重（kg）
        age: 年龄
        activity_level: 活动水平（low/normal/high）

    Returns:
        喂食建议，包含每日粮量、喂食次数
    """
    # 基础热量计算（每公斤体重）
    base_calories = 50 if species == "cat" else 40

    # 活动水平调整
    activity_multiplier = {
        "low": 0.8,
        "normal": 1.0,
        "high": 1.2,
    }
    multiplier = activity_multiplier.get(activity_level, 1.0)

    # 年龄调整
    if age < 1:
        age_multiplier = 1.5  # 幼宠需要更多热量
    elif age >= 7:
        age_multiplier = 0.85  # 老年宠物需要较少热量
    else:
        age_multiplier = 1.0

    # 计算每日热量需求
    daily_calories = weight_kg * base_calories * multiplier * age_multiplier

    # 喂食次数建议
    if age < 0.5:
        feeding_times = 4
    elif age < 1:
        feeding_times = 3
    else:
        feeding_times = 2

    # 每餐热量
    calories_per_meal = daily_calories / feeding_times

    # 假设干粮热量约 350kcal/100g
    food_grams_per_meal = (calories_per_meal / 350) * 100

    return {
        "daily_calories_kcal": round(daily_calories),
        "recommended_feeding_times": feeding_times,
        "food_grams_per_meal": round(food_grams_per_meal, 0),
        "total_food_grams_per_day": round(food_grams_per_meal * feeding_times, 0),
        "advice": f"建议每日喂食{feeding_times}次，每次约{food_grams_per_meal:.0f}g干粮，总计约{food_grams_per_meal * feeding_times:.0f}g/天。\n\n{VET_DISCLAIMER}",
    }