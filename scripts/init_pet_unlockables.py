#!/usr/bin/env python3
"""宠物可解锁内容种子数据初始化脚本

使用方式: uv run python scripts/init_pet_unlockables.py

该脚本可在迁移之外手动执行，用于：
- 新增解锁内容
- 重置解锁数据（使用 --reset 清空后重新插入）
"""
import sys
from pathlib import Path

# 添加项目根目录到 path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from shared.models.database import SessionLocal
from shared.models.pet_models import PetUnlockable

SEED_DATA = [
    # 默认桌宠（原第一只桌宠）
    {"unlock_type": "skin", "unlock_key": "default", "name": "默认桌宠",
     "description": "可爱的基础宠物形象", "required_level": 1, "required_streak": None, "required_habit_score": None},
    # 克里斯汀（第二只桌宠）
    {"unlock_type": "skin", "unlock_key": "christine", "name": "克里斯汀",
     "description": "优雅的第二只桌宠形象", "required_level": 1, "required_streak": None, "required_habit_score": None},
    # 其他皮肤和动作
    {"unlock_type": "skin", "unlock_key": "summer", "name": "夏日清凉",
     "description": "夏日海滩风格外观", "required_level": 3, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "skin", "unlock_key": "sporty", "name": "运动活力",
     "description": "运动装备外观", "required_level": 5, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "action", "unlock_key": "happy_spin", "name": "开心转圈",
     "description": "达标后的开心转圈动作", "required_level": None, "required_streak": 3, "required_habit_score": None},
    {"unlock_type": "action", "unlock_key": "feed_eat", "name": "进食动画",
     "description": "喂食时的进食动作", "required_level": None, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "effect", "unlock_key": "gold_sparkle", "name": "金色光效",
     "description": "升级时的金色闪光效果", "required_level": 10, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "skin", "unlock_key": "winter", "name": "冬日暖阳",
     "description": "冬日温馨风格外观", "required_level": 8, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "skin", "unlock_key": "festival", "name": "节日盛装",
     "description": "节日特别版外观", "required_level": 12, "required_streak": None, "required_habit_score": 85},
    {"unlock_type": "action", "unlock_key": "level_up", "name": "升级庆祝",
     "description": "升级时的庆祝动作", "required_level": 2, "required_streak": None, "required_habit_score": None},
    {"unlock_type": "action", "unlock_key": "water_great", "name": "饮水达人",
     "description": "饮水达标时的喝彩动作", "required_level": None, "required_streak": 7, "required_habit_score": None},
]


def init_unlockables(reset: bool = False):
    """初始化可解锁内容数据"""
    db = SessionLocal()
    try:
        if reset:
            deleted = db.query(PetUnlockable).delete()
            db.commit()
            print(f"已清除 {deleted} 条旧数据")

        created = 0
        skipped = 0
        for item in SEED_DATA:
            existing = db.query(PetUnlockable).filter(
                PetUnlockable.unlock_key == item["unlock_key"]
            ).first()
            if existing:
                skipped += 1
                continue

            u = PetUnlockable(**item)
            db.add(u)
            created += 1

        db.commit()
        print(f"种子数据初始化完成: 新增 {created}, 跳过 {skipped} (已存在)")
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="初始化宠物可解锁内容")
    parser.add_argument("--reset", action="store_true", help="清空后重新插入")
    args = parser.parse_args()

    init_unlockables(reset=args.reset)
