"""验证数据库字段"""
import psycopg2

DB_CONFIG = {
    'host': 'localhost',
    'database': 'dietai_db',
    'user': 'dietai',
    'password': 'dietai123',
    'port': 5432
}

conn = psycopg2.connect(**DB_CONFIG)
cur = conn.cursor()

# 查询用户的目标数据
cur.execute("""
    SELECT user_id, daily_water_goal, target_calories
    FROM user_profiles
    LIMIT 5
""")
rows = cur.fetchall()

print("\n用户ID | 饮水目标 | 卡路里目标")
print("-" * 40)
for r in rows:
    print(f"{r[0]} | {r[1]} ml | {r[2]} kcal")

conn.close()