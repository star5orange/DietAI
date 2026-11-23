# -*- coding: utf-8 -*-
"""family_member_service 单元测试（1.4 归属校验 / F1 上限 / C1 default 与版本号）"""
import pytest

from shared.models.family_models import FamilyMember
from shared.services.family_member_service import (
    get_member_in_family, ensure_member_capacity, get_default_member_id,
    get_member_version, bump_member_version, MAX_FAMILY_MEMBERS,
)


def _add_member(db, home_user_id, name, **kw):
    m = FamilyMember(home_user_id=home_user_id, display_name=name, **kw)
    db.add(m)
    db.commit()
    return m


# ------------------------------------------------------------
# 归属校验三态（C2 校验规则的根基）
# ------------------------------------------------------------

def test_member_in_family_ok(family, db_session):
    member, reason = get_member_in_family(db_session, family["user"].id, family["members"][0].id)
    assert member is not None and reason is None


def test_member_not_in_family_rejected(family, db_session):
    member, reason = get_member_in_family(db_session, family["user"].id, 99999)
    assert member is None and reason == "not_in_family"


def test_other_family_member_rejected(family, db_session):
    """别的家庭的成员 ID → not_in_family（安全红线：绝不回落）"""
    from shared.models.user_models import User

    other_user = User(username="test_other_family", password_hash="x", status=1)
    db_session.add(other_user)
    db_session.commit()
    other = _add_member(db_session, other_user.id, "别人家的")
    member, reason = get_member_in_family(db_session, family["user"].id, other.id)
    assert member is None and reason == "not_in_family"


def test_inactive_member_flagged(family, db_session):
    m = _add_member(db_session, family["user"].id, "停用的人", is_active=False)
    member, reason = get_member_in_family(db_session, family["user"].id, m.id)
    assert member is None and reason == "inactive"


# ------------------------------------------------------------
# 8 人上限（F1）
# ------------------------------------------------------------

def test_capacity_under_limit_ok(family, db_session):
    ensure_member_capacity(db_session, family["user"].id)  # 3 人，不抛


def test_capacity_at_limit_raises(family, db_session):
    for i in range(MAX_FAMILY_MEMBERS):
        _add_member(db_session, family["user"].id, f"m{i}")
    with pytest.raises(ValueError):
        ensure_member_capacity(db_session, family["user"].id)


# ------------------------------------------------------------
# default_member_id（C1：首个创建且启用的成员）
# ------------------------------------------------------------

def test_default_is_first_created(family, db_session):
    assert get_default_member_id(db_session, family["user"].id) == family["members"][0].id


def test_default_skips_deactivated(family, db_session):
    """默认成员被停用 → 跳到下一个启用成员（避免 reassigned_default 回落循环）"""
    first = family["members"][0]
    first.is_active = False
    db_session.commit()
    assert get_default_member_id(db_session, family["user"].id) == family["members"][1].id


def test_default_none_when_all_inactive(family, db_session):
    for m in family["members"]:
        m.is_active = False
    db_session.commit()
    assert get_default_member_id(db_session, family["user"].id) is None


def test_default_none_when_no_members(family_user, db_session):
    assert get_default_member_id(db_session, family_user.id) is None


# ------------------------------------------------------------
# 版本号（C1：成员增删改 / current/locked 变化 +1；Redis 丢失按成员数重建）
# ------------------------------------------------------------

def test_version_increments_on_bump(family, db_session):
    home = family["user"].id
    v1 = get_member_version(db_session, home)
    bump_member_version(home)
    v2 = get_member_version(db_session, home)
    assert v2 == v1 + 1


def test_version_rebuild_baseline_when_lost(family, db_session, stub_redis):
    """Redis 键丢失（重启）→ 按成员数重建基线，且不小于已有值语义"""
    home = family["user"].id
    bump_member_version(home)
    stub_redis.store.clear()
    v = get_member_version(db_session, home)
    assert v == 4  # 3 个成员 → 基线 = count+1
