"""确认卡凭证（pending_store）单元测试 —— 纯进程内，不需要后端 / LLM / 数据库。

对应验收用例 TC-009 的逻辑层（PRD 4.2 确认卡直调）：
- register_record_confirm：返回凭证；user_id 缺失返回 None（前端退回旧路径）
- consume_confirm 一次性：取出即作废，重复提交返回 None
- 串用户拒绝：非持卡人 consume 返回 None 且**不消耗**凭证
- 过期（600s TTL）：过期凭证返回 None
- confirm_field 回填字段：默认 explicit_request；always_confirm 动作传 confirmed_by_user

统一强制走内存降级（monkeypatch _get_redis），不读写真实 Redis。
"""

import asyncio
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.actions import pending_store
from agent.diet_deep_agent.actions.pending_store import (
    PendingConfirm,
    consume_confirm,
    register_record_confirm,
)


@pytest.fixture(autouse=True)
def _memory_mode(monkeypatch):
    """强制内存降级并清空存储，保证用例互不污染、不碰真实 Redis"""

    async def _no_redis():
        return None

    monkeypatch.setattr(pending_store, "_get_redis", _no_redis)
    pending_store._memory_store.clear()
    yield
    pending_store._memory_store.clear()


def test_register_returns_token_and_calls():
    token = asyncio.run(
        register_record_confirm(
            1, "record_food", "螺蛳粉", {"food_name": "螺蛳粉", "meal_type": 2}
        )
    )
    assert token
    entry = asyncio.run(consume_confirm(token, 1))
    assert isinstance(entry, PendingConfirm)
    assert entry.user_id == 1
    assert entry.label == "螺蛳粉"
    assert entry.calls == [
        {
            "action": "record_food",
            "field": "explicit_request",
            "value": True,
            "params": {"food_name": "螺蛳粉", "meal_type": 2},
        }
    ]


def test_consume_is_one_time():
    """取出即作废：重复提交 / 网络重试都不能写两条"""
    token = asyncio.run(
        register_record_confirm(1, "record_water", "一杯水", {"amount_ml": 250})
    )
    assert asyncio.run(consume_confirm(token, 1)) is not None
    assert asyncio.run(consume_confirm(token, 1)) is None


def test_wrong_user_does_not_consume():
    """不是持卡人：拿不到凭证，也不能把别人的凭证消耗掉"""
    token = asyncio.run(register_record_confirm(1, "record_food", "螺蛳粉", {}))
    assert asyncio.run(consume_confirm(token, 999)) is None
    assert asyncio.run(consume_confirm(token, 1)) is not None


def test_expired_token_rejected():
    """TTL 600s：过期凭证返回 None（内存侧把 created_at 拨回 601 秒前）"""
    token = asyncio.run(register_record_confirm(1, "record_food", "螺蛳粉", {}))
    pending_store._memory_store[token]["created_at"] = time.time() - 601
    assert asyncio.run(consume_confirm(token, 1)) is None


def test_confirm_field_override_for_always_confirm():
    """always_confirm 动作（疾病档案）用 confirmed_by_user 回填，且恒为 True"""
    token = asyncio.run(
        register_record_confirm(
            1,
            "record_disease",
            "骨折",
            {"disease_name": "骨折"},
            confirm_field="confirmed_by_user",
        )
    )
    entry = asyncio.run(consume_confirm(token, 1))
    assert entry.calls[0]["field"] == "confirmed_by_user"
    assert entry.calls[0]["value"] is True


def test_missing_user_id_returns_none_token():
    """user_id 缺失：返回 None → 卡片不带凭证 → 前端退回旧路径，不写错数据"""
    token = asyncio.run(register_record_confirm(None, "record_food", "螺蛳粉", {}))
    assert token is None


def test_memory_payload_roundtrip_keeps_calls():
    """to_dict / from_dict 往返后 calls 不丢（Redis 存取走同一条序列化路径）"""
    entry = PendingConfirm(
        user_id=7,
        token="t",
        label="苹果",
        calls=[{"action": "record_food", "field": "explicit_request", "value": True, "params": {"food_name": "苹果"}}],
    )
    restored = PendingConfirm.from_dict(entry.to_dict())
    assert restored.user_id == 7
    assert restored.label == "苹果"
    assert restored.calls == entry.calls
