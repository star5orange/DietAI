"""老人线关怀任务：手动触发 + 落库验核（V5 PRD 3.2 / B2-B4）。

调度器随 main.py 启动（定时点见 shared/tasks/scheduler.py），本脚本用于不等定时点、
立刻触发一次并核对结果，适合回归与演示前排障。

用法:
    uv run python tests/care_tasks.py --list                        # 只看家庭关系与最近推送
    uv run python tests/care_tasks.py --task care_ask --meal-type 2 # 触发午餐关怀询问
    uv run python tests/care_tasks.py --task alerts                 # 触发异常主动推送
    uv run python tests/care_tasks.py --task report                 # 触发父母日报
    uv run python tests/care_tasks.py --task all                    # 三个都跑一遍
    uv run python tests/care_tasks.py --task report --repeat 2      # 第二次应为 0，验幂等

前置条件:
    - PostgreSQL 已运行（读会话/记录/消息表）
    - .env.dev 已按 .env.example 配好（DIETAI_ 前缀）
"""

import argparse
import asyncio
import logging
import sys
from functools import partial
from pathlib import Path

# 本地开发 echo=True 的 SQL 日志不走 logger 级别（setLevel 无效），
# 用 logging.disable 才能压掉；只影响本进程，不改项目配置
logging.disable(logging.INFO)

# 以 `python tests/care_tasks.py` 直接运行时，sys.path[0] 是 tests/，补上项目根目录
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

try:
    from shared.services import family_care_service as care
except Exception as e:  # 依赖未装/环境变量缺失时给出可读提示
    print(f"无法导入 family_care_service，请用 `uv run python tests/care_tasks.py` 运行: {e}")
    sys.exit(2)


CARE_PUSH_TYPES = {"care_ask", "family_daily_report"}

TASK_LABELS = {
    "care_ask": "饭点关怀询问（B2）",
    "alerts": "家庭异常主动推送（B3）",
    "report": "父母日报推送（B4）",
}


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def log_section(title: str):
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'=' * 56}")
    print(f"  {title}")
    print(f"{'=' * 56}{Colors.RESET}")


def show_care_targets() -> int:
    """家庭关系预检：任务返回 0 最常见的原因就是没有 accepted 的 family 关系"""
    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        targets = care.list_care_targets(db)
        if not targets:
            print(
                f"  {Colors.YELLOW}没有可关怀的家庭关系（relationship_type=family 且 status=accepted）；"
                f"三个任务都会返回 0。请先在 App「家人健康」页完成家人绑定。{Colors.RESET}"
            )
            return 0
        print(f"  可关怀家庭: {len(targets)} 组（老人 ← 子女）")
        for t in targets:
            print(f"    - 老人 {t['elder_name']}({t['elder_id']}) ← 子女 {t['guardian_id']}")
        return len(targets)
    finally:
        db.close()


def show_recent_pushes(limit: int):
    """最近关怀推送落库核对（messages 表 + extra_data.type）"""
    from sqlalchemy import or_
    from shared.models.database import SessionLocal
    from shared.models.message_models import Message

    db = SessionLocal()
    try:
        push_type = Message.extra_data["type"].astext
        rows = (
            db.query(Message)
            .filter(
                or_(
                    push_type.in_(list(CARE_PUSH_TYPES)),
                    push_type.like("family_alert_%"),
                )
            )
            .order_by(Message.id.desc())
            .limit(limit)
            .all()
        )
        if not rows:
            print(f"  {Colors.YELLOW}最近没有关怀类消息落库{Colors.RESET}")
            return
        for m in rows:
            content = (m.content or "").replace("\n", " ")[:46]
            print(
                f"    #{m.id} [{m.extra_data.get('type')}] {m.sender_id}→{m.receiver_id} "
                f"{m.created_at:%Y-%m-%d %H:%M} {content}"
            )
    finally:
        db.close()


def run_task(task: str, meal_type, repeat: int) -> int:
    """触发单个任务；返回首次执行的发送条数"""
    if task == "care_ask":
        runner = partial(care.ask_meal_care, meal_type)
    elif task == "alerts":
        runner = care.push_family_alerts
    elif task == "report":
        runner = care.push_daily_reports
    else:
        print(f"{Colors.RED}未知任务: {task}{Colors.RESET}")
        return -1

    print(f"\n  任务: {TASK_LABELS[task]}")
    first = None
    for i in range(repeat):
        try:
            sent = asyncio.run(runner())
        except Exception as e:
            print(f"  {Colors.RED}第 {i + 1} 次执行异常: {e}{Colors.RESET}")
            return -1
        if first is None:
            first = sent
        suffix = "（幂等验证：期望 0）" if i > 0 else ""
        print(f"  第 {i + 1} 次执行: 发送 {sent} 条 {suffix}")

    if first == 0:
        if task == "care_ask":
            print(
                f"  {Colors.YELLOW}说明: 当前不在饭点时段时需用 --meal-type 指定餐次；"
                f"老人当天该餐次已记录、或当天已推送过，也会返回 0。{Colors.RESET}"
            )
        elif task == "report":
            print(
                f"  {Colors.YELLOW}说明: 老人当天既无饮食记录也无异常时不推送（避免空日报）。{Colors.RESET}"
            )
        else:
            print(
                f"  {Colors.YELLOW}说明: 仅推送 warning 级异常；当天已推送过同类异常也会返回 0。{Colors.RESET}"
            )
    return first


def main() -> int:
    parser = argparse.ArgumentParser(description="老人线关怀任务手动触发与验核")
    parser.add_argument(
        "--task",
        choices=["care_ask", "alerts", "report", "all"],
        help="要触发的任务；缺省只做体检（等同 --list）",
    )
    parser.add_argument(
        "--meal-type", type=int, choices=[1, 2, 3, 4, 5], help="care_ask 的餐次（1早 2午 3晚 4加餐 5夜宵），缺省按当前小时自动判定"
    )
    parser.add_argument("--repeat", type=int, default=1, help="重复执行次数；2 可验幂等（第二次应为 0）")
    parser.add_argument("--limit", type=int, default=10, help="最近推送展示条数")
    parser.add_argument("--list", action="store_true", help="只看家庭关系与最近推送，不触发任务")
    args = parser.parse_args()

    log_section("家庭关系预检")
    show_care_targets()

    log_section("最近关怀推送（messages）")
    show_recent_pushes(args.limit)

    if args.task and not args.list:
        log_section("触发任务")
        tasks = ["care_ask", "alerts", "report"] if args.task == "all" else [args.task]
        for task in tasks:
            run_task(task, args.meal_type, max(1, args.repeat))

        log_section("触发后落库核对")
        show_recent_pushes(args.limit)

    return 0


if __name__ == "__main__":
    sys.exit(main())
