"""
数据库迁移脚本：为 fasting_plans 表添加 fasting_days 字段

运行方式：
    python scripts/add_fasting_days_migration.py
"""

import os
import psycopg2
from dotenv import load_dotenv

# 加载环境变量
load_dotenv('.env.dev')


def migrate():
    """添加 fasting_days 字段到 fasting_plans 表"""
    # 从环境变量获取数据库连接信息
    database_url = os.getenv('DIETAI_DATABASE_URL', 'postgresql://dietai:dietai123@localhost:5432/dietai_db')
    
    # 解析数据库URL
    # 格式: postgresql://user:password@host:port/database
    import re
    match = re.match(r'postgresql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)', database_url)
    if not match:
        print("❌ 无法解析数据库URL")
        return
    
    user, password, host, port, database = match.groups()
    
    conn = psycopg2.connect(
        host=host,
        port=int(port),
        database=database,
        user=user,
        password=password
    )
    
    cursor = conn.cursor()
    
    try:
        # 检查字段是否已存在
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'fasting_plans' AND column_name = 'fasting_days'
        """)
        
        if cursor.fetchone():
            print("✅ fasting_days 字段已存在，无需迁移")
            return
        
        # 添加字段
        cursor.execute("""
            ALTER TABLE fasting_plans 
            ADD COLUMN fasting_days JSONB
        """)
        
        cursor.execute("""
            COMMENT ON COLUMN fasting_plans.fasting_days IS '断食日列表，5:2需要2天，basic_fasting需要1-2天'
        """)
        
        conn.commit()
        print("✅ 已成功添加 fasting_days 字段")
        
    except Exception as e:
        conn.rollback()
        print(f"❌ 迁移失败: {e}")
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    migrate()