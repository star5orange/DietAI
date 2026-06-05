"""
DietAI 关键接口压力测试

用法:
    # 方式1 - Locust（推荐）
    pip install locust
    cd tests/load_test
    locust -f locustfile.py --host=http://localhost:8000

    # 方式2 - 独立脚本（无需 locust）
    python tests/load_test/locustfile.py --standalone

    # 打开 Locust Web UI: http://localhost:8089
    # 设置并发用户数=50，生成速率=10/s，运行时间=60s

目标:
    - CRUD 接口 < 500ms avg
    - 并发 50 无异常
    - P95 < 1000ms
"""

import time
import json
import statistics
import sys
import os
from datetime import date, datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# ---- 配置 ----
BASE_URL = os.environ.get("DIETAI_BASE_URL", "http://localhost:8000")
TEST_USERNAME = os.environ.get("TEST_USERNAME", "testuser")
TEST_PASSWORD = os.environ.get("TEST_PASSWORD", "testpass123")
CONCURRENT_USERS = 50
WARMUP_REQUESTS = 5


class DietAILoadTest:
    """独立压测运行器（不依赖 locust）"""

    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url
        self.token = None
        self.session = requests.Session()
        self.results = {}  # endpoint -> [latencies]

    def login(self) -> str:
        """登录获取 JWT token"""
        resp = self.session.post(
            f"{self.base_url}/api/auth/login",
            json={"username": TEST_USERNAME, "password": TEST_PASSWORD},
            timeout=10,
        )
        data = resp.json()
        if not data.get("success"):
            # 尝试注册
            resp = self.session.post(
                f"{self.base_url}/api/auth/register",
                json={
                    "username": TEST_USERNAME,
                    "email": f"{TEST_USERNAME}@test.com",
                    "password": TEST_PASSWORD,
                },
                timeout=10,
            )
            reg_data = resp.json()
            if not reg_data.get("success"):
                raise RuntimeError(f"注册失败: {reg_data}")

            # 重新登录
            resp = self.session.post(
                f"{self.base_url}/api/auth/login",
                json={"username": TEST_USERNAME, "password": TEST_PASSWORD},
                timeout=10,
            )
            data = resp.json()

        token_data = data.get("data", {})
        self.token = token_data.get("access_token", "")
        if not self.token:
            raise RuntimeError(f"登录失败: {data}")
        print(f"[Auth] Token obtained: {self.token[:20]}...")
        return self.token

    def _auth_headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    def _measure(self, name: str, method: str, path: str, **kwargs):
        """执行单次请求并记录延迟"""
        url = f"{self.base_url}{path}"
        start = time.perf_counter()
        try:
            resp = self.session.request(
                method, url, headers=self._auth_headers(), timeout=30, **kwargs
            )
            elapsed = time.perf_counter() - start
            if resp.status_code >= 400:
                self.results.setdefault(f"{name}_errors", []).append(resp.status_code)
            return elapsed
        except Exception as e:
            elapsed = time.perf_counter() - start
            self.results.setdefault(f"{name}_errors", []).append(str(e)[:80])
            return elapsed

    def test_create_exercise(self):
        """POST /api/exercises/records"""
        payload = {
            "exercise_type": "跑步",
            "duration_minutes": 30,
            "intensity": 2,
            "record_date": str(date.today()),
            "calories_burned": 300,
            "notes": "load test",
        }
        return self._measure("POST exercises/records", "POST",
                             "/api/exercises/records", json=payload)

    def test_list_exercises(self):
        """GET /api/exercises/records"""
        return self._measure("GET exercises/records", "GET",
                             "/api/exercises/records?limit=10")

    def test_create_water(self):
        """POST /api/water/records"""
        payload = {
            "amount_ml": 250,
            "record_time": datetime.now().isoformat(),
            "drink_type": "水",
        }
        return self._measure("POST water/records", "POST",
                             "/api/water/records", json=payload)

    def test_water_summary(self):
        """GET /api/water/daily-summary/{date}"""
        return self._measure("GET water/daily-summary", "GET",
                             f"/api/water/daily-summary/{date.today()}")

    def test_weekly_summary(self):
        """GET /api/health/weekly-summary"""
        return self._measure("GET health/weekly-summary", "GET",
                             "/api/health/weekly-summary")

    def test_create_reminder(self):
        """POST /api/reminders/"""
        payload = {
            "reminder_type": "water",
            "remind_time": "10:00:00",
            "repeat_days": 127,
            "is_enabled": True,
            "title": "load test reminder",
        }
        return self._measure("POST reminders/", "POST",
                             "/api/reminders/", json=payload)

    def run(self, concurrent: int = CONCURRENT_USERS, iterations: int = 100):
        """
        执行压测。

        Args:
            concurrent: 并发数
            iterations: 每个接口的总请求数
        """
        print(f"\n{'='*60}")
        print(f"DietAI 接口压力测试")
        print(f"目标: {self.base_url}")
        print(f"并发: {concurrent} | 每个接口请求: {iterations}")
        print(f"{'='*60}\n")

        # 1. 登录
        self.login()

        # 2. 预热
        print("[Warmup] 预热中...")
        for _ in range(WARMUP_REQUESTS):
            self.test_create_exercise()
            self.test_create_water()
        print("[Warmup] 完成\n")

        # 3. 定义测试用例
        test_cases = [
            ("POST /api/exercises/records", self.test_create_exercise),
            ("GET /api/exercises/records", self.test_list_exercises),
            ("POST /api/water/records", self.test_create_water),
            ("GET /api/water/daily-summary/{date}", self.test_water_summary),
            ("GET /api/health/weekly-summary", self.test_weekly_summary),
            ("POST /api/reminders/", self.test_create_reminder),
        ]

        # 4. 执行压测
        for name, test_fn in test_cases:
            print(f"[Test] {name} ...", end=" ", flush=True)

            latencies = []
            errors = []

            with ThreadPoolExecutor(max_workers=concurrent) as executor:
                futures = [executor.submit(test_fn) for _ in range(iterations)]
                for future in as_completed(futures):
                    try:
                        lat = future.result(timeout=30)
                        if isinstance(lat, (int, float)):
                            latencies.append(lat)
                    except Exception as e:
                        errors.append(str(e)[:80])

            latencies.sort()
            n = len(latencies)
            error_count = len(errors)

            if n == 0:
                print("FAILED (all errors)")
                continue

            avg = statistics.mean(latencies) * 1000
            p50 = latencies[int(n * 0.50)] * 1000 if n > 0 else 0
            p95 = latencies[int(n * 0.95)] * 1000 if n > 1 else latencies[0] * 1000
            p99 = latencies[int(n * 0.99)] * 1000 if n > 2 else latencies[-1] * 1000
            error_rate = (error_count / iterations) * 100

            status = "PASS" if avg < 500 and error_rate < 1 else "WARN" if avg < 1000 else "FAIL"
            print(f"{status} | avg={avg:.1f}ms p50={p50:.1f}ms p95={p95:.1f}ms "
                  f"p99={p99:.1f}ms errors={error_rate:.1f}%")

            self.results[name] = {
                "avg_ms": round(avg, 1),
                "p50_ms": round(p50, 1),
                "p95_ms": round(p95, 1),
                "p99_ms": round(p99, 1),
                "error_rate_pct": round(error_rate, 1),
                "total_requests": n,
                "status": status,
            }

        # 5. 总结
        print(f"\n{'='*60}")
        print("压测总结")
        print(f"{'='*60}")
        print(f"{'接口':<40} {'avg':>8} {'p95':>8} {'p99':>8} {'错误率':>8} {'判定':>6}")
        print("-" * 80)
        for name, r in self.results.items():
            if isinstance(r, dict):
                print(f"{name:<40} {r['avg_ms']:>7.1f}ms {r['p95_ms']:>7.1f}ms "
                      f"{r['p99_ms']:>7.1f}ms {r['error_rate_pct']:>7.1f}% {r['status']:>6}")

        # 6. 优化建议
        slow_endpoints = [
            (name, r) for name, r in self.results.items()
            if isinstance(r, dict) and r["avg_ms"] >= 500
        ]
        if slow_endpoints:
            print(f"\n⚠ 性能不达标接口分析:")
            for name, r in slow_endpoints:
                print(f"  - {name}: avg={r['avg_ms']}ms")
                self._suggest_optimization(name, r)

        return self.results

    def _suggest_optimization(self, name: str, result: dict):
        """给出针对性优化建议"""
        suggestions = {
            "GET /api/health/weekly-summary": [
                "该接口查询7天数据并做大量聚合计算",
                "→ 建议：添加数据库复合索引 idx_dns_user_date(user_id, summary_date DESC)",
                "→ 建议：对计算结果做 Redis 缓存 (TTL=3600s)，key=weekly_summary:{user_id}:{target_date}",
                "→ 建议：将 weight_records 的 daily-latest 子查询改为窗口函数",
            ],
            "POST /api/exercises/records": [
                "创建记录后触发 _recalc_daily_exercise 全量 SUM",
                "→ 建议：确认 exercise_records 表有 (user_id, record_date) 复合索引",
                "→ 建议：使用异步任务延迟更新汇总，减少请求链路",
            ],
            "POST /api/water/records": [
                "创建记录后触发 _recalc_daily_water 全量 SUM",
                "→ 建议：确认 water_intake_records 表有 (user_id, record_time) 复合索引",
                "→ 建议：每日汇总更新可改为增量更新而非全量 SUM",
            ],
        }
        for key, tips in suggestions.items():
            if key in name:
                for tip in tips:
                    print(f"    {tip}")


# ==================== Locust 集成（可选） ====================

try:
    from locust import HttpUser, task, between

    class DietAIUser(HttpUser):
        """Locust 用户类 — 模拟真实用户行为"""
        wait_time = between(1, 3)

        def on_start(self):
            """登录"""
            resp = self.client.post("/api/auth/login", json={
                "username": TEST_USERNAME,
                "password": TEST_PASSWORD,
            })
            data = resp.json()
            token_data = data.get("data", {})
            self.token = token_data.get("access_token", "")
            if self.token:
                self.client.headers.update({"Authorization": f"Bearer {self.token}"})

        @task(3)
        def create_exercise(self):
            self.client.post("/api/exercises/records", json={
                "exercise_type": "跑步",
                "duration_minutes": 30,
                "intensity": 2,
                "record_date": str(date.today()),
                "calories_burned": 300,
            })

        @task(2)
        def list_exercises(self):
            self.client.get("/api/exercises/records?limit=10")

        @task(3)
        def create_water(self):
            self.client.post("/api/water/records", json={
                "amount_ml": 250,
                "record_time": datetime.now().isoformat(),
                "drink_type": "水",
            })

        @task(2)
        def water_summary(self):
            self.client.get(f"/api/water/daily-summary/{date.today()}")

        @task(1)
        def weekly_summary(self):
            self.client.get("/api/health/weekly-summary")

        @task(1)
        def create_reminder(self):
            self.client.post("/api/reminders/", json={
                "reminder_type": "water",
                "remind_time": "10:00:00",
                "repeat_days": 127,
                "is_enabled": True,
                "title": "test",
            })

except ImportError:
    class DietAIUser:
        pass


# ==================== 入口 ====================

if __name__ == "__main__":
    if "--standalone" in sys.argv:
        tester = DietAILoadTest()
        tester.run(concurrent=CONCURRENT_USERS, iterations=200)
    elif "--quick" in sys.argv:
        tester = DietAILoadTest()
        tester.run(concurrent=10, iterations=50)
    else:
        print(__doc__)
        print("Usage:")
        print("  python tests/load_test/locustfile.py --standalone  # 独立压测")
        print("  python tests/load_test/locustfile.py --quick       # 快速验证(10并发)")
        print("  locust -f tests/load_test/locustfile.py --host=http://localhost:8000")
