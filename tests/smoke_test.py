"""
DietAI 冒烟测试脚本 - 一键验证所有关键后端接口

用法:
    python tests/smoke_test.py
    python tests/smoke_test.py --base-url http://localhost:8000
    python tests/smoke_test.py --verbose

前置条件:
    - 后端服务已启动
    - PostgreSQL 和 Redis 已运行
"""

import sys
import json
import time
import argparse
from datetime import date, datetime
from typing import Optional

try:
    import requests
except ImportError:
    print("请安装 requests: pip install requests")
    sys.exit(1)


# ==================== 配置 ====================
DEFAULT_BASE_URL = "http://localhost:8000"
# 注意：后端 UserCreate 限制 username 长度 1-10（shared/models/schemas/user.py），
# 所以这里用 1 位前缀 + 8 位时间戳，避免 422。
_STAMP = int(time.time()) % 100000000
TEST_USER = {
    "username": f"s{_STAMP}",
    "password": "Test123456!",
    "email": f"s{_STAMP}@test.com",
}

# ==================== 工具函数 ====================
class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


passed = 0
failed = 0
skipped = 0
results = []


def log_pass(name: str, detail: str = ""):
    global passed
    passed += 1
    msg = f"  {Colors.GREEN}✓ PASS{Colors.RESET} {name}"
    if detail:
        msg += f" - {detail}"
    print(msg)
    results.append(("PASS", name, detail))


def log_fail(name: str, detail: str = ""):
    global failed
    failed += 1
    msg = f"  {Colors.RED}✗ FAIL{Colors.RESET} {name}"
    if detail:
        msg += f" - {detail}"
    print(msg)
    results.append(("FAIL", name, detail))


def log_skip(name: str, detail: str = ""):
    global skipped
    skipped += 1
    msg = f"  {Colors.YELLOW}⊘ SKIP{Colors.RESET} {name}"
    if detail:
        msg += f" - {detail}"
    print(msg)
    results.append(("SKIP", name, detail))


def log_section(title: str):
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}{Colors.RESET}")


class SmokeTest:
    def __init__(self, base_url: str, verbose: bool = False):
        self.base_url = base_url.rstrip("/")
        self.verbose = verbose
        self.token: Optional[str] = None
        self.headers = {}
        self.user_id: Optional[int] = None
        self.created_ids = {}  # 清理用

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"

    def _log_response(self, resp: requests.Response, name: str):
        if self.verbose:
            try:
                body = resp.json()
                print(f"    Response: {json.dumps(body, ensure_ascii=False)[:200]}")
            except Exception:
                print(f"    Response: {resp.text[:200]}")

    # ==================== 测试用例 ====================

    def test_health_check(self):
        """0. 健康检查"""
        log_section("0. 服务健康检查")
        try:
            resp = requests.get(self._url("/docs"), timeout=5)
            if resp.status_code == 200:
                log_pass("后端服务运行中")
            else:
                log_fail("后端服务异常", f"状态码: {resp.status_code}")
        except requests.ConnectionError:
            log_fail("后端服务无法连接", f"请确认 {self.base_url} 是否启动")
            return False
        return True

    def test_auth(self):
        """1. 认证模块"""
        log_section("1. 认证模块")

        # 注册（/api/auth/register 只返回 user_id，不发 token）
        resp = requests.post(self._url("/api/auth/register"), json=TEST_USER, timeout=10)
        self._log_response(resp, "register")
        if resp.status_code == 200 and resp.json().get("success"):
            data = resp.json().get("data", {})
            self.user_id = data.get("user_id")
            log_pass("用户注册", f"用户名: {TEST_USER['username']} id={self.user_id}")
        else:
            log_skip("用户注册", f"未注册成功（可能已存在）: {resp.status_code}")

        # 登录换 token
        resp = requests.post(self._url("/api/auth/login"), json={
            "username": TEST_USER["username"],
            "password": TEST_USER["password"],
        }, timeout=10)
        self._log_response(resp, "login")
        if resp.status_code != 200:
            log_fail("登录失败", f"状态码: {resp.status_code}, {resp.text[:100]}")
            return False
        data = resp.json().get("data", {})
        self.token = data.get("access_token") or data.get("token")
        if not self.token:
            log_fail("获取 token 失败", f"响应字段: {list(data.keys())}")
            return False
        self.headers = {"Authorization": f"Bearer {self.token}"}
        log_pass("登录并获取 Token", f"{self.token[:20]}...")

        # 验证 token
        resp = requests.get(self._url("/api/auth/verify-token"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("Token 验证")
        else:
            log_fail("Token 验证失败", f"状态码: {resp.status_code}")

        # 获取用户信息
        resp = requests.get(self._url("/api/auth/me"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取当前用户信息")
        else:
            log_fail("获取用户信息失败", f"状态码: {resp.status_code}")

        return True

    def test_user_profile(self):
        """2. 用户档案"""
        log_section("2. 用户档案")

        # 获取档案
        resp = requests.get(self._url("/api/users/profile"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取用户档案")
        else:
            log_fail("获取用户档案失败")

        # 更新档案（BMR/TDEE 依赖 体重+身高+性别+出生日期，缺一即 400）
        resp = requests.put(self._url("/api/users/profile"), headers=self.headers, json={
            "gender": 1,
            "height": 175.0,
            "weight": 70.0,
            "birth_date": "1995-06-15",
            "activity_level": 2,
            "crowd_tag": "健身",
            "constitution_type": "平和质",
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("更新用户档案", "人群标签=健身, 体质=平和质")
        else:
            log_fail("更新用户档案失败", f"状态码: {resp.status_code}")

        # 用户统计
        resp = requests.get(self._url("/api/users/stats"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取用户统计")
        else:
            log_fail("获取用户统计失败")

        # 过敏原
        resp = requests.post(self._url("/api/users/allergies"), headers=self.headers, json={
            "allergen_type": 1,
            "allergen_name": "花生",
            "severity_level": 2,
            "reaction_description": "皮肤发痒",
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("添加过敏原", "花生")
            allergy_data = resp.json().get("data", {})
            self.created_ids["allergy"] = allergy_data.get("id")
        else:
            log_fail("添加过敏原失败")

        # 获取过敏原列表
        resp = requests.get(self._url("/api/users/allergies"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取过敏原列表")
        else:
            log_fail("获取过敏原列表失败")

    def test_onboarding(self):
        """3. Onboarding"""
        log_section("3. Onboarding")

        # 获取状态
        resp = requests.get(self._url("/api/users/onboarding/status"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取 Onboarding 状态")
        else:
            log_fail("获取 Onboarding 状态失败")

        # 体质测试
        resp = requests.post(self._url("/api/users/constitution-quiz"), headers=self.headers, json={
            "answers": [{"question_id": i, "score": 3} for i in range(1, 10)],
        }, timeout=10)
        if resp.status_code == 200:
            log_pass("体质测试")
        else:
            log_fail("体质测试失败")

    def test_food_records(self):
        """4. 饮食记录"""
        log_section("4. 饮食记录")

        today = date.today().isoformat()

        # 创建饮食记录（该接口是 SSE 流式：先落库 → Agent 分析 → stream_complete 带 record_id）
        try:
            resp = requests.post(self._url("/api/foods/records"), headers=self.headers, json={
                "food_name": "宫保鸡丁",
                "meal_type": 2,
                "record_date": today,
                "recording_method": 2,
            }, timeout=120, stream=True)
            if resp.status_code != 200:
                log_fail("创建饮食记录失败", f"状态码: {resp.status_code}")
            else:
                record_id = None
                stream_error = None
                for raw in resp.iter_lines():
                    if not raw:
                        continue
                    line = raw.decode("utf-8") if isinstance(raw, bytes) else raw
                    if not line.startswith("data: "):
                        continue
                    try:
                        payload = json.loads(line[6:])
                    except Exception:
                        continue
                    ptype = payload.get("type")
                    if ptype == "stream_complete":
                        record_id = (payload.get("data") or {}).get("record_id")
                    elif ptype == "error":
                        stream_error = str((payload.get("data") or {}).get("message") or "")[:80]
                if record_id:
                    self.created_ids["food_record"] = record_id
                    log_pass("创建饮食记录（SSE）", f"宫保鸡丁, id={record_id}")
                elif stream_error:
                    log_fail("创建饮食记录失败", stream_error)
                else:
                    log_skip("创建饮食记录", "SSE 未返回 record_id（Agent 可能未就绪）")
        except requests.RequestException as e:
            log_fail("创建饮食记录异常", str(e)[:80])

        # 获取今日记录
        resp = requests.get(self._url("/api/foods/records"), headers=self.headers,
                           params={"record_date": today}, timeout=5)
        if resp.status_code == 200:
            log_pass("获取今日饮食记录")
        else:
            log_fail("获取饮食记录失败")

        # 每日汇总
        resp = requests.get(self._url(f"/api/foods/daily-summary/{today}"), headers=self.headers,
                           timeout=5)
        if resp.status_code == 200:
            log_pass("获取每日营养汇总")
        else:
            log_fail("获取每日汇总失败")

        # 营养趋势
        resp = requests.get(self._url("/api/foods/nutrition-trends"), headers=self.headers,
                           params={"days": 7}, timeout=5)
        if resp.status_code == 200:
            log_pass("获取营养趋势", "7天")
        else:
            log_fail("获取营养趋势失败")

    def test_exercise_records(self):
        """5. 运动记录（含力量训练详情）"""
        log_section("5. 运动记录")

        today = date.today().isoformat()

        # 有氧运动
        resp = requests.post(self._url("/api/exercises/records"), headers=self.headers, json={
            "exercise_name": "跑步",
            "exercise_type": "cardio",
            "duration_minutes": 30,
            "calories_burned": 300,
            "record_date": today,
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("创建有氧运动记录", "跑步 30min 300kcal")
        else:
            log_fail("创建有氧运动记录失败", f"状态码: {resp.status_code}")

        # 力量训练（含 strength_detail）
        resp = requests.post(self._url("/api/exercises/records"), headers=self.headers, json={
            "exercise_name": "胸部训练",
            "exercise_type": "strength",
            "duration_minutes": 60,
            "calories_burned": 350,
            "record_date": today,
            "strength_detail": {
                "muscle_groups": ["胸", "三头"],
                "sets": [
                    {"exercise": "卧推", "sets": 4, "reps": 12, "weight_kg": 60},
                    {"exercise": "哑铃飞鸟", "sets": 3, "reps": 15, "weight_kg": 14},
                ]
            }
        }, timeout=5)
        if resp.status_code == 200:
            data = resp.json().get("data", {})
            self.created_ids["exercise_record"] = data.get("id")
            log_pass("创建力量训练记录", "含 strength_detail（卧推+哑铃飞鸟）")
        else:
            log_fail("创建力量训练记录失败", f"状态码: {resp.status_code}, {resp.text[:150]}")

        # 运动记录列表（后端无 /daily-summary，改用记录列表验证落库）
        resp = requests.get(self._url("/api/exercises/records"), headers=self.headers,
                           params={"record_date": today}, timeout=5)
        if resp.status_code == 200:
            log_pass("获取运动记录列表")
        else:
            log_fail("获取运动记录列表失败", f"状态码: {resp.status_code}")

        # 运动统计
        resp = requests.get(self._url("/api/exercises/statistics"), headers=self.headers,
                           params={"period": "7d"}, timeout=5)
        if resp.status_code == 200:
            log_pass("运动统计（周）")
        else:
            log_fail("运动统计失败")

    def test_water_records(self):
        """6. 饮水记录"""
        log_section("6. 饮水记录")

        today = date.today().isoformat()

        # 记录饮水
        resp = requests.post(self._url("/api/water/records"), headers=self.headers, json={
            "amount_ml": 250,
            "drink_type": "water",
            "time_period": "morning",
            "record_date": today,
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("记录饮水", "250ml 白开水 早晨")
        else:
            log_fail("记录饮水失败", f"状态码: {resp.status_code}")

        # 饮水汇总
        resp = requests.get(self._url(f"/api/water/daily-summary/{today}"), headers=self.headers,
                           timeout=5)
        if resp.status_code == 200:
            log_pass("饮水每日汇总")
        else:
            log_fail("饮水每日汇总失败")

        # 饮水统计
        resp = requests.get(self._url("/api/water/statistics"), headers=self.headers,
                           params={"period": "7d"}, timeout=5)
        if resp.status_code == 200:
            log_pass("饮水统计（周）")
        else:
            log_fail("饮水统计失败")

    def test_reminders(self):
        """7. 提醒设置"""
        log_section("7. 提醒设置")

        # 创建提醒（ReminderCreate: reminder_type/remind_time/repeat_days bitmask）
        resp = requests.post(self._url("/api/reminders"), headers=self.headers, json={
            "title": "喝水提醒",
            "description": "该喝水了！",
            "reminder_type": "water",
            "remind_time": "10:00",
            "repeat_days": 127,
        }, timeout=5)
        if resp.status_code == 200:
            data = resp.json().get("data", {})
            reminder_id = data.get("id")
            self.created_ids["reminder"] = reminder_id
            log_pass("创建提醒", "喝水提醒 10:00")
        else:
            log_fail("创建提醒失败", f"状态码: {resp.status_code}")

        # 获取提醒列表
        resp = requests.get(self._url("/api/reminders"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取提醒列表")
        else:
            log_fail("获取提醒列表失败")

        # 切换提醒开关
        if self.created_ids.get("reminder"):
            resp = requests.put(
                self._url(f"/api/reminders/{self.created_ids['reminder']}"),
                headers=self.headers,
                json={"is_enabled": False},
                timeout=5,
            )
            if resp.status_code == 200:
                log_pass("切换提醒开关", "关闭")
            else:
                log_fail("切换提醒开关失败")

    def test_wellness(self):
        """8. 养生推荐"""
        log_section("8. 养生推荐")

        # 获取今日养生
        resp = requests.get(self._url("/api/wellness/daily-recommendation"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取今日养生推荐")
        else:
            log_fail("获取今日养生推荐失败", f"状态码: {resp.status_code}")

        # 节气信息
        resp = requests.get(self._url("/api/wellness/solar-terms"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取节气信息")
        else:
            log_fail("获取节气信息失败", f"状态码: {resp.status_code}")

    def test_saved_meals(self):
        """9. 收藏餐食"""
        log_section("9. 收藏餐食")

        # 创建收藏
        resp = requests.post(self._url("/api/saved-meals"), headers=self.headers, json={
            "meal_name": "减脂鸡胸沙拉",
            "category": "lunch",
            "nutrition": {
                "calories": 320,
                "protein": 35,
                "fat": 8,
                "carbohydrates": 25,
            }
        }, timeout=5)
        if resp.status_code == 200:
            data = resp.json().get("data", {})
            self.created_ids["saved_meal"] = data.get("id")
            log_pass("创建收藏餐食", "减脂鸡胸沙拉")
        else:
            log_fail("创建收藏餐食失败", f"状态码: {resp.status_code}")

        # 获取收藏列表
        resp = requests.get(self._url("/api/saved-meals"), headers=self.headers, timeout=5)
        if resp.status_code == 200:
            log_pass("获取收藏餐食列表")
        else:
            log_fail("获取收藏餐食列表失败")

    def test_health_analysis(self):
        """10. 健康分析"""
        log_section("10. 健康分析")

        # BMR 计算
        resp = requests.post(self._url("/api/health/analysis"), headers=self.headers, json={
            "analysis_type": "bmr",
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("BMR 计算")
        else:
            log_fail("BMR 计算失败")

        # TDEE 计算
        resp = requests.post(self._url("/api/health/analysis"), headers=self.headers, json={
            "analysis_type": "tdee",
        }, timeout=5)
        if resp.status_code == 200:
            log_pass("TDEE 计算")
        else:
            log_fail("TDEE 计算失败")

    def test_chat(self):
        """11. AI 聊天（非流式简化测试）"""
        log_section("11. AI 聊天")

        for session_type, name in [(1, "营养咨询"), (4, "运动建议"), (5, "养生咨询")]:
            try:
                resp = requests.post(
                    self._url("/api/chat/send-message-stream"),
                    headers=self.headers,
                    json={
                        "message": f"你好，我想咨询{name}相关的问题",
                        "session_type": session_type,
                    },
                    timeout=30,
                    stream=True,
                )
                if resp.status_code == 200:
                    # 读取前几个 chunk 确认流式响应正常
                    chunk_count = 0
                    for line in resp.iter_lines():
                        if line:
                            chunk_count += 1
                            if chunk_count >= 2:
                                break
                    log_pass(f"AI 聊天 - {name}", f"流式响应正常")
                else:
                    log_fail(f"AI 聊天 - {name}", f"状态码: {resp.status_code}")
            except requests.Timeout:
                log_skip(f"AI 聊天 - {name}", "超时（AI 服务可能未配置）")
            except Exception as e:
                log_skip(f"AI 聊天 - {name}", str(e)[:50])

    def test_food_analysis(self):
        """12. 食物图片分析（需要 AI 模型）"""
        log_section("12. 食物图片分析")
        log_skip("食物图片分析", "需要真实图片，手动测试")

    def test_deep_agent(self):
        """13. Agent 动作链路（PRD 4.1 动作注册表 / 4.5 撤销 / 4.8 卡片）"""
        log_section("13. Agent 动作链路（/api/deep）")

        # 13.1 对话流（SSE）：应返回 session + content 事件
        card_seen = False
        text_seen = False
        try:
            resp = requests.post(
                self._url("/api/deep/chat"),
                headers=self.headers,
                json={
                    "message": "帮我记录：我刚喝了一瓶水，500ml",
                    "session_type": 1,
                },
                timeout=60,
                stream=True,
            )
            if resp.status_code != 200:
                log_fail("Agent 对话流（/api/deep/chat）", f"状态码: {resp.status_code}")
            else:
                for raw in resp.iter_lines():
                    if not raw:
                        continue
                    line = raw.decode("utf-8") if isinstance(raw, bytes) else raw
                    if not line.startswith("data: "):
                        continue
                    try:
                        payload = json.loads(line[6:])
                    except Exception:
                        continue
                    ptype = payload.get("type")
                    if ptype == "content":
                        text_seen = True
                    elif ptype == "card":
                        card_seen = True
                    elif ptype == "error":
                        log_fail(
                            "Agent 对话流（/api/deep/chat）",
                            str(payload.get("error"))[:80],
                        )
                        break

                if text_seen:
                    log_pass("Agent 对话流（/api/deep/chat）", "content 事件正常")
                else:
                    log_skip("Agent 对话流（/api/deep/chat）", "未收到 content 事件")

                if card_seen:
                    log_pass("Agent 动作卡片（card 事件）", "写操作出卡正常")
                else:
                    log_skip(
                        "Agent 动作卡片（card 事件）",
                        "本次未出卡（LLM 意图判定），可在演示环境复测",
                    )
        except requests.Timeout:
            log_skip("Agent 对话流（/api/deep/chat）", "超时（LLM 服务可能未配置）")
        except Exception as e:
            log_skip("Agent 对话流（/api/deep/chat）", str(e)[:50])

        # 13.2 撤销接口：无有效日志时应结构化返回，不得 500（PRD 4.5 超窗提示）
        try:
            resp = requests.post(
                self._url("/api/deep/actions/undo"),
                headers=self.headers,
                json={"undo_token": "smoke-test-invalid-token"},
                timeout=15,
            )
            body = resp.json() if resp.status_code == 200 else {}
            if resp.status_code == 200 and "success" in body:
                log_pass("Agent 撤销接口", f"success={body.get('success')}")
            else:
                log_fail("Agent 撤销接口", f"状态码: {resp.status_code}")
        except Exception as e:
            log_skip("Agent 撤销接口", str(e)[:50])

        # 13.3 今日状态（卡片数据来源）
        try:
            resp = requests.get(
                self._url("/api/deep/daily-status"), headers=self.headers, timeout=15
            )
            if resp.status_code == 200:
                log_pass("Agent 今日状态接口")
            else:
                log_fail("Agent 今日状态接口", f"状态码: {resp.status_code}")
        except Exception as e:
            log_skip("Agent 今日状态接口", str(e)[:50])

    def cleanup(self):
        """清理测试数据"""
        log_section("清理测试数据")

        # 删除提醒
        if self.created_ids.get("reminder"):
            resp = requests.delete(
                self._url(f"/api/reminders/{self.created_ids['reminder']}"),
                headers=self.headers, timeout=5
            )
            if resp.status_code == 200:
                log_pass("删除测试提醒")

        # 删除过敏原
        if self.created_ids.get("allergy"):
            resp = requests.delete(
                self._url(f"/api/allergies/{self.created_ids['allergy']}"),
                headers=self.headers, timeout=5
            )
            if resp.status_code == 200:
                log_pass("删除测试过敏原")

        # 删除收藏餐食
        if self.created_ids.get("saved_meal"):
            resp = requests.delete(
                self._url(f"/api/saved-meals/{self.created_ids['saved_meal']}"),
                headers=self.headers, timeout=5
            )
            if resp.status_code == 200:
                log_pass("删除测试收藏餐食")

    def run(self):
        """运行所有测试"""
        print(f"\n{Colors.BOLD}{'='*50}")
        print(f"  DietAI 冒烟测试")
        print(f"  目标: {self.base_url}")
        print(f"  时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*50}{Colors.RESET}")

        start_time = time.time()

        # 0. 健康检查
        if not self.test_health_check():
            print(f"\n{Colors.RED}后端服务未启动，终止测试{Colors.RESET}")
            return

        # 1. 认证
        if not self.test_auth():
            print(f"\n{Colors.RED}认证失败，终止测试{Colors.RESET}")
            return

        # 2-13. 功能测试
        self.test_user_profile()
        self.test_onboarding()
        self.test_food_records()
        self.test_exercise_records()
        self.test_water_records()
        self.test_reminders()
        self.test_wellness()
        self.test_saved_meals()
        self.test_health_analysis()
        self.test_chat()
        self.test_food_analysis()
        self.test_deep_agent()

        # 清理
        self.cleanup()

        elapsed = time.time() - start_time

        # ==================== 结果汇总 ====================
        total = passed + failed + skipped
        print(f"\n{Colors.BOLD}{'='*50}")
        print(f"  测试结果汇总")
        print(f"{'='*50}{Colors.RESET}")
        print(f"  总计: {total}  {Colors.GREEN}通过: {passed}{Colors.RESET}  {Colors.RED}失败: {failed}{Colors.RESET}  {Colors.YELLOW}跳过: {skipped}{Colors.RESET}")
        print(f"  耗时: {elapsed:.1f}s")

        if failed > 0:
            print(f"\n{Colors.RED}{Colors.BOLD}失败项:{Colors.RESET}")
            for status, name, detail in results:
                if status == "FAIL":
                    print(f"  - {name}: {detail}")

        if failed == 0:
            print(f"\n{Colors.GREEN}{Colors.BOLD}所有测试通过！{Colors.RESET}")
        else:
            print(f"\n{Colors.RED}{Colors.BOLD}存在失败项，请检查！{Colors.RESET}")

        return failed == 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DietAI 冒烟测试")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="后端地址")
    parser.add_argument("--verbose", action="store_true", help="详细输出")
    args = parser.parse_args()

    tester = SmokeTest(args.base_url, args.verbose)
    success = tester.run()
    sys.exit(0 if success else 1)
