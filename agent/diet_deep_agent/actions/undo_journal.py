"""撤销日志（PRD 4.5）：只保留每个用户"最近一条"写操作，窗口 10 分钟。

- Redis key: dietai:undo:{user_id}，TTL 600s，单条覆盖式写入
  （天然满足"仅最近一条可撤销"：新写操作会顶掉上一条的撤销令牌）
- Redis 不可用时降级为进程内内存，判定规则一致（10 分钟窗口）

所有方法都不抛异常：撤销日志属于"后悔药"，故障不能影响主流程。
"""

import json
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Optional

logger = logging.getLogger(__name__)

UNDO_TTL_SECONDS = 600
_KEY_PREFIX = "dietai:undo:"

# 内存降级存储：{user_id: payload}
_memory_store: dict[int, dict[str, Any]] = {}
_redis_client: Any = None
_redis_disabled = False


@dataclass
class UndoEntry:
    """一条写操作的撤销凭证"""

    action: str
    undo_token: str
    summary: str
    created_at: float = field(default_factory=time.time)
    # 回滚所需的补充信息（如 record_weight 记录前的 UserProfile 体重/BMI）：
    # 写操作改了记录之外的表时，靠它把那些字段精确还原，而不是靠猜
    payload: dict[str, Any] = field(default_factory=dict)

    def is_expired(self, ttl_seconds: int = UNDO_TTL_SECONDS) -> bool:
        return time.time() - self.created_at > ttl_seconds

    def deadline_iso(self, ttl_seconds: int = UNDO_TTL_SECONDS) -> str:
        """撤销截止时间（ISO，带本地时区偏移，避免客户端按错误时区解析）"""
        return datetime.fromtimestamp(self.created_at + ttl_seconds).astimezone().isoformat()

    def to_dict(self) -> dict[str, Any]:
        return {
            "action": self.action,
            "undo_token": self.undo_token,
            "summary": self.summary,
            "created_at": self.created_at,
            "payload": self.payload,
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "UndoEntry":
        extra = payload.get("payload")
        return cls(
            action=str(payload.get("action") or ""),
            undo_token=str(payload.get("undo_token") or ""),
            summary=str(payload.get("summary") or ""),
            created_at=float(payload.get("created_at") or 0),
            payload=dict(extra) if isinstance(extra, dict) else {},
        )


class UndoJournal:
    """最近一条写操作的撤销日志（单条覆盖式）"""

    def __init__(self, ttl_seconds: int = UNDO_TTL_SECONDS) -> None:
        self.ttl_seconds = ttl_seconds

    async def push(self, user_id: int, entry: UndoEntry) -> None:
        """写入撤销凭证（覆盖上一条）"""
        payload = entry.to_dict()
        client = await _get_redis()
        if client is not None:
            try:
                await client.set(
                    _key(user_id),
                    json.dumps(payload, ensure_ascii=False),
                    ex=self.ttl_seconds,
                )
                _memory_store.pop(user_id, None)
                return
            except Exception as e:  # Redis 故障 → 降级内存
                _disable_redis(e)
        _memory_store[user_id] = payload

    async def peek(self, user_id: int) -> Optional[UndoEntry]:
        """读取撤销凭证；已过期则清理并返回 None"""
        payload = await self._load(user_id)
        if payload is None:
            return None
        entry = UndoEntry.from_dict(payload)
        if entry.is_expired(self.ttl_seconds):
            await self.clear(user_id)
            return None
        return entry

    async def clear(self, user_id: int) -> None:
        """清除撤销凭证（撤销成功 / 已过期 / 记录不存在）"""
        _memory_store.pop(user_id, None)
        client = await _get_redis()
        if client is not None:
            try:
                await client.delete(_key(user_id))
            except Exception as e:
                _disable_redis(e)

    async def _load(self, user_id: int) -> Optional[dict[str, Any]]:
        client = await _get_redis()
        if client is not None:
            try:
                raw = await client.get(_key(user_id))
                return json.loads(raw) if raw else None
            except Exception as e:
                _disable_redis(e)
        return _memory_store.get(user_id)


def _key(user_id: int) -> str:
    return f"{_KEY_PREFIX}{user_id}"


async def _get_redis() -> Any:
    """惰性获取 Redis 客户端；一旦不可用则本进程内不再重试"""
    global _redis_client
    if _redis_disabled:
        return None
    if _redis_client is not None:
        return _redis_client
    try:
        from agent.common_utils.redis_util import get_redis_client

        _redis_client = await get_redis_client()
    except Exception as e:
        _disable_redis(e)
        return None
    return _redis_client


def _disable_redis(exc: Exception) -> None:
    global _redis_client, _redis_disabled
    _redis_client = None
    _redis_disabled = True
    logger.warning(f"撤销日志 Redis 不可用，降级为进程内内存：{exc}")


# 模块级单例（动作定义直接引用）
undo_journal = UndoJournal()