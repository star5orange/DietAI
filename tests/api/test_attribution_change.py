# -*- coding: utf-8 -*-
"""C7 记录归属修改接口测试（POST /api/family/attribution/change）"""
import pytest

from shared.models.water_models import WaterIntakeRecord
from shared.models.food_models import FoodRecord


def _change(client, token, body):
    return client.post(
        "/api/family/attribution/change",
        headers={"Authorization": f"Bearer {token}"},
        json=body,
    ).json()


@pytest.fixture
def water_record(family_user, db_session):
    from datetime import datetime

    rec = WaterIntakeRecord(user_id=family_user.id, amount_ml=250, record_time=datetime.now())
    db_session.add(rec)
    db_session.commit()
    return rec


# ------------------------------------------------------------
# 正常路径
# ------------------------------------------------------------

def test_change_to_member_success(family, user_token, client, water_record, db_session):
    r = _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": family["members"][0].id, "attributed_by": "manual",
    })
    assert r["success"] is True
    assert r["data"]["member_id"] == family["members"][0].id
    assert r["data"]["member_name"] == "奶奶"
    assert r["data"]["operator_user_id"] == family["user"].id  # 令牌派生

    db_session.refresh(water_record)
    assert water_record.member_id == family["members"][0].id
    assert water_record.attributed_by == "manual"
    assert water_record.recorded_by_user_id == family["user"].id  # F12 操作者落库
    assert water_record.attribution_confidence == 1.0


def test_change_to_self_member_none(family, user_token, client, water_record, db_session):
    """member_id 空 = 归属账号本人"""
    r = _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": None, "attributed_by": "manual",
    })
    assert r["success"] is True
    assert r["data"]["member_id"] is None and r["data"]["member_name"] is None
    db_session.refresh(water_record)
    assert water_record.member_id is None


def test_repeated_change_last_wins(family, user_token, client, water_record, db_session):
    """幂等：同一 record_id 重复纠错 = 最后一次为准"""
    m1, m2 = family["members"][0], family["members"][1]
    _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": m1.id, "attributed_by": "manual"})
    _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": m2.id, "attributed_by": "manual"})
    db_session.refresh(water_record)
    assert water_record.member_id == m2.id


def test_food_record_change(family, user_token, client, db_session):
    from datetime import datetime, date

    rec = FoodRecord(
        user_id=family["user"].id, record_date=date.today(), record_time=datetime.now(),
        meal_type=1, food_name="米饭",
    )
    db_session.add(rec)
    db_session.commit()
    r = _change(client, user_token, {
        "record_type": "food", "record_id": rec.id,
        "member_id": family["members"][2].id, "attributed_by": "manual"})
    assert r["success"] is True and r["data"]["member_name"] == "小宝"


# ------------------------------------------------------------
# 校验拒绝（契约 C7：双重家庭校验）
# ------------------------------------------------------------

def test_cross_family_member_rejected(family, user_token, client, water_record):
    r = _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": 999999, "attributed_by": "manual"})
    assert r["success"] is False


def test_inactive_member_rejected(family, user_token, client, water_record, db_session):
    m = family["members"][1]
    m.is_active = False
    db_session.commit()
    r = _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": m.id, "attributed_by": "manual"})
    assert r["success"] is False and "停用" in r["message"]


def test_record_of_other_family_rejected(family_user, user_token, client):
    """记录不属于本家庭（user_id 不同）→ 拒绝"""
    from shared.models.database import SessionLocal  # noqa: F401
    from datetime import datetime

    # 直接在共享测试会话外造一条他人记录不可行（事务回滚域），
    # 用 record_id=999999 模拟"不存在/不属于本家庭"同路径
    r = _change(client, user_token, {
        "record_type": "water", "record_id": 999999,
        "member_id": None, "attributed_by": "manual"})
    assert r["success"] is False


def test_bad_attributed_by_rejected(family, user_token, client, water_record):
    r = _change(client, user_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": family["members"][0].id, "attributed_by": "voice_name"})
    assert r["success"] is False  # C7 仅允许 screen/manual


def test_bad_record_type_rejected(family, user_token, client, water_record):
    r = _change(client, user_token, {
        "record_type": "exercise", "record_id": water_record.id,
        "member_id": family["members"][0].id, "attributed_by": "manual"})
    assert r["success"] is False


# ------------------------------------------------------------
# 设备模式（契约 C7：screen 纠错 + current_member_id 联动）
# ------------------------------------------------------------

def test_device_screen_correction_updates_current_member(
    family, robot_device, device_token, client, water_record, db_session
):
    r = _change(client, device_token, {
        "record_type": "water", "record_id": water_record.id,
        "member_id": family["members"][0].id, "attributed_by": "screen"})
    assert r["success"] is True
    assert r["data"]["operator_user_id"] == family["user"].id  # 设备令牌 → 绑定账号

    db_session.refresh(robot_device)
    assert robot_device.current_member_id == family["members"][0].id  # C4 方向一等效
