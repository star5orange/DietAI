# -*- coding: utf-8 -*-
"""T16 健康档案挂成员：查询规则（member 优先 / 空回落账号级 / 禁止跨成员合并）+ 写入校验"""
import pytest
from fastapi import HTTPException

from shared.models.family_models import FamilyMember
from shared.models.user_models import Allergy, Disease, HealthGoal
from shared.services.health_profile_scope import apply_member_scope, validate_member


@pytest.fixture
def profile_family(db_session, family_user):
    """造奶奶+爸爸两个成员；账号级过敏 1 条 + 奶奶专属疾病 1 条 + 爸爸专属过敏 1 条"""
    m_grandma = FamilyMember(home_user_id=family_user.id, display_name="奶奶", member_type=1, sort_order=1)
    m_dad = FamilyMember(home_user_id=family_user.id, display_name="爸爸", member_type=0, sort_order=2)
    db_session.add_all([m_grandma, m_dad])
    db_session.flush()

    db_session.add(Allergy(user_id=family_user.id, allergen_type=1,
                           allergen_name="花生", severity_level=2))          # 账号级
    db_session.add(Disease(user_id=family_user.id, disease_name="高血压",
                           member_id=m_grandma.id, is_current=True))          # 奶奶专属
    db_session.add(Allergy(user_id=family_user.id, allergen_type=1,
                           allergen_name="芒果", member_id=m_dad.id))         # 爸爸专属
    db_session.flush()
    return db_session, family_user, m_grandma, m_dad


# ---------- 查询规则 ----------

def test_no_member_param_returns_account_level_only(profile_family):
    """不带 member_id：旧行为，只看账号级（App 老版本零改动）"""
    db, user, _, _ = profile_family
    rows = apply_member_scope(db.query(Allergy).filter(Allergy.user_id == user.id), Allergy, None).all()
    assert {r.allergen_name for r in rows} == {"花生"}  # 奶奶/爸爸的专属条目绝不混入


def test_member_scope_includes_account_level_excludes_others(profile_family):
    """查奶奶：账号级可见（空回落），爸爸的专属被排除（禁止多成员合并）"""
    db, _, m_grandma, m_dad = profile_family
    rows = apply_member_scope(db.query(Allergy), Allergy, m_grandma.id).all()
    names = {r.allergen_name for r in rows}
    assert names == {"花生"}            # 有芒果（爸爸）则失败
    assert all(r.member_id is None for r in rows)


def test_member_specific_rows_ordered_first(profile_family):
    """成员专属条目排在账号级之前（member 匹配优先）"""
    db, user, _, m_dad = profile_family
    db.add(Allergy(user_id=user.id, allergen_type=2, allergen_name="青霉素"))  # 账号级第二条
    db.flush()
    rows = apply_member_scope(db.query(Allergy), Allergy, m_dad.id).all()
    assert rows[0].allergen_name == "芒果" and rows[0].member_id == m_dad.id


def test_goal_and_disease_scope(profile_family):
    db, _, m_grandma, _ = profile_family
    diseases = apply_member_scope(db.query(Disease), Disease, m_grandma.id).all()
    assert [d.disease_name for d in diseases] == ["高血压"]
    goals = apply_member_scope(db.query(HealthGoal), HealthGoal, m_grandma.id).all()
    assert goals == []


# ---------- 写入校验 ----------

def test_validate_member_rejects_cross_family(profile_family):
    db, user, _, _ = profile_family
    with pytest.raises(HTTPException) as exc:
        validate_member(db, user.id, 99999)   # 串号成员
    assert exc.value.status_code == 403


def test_validate_member_rejects_inactive(profile_family):
    db, user, m_grandma, _ = profile_family
    m_grandma.is_active = False
    db.flush()
    with pytest.raises(HTTPException) as exc:
        validate_member(db, user.id, m_grandma.id)
    assert exc.value.status_code == 404


def test_validate_member_accepts_own_active(profile_family):
    db, user, m_grandma, _ = profile_family
    validate_member(db, user.id, m_grandma.id)  # 不抛异常即通过
