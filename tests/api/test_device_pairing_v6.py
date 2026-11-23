# -*- coding: utf-8 -*-
"""1.5b 配对链路家庭化测试（契约 C6：device_type / locked / home_user_id）"""
from datetime import datetime, timedelta

from shared.models.device_models import Device


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _make_pairing_device(db_session, family_user, key_suffix):
    d = Device(
        device_key=f"PAIR:00:00:00:00:{key_suffix}",
        pairing_code="654321",
        pairing_expires_at=datetime.utcnow() + timedelta(minutes=5),
        is_bound=False,
    )
    db_session.add(d)
    db_session.commit()
    return d


def _confirm(client, user_token, device_type=None):
    body = {"pairing_code": "654321"}
    if device_type:
        body["device_type"] = device_type
    return client.post("/api/device/confirm-pairing", headers=_auth(user_token), json=body).json()


def test_confirm_clock_locks_default_member(family, user_token, client, db_session):
    """时钟绑定 → 锁定成员 = 家庭默认成员（奶奶），当前成员同步指向"""
    _make_pairing_device(db_session, family["user"], "11")
    r = _confirm(client, user_token, "clock")
    assert r["success"] is True, r
    data = r["data"]
    assert data["device_type"] == "clock"
    assert data["home_user_id"] == family["user"].id
    assert data["locked_member_id"] == family["members"][0].id
    assert data["current_member_id"] == family["members"][0].id


def test_confirm_robot_not_locked(family, user_token, client, db_session):
    """机器人绑定 → 无锁定成员（可切换），当前成员初始为空=记本人"""
    _make_pairing_device(db_session, family["user"], "12")
    r = _confirm(client, user_token, "robot")
    assert r["success"] is True
    data = r["data"]
    assert data["device_type"] == "robot"
    assert data["locked_member_id"] is None
    assert data["current_member_id"] is None
    assert data["home_user_id"] == family["user"].id


def test_confirm_default_type_is_clock(family, user_token, client, db_session):
    """旧版 App 不传 device_type → 缺省 clock（向后兼容）"""
    _make_pairing_device(db_session, family["user"], "13")
    r = _confirm(client, user_token)
    assert r["success"] is True
    assert r["data"]["device_type"] == "clock"


def test_device_status_returns_c6_fields(family, user_token, client, db_session):
    """device/status 返回 C6 新字段（App 设备详情页依赖）"""
    _make_pairing_device(db_session, family["user"], "14")
    r = _confirm(client, user_token, "clock")
    assert r["success"] is True
    device_id = r["data"]["device_id"]

    s = client.get("/api/device/status", headers=_auth(user_token)).json()
    assert s["success"] is True
    data = s["data"]
    assert data["device_id"] == device_id
    for field in ("device_type", "name", "home_user_id",
                  "current_member_id", "locked_member_id", "firmware_version"):
        assert field in data
    assert data["device_type"] == "clock"
    assert data["locked_member_id"] == family["members"][0].id
