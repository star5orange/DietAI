"""
使用 psycopg2 直接连接数据库添加字段
"""
import psycopg2
from psycopg2 import sql

# 数据库连接参数（根据实际情况修改）
DB_CONFIG = {
    'host': 'localhost',
    'database': 'dietai',
    'user': 'postgres',
    'password': '123456',
    'port': 5432
}

def add_target_calories_field():
    """添加 target_calories 字段"""
    conn = None
    try:
        # 连接数据库
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()

        # 检查字段是否已存在
        cur.execute("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name='user_profiles'
            AND column_name='target_calories'
        """)
        result = cur.fetchone()

        if result:
            print("✓ target_calories 字段已存在")
            return

        # 添加字段
        cur.execute("""
            ALTER TABLE user_profiles
            ADD COLUMN target_calories INTEGER DEFAULT 2000
        """)
        conn.commit()
        print("✓ 成功添加 target_calories 字段")

        # 更新现有记录
        cur.execute("""
            UPDATE user_profiles
            SET target_calories = 2000
            WHERE target_calories IS NULL
        """)
        conn.commit()
        print("✓ 已更新现有记录的默认值为 2000")

        cur.close()

    except Exception as e:
        print(f"✗ 添加字段失败: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("开始添加 target_calories 字段...")
    add_target_calories_field()
    print("完成！")