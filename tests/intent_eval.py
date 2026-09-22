"""V5.0 对话意图命中率评测（PRD §6：对话意图命中率 ≥90%）。

语料集：tests/action_corpus.jsonl（15 个动作 × 4 条口语表达，共 60 条）
评测口径：
    对每条语料调用 /api/deep/chat，观察 Agent 本轮实际调用的注册表动作
    （SSE `card` 事件里的 action）。命中条件（满足其一即算命中）：
      1. 卡片动作 == 语料标注动作（主口径）
      2. 回复文本命中该条语料的 fallback_keywords（用于动作合法地不出卡的场景，
         如 undo 无日志可撤销、体检数据未授权、宠物未添加）
用法:
    # 离线校验语料覆盖度（不需要后端与 LLM）
    python tests/intent_eval.py --check-corpus

    # 在线评测（需后端 + LLM 已启动）
    python tests/intent_eval.py
    python tests/intent_eval.py --bind-family          # 家人类动作需要已绑定家人
    python tests/intent_eval.py --username u --password p   # 用已有账号（含家人关系）
    python tests/intent_eval.py --threshold 0.9 --action record_water
    python tests/intent_eval.py --base-url http://localhost:8000 --limit 10
"""

import argparse
import json
import sys
import time
from collections import defaultdict
from pathlib import Path
from typing import Optional

try:
    import requests
except ImportError:
    print("请安装 requests: pip install requests")
    sys.exit(1)


# 以 `python tests/intent_eval.py` 直接运行时，sys.path[0] 是 tests/，
# 补上项目根目录，--check-corpus 才能导入 agent 侧的动作注册表。
PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

CORPUS_PATH = Path(__file__).with_name("action_corpus.jsonl")
DEFAULT_BASE_URL = "http://localhost:8000"
DEFAULT_THRESHOLD = 0.90
# 评测临时账号的默认口令（后端限制 username 1-10 字符，见 shared/models/schemas/user.py）
DEFAULT_PASSWORD = "Test123456!"
# --bind-family 用的固定家人账号（复用以避免每次评测都新建账号）
# 称谓需覆盖语料里出现的家人（妈 / 爸 / 奶奶），否则家人类样本会因「未绑定该家人」不出卡
FIXTURE_ELDERS = (
    ("evalma", "妈"),
    ("evalba", "爸"),
    ("evalnn", "奶奶"),
)

# 语料覆盖度校验的期望动作（PRD 3.1：一期 6 + 二期 9 = 15）
EXPECTED_ACTIONS = [
    "record_food",
    "record_water",
    "record_weight",
    "query_today",
    "query_family",
    "undo",
    "query_nutrition",
    "query_weight_trend",
    "record_pet_feeding",
    "query_pet",
    "query_exam",
    "set_reminder",
    "query_cost",
    "generate_weekly_report",
    "send_reminder_to_family",
]


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


# ==================== 语料 ====================

def load_corpus(action: Optional[str] = None, limit: Optional[int] = None) -> list[dict]:
    if not CORPUS_PATH.exists():
        print(f"{Colors.RED}语料文件不存在: {CORPUS_PATH}{Colors.RESET}")
        sys.exit(2)
    samples = []
    for line_no, raw in enumerate(CORPUS_PATH.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"{Colors.RED}语料第 {line_no} 行 JSON 解析失败: {e}{Colors.RESET}")
            sys.exit(2)
        if not item.get("text") or not item.get("action"):
            print(f"{Colors.RED}语料第 {line_no} 行缺少 text/action 字段{Colors.RESET}")
            sys.exit(2)
        item.setdefault("id", f"line-{line_no}")
        item.setdefault("tags", [])
        item.setdefault("fallback_keywords", [])
        samples.append(item)
    if action:
        samples = [s for s in samples if s["action"] == action]
    if limit:
        samples = samples[:limit]
    return samples


def check_corpus(samples: list[dict]) -> int:
    """离线校验：语料是否覆盖注册表全部动作（不需要后端）"""
    print(f"\n{Colors.BOLD}{'=' * 56}")
    print("  语料覆盖度校验（离线）")
    print(f"{'=' * 56}{Colors.RESET}")

    registered = set(EXPECTED_ACTIONS)
    try:
        from agent.diet_deep_agent.actions import registry

        registered = set(registry.names)
        print(f"  注册表动作数: {len(registered)}（来自 ActionRegistry）")
    except Exception as e:
        print(f"  {Colors.YELLOW}无法导入注册表，退化为期望清单校验: {e}{Colors.RESET}")

    covered = {s["action"] for s in samples}
    missing = sorted(registered - covered)
    unknown = sorted(covered - registered)

    per_action = defaultdict(int)
    for s in samples:
        per_action[s["action"]] += 1

    print(f"  语料条数: {len(samples)}，覆盖动作: {len(covered)}/{len(registered)}")
    for name in sorted(per_action):
        print(f"    - {name}: {per_action[name]} 条")

    ok = True
    if missing:
        ok = False
        print(f"  {Colors.RED}✗ 未被语料覆盖的动作: {', '.join(missing)}{Colors.RESET}")
    if unknown:
        ok = False
        print(f"  {Colors.RED}✗ 语料中出现注册表未定义的动作: {', '.join(unknown)}{Colors.RESET}")
    if ok:
        print(f"\n  {Colors.GREEN}✓ 语料覆盖注册表全部动作{Colors.RESET}")
    return 0 if ok else 1


# ==================== 在线评测 ====================

class IntentEval:
    def __init__(self, base_url: str, timeout: int = 90, verbose: bool = False):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.verbose = verbose
        self.headers: dict = {}

    def _url(self, path: str) -> str:
        return f"{self.base_url}{path}"

    def login(self, username: Optional[str] = None, password: Optional[str] = None) -> bool:
        """登录评测账号。

        username 为空时注册一个临时账号（1-10 字符限制）；给了用户名则直接登录，
        便于用「已绑定家人」的既有账号评测家人类动作。
        """
        if not username:
            # 后端限制 username 长度 1-10（shared/models/schemas/user.py）
            stamp = int(time.time()) % 100000000
            username = f"i{stamp}"
            password = password or DEFAULT_PASSWORD
            # /api/auth/register 只返回 user_id，token 需再调 /api/auth/login
            self._register(username, password)

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
            print(f"{Colors.RED}登录失败，无法开始评测（{self.base_url}）{Colors.RESET}")
            return False
        self.headers = {"Authorization": f"Bearer {token}"}
        return True

    def _register(self, username: str, password: str) -> Optional[int]:
        """注册账号（已存在时忽略），返回 user_id 或 None"""
        resp = requests.post(
            self._url("/api/auth/register"),
            json={"username": username, "password": password, "email": f"{username}@test.com"},
            timeout=10,
        )
        if resp.status_code == 200:
            return (resp.json().get("data") or {}).get("user_id")
        return None

    def _token_of(self, username: str, password: str) -> Optional[str]:
        """取指定账号的 token（用于替家人账号接受申请）"""
        resp = requests.post(
            self._url("/api/auth/login"),
            json={"username": username, "password": password},
            timeout=10,
        )
        if resp.status_code != 200:
            return None
        data = resp.json().get("data", {})
        return data.get("access_token") or data.get("token")

    def _search_user_id(self, username: str) -> Optional[int]:
        """按用户名精确匹配取 user_id（复用已存在的夹具账号时用）"""
        try:
            resp = requests.get(
                self._url("/api/social/search"),
                headers=self.headers,
                params={"keyword": username},
                timeout=10,
            )
            if resp.status_code != 200:
                return None
            for item in resp.json().get("data") or []:
                if item.get("username") == username:
                    return item.get("id")
        except Exception:
            return None
        return None

    def setup_family_fixture(self) -> None:
        """给评测账号绑定语料涉及的家人（best-effort，失败不中断评测）。

        query_family / send_reminder_to_family 只在存在 accepted 家庭关系、
        且称谓能匹配到该家人时才出卡；没有关系时 Agent 按 PRD 5.4 拒绝并引导绑定，
        属于设计内行为（corpus 里的 family 样本也就测不到出卡路径）。
        这里走产品自身的「添加家人 → 对方接受」接口，不直接写库，
        保证前置状态与真实用户一致。
        """
        bound = [label for username, label in FIXTURE_ELDERS if self._bind_family_member(username, label)]
        if bound:
            print(f"{Colors.GREEN}✓ 家人夹具就绪{Colors.RESET} 已绑定 {'、'.join(bound)}")
        else:
            print(f"{Colors.YELLOW}⊘ 家人夹具创建失败，家人类样本按未绑定处理{Colors.RESET}")

    def _bind_family_member(self, elder_username: str, label: str) -> bool:
        """与一个固定的家人账号建立 accepted 家庭关系（评测账号视角的称谓 = label）"""
        elder_id = self._register(elder_username, DEFAULT_PASSWORD) or self._search_user_id(elder_username)
        elder_token = self._token_of(elder_username, DEFAULT_PASSWORD)
        if not elder_id or not elder_token:
            return False

        try:
            resp = requests.post(
                self._url("/api/social/family"),
                headers=self.headers,
                json={"target_user_id": elder_id, "relationship_label": label},
                timeout=10,
            )
            request_id = (resp.json().get("data") or {}).get("request_id") if resp.status_code == 200 else None
        except Exception:
            request_id = None
        if not request_id:
            return False

        # 家人账号接受（接收方不设称谓，由 _auto_sync_labels 自动补互逆称谓）
        resp = requests.put(
            self._url(f"/api/social/friend-request/{request_id}"),
            params={"action": "accept"},
            headers={"Authorization": f"Bearer {elder_token}"},
            timeout=10,
        )
        return resp.status_code == 200

    def ask(self, text: str, session_type: int = 1) -> tuple[list[str], str]:
        """调用 /api/deep/chat，返回（本轮卡片动作列表, 回复文本）"""
        actions: list[str] = []
        text_parts: list[str] = []
        resp = requests.post(
            self._url("/api/deep/chat"),
            headers=self.headers,
            json={"message": text, "session_type": session_type},
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
                action = (payload.get("card") or {}).get("action")
                if action:
                    actions.append(str(action))
            elif ptype == "content":
                text_parts.append(str(payload.get("content") or ""))
            elif ptype == "error":
                raise RuntimeError(str(payload.get("error") or "agent error")[:120])
        return actions, "\n".join(text_parts)

    def run(self, samples: list[dict], threshold: float, sleep: float = 0.0) -> int:
        stat = defaultdict(lambda: {"total": 0, "hit": 0})
        failures: list[dict] = []
        errors = 0

        for idx, sample in enumerate(samples, 1):
            expected = sample["action"]
            stat[expected]["total"] += 1
            tag = f"[{idx}/{len(samples)}] {sample['id']}"
            try:
                actions, reply = self.ask(sample["text"])
            except Exception as e:
                errors += 1
                stat[expected]["total"] -= 1
                print(f"  {Colors.YELLOW}⊘ SKIP{Colors.RESET} {tag} {sample['text']} - {e}")
                if errors >= 5:
                    print(f"\n{Colors.RED}连续失败过多，终止评测（请确认后端与 LLM 已就绪）{Colors.RESET}")
                    break
                continue

            hit = expected in actions
            evidence = f"card={actions}"
            if not hit:
                for kw in sample.get("fallback_keywords", []):
                    if kw and kw in reply:
                        hit = True
                        evidence = f"text~{kw}"
                        break

            if hit:
                stat[expected]["hit"] += 1
                print(f"  {Colors.GREEN}✓ HIT {Colors.RESET} {tag} {sample['text']} - {evidence}")
            else:
                print(f"  {Colors.RED}✗ MISS{Colors.RESET} {tag} {sample['text']} - {evidence}")
                failures.append(
                    {"id": sample["id"], "expected": expected, "text": sample["text"], "got": actions}
                )

            if self.verbose:
                print(f"        reply: {reply[:160].replace(chr(10), ' ')}")
            if sleep:
                time.sleep(sleep)

        # ==================== 汇总 ====================
        total = sum(v["total"] for v in stat.values())
        hit = sum(v["hit"] for v in stat.values())
        print(f"\n{Colors.BOLD}{'=' * 56}")
        print("  意图命中率（按注册表动作）")
        print(f"{'=' * 56}{Colors.RESET}")
        for name in EXPECTED_ACTIONS:
            if name not in stat:
                continue
            v = stat[name]
            rate = (v["hit"] / v["total"]) if v["total"] else 0.0
            color = Colors.GREEN if rate >= threshold else Colors.RED
            print(f"  {name:<26} {color}{v['hit']}/{v['total']}  {rate:6.1%}{Colors.RESET}")

        overall = (hit / total) if total else 0.0
        print(f"\n  样本: {total}  命中: {hit}  未命中: {total - hit}  跳过: {len(samples) - total}")
        color = Colors.GREEN if overall >= threshold else Colors.RED
        print(f"  总命中率: {color}{overall:.1%}{Colors.RESET}  （阈值 {threshold:.0%}）")

        if failures:
            print(f"\n{Colors.RED}{Colors.BOLD}未命中明细:{Colors.RESET}")
            for f in failures:
                print(f"  - {f['id']}: 「{f['text']}」 期望 {f['expected']}，实际卡片 {f['got'] or '无'}")

        if total == 0:
            print(f"\n{Colors.YELLOW}没有可评测样本（全部跳过）{Colors.RESET}")
            return 2
        return 0 if overall >= threshold else 1


def main() -> int:
    parser = argparse.ArgumentParser(description="V5.0 对话意图命中率评测")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="后端地址")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD, help="命中率阈值（默认 0.9）")
    parser.add_argument("--action", help="只评测指定动作（调试用）")
    parser.add_argument("--limit", type=int, help="只跑前 N 条")
    parser.add_argument("--timeout", type=int, default=90, help="单条请求超时（秒）")
    parser.add_argument("--sleep", type=float, default=0.0, help="每条之间的间隔（秒）")
    parser.add_argument("--check-corpus", action="store_true", help="离线校验语料覆盖度，不调用后端")
    parser.add_argument("--username", help="用已有账号登录评测（默认注册一个临时账号）")
    parser.add_argument("--password", help="配合 --username 使用")
    parser.add_argument(
        "--bind-family",
        action="store_true",
        help="评测前给临时账号绑定一个家人（走 /api/social 申请+接受），"
             "否则 query_family / send_reminder_to_family 会因「未绑定家人」不出卡",
    )
    parser.add_argument("--verbose", action="store_true", help="打印每条回复摘要")
    args = parser.parse_args()

    samples = load_corpus(args.action, args.limit)
    if not samples:
        print(f"{Colors.RED}没有匹配的语料{Colors.RESET}")
        return 2

    if args.check_corpus:
        return check_corpus(load_corpus())

    print(f"\n{Colors.BOLD}{'=' * 56}")
    print("  DietAI 对话意图命中率评测")
    print(f"  目标: {args.base_url}  样本: {len(samples)}  阈值: {args.threshold:.0%}")
    print(f"{'=' * 56}{Colors.RESET}")

    evaluator = IntentEval(args.base_url, timeout=args.timeout, verbose=args.verbose)
    if not evaluator.login(args.username, args.password):
        return 2
    if args.bind_family:
        evaluator.setup_family_fixture()
    return evaluator.run(samples, args.threshold, sleep=args.sleep)


if __name__ == "__main__":
    sys.exit(main())
