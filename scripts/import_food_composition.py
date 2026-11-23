#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""导入《中国食物成分表》→ food_database（聚合数据 11087 号数据包，MySQL dump 格式）

数据源: scripts/11087-sql/11087-sql/food_nutrition.sql
目标表: food_database（合并存储，data_source='中国食物成分表' 标识来源）
映射:   6 项核心营养 → 独立列；别名 → alias_name；其余微量营养素 → extra_nutrients(JSON)
特性:   kJ→kcal 换算、数值清洗（去单位/特殊符号转NULL）、幂等（按 data_source 全量重灌，
        与其他来源重名的食物跳过，现有数据优先）

用法: uv run python scripts/import_food_composition.py
"""
import re
import sys
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from shared.models.database import SessionLocal
from shared.models.food_models import FoodDatabase

SQL_PATH = Path(__file__).resolve().parent / "11087-sql" / "11087-sql" / "food_nutrition.sql"
KJ_TO_KCAL = Decimal("0.238846")
DATA_SOURCE = "中国食物成分表"

# 源列名 → food_database 核心列 的映射
CORE_FIELDS = {
    "energy": "calories_per_100g",      # 能量（kJ 换算成 kcal）
    "protein": "protein_per_100g",
    "fat": "fat_per_100g",
    "carbohydrate": "carbohydrates_per_100g",
    "dietary_fiber": "fiber_per_100g",
    "sodium": "sodium_per_100g",
}
# 其余全部进 extra_nutrients JSON（键名保持源语义）
EXTRA_FIELDS = [
    "edible_part", "water", "energy", "cholesterol", "ash", "carotene",
    "vitamin_a", "vitamin_e", "thiamin", "riboflavin", "niacin", "vitamin_c",
    "calcium", "phosphorus", "potassium", "magnesium", "iron", "zinc",
    "selenium", "copper", "manganese", "iodine", "sfa", "mufa", "pufa",
    "fatty_acids_total",
]

INVALID = {"", "—", "-", "--", "Tr", "trace", "NULL"}


def split_sql_values(body: str) -> list:
    """按顶层逗号切分 VALUES(...) 内部的值，容忍引号内的逗号与转义"""
    items, buf, in_str, i = [], [], False, 0
    while i < len(body):
        ch = body[i]
        if in_str:
            if ch == "\\" and i + 1 < len(body):
                buf.append(body[i:i + 2]); i += 2; continue
            if ch == "'":
                if i + 1 < len(body) and body[i + 1] == "'":
                    buf.append("''"); i += 2; continue
                in_str = False; buf.append(ch); i += 1; continue
            buf.append(ch); i += 1; continue
        if ch == "'":
            in_str = True; buf.append(ch); i += 1; continue
        if ch == ",":
            items.append("".join(buf).strip()); buf = []; i += 1; continue
        buf.append(ch); i += 1
    if buf:
        items.append("".join(buf).strip())
    return items


def unquote(v: str):
    """去掉 SQL 字面量的引号/NULL 标记"""
    if v.upper() == "NULL":
        return None
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1].replace("''", "'").replace("\\'", "'").replace('\\"', '"')
    return v


def clean_number(raw) -> Decimal | None:
    """清洗营养值字符串 → Decimal；无效/痕迹量转 None"""
    if raw is None:
        return None
    s = str(raw).strip()
    if s.lower() in INVALID:
        return None
    s = re.sub(r"(g|mg|μg|ug|kJ|kcal|%)$", "", s).strip()
    if s.lower() in INVALID or not s:
        return None
    try:
        return Decimal(s)
    except Exception:
        return None


def parse_dump(path: Path):
    """解析 MySQL dump，返回 (categories, foods) 原始行"""
    text = path.read_text(encoding="utf-8")
    bt = chr(96)
    rows = {"categories": [], "foods": []}

    for m in re.finditer(
        r"INSERT INTO " + bt + r"j_food_categories" + bt + r" \([^)]*\) VALUES \((.*?)\);",
        text, re.S,
    ):
        vals = split_sql_values(m.group(1))
        if len(vals) >= 6:
            rows["categories"].append([unquote(v) for v in vals])

    for m in re.finditer(
        r"INSERT INTO " + bt + r"j_food_nutrition" + bt + r" \((.*?)\) VALUES \((.*?)\);",
        text, re.S,
    ):
        cols = [c.strip().strip(bt) for c in m.group(1).split(",")]
        vals = split_sql_values(m.group(2))
        if len(cols) != len(vals):
            print(f"  [跳过] 列数不匹配: {vals[2] if len(vals) > 2 else vals}")
            continue
        rows["foods"].append(dict(zip(cols, [unquote(v) for v in vals])))
    return rows


def run():
    if not SQL_PATH.exists():
        sys.exit(f"找不到数据文件: {SQL_PATH}")

    data = parse_dump(SQL_PATH)
    print(f"解析完成: 分类 {len(data['categories'])} 条, 食物 {len(data['foods'])} 条")

    # cate_id(源字符串) → 分类名 的映射（食物行的 cate_id 指向子分类）
    cate_title = {}
    for r in data["categories"]:
        if r[3] not in (None, "0"):
            cate_title[str(r[3])] = r[1]

    db = SessionLocal()
    try:
        # 幂等：先清掉本来源的历史数据，再全量重灌（其他来源的数据不动）
        db.query(FoodDatabase).filter(FoodDatabase.data_source == DATA_SOURCE).delete()
        db.flush()

        # 其他来源已占用的食物名：跳过，现有数据优先
        taken_names = {
            name for (name,) in db.query(FoodDatabase.food_name).all()
        }
        taken_codes = {
            code for (code,) in db.query(FoodDatabase.food_code).all()
        }

        inserted, skipped_name, skipped_code, no_name = 0, 0, 0, 0
        for f in data["foods"]:
            name = (f.get("food_name") or "").strip()
            if not name:
                no_name += 1
                continue
            code = f"CN{f['id']}"
            if code in taken_codes:
                skipped_code += 1
                continue
            if name in taken_names:
                skipped_name += 1
                continue

            core = {}
            for src, dst in CORE_FIELDS.items():
                val = clean_number(f.get(src))
                if src == "energy":
                    core[dst] = round(val * KJ_TO_KCAL, 2) if val is not None else None
                else:
                    core[dst] = val
            extra = {}
            for field in EXTRA_FIELDS:
                val = clean_number(f.get(field))
                if val is not None:
                    extra[field] = float(val)

            db.add(FoodDatabase(
                food_code=code,
                food_name=name,
                food_name_en=(f.get("english_name") or None),
                alias_name=(f.get("alias_name") or None),
                category=cate_title.get(str(f.get("cate_id") or "")),
                data_source=DATA_SOURCE,
                **core,
                extra_nutrients=extra or None,
            ))
            taken_names.add(name)
            inserted += 1

        db.commit()
        total = db.query(FoodDatabase).count()
        from_source = db.query(FoodDatabase).filter(FoodDatabase.data_source == DATA_SOURCE).count()
        with_extra = db.query(FoodDatabase).filter(FoodDatabase.extra_nutrients.isnot(None)).count()
        print(f"导入完成: 新增 {inserted} 条 (重名跳过 {skipped_name}, 编码冲突 {skipped_code}, 无名称 {no_name})")
        print(f"food_database 现有总量 {total} 条, 其中成分表来源 {from_source} 条, 含微量营养素 {with_extra} 条")
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    run()
