#!/usr/bin/env python3
"""人类食物营养库种子数据初始化（每 100g 可食部）

背景：`food_database` 表为空时，record_food 的 _lookup_food 永远匹配不到食物，
所有记录都落在 analysis_status=1，导致「今日汇总」长期为 0。

数据为常见食物的参考值（《中国食物成分表》口径），非实验室实测，
故统一以 verified=False 落库，后续可由营养师校准。

重复执行安全：按 food_name 去重，已存在的跳过。
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from shared.models.database import SessionLocal
from shared.models.food_models import FoodDatabase

SOURCE = "中国食物成分表(参考值)"

# category 取值：grain 谷薯 / vegetable 蔬菜 / fruit 水果 / meat 畜禽肉 /
#               aquatic 水产 / egg_dairy 蛋奶 / bean 豆制品 / nut 坚果 / dish 常见菜品
SEED_DATA = [
    # ---- 谷薯类 ----
    {"food_name": "米饭", "food_name_en": "cooked rice", "category": "grain", "calories_per_100g": 116, "protein_per_100g": 2.6, "fat_per_100g": 0.3, "carbohydrates_per_100g": 25.9, "fiber_per_100g": 0.3, "sodium_per_100g": 2},
    {"food_name": "白粥", "category": "grain", "calories_per_100g": 46, "protein_per_100g": 1.1, "fat_per_100g": 0.3, "carbohydrates_per_100g": 9.9, "fiber_per_100g": 0.1, "sodium_per_100g": 2},
    {"food_name": "小米粥", "category": "grain", "calories_per_100g": 46, "protein_per_100g": 1.4, "fat_per_100g": 0.7, "carbohydrates_per_100g": 8.4, "fiber_per_100g": 0.2, "sodium_per_100g": 2},
    {"food_name": "馒头", "category": "grain", "calories_per_100g": 223, "protein_per_100g": 7.0, "fat_per_100g": 1.1, "carbohydrates_per_100g": 47.0, "fiber_per_100g": 1.3, "sodium_per_100g": 165},
    {"food_name": "面条", "food_name_en": "cooked noodles", "category": "grain", "calories_per_100g": 109, "protein_per_100g": 3.5, "fat_per_100g": 0.5, "carbohydrates_per_100g": 22.9, "fiber_per_100g": 0.8, "sodium_per_100g": 100},
    {"food_name": "全麦面包", "category": "grain", "calories_per_100g": 246, "protein_per_100g": 8.8, "fat_per_100g": 3.3, "carbohydrates_per_100g": 45.0, "fiber_per_100g": 6.0, "sodium_per_100g": 400},
    {"food_name": "燕麦片", "category": "grain", "calories_per_100g": 377, "protein_per_100g": 15.0, "fat_per_100g": 6.7, "carbohydrates_per_100g": 61.0, "fiber_per_100g": 10.6, "sodium_per_100g": 3},
    {"food_name": "红薯", "category": "grain", "calories_per_100g": 90, "protein_per_100g": 1.1, "fat_per_100g": 0.2, "carbohydrates_per_100g": 20.7, "fiber_per_100g": 1.6, "sodium_per_100g": 28},
    {"food_name": "紫薯", "category": "grain", "calories_per_100g": 82, "protein_per_100g": 1.4, "fat_per_100g": 0.2, "carbohydrates_per_100g": 19.0, "fiber_per_100g": 1.5, "sodium_per_100g": 30},
    {"food_name": "土豆", "food_name_en": "potato", "category": "grain", "calories_per_100g": 81, "protein_per_100g": 2.0, "fat_per_100g": 0.2, "carbohydrates_per_100g": 17.8, "fiber_per_100g": 1.2, "sodium_per_100g": 5},
    {"food_name": "玉米", "food_name_en": "sweet corn", "category": "grain", "calories_per_100g": 112, "protein_per_100g": 4.0, "fat_per_100g": 1.2, "carbohydrates_per_100g": 22.8, "fiber_per_100g": 2.9, "sodium_per_100g": 3},

    # ---- 蔬菜类 ----
    {"food_name": "西兰花", "food_name_en": "broccoli", "category": "vegetable", "calories_per_100g": 33, "protein_per_100g": 4.1, "fat_per_100g": 0.6, "carbohydrates_per_100g": 4.3, "fiber_per_100g": 1.6, "sodium_per_100g": 18},
    {"food_name": "菠菜", "category": "vegetable", "calories_per_100g": 28, "protein_per_100g": 2.6, "fat_per_100g": 0.3, "carbohydrates_per_100g": 4.5, "fiber_per_100g": 1.7, "sodium_per_100g": 85},
    {"food_name": "生菜", "category": "vegetable", "calories_per_100g": 15, "protein_per_100g": 1.3, "fat_per_100g": 0.3, "carbohydrates_per_100g": 2.0, "fiber_per_100g": 0.7, "sodium_per_100g": 32},
    {"food_name": "黄瓜", "category": "vegetable", "calories_per_100g": 16, "protein_per_100g": 0.8, "fat_per_100g": 0.2, "carbohydrates_per_100g": 2.9, "fiber_per_100g": 0.5, "sodium_per_100g": 5},
    {"food_name": "番茄", "food_name_en": "tomato", "category": "vegetable", "calories_per_100g": 20, "protein_per_100g": 0.9, "fat_per_100g": 0.2, "carbohydrates_per_100g": 4.0, "fiber_per_100g": 0.5, "sodium_per_100g": 5},
    {"food_name": "胡萝卜", "category": "vegetable", "calories_per_100g": 39, "protein_per_100g": 1.0, "fat_per_100g": 0.2, "carbohydrates_per_100g": 8.8, "fiber_per_100g": 1.1, "sodium_per_100g": 71},
    {"food_name": "大白菜", "category": "vegetable", "calories_per_100g": 18, "protein_per_100g": 1.5, "fat_per_100g": 0.1, "carbohydrates_per_100g": 3.2, "fiber_per_100g": 0.8, "sodium_per_100g": 57},
    {"food_name": "青椒", "category": "vegetable", "calories_per_100g": 22, "protein_per_100g": 1.4, "fat_per_100g": 0.3, "carbohydrates_per_100g": 5.4, "fiber_per_100g": 1.4, "sodium_per_100g": 3},
    {"food_name": "香菇", "category": "vegetable", "calories_per_100g": 26, "protein_per_100g": 2.2, "fat_per_100g": 0.3, "carbohydrates_per_100g": 5.2, "fiber_per_100g": 3.3, "sodium_per_100g": 1},
    {"food_name": "木耳", "category": "vegetable", "calories_per_100g": 27, "protein_per_100g": 1.5, "fat_per_100g": 0.2, "carbohydrates_per_100g": 6.0, "fiber_per_100g": 2.6, "sodium_per_100g": 8},
    {"food_name": "茄子", "category": "vegetable", "calories_per_100g": 23, "protein_per_100g": 1.1, "fat_per_100g": 0.2, "carbohydrates_per_100g": 4.9, "fiber_per_100g": 1.3, "sodium_per_100g": 5},
    {"food_name": "西葫芦", "category": "vegetable", "calories_per_100g": 19, "protein_per_100g": 0.8, "fat_per_100g": 0.2, "carbohydrates_per_100g": 3.8, "fiber_per_100g": 0.6, "sodium_per_100g": 5},

    # ---- 水果类 ----
    {"food_name": "苹果", "food_name_en": "apple", "category": "fruit", "calories_per_100g": 53, "protein_per_100g": 0.2, "fat_per_100g": 0.2, "carbohydrates_per_100g": 13.5, "fiber_per_100g": 1.2, "sodium_per_100g": 1.6},
    {"food_name": "香蕉", "food_name_en": "banana", "category": "fruit", "calories_per_100g": 93, "protein_per_100g": 1.4, "fat_per_100g": 0.2, "carbohydrates_per_100g": 22.0, "fiber_per_100g": 1.2, "sodium_per_100g": 0.8},
    {"food_name": "橙子", "category": "fruit", "calories_per_100g": 48, "protein_per_100g": 0.8, "fat_per_100g": 0.2, "carbohydrates_per_100g": 11.1, "fiber_per_100g": 0.6, "sodium_per_100g": 1.2},
    {"food_name": "西瓜", "category": "fruit", "calories_per_100g": 31, "protein_per_100g": 0.6, "fat_per_100g": 0.1, "carbohydrates_per_100g": 7.9, "fiber_per_100g": 0.3, "sodium_per_100g": 3.2},
    {"food_name": "葡萄", "category": "fruit", "calories_per_100g": 45, "protein_per_100g": 0.5, "fat_per_100g": 0.2, "carbohydrates_per_100g": 10.3, "fiber_per_100g": 0.4, "sodium_per_100g": 1.3},
    {"food_name": "蓝莓", "category": "fruit", "calories_per_100g": 57, "protein_per_100g": 0.7, "fat_per_100g": 0.3, "carbohydrates_per_100g": 14.5, "fiber_per_100g": 2.4, "sodium_per_100g": 1},
    {"food_name": "猕猴桃", "category": "fruit", "calories_per_100g": 61, "protein_per_100g": 0.8, "fat_per_100g": 0.6, "carbohydrates_per_100g": 14.5, "fiber_per_100g": 2.6, "sodium_per_100g": 10},
    {"food_name": "草莓", "category": "fruit", "calories_per_100g": 32, "protein_per_100g": 1.0, "fat_per_100g": 0.2, "carbohydrates_per_100g": 7.1, "fiber_per_100g": 1.1, "sodium_per_100g": 4.2},
    {"food_name": "火龙果", "category": "fruit", "calories_per_100g": 55, "protein_per_100g": 1.1, "fat_per_100g": 0.2, "carbohydrates_per_100g": 13.3, "fiber_per_100g": 1.6, "sodium_per_100g": 2.7},

    # ---- 畜禽肉类 ----
    {"food_name": "鸡胸肉", "food_name_en": "chicken breast", "category": "meat", "calories_per_100g": 133, "protein_per_100g": 19.4, "fat_per_100g": 5.0, "carbohydrates_per_100g": 2.5, "fiber_per_100g": 0, "sodium_per_100g": 63},
    {"food_name": "鸡腿肉", "category": "meat", "calories_per_100g": 181, "protein_per_100g": 16.0, "fat_per_100g": 13.0, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 64},
    {"food_name": "鸡翅", "category": "meat", "calories_per_100g": 194, "protein_per_100g": 17.4, "fat_per_100g": 11.8, "carbohydrates_per_100g": 4.6, "fiber_per_100g": 0, "sodium_per_100g": 51},
    {"food_name": "猪里脊", "food_name_en": "pork tenderloin", "category": "meat", "calories_per_100g": 155, "protein_per_100g": 20.2, "fat_per_100g": 7.9, "carbohydrates_per_100g": 0.7, "fiber_per_100g": 0, "sodium_per_100g": 43},
    {"food_name": "瘦猪肉", "category": "meat", "calories_per_100g": 143, "protein_per_100g": 20.3, "fat_per_100g": 6.2, "carbohydrates_per_100g": 1.5, "fiber_per_100g": 0, "sodium_per_100g": 57},
    {"food_name": "五花肉", "category": "meat", "calories_per_100g": 568, "protein_per_100g": 7.7, "fat_per_100g": 59.0, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 34},
    {"food_name": "牛肉", "food_name_en": "lean beef", "category": "meat", "calories_per_100g": 106, "protein_per_100g": 20.2, "fat_per_100g": 2.3, "carbohydrates_per_100g": 1.2, "fiber_per_100g": 0, "sodium_per_100g": 53},
    {"food_name": "牛排", "category": "meat", "calories_per_100g": 181, "protein_per_100g": 22.0, "fat_per_100g": 9.8, "carbohydrates_per_100g": 0.5, "fiber_per_100g": 0, "sodium_per_100g": 55},
    {"food_name": "羊肉", "category": "meat", "calories_per_100g": 118, "protein_per_100g": 20.5, "fat_per_100g": 3.9, "carbohydrates_per_100g": 0.2, "fiber_per_100g": 0, "sodium_per_100g": 69},
    {"food_name": "鸭肉", "category": "meat", "calories_per_100g": 240, "protein_per_100g": 15.5, "fat_per_100g": 19.7, "carbohydrates_per_100g": 0.2, "fiber_per_100g": 0, "sodium_per_100g": 69},

    # ---- 水产类 ----
    {"food_name": "鲈鱼", "food_name_en": "sea bass", "category": "aquatic", "calories_per_100g": 105, "protein_per_100g": 18.6, "fat_per_100g": 3.4, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 144},
    {"food_name": "草鱼", "category": "aquatic", "calories_per_100g": 113, "protein_per_100g": 16.6, "fat_per_100g": 5.2, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 46},
    {"food_name": "三文鱼", "food_name_en": "salmon", "category": "aquatic", "calories_per_100g": 139, "protein_per_100g": 17.2, "fat_per_100g": 7.8, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 63},
    {"food_name": "鳕鱼", "category": "aquatic", "calories_per_100g": 88, "protein_per_100g": 20.4, "fat_per_100g": 0.5, "carbohydrates_per_100g": 0.5, "fiber_per_100g": 0, "sodium_per_100g": 130},
    {"food_name": "鲫鱼", "category": "aquatic", "calories_per_100g": 108, "protein_per_100g": 17.1, "fat_per_100g": 2.7, "carbohydrates_per_100g": 3.8, "fiber_per_100g": 0, "sodium_per_100g": 41},
    {"food_name": "基围虾", "food_name_en": "shrimp", "category": "aquatic", "calories_per_100g": 101, "protein_per_100g": 18.2, "fat_per_100g": 1.4, "carbohydrates_per_100g": 3.9, "fiber_per_100g": 0, "sodium_per_100g": 172},
    {"food_name": "螃蟹", "category": "aquatic", "calories_per_100g": 95, "protein_per_100g": 17.5, "fat_per_100g": 2.6, "carbohydrates_per_100g": 2.3, "fiber_per_100g": 0, "sodium_per_100g": 193},
    {"food_name": "鱿鱼", "category": "aquatic", "calories_per_100g": 84, "protein_per_100g": 17.4, "fat_per_100g": 1.6, "carbohydrates_per_100g": 0, "fiber_per_100g": 0, "sodium_per_100g": 134},

    # ---- 蛋奶类 ----
    {"food_name": "鸡蛋", "food_name_en": "egg", "category": "egg_dairy", "calories_per_100g": 144, "protein_per_100g": 13.3, "fat_per_100g": 8.8, "carbohydrates_per_100g": 2.8, "fiber_per_100g": 0, "sodium_per_100g": 131},
    {"food_name": "鸡蛋白", "food_name_en": "egg white", "category": "egg_dairy", "calories_per_100g": 60, "protein_per_100g": 11.6, "fat_per_100g": 0.1, "carbohydrates_per_100g": 3.1, "fiber_per_100g": 0, "sodium_per_100g": 166},
    {"food_name": "牛奶", "food_name_en": "milk", "category": "egg_dairy", "calories_per_100g": 54, "protein_per_100g": 3.0, "fat_per_100g": 3.2, "carbohydrates_per_100g": 3.4, "fiber_per_100g": 0, "sodium_per_100g": 37},
    {"food_name": "脱脂牛奶", "category": "egg_dairy", "calories_per_100g": 33, "protein_per_100g": 3.4, "fat_per_100g": 0.3, "carbohydrates_per_100g": 4.9, "fiber_per_100g": 0, "sodium_per_100g": 42},
    {"food_name": "酸奶", "food_name_en": "yogurt", "category": "egg_dairy", "calories_per_100g": 72, "protein_per_100g": 2.5, "fat_per_100g": 2.7, "carbohydrates_per_100g": 9.3, "fiber_per_100g": 0, "sodium_per_100g": 39},
    {"food_name": "奶酪", "category": "egg_dairy", "calories_per_100g": 328, "protein_per_100g": 25.7, "fat_per_100g": 23.5, "carbohydrates_per_100g": 3.5, "fiber_per_100g": 0, "sodium_per_100g": 584},

    # ---- 豆制品 ----
    {"food_name": "豆腐", "food_name_en": "tofu", "category": "bean", "calories_per_100g": 82, "protein_per_100g": 8.1, "fat_per_100g": 3.7, "carbohydrates_per_100g": 4.2, "fiber_per_100g": 0.4, "sodium_per_100g": 7.2},
    {"food_name": "豆浆", "food_name_en": "soy milk", "category": "bean", "calories_per_100g": 31, "protein_per_100g": 3.0, "fat_per_100g": 1.6, "carbohydrates_per_100g": 1.2, "fiber_per_100g": 1.1, "sodium_per_100g": 3},
    {"food_name": "黄豆", "category": "bean", "calories_per_100g": 390, "protein_per_100g": 35.0, "fat_per_100g": 16.0, "carbohydrates_per_100g": 34.2, "fiber_per_100g": 15.5, "sodium_per_100g": 2.2},
    {"food_name": "腐竹", "category": "bean", "calories_per_100g": 459, "protein_per_100g": 44.6, "fat_per_100g": 21.7, "carbohydrates_per_100g": 22.3, "fiber_per_100g": 1.0, "sodium_per_100g": 26.5},

    # ---- 坚果类 ----
    {"food_name": "花生", "category": "nut", "calories_per_100g": 601, "protein_per_100g": 21.7, "fat_per_100g": 48.0, "carbohydrates_per_100g": 23.8, "fiber_per_100g": 6.3, "sodium_per_100g": 34},
    {"food_name": "核桃", "category": "nut", "calories_per_100g": 646, "protein_per_100g": 14.9, "fat_per_100g": 58.8, "carbohydrates_per_100g": 19.1, "fiber_per_100g": 9.5, "sodium_per_100g": 6.4},
    {"food_name": "杏仁", "category": "nut", "calories_per_100g": 578, "protein_per_100g": 22.5, "fat_per_100g": 45.4, "carbohydrates_per_100g": 23.9, "fiber_per_100g": 8.0, "sodium_per_100g": 8},
    {"food_name": "腰果", "category": "nut", "calories_per_100g": 559, "protein_per_100g": 17.3, "fat_per_100g": 36.7, "carbohydrates_per_100g": 41.6, "fiber_per_100g": 3.6, "sodium_per_100g": 251},

    # ---- 常见菜品（按同名食材 + 常见烹调用油估算，能量明显高于生食材） ----
    {"food_name": "清蒸鲈鱼", "category": "dish", "calories_per_100g": 128, "protein_per_100g": 18.0, "fat_per_100g": 5.5, "carbohydrates_per_100g": 1.0, "fiber_per_100g": 0, "sodium_per_100g": 320},
    {"food_name": "白灼虾", "category": "dish", "calories_per_100g": 110, "protein_per_100g": 17.8, "fat_per_100g": 1.6, "carbohydrates_per_100g": 4.0, "fiber_per_100g": 0, "sodium_per_100g": 300},
    {"food_name": "西红柿炒鸡蛋", "category": "dish", "calories_per_100g": 118, "protein_per_100g": 6.5, "fat_per_100g": 8.5, "carbohydrates_per_100g": 4.5, "fiber_per_100g": 0.6, "sodium_per_100g": 380},
    {"food_name": "清炒西兰花", "category": "dish", "calories_per_100g": 68, "protein_per_100g": 3.8, "fat_per_100g": 4.5, "carbohydrates_per_100g": 4.0, "fiber_per_100g": 1.6, "sodium_per_100g": 300},
    {"food_name": "水煮鸡胸肉", "category": "dish", "calories_per_100g": 141, "protein_per_100g": 19.0, "fat_per_100g": 5.5, "carbohydrates_per_100g": 2.5, "fiber_per_100g": 0, "sodium_per_100g": 220},
    {"food_name": "番茄鸡蛋面", "category": "dish", "calories_per_100g": 132, "protein_per_100g": 5.2, "fat_per_100g": 3.8, "carbohydrates_per_100g": 19.5, "fiber_per_100g": 0.9, "sodium_per_100g": 420},
    {"food_name": "鸡公煲", "category": "dish", "calories_per_100g": 185, "protein_per_100g": 13.0, "fat_per_100g": 12.5, "carbohydrates_per_100g": 5.0, "fiber_per_100g": 0.8, "sodium_per_100g": 620},
]


def init() -> None:
    db = SessionLocal()
    try:
        created = 0
        for item in SEED_DATA:
            data = {**item, "data_source": SOURCE, "verified": False}
            existing = (
                db.query(FoodDatabase)
                .filter(FoodDatabase.food_name == data["food_name"])
                .first()
            )
            if existing:
                continue
            db.add(FoodDatabase(**data))
            created += 1
        db.commit()
        print(
            f"食物库初始化完成: 新增 {created} 条, 跳过 {len(SEED_DATA) - created} 条（已存在）"
        )
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
    finally:
        db.close()


if __name__ == "__main__":
    init()
