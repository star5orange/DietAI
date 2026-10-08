"""确认卡的确认凭证（PRD 4.2）。

叙述性提及「我吃了 / 我喝了 / 我称了」时，写操作返回「要帮你记录吗？」确认卡。
卡片携带 confirm_token，用户点「帮我记录」后由后端 /deep/actions/confirm 取出这张卡
预先备好的动作调用直接执行——不再让模型把按钮文案重新解析一遍。

否则份量、餐次、估算热量会在「重新理解」中丢失或被改写（卡片上写 500 大卡、
落库变成别的数值），重复点击或网络重试还会写两条记录。

- Redis key: dietai:confirm:{token}，TTL 600s（与撤销窗口一致）
- Redis 不可用时降级为进程内内存，语义一致（所有方法都不抛异常）
- 一次性：确认接口取出后立即作废，过期 / 重复提交都返回 None
"""

import json
import logging
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Optional

# 复用撤销日志的 Redis 惰性连接与降级判断（同一套「Redis 是否可用」口径）
from agent.diet_deep_agent.actions.undo_journal import _disable_redis, _get_redis

logger = logging.getLogger(__name__)

CONFIRM_TTL_SECONDS = 600
_KEY_PREFIX = "dietai:confirm:"

# 内存降级存储：{token: payload}
_memory_store: dict[str, dict[str, Any]] = {}


@dataclass
class PendingConfirm:
    """一张确认卡背后的动作调用（用户点一次「帮我记录」= 执行这里全部调用）"""

    user_id: int
    token: str
    label: str  # 待记录项名称（如「螺蛳粉」），用于历史回显时的用户消息文案
    calls: list[dict[str, Any]]  # [{"action": ..., "field": ..., "value": ..., "params": {...}}]
    created_at: float = field(default_factory=time.time)

    def is_expired(self, ttl_seconds: int = CONFIRM_TTL_SECONDS) -> bool:
        return time.time() - self.created_at > ttl_seconds

    def to_dict(self) -> dict[str, Any]:
        return {
            "user_id": self.user_id,
            "token": self.token,
            "label": self.label,
            "calls": self.calls,
            "created_at": self.created_at,
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "PendingConfirm":
        calls = payload.get("calls")
        return cls(
            user_id=int(payload.get("user_id") or 0),
            token=str(payload.get("token") or ""),
            label=str(payload.get("label") or ""),
            calls=(
                [dict(c) for c in calls if isinstance(c, dict)]
                if isinstance(calls, list) else []
            ),
            created_at=float(payload.get("created_at") or 0),
        )


async def register_record_confirm(
    user_id: Optional[int],
    action: str,
    label: str,
    params: dict[str, Any],
    confirm_field: str = "explicit_request",
) -> Optional[str]:
    """登记一张确认卡的凭证并返回 confirm_token。

    确认时执行的就是这里的调用：按 params 调用 action，并把 confirm_field 填成 True。
    user_id 缺失（动作上下文异常）时返回 None：卡片不带凭证，前端会退回「把按钮文案
    当消息发出去」的旧路径，不会写错数据。

    confirm_field：点「帮我记录」时回填 True 的入参名。默认 explicit_request
    （叙述性提及路径）；always_confirm 的动作（疾病档案写入 / 标记痊愈）传
    confirmed_by_user —— 该字段模型必须始终留空，只能由本凭证回填。
    """
    if user_id is None:
        return None
    token = uuid.uuid4().hex
    entry = PendingConfirm(
        user_id=int(user_id),
        token=token,
        label=label,
        calls=[
            {
                "action": action,
                "field": confirm_field,
                "value": True,
                "params": params,
            }
        ],
    )
    await _save(entry)
    return token


async def consume_confirm(token: str, user_id: int) -> Optional[PendingConfirm]:
    """取出并作废凭证（一次性）：过期 / 已用过 / 不属于该用户都返回 None"""
    if not token:
        return None
    payload = await _load(token)
    if payload is None:
        return None

    entry = PendingConfirm.from_dict(payload)
    if entry.user_id != int(user_id):
        return None  # 不是持卡人的凭证：不消耗，避免被误作废
    await _delete(token)  # 一次性：取出即作废
    if entry.is_expired():
        return None
    return entry


async def _save(entry: PendingConfirm) -> None:
    payload = entry.to_dict()
    client = await _get_redis()
    if client is not None:
        try:
            await client.set(
                _key(entry.token),
                json.dumps(payload, ensure_ascii=False),
                ex=CONFIRM_TTL_SECONDS,
            )
            _memory_store.pop(entry.token, None)
            return
        except Exception as e:
            _disable_redis(e)
    _prune_expired()
    _memory_store[entry.token] = payload


async def _load(token: str) -> Optional[dict[str, Any]]:
    client = await _get_redis()
    if client is not None:
        try:
            raw = await client.get(_key(token))
            return json.loads(raw) if raw else None
        except Exception as e:
            _disable_redis(e)
    return _memory_store.get(token)


async def _delete(token: str) -> None:
    _memory_store.pop(token, None)
    client = await _get_redis()
    if client is not None:
        try:
            await client.delete(_key(token))
        except Exception as e:
            _disable_redis(e)


def _prune_expired() -> None:
    """内存降级时顺手清理过期凭证（Redis 侧由 TTL 自动过期）"""
    now = time.time()
    stale = [
        token
        for token, payload in _memory_store.items()
        if now - float(payload.get("created_at") or 0) > CONFIRM_TTL_SECONDS
    ]
    for token in stale:
        _memory_store.pop(token, None)


def _key(token: str) -> str:
    return f"{_KEY_PREFIX}{token}"