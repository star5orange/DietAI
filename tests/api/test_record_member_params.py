# -*- coding: utf-8 -*-
"""1.6 记录接口归属参数测试（App 手动记录指定成员）"""
import pytest
from datetime import date, datetime

from shared.models.water_models import WaterIntakeRecord
from shared.models.food_models import FoodRecord


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------
# 饮水：POST /api/water/records
# ------------------------------------------------------------

def test_water_record_with_member(family, user_token, client, db_session):
    r = client.post("/api/water/records", headers=_auth(user_token), json={
        "amount_ml": 250,
        "member_id": family["members"][0].id,
    }).json()
    assert r["success"] is True

    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id == family["members"][0].id
    assert rec.attributed_by == "manual"
    assert rec.attribution_confidence == 1.0
    assert rec.recorded_by_user_id == family["user"].id  # F12 操作者


def test_water_record_without_member_untouched(family, user_token, client, db_session):
    """member_id 空 = 本人记录，归属字段保持空（A8 兼容语义）"""
    r = client.post("/api/water/records", headers=_auth(user_token), json={"amount_ml": 200}).json()
    assert r["success"] is True
    rec = (
        db_session.query(WaterIntakeRecord)
        .filter(WaterIntakeRecord.user_id == family["user"].id)
        .order_by(WaterIntakeRecord.id.desc())
        .first()
    )
    assert rec.member_id is None and rec.attributed_by is None
    assert rec.recorded_by_user_id is None


def test_water_record_cross_family_member_rejected(family, user_token, client):
    r = client.post("/api/water/records", headers=_auth(user_token), json={
        "amount_ml": 200, "member_id": 999999,
    }).json()
    assert r["success"] is False


def test_water_record_inactive_member_rejected(family, user_token, client, db_session):
    m = family["members"][1]
    m.is_active = False
    db_session.commit()
    r = client.post("/api/water/records", headers=_auth(user_token), json={
        "amount_ml": 200, "member_id": m.id,
    }).json()
    assert r["success"] is False and "停用" in r["message"]


# ------------------------------------------------------------
# 饮食：POST /api/foods/records/traditional
# ------------------------------------------------------------

def _food_body(member_id=None):
    body = {
        "record_date": date.today().isoformat(),
        "meal_type": 1,
        "food_name": "米饭",
        "recording_method": 1,
        "from_source": "manual",
    }
    if member_id is not None:
        body["member_id"] = member_id
    return body


def test_food_traditional_with_member(family, user_token, client, db_session):
    r = client.post(
        "/api/foods/records/traditional",
        headers=_auth(user_token), json=_food_body(family["members"][2].id),
    ).json()
    assert r["success"] is True, r

    rec = (
        db_session.query(FoodRecord)
        .filter(FoodRecord.user_id == family["user"].id)
        .order_by(FoodRecord.id.desc())
        .first()
    )
    assert rec.member_id == family["members"][2].id
    assert rec.attributed_by == "manual"
    assert rec.recorded_by_user_id == family["user"].id


def test_food_traditional_bad_member_400(family, user_token, client):
    resp = client.post(
        "/api/foods/records/traditional",
        headers=_auth(user_token), json=_food_body(999999),
    )
    assert resp.status_code == 400


def test_food_traditional_without_member(family, user_token, client, db_session):
    r = client.post(
        "/api/foods/records/traditional",
        headers=_auth(user_token), json=_food_body(),
    ).json()
    assert r["success"] is True
    rec = (
        db_session.query(FoodRecord)
        .filter(FoodRecord.user_id == family["user"].id)
        .order_by(FoodRecord.id.desc())
        .first()
    )
    assert rec.member_id is None and rec.recorded_by_user_id is None


# ------------------------------------------------------------
# 拍照确认：POST /api/foods/records/confirm-create
# ------------------------------------------------------------

def test_food_confirm_create_with_member(family, user_token, client, db_session):
    r = client.post("/api/foods/records/confirm-create", headers=_auth(user_token), json={
        "record_date": date.today().isoformat(),
        "record_time": datetime.now().isoformat(),
        "meal_type": 2,
        "food_name": "番茄炒蛋",
        "food_items": ["番茄", "鸡蛋"],
        "recording_method": 2,
        "member_id": family["members"][1].id,
    }).json()
    assert r["success"] is True, r

    rec = (
        db_session.query(FoodRecord)
        .filter(FoodRecord.user_id == family["user"].id)
        .order_by(FoodRecord.id.desc())
        .first()
    )
    assert rec.member_id == family["members"][1].id
    assert rec.attributed_by == "manual"
    assert rec.recorded_by_user_id == family["user"].id
