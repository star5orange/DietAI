"""一键回归：把分散的校验脚本按顺序跑完并汇总。

覆盖（可单独跳过）:
    precheck   后端 /docs 可达 + PostgreSQL 可连 + 后端进程是否旧于代码（旧代码须重启）
    scheduler  V5 老人线 3 个定时任务是否已注册（不等定时点）
    smoke      tests/smoke_test.py（含 13. Agent 动作链路）
    care       tests/care_tasks.py（老人线关怀任务触发 + 幂等）
    rules      tests/rules_eval.py（PRD 规则断言：D5/D12/D13/4.6/4.7/5.4/宠物红线/B3）
    intent     tests/intent_eval.py（15 动作意图命中率，默认阈值 90%）

用法:
    uv run python tests/regression.py
    uv run python tests/regression.py --skip intent          # 少了 LLM 也能跑
    uv run python tests/regression.py --skip smoke,care      # 只跑离线项
    uv run python tests/regression.py --threshold 0.85 --verbose

注意:
    - precheck 失败时，依赖后端的步骤（smoke / rules / care / intent）自动跳过
    - care 会向开发库写入当天的关怀推送（幂等，同一天重复跑第二次为 0）
    - 退出码: 0 全部通过；1 存在失败
"""

import argparse
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

PROJECT_ROOT = Path(__file__).resolve().parents[1]
TESTS_DIR = PROJECT_ROOT / "tests"

# 以 `python tests/regression.py` 直接运行时 sys.path[0] 是 tests/，
# 补上项目根目录，scheduler 步骤要进程内导入 shared.*
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")

STEPS = ["precheck", "scheduler", "smoke", "care", "rules", "intent"]

# V5 老人线定时任务（shared/tasks/scheduler.py）
EXPECTED_FAMILY_JOBS = {
    "family_meal_care_ask": "饭点关怀询问",
    "family_alerts_push": "家庭异常主动提醒",
    "family_daily_report_push": "父母日报推送",
}


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


RESULTS: list[tuple[str, str, str, str, float]] = []   # (key, name, status, detail, seconds)


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text or "")


def log_section(title: str):
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}{Colors.RESET}")


def record(key: str, name: str, status: str, detail: str, seconds: float):
    color = {"PASS": Colors.GREEN, "FAIL": Colors.RED, "SKIP": Colors.YELLOW}[status]
    print(f"  {color}[{status}]{Colors.RESET} {name}（{seconds:.1f}s）{(' - ' + detail) if detail else ''}")
    RESULTS.append((key, name, status, detail, seconds))


def tail(text: str, lines: int = 25) -> str:
    content = [ln for ln in strip_ansi(text).splitlines() if ln.strip()]
    return "\n".join(f"      | {ln}" for ln in content[-lines:])


def run_script(script: str, args: list[str], timeout: int) -> tuple[int, str]:
    """在子进程中运行 tests/ 下的脚本；统一 UTF-8，避免 Windows 控制台编码炸掉子进程"""
    env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
    proc = subprocess.run(
        [sys.executable, str(TESTS_DIR / script), *args],
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        env=env,
    )
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


# ==================== 各步骤 ====================

# 参与"后端进程是否旧于代码"比对的目录/文件（tests/ 不参与：改测试脚本不用重启后端）
_STALE_SCAN_PATHS = ("agent", "routers", "shared", "main.py")


def _latest_code_mtime() -> float:
    """后端代码的最新修改时间（排除 __pycache__）"""
    latest = 0.0
    for rel in _STALE_SCAN_PATHS:
        path = PROJECT_ROOT / rel
        if path.is_file():
            candidates = [path]
        else:
            candidates = path.rglob("*.py")
        for p in candidates:
            if "__pycache__" in p.parts:
                continue
            try:
                latest = max(latest, p.stat().st_mtime)
            except OSError:
                continue
    return latest


def _get_listener_start(port: int) -> Optional[datetime]:
    """取监听指定端口的进程启动时间（Windows/PowerShell）；取不到返回 None"""
    ps = (
        "$c=Get-NetTCPConnection -State Listen -LocalPort {port} -ErrorAction Stop | "
        "Select-Object -First 1; $p=Get-Process -Id $c.OwningProcess; "
        "'{{0}}|{{1}}' -f $p.Id, $p.StartTime.ToString('o')"
    ).format(port=port)
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            capture_output=True, text=True, timeout=20,
        )
        out = (proc.stdout or "").strip()
        pid_s, iso = out.split("|", 1)
        started = datetime.fromisoformat(iso.strip())
        # PowerShell 'o' 格式带本地时区偏移，datetime.fromtimestamp 是 naive，统一去 tzinfo 再比
        return started.replace(tzinfo=None)
    except Exception:
        return None


def _check_backend_fresh(base_url: str) -> None:
    """旧进程检测：后端进程启动时间早于代码最新修改时间 → 提示重启。

    本轮 intent 评测"全灭"的根因就是 8000 跑着旧代码，这里让回归自动抓出该问题。
    """
    start = time.time()
    try:
        from urllib.parse import urlparse

        port = urlparse(base_url).port or (443 if base_url.startswith("https") else 80)
    except Exception:
        port = 8000

    started_at = _get_listener_start(port)
    if started_at is None:
        record(
            "precheck", "后端进程版本", "SKIP",
            f"无法取得 {port} 端口监听进程信息（非 Windows 或无 PowerShell）",
            time.time() - start,
        )
        return

    latest_mtime = _latest_code_mtime()
    if latest_mtime <= 0:
        record("precheck", "后端进程版本", "SKIP", "无法扫描代码修改时间", time.time() - start)
        return

    latest_dt = datetime.fromtimestamp(latest_mtime)
    # 5s 容差：编辑器保存/格式化造成的毫秒级抖动不算旧
    if started_at < latest_dt - timedelta(seconds=5):
        record(
            "precheck", "后端进程版本", "FAIL",
            f"进程启动于 {started_at:%H:%M:%S}，早于代码修改 {latest_dt:%H:%M:%S}，"
            "运行的是旧代码，请重启后端后再回归",
            time.time() - start,
        )
        return
    record(
        "precheck", "后端进程版本", "PASS",
        f"进程 {started_at:%H:%M:%S} 不旧于代码 {latest_dt:%H:%M:%S}",
        time.time() - start,
    )


def step_precheck(base_url: str) -> tuple[bool, bool]:
    """后端 /docs 可达 + 数据库可连；返回 (后端可用, 数据库可用)"""
    start = time.time()
    backend_ok = False
    db_ok = False

    try:
        import requests

        resp = requests.get(f"{base_url.rstrip('/')}/docs", timeout=5)
        backend_ok = resp.status_code == 200
        backend_detail = "后端 OK" if backend_ok else f"后端 /docs 返回 {resp.status_code}"
    except Exception as e:
        backend_detail = f"后端不可达（{e}）"

    try:
        from sqlalchemy import text
        from shared.models.database import SessionLocal

        db = SessionLocal()
        try:
            db.execute(text("select 1"))
        finally:
            db.close()
        db_ok = True
        db_detail = "PostgreSQL OK"
    except Exception as e:
        db_detail = f"PostgreSQL 不可连（{e}）"

    detail = f"{backend_detail}；{db_detail}"
    record("precheck", "环境预检", "PASS" if (backend_ok and db_ok) else "FAIL", detail, time.time() - start)
    if backend_ok:
        _check_backend_fresh(base_url)
    return backend_ok, db_ok


def step_scheduler() -> str:
    """V5 老人线定时任务注册检查（注册后立刻关停，不触发执行）

    AsyncIOScheduler.start() 需要活动事件循环，因此放进 asyncio.run 里执行。
    """
    import asyncio

    start = time.time()

    async def _collect_jobs():
        from shared.tasks.scheduler import setup_scheduler, shutdown_scheduler

        scheduler = setup_scheduler()
        jobs = {j.id: j for j in scheduler.get_jobs()}
        shutdown_scheduler()
        return jobs

    try:
        jobs = asyncio.run(_collect_jobs())
    except Exception as e:
        record("scheduler", "定时任务注册", "FAIL", f"无法注册调度器: {e}", time.time() - start)
        return "FAIL"

    missing = [jid for jid in EXPECTED_FAMILY_JOBS if jid not in jobs]
    if missing:
        detail = "缺少任务: " + ", ".join(missing)
        record("scheduler", "定时任务注册", "FAIL", detail, time.time() - start)
        return "FAIL"

    print("      已注册的老人线任务:")
    for jid, label in EXPECTED_FAMILY_JOBS.items():
        print(f"        - {jid}（{label}）: {jobs[jid].trigger}")
    record("scheduler", "定时任务注册", "PASS", f"{len(EXPECTED_FAMILY_JOBS)} 个任务齐全", time.time() - start)
    return "PASS"


def step_smoke(base_url: str, timeout: int, verbose: bool) -> str:
    """冒烟测试（含 13. Agent 动作链路）"""
    start = time.time()
    try:
        code, out = run_script("smoke_test.py", ["--base-url", base_url], timeout)
    except subprocess.TimeoutExpired:
        record("smoke", "冒烟测试", "FAIL", f"超时（>{timeout}s）", time.time() - start)
        return "FAIL"

    clean = strip_ansi(out)
    m = re.search(r"通过:\s*(\d+)\s*失败:\s*(\d+)\s*跳过:\s*(\d+)", clean)
    if verbose:
        print(tail(out, 40))
    if not m:
        record("smoke", "冒烟测试", "FAIL", "未解析到结果汇总（后端未启动？）", time.time() - start)
        print(tail(out, 15))
        return "FAIL"

    passed, failed, skipped = m.groups()
    detail = f"通过 {passed} / 失败 {failed} / 跳过 {skipped}"
    if code == 0 and failed == "0":
        record("smoke", "冒烟测试", "PASS", detail, time.time() - start)
        return "PASS"

    record("smoke", "冒烟测试", "FAIL", detail, time.time() - start)
    failed_lines = [ln for ln in clean.splitlines() if "✗ FAIL" in ln]
    for ln in failed_lines:
        print(f"      | {ln.strip()}")
    return "FAIL"


def step_care(repeat: int, timeout: int) -> str:
    """老人线关怀任务：触发 + 幂等（第二次必须为 0 条）"""
    start = time.time()
    try:
        code, out = run_script(
            "care_tasks.py", ["--task", "all", "--repeat", str(repeat), "--limit", "8"], timeout
        )
    except subprocess.TimeoutExpired:
        record("care", "关怀任务与幂等", "FAIL", f"超时（>{timeout}s）", time.time() - start)
        return "FAIL"

    clean = strip_ansi(out)
    if code != 0:
        record("care", "关怀任务与幂等", "FAIL", f"脚本退出码 {code}", time.time() - start)
        print(tail(out, 20))
        return "FAIL"

    if "没有可关怀的家庭关系" in clean:
        record("care", "关怀任务与幂等", "SKIP", "无 accepted 的 family 关系，无法验证", time.time() - start)
        return "SKIP"

    firsts = re.findall(r"第 1 次执行: 发送 (\d+) 条", clean)
    seconds = re.findall(r"第 2 次执行: 发送 (\d+) 条", clean)
    if len(seconds) < 3:
        record("care", "关怀任务与幂等", "FAIL", "三个任务的执行结果不全", time.time() - start)
        print(tail(out, 25))
        return "FAIL"

    detail = f"首次发送 {firsts}，第二次 {seconds}"
    bad = [i for i, s in enumerate(seconds) if s != "0"]
    if bad:
        record("care", "关怀任务与幂等", "FAIL", f"幂等失效 {detail}", time.time() - start)
        print(tail(out, 25))
        return "FAIL"

    # 首次全 0 说明当天已推送过（幂等键 = type + date），本次没真正走发送分支，
    # 只能证明幂等，不能证明"能发出"，故降级为 SKIP 而非 PASS。
    if firsts and all(f == "0" for f in firsts):
        record(
            "care", "关怀任务与幂等", "SKIP",
            f"当天已推送过（幂等键含日期），未走到发送分支：{detail}；"
            "删当天 messages 记录后可重现",
            time.time() - start,
        )
        return "SKIP"

    record("care", "关怀任务与幂等", "PASS", detail, time.time() - start)
    return "PASS"


def step_rules(base_url: str, timeout: int, verbose: bool) -> str:
    """PRD 规则行为断言（D5/D12/D13/4.6/4.7/5.4/宠物红线/B3 口径）"""
    start = time.time()
    try:
        code, out = run_script("rules_eval.py", ["--base-url", base_url], timeout)
    except subprocess.TimeoutExpired:
        record("rules", "PRD 规则断言", "FAIL", f"超时（>{timeout}s）", time.time() - start)
        return "FAIL"

    clean = strip_ansi(out)
    if verbose:
        print(tail(out, 40))
    m = re.search(r"通过:\s*(\d+)\s*失败:\s*(\d+)\s*跳过:\s*(\d+)(?:\s*警告:\s*(\d+))?", clean)
    if not m:
        record("rules", "PRD 规则断言", "FAIL", "未解析到结果汇总（后端未启动？）", time.time() - start)
        print(tail(out, 15))
        return "FAIL"

    p_, f_, s_ = m.group(1), m.group(2), m.group(3)
    w_ = m.group(4) or "0"
    detail = f"通过 {p_} / 失败 {f_} / 跳过 {s_} / 警告 {w_}"
    if code == 0 and f_ == "0":
        record("rules", "PRD 规则断言", "PASS", detail, time.time() - start)
        return "PASS"

    record("rules", "PRD 规则断言", "FAIL", detail, time.time() - start)
    for ln in [ln for ln in clean.splitlines() if "✗ FAIL" in ln][:10]:
        print(f"      | {ln.strip()}")
    return "FAIL"


def step_intent(base_url: str, threshold: float, timeout: int, verbose: bool) -> str:
    """15 动作意图命中率（低于阈值即失败）

    带 --bind-family：家人类动作（query_family / send_reminder_to_family）
    只有存在 accepted 家庭关系时才出卡，否则会被判为未命中。
    """
    start = time.time()
    try:
        code, out = run_script(
            "intent_eval.py",
            ["--base-url", base_url, "--threshold", str(threshold), "--bind-family"],
            timeout,
        )
    except subprocess.TimeoutExpired:
        record("intent", "意图命中率", "FAIL", f"超时（>{timeout}s）", time.time() - start)
        return "FAIL"

    clean = strip_ansi(out)
    if verbose:
        print(tail(out, 30))
    m = re.search(r"总命中率:\s*([\d.]+)%", clean)
    samples = re.search(r"样本:\s*(\d+)\s+命中:\s*(\d+)\s+未命中:\s*(\d+)\s+跳过:\s*(\d+)", clean)
    detail = f"命中率 {m.group(1)}%（阈值 {threshold:.0%}）" if m else "未解析到命中率"
    if samples:
        detail += f"，样本 {samples.group(1)} 命中 {samples.group(2)} 未命中 {samples.group(3)} 跳过 {samples.group(4)}"

    if code == 0 and m:
        record("intent", "意图命中率", "PASS", detail, time.time() - start)
        return "PASS"

    if code == 2:
        record("intent", "意图命中率", "FAIL", f"未取得有效样本（后端/LLM 未就绪）{detail}", time.time() - start)
    else:
        record("intent", "意图命中率", "FAIL", detail, time.time() - start)
    miss_lines = [ln for ln in clean.splitlines() if "✗ MISS" in ln]
    for ln in miss_lines[:12]:
        print(f"      | {ln.strip()}")
    return "FAIL"


# ==================== 主流程 ====================

def main() -> int:
    parser = argparse.ArgumentParser(description="DietAI 一键回归")
    parser.add_argument("--base-url", default="http://localhost:8000", help="后端地址")
    parser.add_argument("--threshold", type=float, default=0.90, help="意图命中率阈值（默认 0.9）")
    parser.add_argument("--repeat", type=int, default=2, help="关怀任务重复次数（2 验幂等）")
    parser.add_argument("--skip", default="", help=f"跳过的步骤，逗号分隔: {','.join(STEPS)}")
    parser.add_argument("--timeout", type=int, default=1800, help="单个脚本的超时（秒）")
    parser.add_argument("--verbose", action="store_true", help="打印子脚本的关键输出")
    args = parser.parse_args()

    skip = {s.strip() for s in args.skip.split(",") if s.strip()}
    unknown = skip - set(STEPS)
    if unknown:
        print(f"{Colors.RED}未知步骤: {', '.join(sorted(unknown))}，可选: {','.join(STEPS)}{Colors.RESET}")
        return 2

    log_section("DietAI 一键回归")
    print(f"  目标: {args.base_url}   跳过: {','.join(sorted(skip)) or '无'}")
    print(f"  时间: {time.strftime('%Y-%m-%d %H:%M:%S')}")

    started = time.time()

    # 1. 环境预检
    if "precheck" in skip:
        print(f"\n  {Colors.YELLOW}⊘ 已跳过环境预检，默认后端与数据库可用{Colors.RESET}")
        backend_ok, db_ok = True, True
    else:
        backend_ok, db_ok = step_precheck(args.base_url)

    # 2. 定时任务注册（只依赖项目代码，不依赖运行中的后端）
    if "scheduler" not in skip:
        step_scheduler()

    # 3. 依赖运行环境的步骤（care/rules 只需数据库或后端，smoke/intent 需要后端）
    for key, name, ready, reason in (
        ("smoke", "冒烟测试", backend_ok, "后端不可达"),
        ("care", "关怀任务与幂等", db_ok, "数据库不可连"),
        ("rules", "PRD 规则断言", backend_ok, "后端不可达"),
        ("intent", "意图命中率", backend_ok, "后端不可达"),
    ):
        if key in skip:
            continue
        if not ready:
            record(key, name, "SKIP", reason, 0.0)
        elif key == "smoke":
            step_smoke(args.base_url, args.timeout, args.verbose)
        elif key == "care":
            step_care(args.repeat, args.timeout)
        elif key == "rules":
            step_rules(args.base_url, args.timeout, args.verbose)
        else:
            step_intent(args.base_url, args.threshold, args.timeout, args.verbose)

    # ==================== 汇总 ====================
    elapsed = time.time() - started
    passed = [r for r in RESULTS if r[2] == "PASS"]
    failed = [r for r in RESULTS if r[2] == "FAIL"]
    skipped = [r for r in RESULTS if r[2] == "SKIP"]

    log_section("回归结果")
    for key, name, status, detail, secs in RESULTS:
        color = {"PASS": Colors.GREEN, "FAIL": Colors.RED, "SKIP": Colors.YELLOW}[status]
        print(f"  {color}{status:<4}{Colors.RESET} {name:<14} {secs:6.1f}s  {detail}")

    print(
        f"\n  通过 {Colors.GREEN}{len(passed)}{Colors.RESET}  "
        f"失败 {Colors.RED}{len(failed)}{Colors.RESET}  "
        f"跳过 {Colors.YELLOW}{len(skipped)}{Colors.RESET}   总耗时 {elapsed:.1f}s"
    )
    if failed:
        print(f"\n{Colors.RED}{Colors.BOLD}存在失败项，请检查！{Colors.RESET}")
        return 1
    print(f"\n{Colors.GREEN}{Colors.BOLD}回归通过！{Colors.RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
