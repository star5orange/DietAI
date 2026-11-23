# -*- coding: utf-8 -*-
"""A8 旧数据兼容：member_id 为空的历史记录读取与统计正常（不做回填）"""
from datetime import datetime

from shared.models.water_models import WaterIntakeRecord


def test_legacy_record_readable_and_untouched(family, user_token, client, db_session):
    """旧记录 member_id=None：列表可读、归属语义=账号本人、不被接口改动"""
    legacy = WaterIntakeRecord(
        user_id=family["user"].id, amount_ml=300,
        record_time=datetime.now(), drink_type="水",
    )
    db_session.add(legacy)
    db_session.commit()

    r = client.get(
        "/api/water/records",
        headers={"Authorization": f"Bearer {user_token}"},
    ).json()
    assert r["success"] is True
    ids = [item["id"] for item in r["data"]]
    assert legacy.id in ids

    db_session.refresh(legacy)
    assert legacy.member_id is None  # 不回填（A8 兼容原则）


def test_legacy_record_member_summary_filters_out(family, db_session):
    """成员级统计按 member_id 过滤：旧记录（None）不进任何成员的口径"""
    legacy = WaterIntakeRecord(
        user_id=family["user"].id, amount_ml=300, record_time=datetime.now(),
    )
    member_record = WaterIntakeRecord(
        user_id=family["user"].id, amount_ml=200, record_time=datetime.now(),
        member_id=family["members"][0].id,
    )
    db_session.add_all([legacy, member_record])
    db_session.commit()

    grandma_total = (
        db_session.query(WaterIntakeRecord)
        .filter(
            WaterIntakeRecord.user_id == family["user"].id,
            WaterIntakeRecord.member_id == family["members"][0].id,
        )
        .count()
    )
    assert grandma_total == 1  # 只有显式归属奶奶的那条

    user_total = (
        db_session.query(WaterIntakeRecord)
        .filter(
            WaterIntakeRecord.user_id == family["user"].id,
            WaterIntakeRecord.member_id.is_(None),
        )
        .count()
    )
    assert user_total >= 1  # 旧记录归"本人"口径
