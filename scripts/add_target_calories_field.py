"""
手动添加 target_calories 字段到 user_profiles 表
"""
import sys
import os

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from shared.models.database import SessionLocal, engine

def add_target_calories_field():
    """添加 target_calories 字段"""
    db = SessionLocal()
    try:
        # 检查字段是否已存在
        result = db.execute(text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name='user_profiles'
            AND column_name='target_calories'
        """)).fetchone()

        if result:
            print("✓ target_calories 字段已存在")
            return

        # 添加字段
        db.execute(text("""
            ALTER TABLE user_profiles
            ADD COLUMN target_calories INTEGER DEFAULT 2000
        """))
        db.commit()
        print("✓ 成功添加 target_calories 字段")

        # 更新现有记录
        db.execute(text("""
            UPDATE user_profiles
            SET target_calories = 2000
            WHERE target_calories IS NULL
        """))
        db.commit()
        print("✓ 已更新现有记录的默认值为 2000")

    except Exception as e:
        db.rollback()
        print(f"✗ 添加字段失败: {e}")
        raise
    finally:
        db.close()

if __name__ == "__main__":
    print("开始添加 target_calories 字段...")
    add_target_calories_field()
    print("完成！")