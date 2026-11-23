"""健康档案类写动作的共用纯函数（V6 健康档案扩权）。

动作按名称在用户档案里定位条目（「骨折」→ diseases 表里的那一行），
但 `Disease.disease_name` / `Allergy.allergen_name` 是字段级加密列
（`EncryptedString`）：`shared/utils/field_encryption.py` 每次加密都用新的随机
nonce，同一明文的密文完全不同 —— SQL 的 `LIKE` / `==` 对它们**完全失效**。

因此匹配必须：整表取回该用户的档案 → 让 ORM 自动解密 → 在 Python 侧比对。
本模块只放纯函数（不碰数据库、不调模型），便于单测直接覆盖。
"""

import re
from typing import Optional, Sequence

# 健康目标区间（口径对齐 shared/models/schemas/user.py 的 UserProfileUpdate）
MIN_TARGET_CALORIES = 800
MAX_TARGET_CALORIES = 5000
MIN_WATER_GOAL_ML = 500
MAX_WATER_GOAL_ML = 5000


def normalize_name(value: Optional[str]) -> str:
    """档案名称归一：去掉所有空白 + 转小写。

    「青霉素 」「青霉素」「 Penicillin 」归一后可比；中文场景只做去空白与大小写。
    """
    if value is None:
        return ""
    return re.sub(r"\s+", "", str(value)).lower()


def match_indices_by_name(candidates: Sequence[str], query: str) -> list[int]:
    """按名称双向包含匹配，返回候选下标列表（0 基，顺序与原表一致）。

    双向包含：用户说「骨折」，档案里写的是「腕部骨折」也算命中；反之亦然。
    归一后为空的一侧不参与匹配（避免空串命中一切）。
    多个命中时由调用方决定取舍（当前实现取第一条并告知用户）。
    """
    needle = normalize_name(query)
    if not needle:
        return []
    hits: list[int] = []
    for index, candidate in enumerate(candidates):
        haystack = normalize_name(candidate)
        if not haystack:
            continue
        if needle in haystack or haystack in needle:
            hits.append(index)
    return hits


def validate_targets(
    target_calories: Optional[int],
    daily_water_goal: Optional[int],
) -> Optional[str]:
    """校验健康目标入参：合法返回 None，非法返回给用户看的错误文案。

    规则：至少给一个；热量 800-5000 kcal，饮水 500-5000 ml（与页面端同一口径）。
    """
    if target_calories is None and daily_water_goal is None:
        return "请至少给出一个目标：每日热量（kcal）或每日饮水（ml）"
    if target_calories is not None and not (
        MIN_TARGET_CALORIES <= int(target_calories) <= MAX_TARGET_CALORIES
    ):
        return (
            f"热量目标 {target_calories} 超出合理范围"
            f"（{MIN_TARGET_CALORIES}-{MAX_TARGET_CALORIES} kcal），请确认后再试"
        )
    if daily_water_goal is not None and not (
        MIN_WATER_GOAL_ML <= int(daily_water_goal) <= MAX_WATER_GOAL_ML
    ):
        return (
            f"饮水目标 {daily_water_goal} 超出合理范围"
            f"（{MIN_WATER_GOAL_ML}-{MAX_WATER_GOAL_ML} ml），请确认后再试"
        )
    return None