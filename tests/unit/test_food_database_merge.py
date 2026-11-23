# -*- coding: utf-8 -*-
"""中国食物成分表并入 food_database 后的行为测试：
match_food 别名/英文匹配生效、extra_nutrients 数据完整、导入映射数值正确
"""
import pytest

from shared.models.food_models import FoodDatabase
from shared.services.food_matching import match_food


@pytest.fixture
def seeded_food_db(db_session):
    """最小数据集：2 条成分表来源（带别名/英文/JSON）+ 1 条旧来源（验证现有数据优先语义）"""
    db_session.query(FoodDatabase).delete()
    db_session.flush()

    db_session.add_all([
        FoodDatabase(
            food_code="CN259", food_name="小麦粉(标准粉)", alias_name="面粉", category="小麦",
            calories_per_100g=357.55, protein_per_100g=11.2, fat_per_100g=1.5,
            carbohydrates_per_100g=73.6, sodium_per_100g=3.1,
            extra_nutrients={"energy_kj": 1497, "calcium": 31, "iron": 3.5},
            data_source="中国食物成分表",
        ),
        FoodDatabase(
            food_code="CN300", food_name="稻米(粳米)", food_name_en="rice", category="稻米",
            calories_per_100g=345.85, protein_per_100g=7.7,
            extra_nutrients={"energy_kj": 1448},
            data_source="中国食物成分表",
        ),
        FoodDatabase(
            food_code="US001", food_name="西红柿", category="vegetables",
            calories_per_100g=18.0, protein_per_100g=0.9,
            data_source="usda",
        ),
    ])
    db_session.flush()
    return db_session


# ---------- match_food 别名/英文匹配（并入的两层） ----------

def test_alias_exact_hit(seeded_food_db):
    """「面粉」是别名，原三级匹配命中不了，现 alias 层精确命中"""
    result = match_food(seeded_food_db, "面粉")
    assert result is not None
    assert result["matched_name"] == "小麦粉(标准粉)"
    assert result["per_100g"]["calories"] == 357.55


def test_exact_name_still_wins_over_alias(seeded_food_db):
    """同输入既命中精确名又命中他条别名时，精确名优先"""
    db = seeded_food_db
    db.add(FoodDatabase(food_code="X1", food_name="面粉", calories_per_100g=350.0))
    db.flush()
    result = match_food(db, "面粉")
    assert result["matched_name"] == "面粉"


def test_english_name_fuzzy_hit(seeded_food_db):
    """英文别名模糊命中（VLM 输出英文名时兜底）"""
    result = match_food(seeded_food_db, "Rice")
    assert result is not None
    assert result["matched_name"] == "稻米(粳米)"


def test_reverse_containment_unaffected(seeded_food_db):
    """原有反向包含层不受改动影响：「水煮西红柿」→「西红柿」（输入含完整库名才命中）"""
    result = match_food(seeded_food_db, "水煮西红柿")
    assert result is not None
    assert result["matched_name"] == "西红柿"


def test_no_match_returns_none(seeded_food_db):
    assert match_food(seeded_food_db, "完全不存在的东西xyz") is None


# ---------- 数据完整性（导入映射语义） ----------

def test_extra_nutrients_stored_and_readable(seeded_food_db):
    """微量营养素 JSON 存得进、读得出（零丢弃）"""
    row = seeded_food_db.query(FoodDatabase).filter(
        FoodDatabase.food_code == "CN259").first()
    assert row.extra_nutrients["energy_kj"] == 1497
    assert row.extra_nutrients["calcium"] == 31
    assert row.extra_nutrients["iron"] == 3.5


def test_data_source_marks_origin(seeded_food_db):
    sources = {s for (s,) in seeded_food_db.query(FoodDatabase.data_source).all()}
    assert "中国食物成分表" in sources and "usda" in sources


def test_old_rows_keep_priority_semantics(seeded_food_db):
    """旧来源行（usda）的匹配行为不变——用户记录「西红柿」仍命中旧数据"""
    result = match_food(seeded_food_db, "西红柿")
    assert result is not None
    assert result["per_100g"]["calories"] == 18.0
