import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.models.database import SessionLocal
from shared.models.wellness_models import WellnessKnowledge
import json

data = [
    {
        "category": "节气",
        "sub_category": "小满",
        "title": "小满节气饮食指南",
        "content": "小满时节，气温升高，雨水增多，宜食清热利湿之品。",
        "recommended_foods": json.dumps({"ingredients": ["苦瓜", "冬瓜", "薏仁", "绿豆", "莲藕"], "recipes": [{"name": "苦瓜炒蛋", "description": "苦瓜切片，与鸡蛋同炒，清热解暑", "benefits": "清心明目，降血糖"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣食物", "油炸食物", "生冷食物"]}),
        "applicable_constitutions": json.dumps(["平和质", "痰湿质", "湿热质"]),
        "season": "夏季",
        "solar_term": "小满"
    },
    {
        "category": "节气",
        "sub_category": "芒种",
        "title": "芒种节气饮食指南",
        "content": "芒种时节，梅雨开始，宜吃清淡易消化、健脾祛湿的食物。",
        "recommended_foods": json.dumps({"ingredients": ["山药", "白术", "茯苓", "赤小豆", "鸭肉"], "recipes": [{"name": "山药茯苓粥", "description": "山药、茯苓、粳米同煮，健脾祛湿", "benefits": "健脾益气，利水渗湿"}]}),
        "avoid_foods": json.dumps({"items": ["油腻食物", "甜腻食物", "冷饮"]}),
        "applicable_constitutions": json.dumps(["气虚质", "阳虚质", "痰湿质"]),
        "season": "夏季",
        "solar_term": "芒种"
    },
    {
        "category": "季节",
        "sub_category": "夏季",
        "title": "夏季养生饮食要点",
        "content": "夏季属火，对应心，宜清心消暑，多食瓜果蔬菜，少食辛辣。",
        "recommended_foods": json.dumps({"ingredients": ["西瓜", "黄瓜", "番茄", "莲子", "百合"], "recipes": [{"name": "莲子百合粥", "description": "莲子、百合与大米熬粥，清心安神", "benefits": "养心安神，清热解暑"}]}),
        "avoid_foods": json.dumps({"items": ["辛辣烧烤", "高度白酒", "麻辣火锅"]}),
        "applicable_constitutions": json.dumps(["平和质", "阴虚质"]),
        "season": "夏季",
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "痰湿质",
        "title": "痰湿体质饮食调养",
        "content": "痰湿质者宜清淡，多食健脾利湿之品，忌肥甘厚腻。",
        "recommended_foods": json.dumps({"ingredients": ["薏苡仁", "赤小豆", "冬瓜", "荷叶", "白萝卜"], "recipes": [{"name": "冬瓜薏米汤", "description": "冬瓜连皮切块，与薏米同煮，利水消肿", "benefits": "健脾利湿，化痰消脂"}]}),
        "avoid_foods": json.dumps({"items": ["肥肉", "奶油", "甜食", "啤酒"]}),
        "applicable_constitutions": json.dumps(["痰湿质"]),
        "season": None,
        "solar_term": None
    },
    {
        "category": "体质",
        "sub_category": "阳虚质",
        "title": "阳虚体质饮食调养",
        "content": "阳虚质宜温补阳气，多食温性食物，忌生冷寒凉。",
        "recommended_foods": json.dumps({"ingredients": ["羊肉", "生姜", "桂圆", "红枣", "核桃"], "recipes": [{"name": "当归生姜羊肉汤", "description": "当归、生姜与羊肉同炖，温阳补血", "benefits": "温中散寒，补气养血"}]}),
        "avoid_foods": json.dumps({"items": ["西瓜", "梨", "冷饮", "生鱼片"]}),
        "applicable_constitutions": json.dumps(["阳虚质"]),
        "season": None,
        "solar_term": None
    },
]

def init_data():
    db = SessionLocal()
    try:
        for item in data:
            exists = db.query(WellnessKnowledge).filter(
                WellnessKnowledge.category == item["category"],
                WellnessKnowledge.sub_category == item["sub_category"]
            ).first()
            if not exists:
                db.add(WellnessKnowledge(**item))
        db.commit()
        print(f"成功插入养生知识数据，共 {len(data)} 条")
    except Exception as e:
        db.rollback()
        print(f"数据插入失败: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    init_data()