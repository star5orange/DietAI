# -*- coding: utf-8 -*-
"""C1 成员列表 + 成员 CRUD 接口测试"""


def _get(client, token, params=""):
    return client.get(
        f"/api/family/members{params}",
        headers={"Authorization": f"Bearer {token}"},
    ).json()


def _post(client, token, body):
    return client.post(
        "/api/family/members",
        headers={"Authorization": f"Bearer {token}"},
        json=body,
    ).json()


def _patch(client, token, member_id, body):
    return client.patch(
        f"/api/family/members/{member_id}",
        headers={"Authorization": f"Bearer {token}"},
        json=body,
    ).json()


# ------------------------------------------------------------
# C1：家庭成员列表
# ------------------------------------------------------------

def test_c1_app_mode_returns_family(family, user_token, client):
    data = _get(client, user_token)["data"]
    assert data["current_member_id"] is None       # App 模式恒 null（契约 C1）
    assert data["locked_member_id"] is None
    assert data["default_member_id"] == family["members"][0].id
    ids = [m["id"] for m in data["members"]]
    assert ids == [m.id for m in family["members"]]  # sort_order 升序
    assert data["members"][0]["alias"] == "妈,妈妈,老妈"  # alias 原样下发


def test_c1_device_mode_returns_own_current_locked(family, robot_device, device_token, db_session, client):
    """device_token 调用 → current/locked 是该设备自己的值（契约 C1）"""
    robot_device.current_member_id = family["members"][1].id
    db_session.commit()

    r = client.get(
        "/api/family/members",
        headers={"Authorization": f"Bearer {device_token}"},
    ).json()
    assert r["success"] is True
    assert r["data"]["current_member_id"] == family["members"][1].id
    assert r["data"]["locked_member_id"] is None  # 机器人无锁定成员


def test_c1_clock_mode_returns_locked(family, clock_device, db_session, client):
    """时钟 device_token → locked_member_id = 绑定成员（奶奶）"""
    r = client.get(
        "/api/family/members",
        headers={"Authorization": f"Bearer {clock_device.device_token}"},
    ).json()
    assert r["data"]["locked_member_id"] == family["members"][0].id


def test_c1_if_version_unchanged(family, user_token, client):
    v = _get(client, user_token)["data"]["version"]
    r = _get(client, user_token, f"?if_version={v}")
    assert r["success"] is True and r["data"] is None and r["message"] == "unchanged"


def test_c1_if_version_stale_returns_full(family, user_token, client):
    v = _get(client, user_token)["data"]["version"]
    r = _get(client, user_token, f"?if_version={v - 1}")
    assert r["data"] is not None and len(r["data"]["members"]) == 3


def test_c1_include_inactive_filter(family, user_token, client, db_session):
    family["members"][2].is_active = False
    db_session.commit()

    hidden = _get(client, user_token)["data"]["members"]
    assert [m["id"] for m in hidden] == [family["members"][0].id, family["members"][1].id]

    shown = _get(client, user_token, "?include_inactive=true")["data"]["members"]
    assert len(shown) == 3


def test_c1_version_bumps_on_create(family, user_token, client):
    v1 = _get(client, user_token)["data"]["version"]
    _post(client, user_token, {"display_name": "爷爷", "member_type": 1})
    v2 = _get(client, user_token)["data"]["version"]
    assert v2 == v1 + 1


# ------------------------------------------------------------
# 成员 CRUD
# ------------------------------------------------------------

def test_create_member_success(family, user_token, client):
    r = _post(client, user_token, {"display_name": "爷爷", "alias": "姥爷", "member_type": 1, "sort_order": 4})
    assert r["success"] is True
    assert r["data"]["display_name"] == "爷爷"
    assert r["data"]["is_active"] is True


def test_create_member_at_capacity_rejected(family, user_token, client):
    """8 人上限：接口层拒绝第 9 人（F1）"""
    # 已有 3 人，再建 5 人到上限
    for i in range(5):
        assert _post(client, user_token, {"display_name": f"成员{i}"} )["success"] is True
    r = _post(client, user_token, {"display_name": "第九人"})
    assert r["success"] is False
    assert "上限" in r["message"]


def test_deactivate_member_keeps_history_semantics(family, user_token, client):
    r = _patch(client, user_token, family["members"][0].id, {"is_active": False})
    assert r["success"] is True and r["data"]["is_active"] is False


def test_patch_member_not_in_family_rejected(family, user_token, client):
    r = _patch(client, user_token, 999999, {"display_name": "X"})
    assert r["success"] is False


def test_patch_requires_auth(client):
    r = client.patch("/api/family/members/1", json={"display_name": "X"}).json()
    assert r.get("success") is False or "detail" in r
