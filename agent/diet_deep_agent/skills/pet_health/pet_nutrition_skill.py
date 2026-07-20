"""
宠物饮食分析 Skill

分析宠物营养摄入，对比每日目标，给出调整建议。
"""

import logging
from typing import Any

from langchain_core.tools import tool

logger = logging.getLogger(__name__)

VET_DISCLAIMER = "\n\n⚠️ 我是AI助手，建议仅供参考。宠物健康问题请咨询专业兽医。"

# 常见宠物食品营养数据（每100g）
_KNOWN_PET_FOODS = {
    "皇家猫粮": {"calories": 380, "protein": 35, "fat": 16, "carbs": 8, "category": "干粮"},
    "皇家狗粮": {"calories": 350, "protein": 25, "fat": 12, "carbs": 8, "category": "干粮"},
    "鸡胸肉": {"calories": 165, "protein": 31, "fat": 3.6, "carbs": 0, "category": "鲜食"},
    "牛肉": {"calories": 250, "protein": 26, "fat": 15, "carbs": 0, "category": "鲜食"},
    "三文鱼": {"calories": 208, "protein": 20, "fat": 13, "carbs": 0, "category": "鲜食"},
    "鸡肝": {"calories": 119, "protein": 17, "fat": 4.8, "carbs": 2, "category": "鲜食"},
    "南瓜": {"calories": 26, "protein": 1, "fat": 0.1, "carbs": 6.5, "category": "蔬果"},
    "胡萝卜": {"calories": 41, "protein": 0.9, "fat": 0.2, "carbs": 10, "category": "蔬果"},
    "宠物零食": {"calories": 350, "protein": 15, "fat": 15, "carbs": 10, "category": "零食"},
    "猫罐头": {"calories": 120, "protein": 12, "fat": 8, "carbs": 2, "category": "湿粮"},
    "狗罐头": {"calories": 110, "protein": 9, "fat": 7, "carbs": 3, "category": "湿粮"},
}


@tool
def analyze_pet_diet_nutrition(
    pet_name: str,
    breed: str,
    weight_kg: float,
    age: int,
    feeding_records: list[dict],
    target_calories: int,
) -> dict[str, Any]:
    """分析宠物饮食营养摄入。

    Args:
        pet_name: 宠物名称
        breed: 品种
        weight_kg: 体重
        age: 年龄
        feeding_records: 饮食记录列表，每项含 food_name, amount_grams
        target_calories: 目标热量

    Returns:
        营养分析报告
    """
    total_calories = 0
    total_protein = 0
    total_fat = 0
    total_carbs = 0
    detailed = []

    for record in feeding_records:
        food_name = record.get("food_name", record.get("food", "未知食物"))
        amount = record.get("amount_grams", record.get("amount_g", 0))
        source = record.get("source", "手动")

        # 查找营养数据
        food_data = _KNOWN_PET_FOODS.get(food_name)
        if food_data:
            scale = amount / 100.0
            calories = round(food_data["calories"] * scale)
            protein = round(food_data["protein"] * scale, 1)
            fat = round(food_data["fat"] * scale, 1)
            carbs = round(food_data["carbs"] * scale, 1)
            category = food_data["category"]
        else:
            # 未知食物，估算
            calories = round(amount * 3.5)  # 粗略估算
            protein = round(amount * 0.25, 1)
            fat = round(amount * 0.12, 1)
            carbs = round(amount * 0.05, 1)
            category = "未知"

        total_calories += calories
        total_protein += protein
        total_fat += fat
        total_carbs += carbs

        detailed.append({
            "food": food_name,
            "amount_g": amount,
            "calories": calories,
            "protein": protein,
            "fat": fat,
            "carbs": carbs,
            "category": category,
            "source": source,
        })

    # 达标率
    calorie_ratio = total_calories / target_calories if target_calories > 0 else 0

    # 评估等级
    if calorie_ratio >= 0.9 and calorie_ratio <= 1.1:
        assessment = "达标"
        assessment_class = "good"
    elif calorie_ratio < 0.7:
        assessment = "不足"
        assessment_class = "bad"
    elif calorie_ratio > 1.2:
        assessment = "超标"
        assessment_class = "bad"
    else:
        assessment = "接近"
        assessment_class = "warning"

    # 建议
    advice = ""
    if calorie_ratio < 0.7:
        advice = f"今日摄入不足，仅达到目标的{int(calorie_ratio*100)}%，建议适当增加喂食量。"
    elif calorie_ratio > 1.2:
        advice = f"今日摄入超标，达到目标的{int(calorie_ratio*100)}%，建议控制喂食量，避免零食。"
    else:
        advice = "今日摄入基本达标，继续保持。"

    # 鲜食/零食占比检查
    raw_food_calories = sum(d["calories"] for d in detailed if d["category"] == "鲜食")
    treat_calories = sum(d["calories"] for d in detailed if d["category"] == "零食")
    treat_ratio = treat_calories / total_calories if total_calories > 0 else 0

    if treat_ratio > 0.1:
        advice += " 零食占比较高，建议减少零食，以主食为主。"

    return {
        "pet_name": pet_name,
        "summary": {
            "total_calories": total_calories,
            "target_calories": target_calories,
            "calorie_ratio": round(calorie_ratio * 100),
            "total_protein": round(total_protein, 1),
            "total_fat": round(total_fat, 1),
            "total_carbs": round(total_carbs, 1),
        },
        "assessment": assessment,
        "assessment_class": assessment_class,
        "advice": advice + VET_DISCLAIMER,
        "details": detailed,
        "meal_count": len(feeding_records),
    }


@tool
def get_pet_food_database(query: str = "") -> dict[str, Any]:
    """查询常见宠物食品营养数据库。

    Args:
        query: 搜索关键词（可为空，返回全部）

    Returns:
        匹配的食品营养数据
    """
    if not query:
        return {"foods": _KNOWN_PET_FOODS, "count": len(_KNOWN_PET_FOODS)}

    results = {
        name: data
        for name, data in _KNOWN_PET_FOODS.items()
        if query.lower() in name.lower()
    }

    return {
        "query": query,
        "foods": results,
        "count": len(results),
    }