"""食物名匹配：把用户口语化的食物描述映射到 food_database

对话里用户常这样说，而原先「库名包含输入」的单条规则一概匹配不到：
  - 复合表达：「鸡公煲、米饭」「鸡胸肉+西兰花」
  - 带做法修饰：「水煮鸡胸肉」「清蒸鲈鱼」「全麦面包片」
  - 带份量单位：「鸡胸肉 150g」「1个苹果」
  - 全角字符：「１５０克鸡胸肉」

本模块把匹配拆成三步：
  1. 归一化：NFKC 全角转半角 → 去口语噪声词 → 去份量与单位
     （份量本身由 extract_portion_grams 解析出来，供调用方按真实克数换算）
  2. 切分：按顿号/逗号/斜杠/加号/空白等分隔符拆成多段
  3. 逐段匹配：精确 → 反向包含（库名被输入包含，取最长最具体）→ 正向包含（库名包含输入）

多段全部命中时逐项求和（口径为「各 100g」，属于估算），matched_name 用 " + " 拼接。

record_food 动作、food_router 自动填充、回溯脚本共用本模块，
避免各写一份匹配规则导致口径不一致。
"""

import re
import unicodedata
from typing import Any, Optional

from sqlalchemy import func, literal

from shared.models.food_models import FoodDatabase

# 份量与单位（NFKC 归一后单位均为半角）。第一个捕获组是数量，第二个是单位。
_PORTION_RE = re.compile(
    r"(\d+(?:\.\d+)?)\s*"
    r"(kg|千克|公斤|g|克|ml|毫升|l|升|两|斤|份|碗|杯|个|只|片|块|勺|条|根|颗|粒|瓶|袋)",
    re.IGNORECASE,
)

# 重量/体积单位 → 克。计数单位（份/碗/个/片…）没有可靠换算，不在此表中，
# 这类描述（如「2个鸡蛋」）由调用方回落到默认份量。
_UNIT_TO_GRAMS = {
    "g": 1.0,
    "克": 1.0,
    "ml": 1.0,
    "毫升": 1.0,
    "kg": 1000.0,
    "千克": 1000.0,
    "公斤": 1000.0,
    "l": 1000.0,
    "升": 1000.0,
    "两": 50.0,
    "斤": 500.0,
}

# 口语噪声词（只收录明确不影响食物名的词）
_NOISE_WORDS = ("大约", "大概", "差不多", "左右", "一些", "一点")

# 分隔符：顿号、逗号、斜杠、加号、与号、分号、空白，以及口语连接词
# 注意：「和」也做分隔，因此库中若出现「和牛」这类含「和」的食物名会被误切，需在加库时避开
_SEPARATOR_RE = re.compile(r"[、,，/\\+＋&;；\s\u3000]+|(?:还有|以及|外加|加上|和|跟|与)")

# 反向包含匹配要求库名至少 2 个字，避免单字库名（如「虾」）把无关输入吃掉
_MIN_REVERSE_NAME_LEN = 2


def normalize_food_text(text: str) -> str:
    """全角转半角 + 去噪声词 + 去份量单位（保留分隔符，便于后续切分）"""
    if not text:
        return ""
    normalized = unicodedata.normalize("NFKC", str(text))
    for word in _NOISE_WORDS:
        normalized = normalized.replace(word, "")
    normalized = _PORTION_RE.sub("", normalized)
    return normalized.strip("。-—~·:：!！?？")


def extract_portion_grams(text: str) -> Optional[float]:
    """从原始描述里提取份量（克）

    只认重量/体积单位（g/kg/克/千克/公斤/毫升/升/两/斤），
    计数单位（份/碗/个/片…）没有可靠换算，返回 None 交给调用方用默认份量。
    """
    if not text:
        return None
    matched = _PORTION_RE.search(unicodedata.normalize("NFKC", str(text)))
    if matched is None:
        return None
    unit = matched.group(2).lower()
    factor = _UNIT_TO_GRAMS.get(unit)
    if factor is None:
        return None
    grams = float(matched.group(1)) * factor
    return round(grams, 2) if grams > 0 else None


def _clean_part(part: str) -> str:
    """清理单个片段：去掉内部空白与首尾标点"""
    return re.sub(r"[\s\u3000]+", "", part).strip("。-—~·:：!！?？")


def split_food_parts(text: str) -> list[str]:
    """把「鸡公煲、米饭」这类复合描述拆成 [「鸡公煲」, 「米饭」]，并按出现顺序去重"""
    normalized = normalize_food_text(text)
    if not normalized:
        return []

    parts: list[str] = []
    for raw in _SEPARATOR_RE.split(normalized):
        part = _clean_part(raw)
        if part and part not in parts:
            parts.append(part)
    return parts


def _per_100g(row: FoodDatabase) -> dict[str, float]:
    """取一行食物库记录的营养（每 100g），键名与 NutritionDetail 对齐"""
    return {
        "calories": float(row.calories_per_100g or 0),
        "protein": float(row.protein_per_100g or 0),
        "fat": float(row.fat_per_100g or 0),
        "carbohydrates": float(row.carbohydrates_per_100g or 0),
        "dietary_fiber": float(row.fiber_per_100g or 0),
        "sodium": float(row.sodium_per_100g or 0),
    }


def _match_one(db: Any, part: str) -> Optional[FoodDatabase]:
    """单段匹配：精确 → 反向包含 → 正向包含"""
    row = db.query(FoodDatabase).filter(FoodDatabase.food_name == part).first()
    if row is not None:
        return row

    # 反向包含：输入里含着库名，如「水煮鸡胸肉」→「鸡胸肉」。
    # 按库名长度倒序取，保证更具体的条目优先。
    row = (
        db.query(FoodDatabase)
        .filter(func.length(FoodDatabase.food_name) >= _MIN_REVERSE_NAME_LEN)
        .filter(
            literal(part).like(
                func.concat(literal("%"), FoodDatabase.food_name, literal("%"))
            )
        )
        .order_by(func.length(FoodDatabase.food_name).desc(), FoodDatabase.id)
        .first()
    )
    if row is not None:
        return row

    # 正向包含：库名含着输入，如「鸡胸」→「鸡胸肉」。取最短库名（最贴近输入）。
    escaped = part.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return (
        db.query(FoodDatabase)
        .filter(FoodDatabase.food_name.ilike(f"%{escaped}%", escape="\\"))
        .order_by(func.length(FoodDatabase.food_name), FoodDatabase.id)
        .first()
    )


def match_food(db: Any, food_name: str) -> Optional[dict[str, Any]]:
    """把用户说法匹配到食物库

    Returns:
        None（完全匹配不到）或
        {
          "matched_name": 命中库名，多段时用 " + " 拼接,
          "per_100g": 营养（多段命中时为各段之和，口径「各 100g」）,
          "parts": [{"input": 用户说法, "matched": 库名}, ...],
          "multi_part": 是否由多段合并而来,
          "portion_grams": 从原始描述解析出的份量（克），识别不到或复合描述时为 None,
        }
    """
    parts = split_food_parts(food_name)
    if not parts:
        return None

    hits: list[tuple[str, FoodDatabase]] = []
    for part in parts:
        row = _match_one(db, part)
        if row is not None:
            hits.append((part, row))

    if not hits:
        return None

    detail = [{"input": part, "matched": row.food_name} for part, row in hits]

    if len(hits) == 1:
        _, row = hits[0]
        return {
            "matched_name": row.food_name,
            "per_100g": _per_100g(row),
            "parts": detail,
            "multi_part": False,
            # 复合描述里的份量无法折算成单一份量（各段份量不同），故只在单段时解析
            "portion_grams": extract_portion_grams(food_name),
        }

    totals = {key: 0.0 for key in _per_100g(hits[0][1])}
    for _, row in hits:
        for key, value in _per_100g(row).items():
            totals[key] += value

    return {
        "matched_name": " + ".join(row.food_name for _, row in hits),
        "per_100g": {key: round(value, 2) for key, value in totals.items()},
        "parts": detail,
        "multi_part": True,
        "portion_grams": None,
    }
