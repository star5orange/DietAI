"""
DietAI 家人数据代记录红线（403）验证脚本 —— 对应验收用例 TC-038 / TC-047

PRD D9 / 5.4：家人健康数据不可代记录（仅可查看）；接口才是权限层。
已下线写接口必须返回 403 + 统一话术；主流程（记自己）不受影响。

用法:
    python tests/family_write_403.py
    python tests/family_write_403.py --base-url http://localhost:8000
    python tests/family_write_403.py --verbose

前置条件:
    - 后端服务已启动（8000）
    - PostgreSQL / Redis 已运行（注册测试账号需要 DB）

断言清单（7 条，与 docs/DietAI_避雷指南.md §40 验证断言一致）:
    1. POST /api/family/proxy-record/food    （带 target_user_id） -> 403
    2. POST /api/family/proxy-record/water   （带 target_user_id） -> 403
    3. POST /api/foods/records               （SSE，带 target_user_id） -> 403
    4. POST /api/foods/records/traditional   （带 target_user_id） -> 403
    5. POST /api/foods/records/confirm-create（带 target_user_id） -> 403
    6. POST /api/health/exam/upload          （user_id=他人） -> 403
    7. POST /api/foods/records/traditional   （记自己，不带 target_user_id）-> 200（不受影响），随后删除清理
"""

import sys
import time
import argparse
from typing import Optional

try:
    import requests
except ImportError:
    print("请安装 requests: pip install requests")
    sys.exit(1)

DEFAULT_BASE_URL = "http://localhost:8000"
PROXY_MSG = "家人健康数据不可代记录（仅可查看）；如需提醒家人，请使用「提醒家人」功能"
EXAM_MSG = "家人体检数据不可代上传（仅可查看）"

_STAMP = int(time.time()) % 100000000
TEST_USER = {
    "username": f"f{_STAMP}"[:10],  # 后端用户名限 1-10 位
    "password": "Test123456!",
    "email": f"f{_STAMP}@test.com",
}


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


passed = 0
failed = 0
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


def log_section(title: str):
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'=' * 50}")
    print(f"  {title}")
    print(f"{'=' * 50}{Colors.RESET}")


def _detail(resp: requests.Response) -> str:
    """提取 HTTPException 的 detail / BaseResponse 的 message，用于话术断言"""
    try:
        body = resp.json()
    except Exception:
        return ""
    if isinstance(body, dict):
        return str(body.get("detail") or body.get("message") or "")
    return ""


def _assert_403(resp: requests.Response, name: str, expected_msg: str):
    if resp.status_code != 403:
        log_fail(name, f"期望 403，实际 {resp.status_code}: {resp.text[:120]}")
        return
    actual = _detail(resp)
    if expected_msg not in actual:
        log_fail(name, f"403 但话术不符: {actual[:120]}")
        return
    log_pass(name, f"403 + 统一话术")


def run(base_url: str, verbose: bool = False) -> int:
    base = base_url.rstrip("/")
    s = requests.Session()
    other_user_id: Optional[int] = None

    log_section("0. 准备测试账号")
    resp = s.post(f"{base}/api/auth/register", json=TEST_USER, timeout=10)
    if verbose:
        print(f"    register: {resp.status_code} {resp.text[:150]}")
    if resp.status_code == 200 and resp.json().get("success"):
        user_id = resp.json().get("data", {}).get("user_id")
        log_pass("注册测试账号", f"{TEST_USER['username']} id={user_id}")
    else:
        log_fail("注册测试账号", f"{resp.status_code}: {resp.text[:120]}")
        return 1

    resp = s.post(
        f"{base}/api/auth/login",
        json={"username": TEST_USER["username"], "password": TEST_USER["password"]},
        timeout=10,
    )
    if resp.status_code != 200:
        log_fail("登录", f"{resp.status_code}: {resp.text[:120]}")
        return 1
    token = (resp.json().get("data") or {}).get("access_token") or (resp.json().get("data") or {}).get("token")
    if not token:
        log_fail("登录", "未取到 access_token")
        return 1
    headers = {"Authorization": f"Bearer {token}"}
    other_user_id = int(user_id) + 999  # 任意"他人"ID：403 在归属校验层，不要求存在
    log_pass("登录并获取 Token", f"目标他人 id={other_user_id}")

    body_proxy = {
        "record_date": time.strftime("%Y-%m-%d"),
        "meal_type": 2,
        "food_name": "自动化403验证",
        "description": "family_write_403 脚本",
    }

    log_section("1. 家人代记录写接口（必须 403）")

    resp = s.post(
        f"{base}/api/family/proxy-record/food",
        params={"target_user_id": other_user_id, "food_record_id": 1},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.1 family/proxy-record/food", PROXY_MSG)

    resp = s.post(
        f"{base}/api/family/proxy-record/water",
        params={"target_user_id": other_user_id, "amount_ml": 300},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.2 family/proxy-record/water", PROXY_MSG)

    resp = s.post(
        f"{base}/api/foods/records",
        json={**body_proxy, "target_user_id": other_user_id},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.3 foods/records (SSE)", PROXY_MSG)

    resp = s.post(
        f"{base}/api/foods/records/traditional",
        json={**body_proxy, "target_user_id": other_user_id},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.4 foods/records/traditional", PROXY_MSG)

    resp = s.post(
        f"{base}/api/foods/records/confirm-create",
        json={**body_proxy, "target_user_id": other_user_id},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.5 foods/records/confirm-create", PROXY_MSG)

    resp = s.post(
        f"{base}/api/health/exam/upload",
        files={"photo": ("t.png", b"\x89PNG\r\n\x1a\nautomated-test", "image/png")},
        data={"user_id": str(other_user_id)},
        headers=headers,
        timeout=10,
    )
    _assert_403(resp, "1.6 health/exam/upload (代上传)", EXAM_MSG)

    log_section("2. 主流程不受影响（记自己）")

    record_id = None
    resp = s.post(
        f"{base}/api/foods/records/traditional",
        json={**body_proxy, "food_name": "自动化403脚本-自记记录"},
        headers=headers,
        timeout=15,
    )
    if resp.status_code != 200:
        log_fail("2.1 traditional 记自己不被拦截", f"期望 200，实际 {resp.status_code}: {resp.text[:120]}")
    else:
        data = resp.json().get("data") or {}
        record_id = data.get("id") or data.get("record_id")
        log_pass("2.1 traditional 记自己不被拦截", f"record_id={record_id}")

    if record_id:
        resp = s.delete(f"{base}/api/foods/records/{record_id}", headers=headers, timeout=10)
        if resp.status_code == 200:
            log_pass("2.2 清理自记测试记录")
        else:
            log_pass("2.2 清理自记测试记录（删除返回非 200，不阻断）", f"{resp.status_code}")

    log_section("3. 结果汇总")
    total = passed + failed
    print(f"  通过 {passed} / {total}，失败 {failed}")
    if failed:
        for status_, name, detail in results:
            if status_ == "FAIL":
                print(f"  {Colors.RED}✗ {name}: {detail}{Colors.RESET}")
    return 0 if failed == 0 else 1


def main():
    parser = argparse.ArgumentParser(description="家人数据代记录红线（403）验证")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()
    sys.exit(run(args.base_url, args.verbose))


if __name__ == "__main__":
    main()
