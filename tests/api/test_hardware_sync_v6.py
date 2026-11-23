# -*- coding: utf-8 -*-
"""C2 记录上报契约测试（POST /api/hardware/sync + V6 归属字段）

对照契约 v2.1 status 枚举全集：
ok / needs_confirmation（现有）+ rejected_member / reassigned_default /
duplicate / late_sync（V6 新增）

注：V6 新增行为在 sync 改造完成前为"红"，改造后转绿（先红后绿驱动）。
"""
import uuid
from datetime import datetime, timedelta

from shared.models.water_models import WaterIntakeRecord
from shared.models.food_models import FoodRecord


def _sync(client, token, body):
    return client.post(
        "/api/hardware/sync",
        headers={"Authorization": f"Bearer {token}"},
        json=body,
    ).json()


def _now_iso():
    return datetime.now().isoformat()


def _one(**kw):
    base = {"type": "water", "amount_ml": 250, "timestamp": _now_iso()}
    base.update(kw)
    return base


def _results(r):
    """契约统一 results（human 分支过渡期 details/results 双字段）"""
    data = r["data"] or {}
    return data.get("results") or data.get("details") or []


# ------------------------------------------------------------
# ok：归属四件套落库
# ------------------------------------------------------------

def test_sync_water_with_member_ok(family, clock_device, client, db_session):
    """时钟上报带 member_id=锁定成员 → ok 且落库归属正确"""
    grand = family["members"][0]
    r = _sync(client, clock_device.device_token, {
        "user_id": family["user"].id,
        "records": [
            _one(member_id=grand.id, attributed_by="device_bind",
                 attribution_confidence=0.95, client_uuid=str(uuid.uuid4()))
        ],
    })
    assert r["success"] is True
    item = _results(r)[0]
    assert item["status"] == "ok"

    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id == grand.id
    assert rec.attributed_by == "device_bind"
    assert rec.client_uuid is not None  # A3 幂等依据必须落库


def test_sync_member_id_empty_falls_to_user(family, robot_device, client, db_session):
    """member_id 缺省 = 归属账号本人（向后兼容），robot 缺省 attributed_by=default"""
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(client_uuid=str(uuid.uuid4()))],
    })
    assert _results(r)[0]["status"] == "ok"
    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id is None


def test_sync_food_with_member_ok(family, robot_device, client, db_session):
    dad = family["members"][1]
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [{
            "type": "food", "food_name": "米饭", "meal_type": 2,
            "timestamp": _now_iso(),
            "member_id": dad.id, "attributed_by": "screen",
            "client_uuid": str(uuid.uuid4()),
        }],
    })
    item = _results(r)[0]
    assert item["status"] == "ok"
    rec = (
        db_session.query(FoodRecord)
        .filter(FoodRecord.user_id == family["user"].id)
        .order_by(FoodRecord.id.desc())
        .first()
    )
    assert rec.member_id == dad.id and rec.attributed_by == "screen"


# ------------------------------------------------------------
# needs_confirmation（现有行为保持）
# ------------------------------------------------------------

def test_sync_food_without_name_needs_confirmation(family, robot_device, client):
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [{"type": "food", "timestamp": _now_iso()}],
    })
    assert _results(r)[0]["status"] == "needs_confirmation"


# ------------------------------------------------------------
# duplicate：client_uuid 唯一去重（A3）
# ------------------------------------------------------------

def test_duplicate_client_uuid_not_saved_twice(family, robot_device, client, db_session):
    cu = str(uuid.uuid4())
    body = {
        "user_id": family["user"].id,
        "records": [_one(client_uuid=cu)],
    }
    r1 = _sync(client, robot_device.device_token, body)
    r2 = _sync(client, robot_device.device_token, body)  # 断网恢复重复补传

    first = _results(r1)[0]
    second = _results(r2)[0]
    assert first["status"] == "ok"
    assert second["status"] == "duplicate"  # V6 新增：静默去重视为成功

    count = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.client_uuid == cu)
        .count()
    )
    assert count == 1  # A3：库中只有一条


# ------------------------------------------------------------
# rejected_member：串号成员安全拒绝（不落库、不回落）
# ------------------------------------------------------------

def test_rejected_member_not_saved(family, robot_device, client, db_session):
    before = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id).count()
    )
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(member_id=999999, client_uuid=str(uuid.uuid4()))],
    })
    item = _results(r)[0]
    assert item["status"] == "rejected_member"  # 安全红线

    after = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id).count()
    )
    assert after == before  # 未落库


# ------------------------------------------------------------
# reassigned_default：停用成员回落 default 落库（不丢数据）
# ------------------------------------------------------------

def test_inactive_member_reassigned_to_default(family, robot_device, client, db_session):
    dad = family["members"][1]
    dad.is_active = False
    db_session.commit()

    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(member_id=dad.id, client_uuid=str(uuid.uuid4()))],
    })
    item = _results(r)[0]
    assert item["status"] == "reassigned_default"

    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id == family["members"][0].id  # 回落 default（奶奶）
    assert rec.attributed_by == "default"
    assert rec.attribution_confidence is not None and rec.attribution_confidence < 0.5


# ------------------------------------------------------------
# late_sync：超 7 天时间戳仍落库 + 低置信度（不拒绝）
# ------------------------------------------------------------

def test_stale_timestamp_saved_as_late_sync(family, robot_device, client, db_session):
    old_ts = (datetime.now() - timedelta(days=8)).isoformat()
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(timestamp=old_ts, client_uuid=str(uuid.uuid4()))],
    })
    item = _results(r)[0]
    assert item["status"] == "late_sync"

    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.id is not None  # 已落库，未拒绝
    assert rec.attribution_confidence is not None and rec.attribution_confidence < 0.5


# ------------------------------------------------------------
# 旧固件兼容：无 member_id + 时钟有锁定成员 → 归属锁定成员
# ------------------------------------------------------------

def test_legacy_clock_record_attributed_to_locked_member(family, clock_device, client, db_session):
    """升级窗口期：旧固件不带 member_id → 按 locked_member_id 归属（device_bind）"""
    grand = family["members"][0]
    r = _sync(client, clock_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(client_uuid=str(uuid.uuid4()))],  # 无 member_id
    })
    assert _results(r)[0]["status"] == "ok"

    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id == grand.id
    assert rec.attributed_by == "device_bind"


def test_legacy_robot_record_attributed_to_user(family, robot_device, client, db_session):
    """旧固件机器人（无锁定）无 member_id → 归属本人（V5 存量语义）"""
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(client_uuid=str(uuid.uuid4()))],
    })
    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id is None


# ------------------------------------------------------------
# user_id 可省略（device_token 解析，契约 C2）
# ------------------------------------------------------------

def test_sync_without_user_id_uses_token(family, robot_device, client):
    r = _sync(client, robot_device.device_token, {
        "records": [_one(client_uuid=str(uuid.uuid4()))],
    })
    assert r["success"] is True
    assert _results(r)[0]["status"] == "ok"


# ------------------------------------------------------------
# C4 方向一：current_member_id 随记录顺带上报
# ------------------------------------------------------------

def test_sync_updates_device_current_member(family, robot_device, client, db_session):
    target = family["members"][2]
    r = _sync(client, robot_device.device_token, {
        "user_id": family["user"].id,
        "records": [_one(member_id=target.id, client_uuid=str(uuid.uuid4()),
                         current_member_id=target.id)],
    })
    assert _results(r)[0]["status"] == "ok"
    db_session.refresh(robot_device)
    assert robot_device.current_member_id == target.id
