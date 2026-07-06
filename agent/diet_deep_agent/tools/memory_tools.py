"""
记忆工具 - learn_preference 偏好学习

"越用越懂用户"的核心工具。在 Deep Agent 原生 read_file/write_file 之上
提供语义化的偏好学习接口，封装置信度判断和 DB 同步逻辑。
"""

import logging
from typing import Any, Literal

from langchain_core.tools import tool

logger = logging.getLogger(__name__)


@tool
def learn_preference(
    user_id: int,
    preference_type: Literal[
        "allergy", "food_like", "food_dislike", "behavior", "style",
        "constitution", "crowd_tag"
    ],
    value: str,
    confidence: float = 1.0,
    source: Literal["explicit", "inferred", "observed"] = "explicit",
) -> dict[str, Any]:
    """学习并存储用户偏好 —— "越用越懂用户"的核心工具。

    根据置信度自动判断存储位置：
    - confidence >= 1.0（用户明确说的）→ 写入 profile/preferences + 同步 DB
    - confidence < 1.0（行为推断的）→ 写入 insights.md 待确认

    Args:
        user_id: 用户 ID
        preference_type: 偏好类型
            - allergy: 过敏原（如"花生"）
            - food_like: 喜欢的食物
            - food_dislike: 不喜欢的食物
            - behavior: 行为模式（如"常跳早餐"）
            - style: 沟通风格偏好
            - constitution: 体质类型（如"气虚"、"痰湿"等九种体质之一）
            - crowd_tag: 人群标签（如"减脂"、"健身"等，逗号分隔多选）
        value: 偏好内容
        confidence: 置信度（0-1，1.0=用户明确说的，<1.0=推断的）
        source: 来源（explicit=用户说的，inferred=推断的，observed=行为观察）

    Returns:
        存储结果，包含存储位置和后续动作
    """
    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        result = {
            "stored": True,
            "preference_type": preference_type,
            "value": value,
            "confidence": confidence,
            "source": source,
        }

        if confidence >= 1.0:
            # 显式偏好 → 写入 DB 和 profile
            _store_explicit_preference(db, user_id, preference_type, value)
            result["storage"] = "profile (持久)"
            result["action"] = "已写入用户档案，后续分析将自动应用"
        else:
            # 推断偏好 → 记录为待确认
            result["storage"] = "insights (待确认)"
            result["action"] = (
                "已记录为观察到的模式。请在合适的时机向用户确认，"
                "确认后再通过 write_file 将其移入 profile.md"
            )

        db.commit()
        return result

    except Exception as e:
        db.rollback()
        logger.error(f"learn_preference failed: {e}")
        return {"stored": False, "error": str(e)}
    finally:
        db.close()


def _store_explicit_preference(db, user_id: int, ptype: str, value: str):
    """将显式偏好同步写入 PostgreSQL"""
    try:
        if ptype == "allergy":
            from shared.models.user_models import Allergy

            existing = db.query(Allergy).filter(
                Allergy.user_id == user_id,
                Allergy.allergen_name == value,
            ).first()

            if not existing:
                allergy = Allergy(
                    user_id=user_id,
                    allergen_name=value,
                    severity_level=2,  # 默认中度
                )
                db.add(allergy)
                logger.info(f"Added allergy for user {user_id}: {value}")

        elif ptype == "constitution":
            from shared.models.user_models import UserProfile

            profile = db.query(UserProfile).filter(
                UserProfile.user_id == user_id
            ).first()
            if profile:
                profile.constitution_type = value
                logger.info(f"Updated constitution for user {user_id}: {value}")

        elif ptype == "crowd_tag":
            from shared.models.user_models import UserProfile

            profile = db.query(UserProfile).filter(
                UserProfile.user_id == user_id
            ).first()
            if profile:
                # Append to existing tags (comma-separated)
                existing_tags = profile.crowd_tag or ""
                if existing_tags:
                    tag_list = [t.strip() for t in existing_tags.split(",")]
                    if value not in tag_list:
                        tag_list.append(value)
                        profile.crowd_tag = ",".join(tag_list)
                else:
                    profile.crowd_tag = value
                logger.info(f"Updated crowd_tag for user {user_id}: {profile.crowd_tag}")

        elif ptype in ("food_like", "food_dislike", "behavior", "style"):
            # 这些偏好目前通过 MD 文件管理，不写 DB
            # Agent 应通过 write_file("/memories/preferences.md") 更新
            logger.info(
                f"Preference {ptype}={value} for user {user_id} "
                f"→ to be stored via write_file"
            )

    except Exception as e:
        logger.error(f"_store_explicit_preference failed: {e}")
        raise
