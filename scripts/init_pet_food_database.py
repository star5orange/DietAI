#!/usr/bin/env python3
"""宠物食品营养库种子数据初始化"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from shared.models.database import SessionLocal
from shared.models.pet_models import PetFoodDatabase

SEED_DATA = [
    # 猫粮
    {"food_name": "皇家室内成猫粮", "brand": "皇家", "category": "dry_food", "suitable_species": "cat",
     "calories_per_100g": 380, "protein_per_100g": 34.0, "fat_per_100g": 14.0, "carbs_per_100g": 35.0},
    {"food_name": "皇家幼猫粮", "brand": "皇家", "category": "dry_food", "suitable_species": "cat",
     "calories_per_100g": 410, "protein_per_100g": 36.0, "fat_per_100g": 18.0, "carbs_per_100g": 30.0},
    {"food_name": "渴望六种鱼猫粮", "brand": "Orijen", "category": "dry_food", "suitable_species": "cat",
     "calories_per_100g": 406, "protein_per_100g": 40.0, "fat_per_100g": 20.0, "carbs_per_100g": 20.0},
    {"food_name": "爱肯拿鸡肉猫粮", "brand": "Acana", "category": "dry_food", "suitable_species": "cat",
     "calories_per_100g": 395, "protein_per_100g": 37.0, "fat_per_100g": 18.0, "carbs_per_100g": 25.0},
    {"food_name": "巅峰牛肉猫罐", "brand": "Ziwi", "category": "wet_food", "suitable_species": "cat",
     "calories_per_100g": 120, "protein_per_100g": 12.0, "fat_per_100g": 6.0, "carbs_per_100g": 5.0},
    {"food_name": "K9冻干鸡肉猫粮", "brand": "K9 Natural", "category": "dry_food", "suitable_species": "cat",
     "calories_per_100g": 440, "protein_per_100g": 48.0, "fat_per_100g": 32.0, "carbs_per_100g": 4.0},
    # 狗粮
    {"food_name": "皇家贵宾成犬粮", "brand": "皇家", "category": "dry_food", "suitable_species": "dog",
     "calories_per_100g": 370, "protein_per_100g": 28.0, "fat_per_100g": 14.0, "carbs_per_100g": 38.0},
    {"food_name": "渴望大型幼犬粮", "brand": "Orijen", "category": "dry_food", "suitable_species": "dog",
     "calories_per_100g": 390, "protein_per_100g": 38.0, "fat_per_100g": 18.0, "carbs_per_100g": 28.0},
    {"food_name": "冠能中型犬粮", "brand": "冠能", "category": "dry_food", "suitable_species": "dog",
     "calories_per_100g": 360, "protein_per_100g": 26.0, "fat_per_100g": 12.0, "carbs_per_100g": 42.0},
    {"food_name": "比瑞吉牛肉狗罐", "brand": "比瑞吉", "category": "wet_food", "suitable_species": "dog",
     "calories_per_100g": 110, "protein_per_100g": 10.0, "fat_per_100g": 5.0, "carbs_per_100g": 8.0},
    # 零食
    {"food_name": "伟嘉猫条", "brand": "伟嘉", "category": "snack", "suitable_species": "cat",
     "calories_per_100g": 85, "protein_per_100g": 8.0, "fat_per_100g": 3.0, "carbs_per_100g": 8.0},
    {"food_name": "宝路洁齿棒", "brand": "宝路", "category": "snack", "suitable_species": "dog",
     "calories_per_100g": 290, "protein_per_100g": 12.0, "fat_per_100g": 5.0, "carbs_per_100g": 55.0},
]


def init():
    db = SessionLocal()
    try:
        created = 0
        for item in SEED_DATA:
            existing = db.query(PetFoodDatabase).filter(
                PetFoodDatabase.food_name == item["food_name"],
                PetFoodDatabase.brand == item["brand"]
            ).first()
            if existing:
                continue
            db.add(PetFoodDatabase(**item))
            created += 1
        db.commit()
        print(f"宠物食品库初始化完成: 新增 {created} 条, 跳过 {len(SEED_DATA) - created} 条（已存在）")
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    init()
