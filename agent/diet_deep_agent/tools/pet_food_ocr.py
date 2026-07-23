"""
宠物食品 OCR 解析 + 换粮对比工具

拍照录入宠物食品营养成分表，对比两种食品给出换粮建议。
"""

import logging
from typing import Any

from langchain_core.tools import tool

logger = logging.getLogger(__name__)

VET_DISCLAIMER = "\n\n⚠️ 我是AI助手，建议仅供参考。宠物健康问题请咨询专业兽医。"


@tool
def parse_pet_food_ocr(ocr_text: str) -> dict[str, Any]:
    """解析宠物食品营养成分表OCR文字，提取结构化数据。

    支持拍照提取宠物食品包装背面的营养成分表：
    品牌、产品名、热量、蛋白质、脂肪、碳水化合物、适用物种等信息。

    Args:
        ocr_text: OCR识别出的原始文字（营养成分表）

    Returns:
        解析后的结构化营养数据
    """
    if not ocr_text or not ocr_text.strip():
        return {"error": "OCR结果为空，请重新拍照", "success": False}

    text = ocr_text.strip()
    logger.info(f"OCR原始文本: {text[:200]}...")

    # 尝试匹配已知食品
    for name, data in _PET_FOOD_DB.items():
        if name in text:
            return {
                "success": True,
                "matched_existing": True,
                "food_name": name,
                "data": data,
                "message": f"已匹配到现有食品数据：{name}",
            }

    # 尝试从OCR文本中提取关键数值
    # 匹配模式：蛋白质 ≥ X% / 脂肪 ≥ X% / 热量 X kcal
    import re

    def _extract_number(pattern: str, text: str) -> float | None:
        match = re.search(pattern, text)
        return float(match.group(1)) if match else None

    # 提取品牌
    brand = "未知品牌"
    brand_match = re.search(r'(皇家|冠能|希尔斯|比瑞吉|麦富迪|伯纳天纯)', text)
    if brand_match:
        brand = brand_match.group(1)

    # 提取产品名
    product_name = "未知产品"
    name_match = re.search(r'(猫粮|狗粮|猫罐头|狗罐头)', text)
    if name_match:
        product_name = text[:50].strip()

    # 提取营养成分（每100g）
    calories = _extract_number(r'热量[：:\s]*(\d+\.?\d*)', text)
    protein = _extract_number(r'蛋白[质]?[：:\s≥]*(\d+\.?\d*)', text)
    fat = _extract_number(r'脂肪[：:\s≥]*(\d+\.?\d*)', text)
    carbs = _extract_number(r'碳水[：:\s]*(\d+\.?\d*)', text)

    # 判断适用物种
    if "猫" in text and "狗" not in text:
        species = "cat"
    elif "狗" in text and "猫" not in text:
        species = "dog"
    else:
        species = "unknown"

    # 判断食品类型
    if "湿粮" in text or "罐头" in text or "妙鲜包" in text:
        category = "湿粮"
    elif "干粮" in text or "颗粒" in text:
        category = "干粮"
    else:
        category = "未知"

    extracted = {
        "brand": brand,
        "product_name": product_name,
        "species": species,
        "category": category,
        "calories": calories if calories else 0,
        "protein": protein if protein else 0,
        "fat": fat if fat else 0,
        "carbs": carbs if carbs else 0,
    }

    # 检查是否提取到足够数据
    has_data = calories is not None or protein is not None
    if not has_data:
        return {
            "success": False,
            "error": "未能从图片中识别到营养成分数据，请确保拍摄清晰、完整",
            "ocr_text": text[:200],
            "hint": "请拍摄食品包装背面的「营养成分表」部分，确保文字清晰可见",
        }

    return {
        "success": True,
        "matched_existing": False,
        "food_name": product_name,
        "data": extracted,
        "message": f"已从OCR识别到{product_name}的营养数据",
        "confidence": "medium" if calories and protein else "low",
    }


@tool
def compare_pet_foods(
    current_food: dict[str, Any],
    new_food: dict[str, Any],
    pet_weight_kg: float,
) -> dict[str, Any]:
    """对比两种宠物食品的营养成分，生成7天渐进换粮方案。

    Args:
        current_food: 当前食品数据 {name, calories, protein, fat, carbs}
        new_food: 新食品数据 {name, calories, protein, fat, carbs}
        pet_weight_kg: 宠物体重

    Returns:
        营养成分对比 + 7天换粮计划
    """
    cur = current_food
    new = new_food

    cur_name = cur.get("name", "当前食品")
    new_name = new.get("name", "新食品")

    cur_cal = float(cur.get("calories", 0))
    new_cal = float(new.get("calories", 0))
    cur_protein = float(cur.get("protein", 0))
    new_protein = float(new.get("protein", 0))
    cur_fat = float(cur.get("fat", 0))
    new_fat = float(new.get("fat", 0))

    if cur_cal == 0 or new_cal == 0:
        return {"error": "食品数据不完整，无法对比"}

    # 计算差异百分比
    cal_diff_pct = round(((new_cal - cur_cal) / cur_cal) * 100, 1)
    protein_diff_pct = round(((new_protein - cur_protein) / cur_protein) * 100, 1) if cur_protein > 0 else 0
    fat_diff_pct = round(((new_fat - cur_fat) / cur_fat) * 100, 1) if cur_fat > 0 else 0

    # 生成换粮方案（7天渐进过渡）
    # 第1天：75%旧粮 + 25%新粮
    # 第3天：50%旧粮 + 50%新粮
    # 第5天：25%旧粮 + 75%新粮
    # 第7天：100%新粮
    daily_grams = round(pet_weight_kg * 10, 0)  # 估算每日粮量

    transition_plan = []
    for day in range(1, 8):
        new_ratio = min((day - 1) * 0.15, 1.0)  # 每2天增加~15%
        old_ratio = 1.0 - new_ratio

        old_grams = round(daily_grams * old_ratio)
        new_grams = round(daily_grams * new_ratio)

        # 综合热量
        blended_calories = round((cur_cal * old_ratio + new_cal * new_ratio) * daily_grams / 100)

        transition_plan.append({
            "day": day,
            "ratio": f"{round(old_ratio*100)}%/{round(new_ratio*100)}%",
            "old_food_grams": old_grams,
            "new_food_grams": new_grams,
            "blended_calories": blended_calories,
        })

    # 生成对比文案
    cal_label = f"+{cal_diff_pct}%" if cal_diff_pct > 0 else f"{cal_diff_pct}%"
    protein_label = f"+{protein_diff_pct}%" if protein_diff_pct > 0 else f"{protein_diff_pct}%"

    comparison_text = (
        f"### 🐱 换粮对比分析\n\n"
        f"| 指标 | {cur_name} | {new_name} | 差异 |\n"
        f"|------|-----------|------------|------|\n"
        f"| 热量 | {cur_cal} kcal | {new_cal} kcal | {cal_label} |\n"
        f"| 蛋白质 | {cur_protein}g | {new_protein}g | {protein_label} |\n"
        f"| 脂肪 | {cur_fat}g | {new_fat}g | {fat_label} |\n\n"
        f"### 7天渐进换粮方案\n\n"
        f"建议每天喂食约 {daily_grams:.0f}g，按以下比例逐步过渡：\n\n"
    )

    for step in transition_plan:
        comparison_text += (
            f"- **第{step['day']}天**：{cur_name} {step['old_food_grams']}g + "
            f"{new_name} {step['new_food_grams']}g "
            f"（约{step['blended_calories']}kcal）\n"
        )

    # 注意事项
    notes = []
    if abs(cal_diff_pct) > 20:
        notes.append(f"热量差异超过20%({abs(cal_diff_pct)}%)，建议适当调整总喂食量")
    if abs(protein_diff_pct) > 15:
        notes.append(f"蛋白质含量变化较大({abs(protein_diff_pct)}%)，观察宠物粪便状态")
    notes.append("换粮期间注意观察宠物食欲、粪便和精神状态")
    notes.append("如出现呕吐、腹泻等不适，请减缓换粮速度或咨询兽医")

    comparison_text += "\n**注意事项：**\n"
    for note in notes:
        comparison_text += f"- {note}\n"

    return {
        "current_food": {"name": cur_name, "calories": cur_cal, "protein": cur_protein, "fat": cur_fat},
        "new_food": {"name": new_name, "calories": new_cal, "protein": new_protein, "fat": new_fat},
        "calorie_diff_pct": cal_diff_pct,
        "protein_diff_pct": protein_diff_pct,
        "fat_diff_pct": fat_diff_pct,
        "transition_plan": transition_plan,
        "daily_grams_estimated": daily_grams,
        "comparison_text": comparison_text + VET_DISCLAIMER,
    }


@tool
def get_food_db() -> dict[str, dict]:
    """获取当前宠物食品数据库（从 PostgreSQL 查询）。

    Returns:
        以食品名称为 key 的食品数据字典，每个条目包含 brand、species、calories、protein、fat、carbs、category
    """
    from shared.models.pet_models import PetFoodDatabase
    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        foods = db.query(PetFoodDatabase).all()
        return {
            food.name: {
                "brand": food.brand or "",
                "species": food.species or "",
                "calories": float(food.calories) if food.calories else 0,
                "protein": float(food.protein) if food.protein else 0,
                "fat": float(food.fat) if food.fat else 0,
                "carbs": float(food.carbs) if food.carbs else 0,
                "category": food.category or "",
            }
            for food in foods
        }
    except Exception as e:
        logger.error(f"查询食品库失败: {e}")
        return {}
    finally:
        db.close()


@tool
def add_food_to_db(name: str, data: dict) -> str:
    """向数据库新增宠物食品数据。

    Args:
        name: 食品名称
        data: 食品数据字典，包含 brand、species、category、calories、protein、fat、carbs

    Returns:
        添加结果消息
    """
    from shared.models.pet_models import PetFoodDatabase
    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        food = PetFoodDatabase(
            name=name,
            brand=data.get("brand", ""),
            species=data.get("species", ""),
            category=data.get("category", ""),
            calories=data.get("calories", 0),
            protein=data.get("protein", 0),
            fat=data.get("fat", 0),
            carbs=data.get("carbs", 0),
        )
        db.add(food)
        db.commit()
        logger.info(f"已添加宠物食品: {name} (brand={data.get('brand')})")
        return f"已成功添加宠物食品: {name}"
    except Exception as e:
        db.rollback()
        logger.error(f"添加宠物食品失败: {e}")
        return f"添加食品失败: {str(e)}"
    finally:
        db.close()