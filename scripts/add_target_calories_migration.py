"""
使用正确的数据库凭据添加 target_calories 字段
"""
import psycopg2
import sys

# 数据库连接参数（从 .env.dev 读取）
DB_CONFIG = {
    'host': 'localhost',
    'database': 'dietai_db',
    'user': 'dietai',
    'password': 'dietai123',
    'port': 5432
}

def add_target_calories_field():
    """添加 target_calories 字段"""
    conn = None
    try:
        print(f"正在连接数据库: {DB_CONFIG['database']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}")

        # 连接数据库
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor()
        print("✓ 数据库连接成功")

        # 检查字段是否已存在
        cur.execute("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name='user_profiles'
            AND column_name='target_calories'
        """)
        result = cur.fetchone()

        if result:
            print("✓ target_calories 字段已存在，无需添加")
            cur.close()
            return

        # 添加字段
        print("正在添加 target_calories 字段...")
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
        affected_rows = cur.rowcount
        conn.commit()
        print(f"✓ 已更新 {affected_rows} 条记录的默认值为 2000")

        # 验证字段
        cur.execute("""
            SELECT COUNT(*)
            FROM user_profiles
            WHERE target_calories IS NOT NULL
        """)
        count = cur.fetchone()[0]
        print(f"✓ 验证：{count} 条记录已有卡路里目标")

        cur.close()

    except psycopg2.OperationalError as e:
        print(f"✗ 数据库连接失败: {e}")
        print("\n可能的解决方案：")
        print("1. 确认 PostgreSQL 服务正在运行")
        print("2. 确认数据库 dietai_db 存在")
        print("3. 确认用户名和密码正确")
        sys.exit(1)
    except Exception as e:
        print(f"✗ 添加字段失败: {e}")
        if conn:
            conn.rollback()
        sys.exit(1)
    finally:
        if conn:
            conn.close()
            print("\n数据库连接已关闭")

if __name__ == "__main__":
    print("=" * 60)
    print("开始添加 target_calories 字段到数据库")
    print("=" * 60)
    add_target_calories_field()
    print("=" * 60)
    print("数据库迁移完成！")
    print("=" * 60)