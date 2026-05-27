from sqlalchemy.orm import Session
from shared.models.wellness_models import WellnessKnowledge
from typing import Optional


def get_daily_wellness_recommendation(db: Session, solar_term: str, season: str, constitution_type: Optional[str] = None) -> dict:
    """获取每日养生推荐"""
    knowledge = db.query(WellnessKnowledge).filter(
        WellnessKnowledge.solar_term == solar_term,
        WellnessKnowledge.season == season
    ).first()

    result = {
        "current_solar_term": solar_term,
        "current_season": season,
        "constitution_type": constitution_type,
        "recommended_ingredients": knowledge.recommended_foods.get("ingredients", []) if knowledge else [],
        "recommended_recipes": knowledge.recommended_foods.get("recipes", []) if knowledge else [],
        "wellness_tips": [knowledge.content] if knowledge else [],
        "foods_to_avoid": knowledge.avoid_foods.get("items", []) if knowledge else [],
    }

    return result


def get_solar_terms(db: Session, year: int = 2026) -> list[dict]:
    """获取该年所有节气日期"""
    records = db.query(WellnessKnowledge).filter(
        WellnessKnowledge.category == "节气"
    ).all()
    # 简单返回结构，真实日期需要按规则计算，这里仅示例
    return [
        {"name": r.solar_term, "date": r.solar_term, "description": r.title}
        for r in records if r.solar_term
    ]