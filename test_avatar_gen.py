"""测试后端 API 宠物形象生成"""
import httpx, time
BASE = "http://localhost:8008/api"

# 登录
r = httpx.post(f"{BASE}/auth/login", json={"username": "testpet", "password": "12345678"}, timeout=10)
token = r.json()["data"]["access_token"]
h = {"Authorization": f"Bearer {token}"}

# 获取宠物
r = httpx.get(f"{BASE}/pets", headers=h, timeout=10)
pets = r.json()["data"]["pets"]
if not pets:
    print("No pets!")
    exit()
pid = pets[0]["id"]
print(f"Pet: {pets[0]['name']} (id={pid})")

# 生成形象（同步，等最多 60 秒）
print(f"\nGenerating avatar...")
r = httpx.post(
    f"{BASE}/pets/{pid}/generate-avatar",
    headers=h,
    json={"mode": "description", "description": "Q版卡通形象"},
    timeout=60
)
d = r.json()["data"]
print(f"Status: {d.get('status')}")
print(f"Image:  {d.get('base_image_url','')[:100]}")
print(f"Model:  {d.get('ai_model','')}")
print(f"Seed:   {d.get('seed')}")

if "placehold.co" in d.get("base_image_url", ""):
    print("\nFAILED: Still placeholder")
else:
    print("\nSUCCESS: AI-generated image!")
