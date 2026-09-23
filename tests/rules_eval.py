"""PRD 规则行为断言（D4/D5/D12/D13/4.6/4.7/5.4 + 宠物红线 + B3 口径）。

对 /api/deep/chat 的端到端规则验证，每条用一个全新临时账号（无家人/无档案），
逐条发出测试语句并断言卡片/回复符合 PRD 约定。需要后端 + LLM 已启动。

覆盖:
    d5_quantifier        D5  模糊量词：App 端必须追问（待确认卡或追问文案），不得替用户假定数值
    d45_undo_success     D12 撤销-成功：记录后立即撤销成功
    d45_undo_expired     D12 撤销-过期：伪造 11 分钟前的撤销凭证，撤销必须被拒（不用真等 10 分钟）
    time_attribution     4.7 时间归属：「昨天吃了什么」必须查昨天
    privacy_family       5.4 隐私：无家庭关系时查家人必须拒绝并引导绑定
    elder_default        D13 老人线例外：input_channel=hardware 时模糊量词按默认值直接记录，不追问
    pet_redline          D18 红线：宠物会话不得执行人域记录动作
    partial_failure      4.6 部分失败（弱断言，波动记 WARN 不记 FAIL）
    b3_alerts            B3 口径：collect_alerts（定时推送源）与 GET /api/family/alerts 逐条一致

用法:
    uv run python tests/rules_eval.py
    uv run python tests/rules_eval.py --base-url http://127.0.0.1:8010 --verbose
    uv run python tests/rules_eval.py --only d5_quantifier,pet_redline
"""

import argparse
import asyncio
import json
import sys
import time
from collections import Counter
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Optional

# 本地开发 engine.echo=True 的 SQL 日志不走 logger 级别，须在 import shared.* 之前压掉
import logging

logging.disable(logging.INFO)

try:
    import requests
except ImportError:
    print("请安装 requests: pip install requests")
    sys.exit(1)

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

DEFAULT_BASE_URL = "http://localhost:8000"
DEFAULT_PASSWORD = "Test123456!"
# B3 口径对比用的固定夹具账号（与 intent_eval.py --bind-family 一致）
B3_FIXTURE_USERNAME = "evalma"

# 宠物会话不允许出现的人域动作卡（PRD D18/D9：宠物模式不执行人域写操作）
HUMAN_WRITE_ACTIONS = {"record_food", "record_water", "record_weight", "set_reminder"}


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


# ==================== 结果统计 ====================

RESULTS: list[tuple[str, str, str, str]] = []  # (key, status, detail, seconds)


def record(key: str, status: str, detail: str, seconds: float):
    color = {"PASS": Colors.GREEN, "FAIL": Colors.RED, "WARN": Colors.YELLOW, "SKIP": Colors.YELLOW}[status]
    print(f"  {color}[{status}]{Colors.RESET} {key}（{seconds:.1f}s）{(' - ' + detail) if detail else ''}")
    RESULTS.append((key, status, detail, seconds))


# ==================== HTTP 客户端 ====================

class RuleClient:
    def __init__(self, base_url: str, timeout: int = 90, verbose: bool = False):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.verbose = verbose
        self.headers: dict = {}
        self.user_id: Optional[int] = None
        self.username: str = ""

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"

    def register_and_login(self) -> bool:
        """注册并登录一个全新临时账号（无家人关系、无档案，满足隐私/红线类断言的前置）"""
        stamp = int(time.time()) % 100000000
        self.username = f"r{stamp}"
        try:
            resp = requests.post(
                self._url("/api/auth/register"),
                json={
                    "username": self.username,
                    "password": DEFAULT_PASSWORD,
                    "email": f"{self.username}@test.com",
                },
                timeout=10,
            )
            raw_id = (resp.json().get("data") or {}).get("user_id") if resp.status_code == 200 else None
            self.user_id = int(raw_id) if raw_id is not None else None
        except Exception:
            self.user_id = None
        if not self.login(self.username, DEFAULT_PASSWORD):
            return False
        if self.user_id is None:
            # 注册响应没给 user_id 时用 /api/auth/me 兜底
            try:
                me = requests.get(self._url("/api/auth/me"), headers=self.headers, timeout=5)
                if me.status_code == 200:
                    me_data = me.json().get("data") or {}
                    raw_id = me_data.get("id") or me_data.get("user_id")
                    self.user_id = int(raw_id) if raw_id is not None else None
            except Exception:
                pass
        return True

    def login(self, username: str, password: str) -> bool:
        resp = requests.post(
            self._url("/api/auth/login"),
            json={"username": username, "password": password},
            timeout=10,
        )
        token = None
        if resp.status_code == 200:
            data = resp.json().get("data", {})
            token = data.get("access_token") or data.get("token")
        if not token:
            return False
        self.headers = {"Authorization": f"Bearer {token}"}
        return True

    def ask(
        self,
        text: str,
        input_channel: str = "app",
        session_type: Any = None,
    ) -> tuple[list[dict], str]:
        """调用 /api/deep/chat（每条新会话），返回（卡片 payload 列表, 回复文本）"""
        body: dict[str, Any] = {"message": text, "session_type": session_type or 1}
        if input_channel and input_channel != "app":
            body["input_channel"] = input_channel
        cards: list[dict] = []
        parts: list[str] = []
        resp = requests.post(
            self._url("/api/deep/chat"),
            headers=self.headers,
            json=body,
            timeout=self.timeout,
            stream=True,
        )
        if resp.status_code != 200:
            raise RuntimeError(f"HTTP {resp.status_code}")
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
            if ptype == "card":
                cards.append(payload.get("card") or {})
            elif ptype == "content":
                parts.append(str(payload.get("content") or ""))
            elif ptype == "error":
                raise RuntimeError(str(payload.get("error") or "agent error")[:120])
        return cards, "".join(parts)


# ==================== 各规则 ====================

def rule_d5_quantifier(c: RuleClient) -> tuple[str, str]:
    """D5：App 端模糊量词必须追问（待确认卡 / 追问文案），不得直接替用户假定数值记录"""
    cards, reply = c.ask("我喝了一瓶水")
    pending = [
        card
        for card in cards
        if card.get("action") == "record_water" and card.get("card_type") == "pending_confirm"
    ]
    committed = [
        card
        for card in cards
        if card.get("action") == "record_water" and card.get("card_type") not in (None, "text", "pending_confirm")
    ]
    asked_in_text = any(kw in reply for kw in ("多少毫升", "大概多少", "多少 ml", "点选", "选项"))
    if pending and (pending[0].get("data") or {}).get("options"):
        return "PASS", f"出待确认卡，options={len(pending[0]['data']['options'])} 项"
    if asked_in_text and not committed:
        return "PASS", "文本追问份量，未擅自记录"
    if committed:
        return "FAIL", f"模糊量词被直接记录（card_type={committed[0].get('card_type')}），未追问"
    return "FAIL", f"既无待确认卡也未追问。cards={[card.get('action') for card in cards]}"


def rule_undo_success(c: RuleClient) -> tuple[str, str]:
    """D12 成功路径：明确指令记录 → 立即撤销 → 成功文案"""
    cards, _ = c.ask("帮我记录：我喝了 300 毫升水")
    if not any(card.get("action") == "record_water" for card in cards):
        return "FAIL", f"前置记录未成功，卡片 {[card.get('action') for card in cards]}"
    undo_cards, undo_reply = c.ask("刚才那条记错了，撤销")
    undo_ok = any(card.get("action") == "undo" for card in undo_cards)
    if undo_ok or "已撤销" in undo_reply:
        return "PASS", "撤销成功"
    return "FAIL", f"撤销未成功。cards={[card.get('action') for card in undo_cards]} reply={undo_reply[:80]}"


def rule_undo_expired(c: RuleClient) -> tuple[str, str]:
    """D12 过期路径：伪造 11 分钟前的撤销凭证 → 撤销必须被拒且提示超窗口"""
    from agent.diet_deep_agent.actions.undo_journal import UndoEntry, _get_redis, _key

    async def _seed() -> bool:
        entry = UndoEntry(
            action="record_water",
            undo_token="999999001",
            summary="一条伪造的过期记录",
            created_at=time.time() - 700,  # 11 分钟前 > 600s TTL
        )
        client = await _get_redis()
        if client is None:
            return False
        import json as _json

        await client.set(
            _key(c.user_id),
            _json.dumps(entry.to_dict(), ensure_ascii=False),
            ex=600,
        )
        return True

    try:
        seeded = asyncio.run(_seed())
    except Exception as e:
        return "SKIP", f"无法写入 Redis 撤销凭证（{e}）"
    if not seeded:
        return "SKIP", "服务端撤销日志不可用（Redis 未连接），无法验证过期分支"

    _, reply = c.ask("撤销我刚才那条")
    rejected = ("没有可撤销" in reply) or ("10 分钟" in reply)
    if rejected:
        return "PASS", "过期凭证被拒绝，提示在窗口外"
    return "FAIL", f"过期凭证未被拒绝。reply={reply[:100]}"


def rule_time_attribution(c: RuleClient) -> tuple[str, str]:
    """4.7：「昨天吃了什么」必须归属昨天"""
    yesterday = (date.today() - timedelta(days=1)).isoformat()
    cards, _ = c.ask("昨天吃了什么")
    qt = [card for card in cards if card.get("action") == "query_today"]
    if not qt:
        return "FAIL", f"未出 query_today 卡。cards={[card.get('action') for card in cards]}"
    got = (qt[0].get("data") or {}).get("date")
    if got == yesterday:
        return "PASS", f"data.date={got}"
    return "FAIL", f"时间归属错误：期望 {yesterday}，实际 {got}"


def rule_privacy_family(c: RuleClient) -> tuple[str, str]:
    """5.4：无家庭关系时查家人必须拒绝（不出卡）并引导绑定"""
    cards, reply = c.ask("我妈今天吃了吗")
    leaked = any(card.get("action") == "query_family" for card in cards)
    guide = any(kw in reply for kw in ("绑定", "添加家人", "家人健康"))
    if not leaked and guide:
        return "PASS", "拒绝查询并引导绑定"
    if leaked:
        return "FAIL", "无家庭关系却出了 query_family 卡（隐私越权）"
    return "FAIL", f"拒绝了但无绑定引导。reply={reply[:80]}"


def rule_elder_default(c: RuleClient) -> tuple[str, str]:
    """D13：老人线（hardware 渠道）模糊量词不追问，按默认值直接记录"""
    cards, reply = c.ask("我喝了一杯水", input_channel="hardware")
    water_cards = [card for card in cards if card.get("action") == "record_water"]
    if not water_cards:
        return "FAIL", f"硬件渠道未直接记录。cards={[card.get('action') for card in cards]} reply={reply[:80]}"
    card = water_cards[0]
    if card.get("card_type") == "pending_confirm":
        return "FAIL", "硬件渠道仍出了待确认卡（老人线应按默认值记录，PRD D13）"
    default_ml = (card.get("data") or {}).get("amount_ml")
    return "PASS", f"按默认值记录（card_type={card.get('card_type')}, amount_ml={default_ml}）"


def rule_pet_redline(c: RuleClient) -> tuple[str, str]:
    """D18/D9 红线：宠物会话不得执行人域记录动作"""
    cards, reply = c.ask("帮我记录：中午吃了宫保鸡丁", session_type=6)
    leaked = [card.get("action") for card in cards if card.get("action") in HUMAN_WRITE_ACTIONS]
    if leaked:
        return "FAIL", f"宠物会话出现了人域动作卡: {leaked}"
    pet_legal = [card.get("action") for card in cards if card.get("action") in ("record_pet_feeding", "query_pet")]
    detail = "未执行任何人域写操作" + (f"（宠物域合法动作: {pet_legal}）" if pet_legal else "")
    return "PASS", detail


def rule_partial_failure(c: RuleClient) -> tuple[str, str]:
    """4.6：一句话两个动作，失败项（无宠物）不阻塞成功项（饮水）。
    LLM 组合行为有波动，未达预期记 WARN 不记 FAIL。"""
    cards, reply = c.ask("帮我记一下喂了猫，还有喝了 300 毫升水")
    water_ok = any(card.get("action") == "record_water" for card in cards)
    if water_ok and ("猫" in reply or "宠物" in reply):
        return "PASS", "成功项（饮水）执行且失败项（喂猫）有说明"
    if water_ok:
        return "WARN", "饮水成功但回复未提及喂猫失败项"
    return "WARN", f"饮水未出卡（LLM 组合行为波动）。cards={[card.get('action') for card in cards]}"


def rule_b3_alerts(c: RuleClient) -> tuple[str, str]:
    """B3 口径一致性：collect_alerts（定时推送源）与 GET /api/family/alerts 同源同果"""
    from shared.models.database import SessionLocal
    from shared.models.user_models import User
    from shared.models.social_models import UserRelationship
    from shared.services.family_care_service import collect_alerts
    from sqlalchemy import or_

    db = SessionLocal()
    try:
        viewer = db.query(User).filter(User.username == B3_FIXTURE_USERNAME).first()
        if viewer is None:
            return "SKIP", f"夹具账号 {B3_FIXTURE_USERNAME} 不存在（先跑 intent_eval --bind-family 生成）"
        family_count = (
            db.query(UserRelationship)
            .filter(
                or_(
                    UserRelationship.user_id == viewer.id,
                    UserRelationship.related_user_id == viewer.id,
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted",
            )
            .count()
        )
        if family_count == 0:
            return "SKIP", f"{B3_FIXTURE_USERNAME} 无 accepted 家庭关系，口径对比无意义"
        local = collect_alerts(db, viewer.id)
    finally:
        db.close()

    # 接口侧必须用夹具账号自己的 token（c.headers 是临时账号的，查不到其家人）
    fixture = RuleClient(c.base_url, c.timeout)
    if not fixture.login(B3_FIXTURE_USERNAME, DEFAULT_PASSWORD):
        return "SKIP", f"夹具账号 {B3_FIXTURE_USERNAME} 登录失败"
    resp = requests.get(fixture._url("/api/family/alerts"), headers=fixture.headers, timeout=10)
    if resp.status_code != 200:
        return "FAIL", f"GET /api/family/alerts 返回 {resp.status_code}"
    remote = (resp.json().get("data") or {}).get("alerts") or []

    key = lambda a: (str(a.get("type")), a.get("user_id"))  # noqa: E731
    if Counter(map(key, local)) == Counter(map(key, remote)):
        return "PASS", f"两侧一致：{len(local)} 条（家人 {family_count} 位）"
    only_local = [key(a) for a in local if key(a) not in set(map(key, remote))]
    only_remote = [key(a) for a in remote if key(a) not in set(map(key, local))]
    return "FAIL", f"口径不一致。仅本地: {only_local}；仅接口: {only_remote}"


RULES = [
    ("d5_quantifier", "D5 量词追问", rule_d5_quantifier),
    ("d45_undo_success", "D12 撤销-成功", rule_undo_success),
    ("d45_undo_expired", "D12 撤销-过期", rule_undo_expired),
    ("time_attribution", "4.7 时间归属", rule_time_attribution),
    ("privacy_family", "5.4 隐私拒绝", rule_privacy_family),
    ("elder_default", "D13 老人线默认值", rule_elder_default),
    ("pet_redline", "宠物红线", rule_pet_redline),
    ("partial_failure", "4.6 部分失败", rule_partial_failure),
    ("b3_alerts", "B3 口径一致", rule_b3_alerts),
]


def main() -> int:
    parser = argparse.ArgumentParser(description="PRD 规则行为断言")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="后端地址")
    parser.add_argument("--timeout", type=int, default=90, help="单条对话超时（秒）")
    parser.add_argument("--only", help="只跑指定规则（逗号分隔 key）")
    parser.add_argument("--verbose", action="store_true", help="打印每条回复摘要")
    args = parser.parse_args()

    selected = RULES
    if args.only:
        keys = {k.strip() for k in args.only.split(",") if k.strip()}
        selected = [r for r in RULES if r[0] in keys]
        unknown = keys - {r[0] for r in RULES}
        if unknown:
            print(f"{Colors.RED}未知规则: {', '.join(sorted(unknown))}{Colors.RESET}")
            return 2
    if not selected:
        print(f"{Colors.RED}没有匹配的规则{Colors.RESET}")
        return 2

    print(f"\n{Colors.BOLD}{'=' * 56}")
    print("  PRD 规则行为断言")
    print(f"  目标: {args.base_url}  规则: {len(selected)} 项")
    print(f"{'=' * 56}{Colors.RESET}")

    client = RuleClient(args.base_url, timeout=args.timeout, verbose=args.verbose)
    if not client.register_and_login():
        print(f"{Colors.RED}临时账号注册/登录失败，无法开始（{args.base_url}）{Colors.RESET}")
        return 2
    if client.user_id is None:
        print(f"{Colors.RED}无法取得评测账号 user_id，撤销过期用例将跳过{Colors.RESET}")

    started = time.time()
    for key, _label, fn in selected:
        t0 = time.time()
        try:
            status, detail = fn(client)
        except Exception as e:
            status, detail = "FAIL", f"执行异常: {e}"
        record(key, status, detail, time.time() - t0)

    # ==================== 汇总 ====================
    counts = {s: sum(1 for r in RESULTS if r[1] == s) for s in ("PASS", "FAIL", "SKIP", "WARN")}
    elapsed = time.time() - started
    print(f"\n{Colors.BOLD}{'=' * 56}{Colors.RESET}")
    print(
        f"  总计: {len(RESULTS)}  通过: {counts['PASS']}  失败: {counts['FAIL']}  "
        f"跳过: {counts['SKIP']}  警告: {counts['WARN']}   总耗时 {elapsed:.1f}s"
    )
    failures = [r for r in RESULTS if r[1] == "FAIL"]
    if failures:
        print(f"\n{Colors.RED}{Colors.BOLD}未通过明细:{Colors.RESET}")
        for key, _s, detail, _sec in failures:
            print(f"  - {key}: {detail}")
        return 1
    print(f"\n{Colors.GREEN}{Colors.BOLD}规则断言全部通过（警告 {counts['WARN']} 项不影响）{Colors.RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
