"""家庭成员服务 — V6 多成员归属（PRD F1/F8 / 契约 C1-C4）

职责：
- 成员 CRUD 业务规则（8 人上限、停用语义、default_member_id）
- 归属校验（成员必须属于本家庭，1.4）
- 家庭成员版本号维护（C1：成员增删改 + 设备 current/locked 变化均 +1）
"""
from typing import Optional, Tuple

from sqlalchemy.orm import Session

from shared.models.family_models import FamilyMember
from shared.config.redis_config import redis_manager

MAX_FAMILY_MEMBERS = 8

_MEMBER_VERSION_KEY = "dietai:family:member_version:{home_user_id}"


# ============================================================
# 版本号（C1：设备 NVS 缓存比对依据）
# ============================================================

def _version_key(home_user_id: int) -> str:
    return _MEMBER_VERSION_KEY.format(home_user_id=home_user_id)


def get_member_version(db: Session, home_user_id: int) -> int:
    """读取家庭成员版本号；Redis 丢失（重启/过期）时按成员数重建基线。

    基线重建后与设备缓存版本不一致 → 设备比对失败重新拉全量，无害。
    """
    count = db.query(FamilyMember).filter(
        FamilyMember.home_user_id == home_user_id
    ).count()
    baseline = count + 1
    try:
        client = redis_manager.get_client()
        key = _version_key(home_user_id)
        current = client.get(key)
        if current is None:
            client.set(key, baseline)
            return baseline
        return int(current)
    except Exception:
        # Redis 熔断/不可用 → 退化为成员数基线（设备多拉一次全量，无害）
        return baseline


def bump_member_version(home_user_id: int) -> None:
    """版本号 +1（成员增删改、设备 current_member_id / locked_member_id 变化时调用）"""
    try:
        client = redis_manager.get_client()
        key = _version_key(home_user_id)
        if not client.exists(key):
            # 首次递增前初始化基线，避免 INCR 从 1 开始小于设备已缓存值造成回退
            client.set(key, 1)
        client.incr(key)
    except Exception:
        # 版本号丢失只影响增量比对效率，不丢数据
        pass


# ============================================================
# 家庭默认成员（C1 default_member_id：首个创建的成员）
# ============================================================

def get_default_member_id(db: Session, home_user_id: int) -> Optional[int]:
    """家庭默认成员 = 首个创建且仍在启用的成员；无任何启用成员时 None（记给账号本人）"""
    member = (
        db.query(FamilyMember)
        .filter(
            FamilyMember.home_user_id == home_user_id,
            FamilyMember.is_active == True,  # noqa: E712
        )
        .order_by(FamilyMember.created_at.asc(), FamilyMember.id.asc())
        .first()
    )
    return member.id if member else None


# ============================================================
# 归属校验（1.4 / 契约 C2 校验规则）
# ============================================================

def get_member_in_family(
    db: Session, home_user_id: int, member_id: int
) -> Tuple[Optional[FamilyMember], Optional[str]]:
    """校验成员属于本家庭。

    返回 (member, None) 成功；
         (None, "not_in_family") 不属于本家庭（拼错/串号，安全拒绝，绝不回落）；
         (None, "inactive") 属于本家庭但已停用（回落 default，不丢数据）。
    """
    member = db.query(FamilyMember).filter(FamilyMember.id == member_id).first()
    if member is None or member.home_user_id != home_user_id:
        return None, "not_in_family"
    if not member.is_active:
        return None, "inactive"
    return member, None


# ============================================================
# 成员 CRUD 业务规则
# ============================================================

def count_active_members(db: Session, home_user_id: int) -> int:
    return db.query(FamilyMember).filter(
        FamilyMember.home_user_id == home_user_id,
        FamilyMember.is_active == True,  # noqa: E712
    ).count()


def ensure_member_capacity(db: Session, home_user_id: int) -> None:
    """8 人上限（PRD F1），超过由后端拒绝创建"""
    if count_active_members(db, home_user_id) >= MAX_FAMILY_MEMBERS:
        raise ValueError(f"家庭成员已达上限 {MAX_FAMILY_MEMBERS} 人")
