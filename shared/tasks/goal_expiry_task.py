"""
健康目标自动过期任务

每天凌晨 00:05 执行，将超过 target_date 的进行中目标（current_status=1）
自动标记为已过期（current_status=5），保留所有历史记录。
"""

import logging
from datetime import date

from shared.models.database import SessionLocal
from shared.models.user_models import HealthGoal

logger = logging.getLogger(__name__)


def auto_expire_goals():
    """将已过目标日期的进行中目标标记为已过期"""
    logger.info("[健康目标过期] 开始检查")
    db = SessionLocal()
    try:
        today = date.today()
        expired_count = (
            db.query(HealthGoal)
            .filter(
                HealthGoal.current_status == 1,  # 进行中
                HealthGoal.target_date.isnot(None),
                HealthGoal.target_date < today,
            )
            .update(
                {HealthGoal.current_status: 5},  # 5: 已过期
                synchronize_session="fetch",
            )
        )
        db.commit()
        logger.info(f"[健康目标过期] 已将 {expired_count} 个目标标记为已过期")
    except Exception as e:
        db.rollback()
        logger.error(f"[健康目标过期] 任务执行失败: {e}")
    finally:
        db.close()
