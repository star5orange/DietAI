"""T16 健康档案查询规则（allergies / diseases / health_goals 共用）

规则（PRD T16）：
  - member 匹配优先：带 member_id 查询时，成员专属条目排在账号级条目之前
  - 空回落账号级：member_id 为空的条目（账号级）任何成员可见——账号级是共享基线
  - 禁止多成员档案合并：结果里只出现「指定成员 + 账号级」两类，绝无其他成员的数据

不带 member_id 的请求保持旧行为：只看账号级条目（member_id IS NULL）。
"""
from sqlalchemy.orm import Query, Session

from shared.models.user_models import Allergy, Disease, HealthGoal
from shared.services.family_member_service import get_member_in_family


def validate_member(db: Session, user_id: int, member_id: int) -> None:
    """写入路径的成员校验：成员必须属于该家庭且启用（串号/停用直接 403/404 语义拒绝）"""
    member, reason = get_member_in_family(db, user_id, member_id)
    if reason == "not_in_family":
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="成员不属于当前账号家庭")
    if reason == "inactive":
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="成员已停用，不可新增归属")


def apply_member_scope(query: Query, model, member_id) -> Query:
    """查询路径统一规则。

    member_id=None（不指定）→ 只返回账号级条目（旧行为，App 老版本零改动）。
    member_id=M → 返回 M 的条目 + 账号级条目，成员专属排在前面。
    """
    if member_id is None:
        return query.filter(model.member_id.is_(None))
    return query.filter(
        (model.member_id == member_id) | (model.member_id.is_(None))
    ).order_by(
        # 成员专属（非 NULL）优先，再按创建时间倒序
        model.member_id.is_(None).asc(),
        model.created_at.desc(),
    )


PROFILE_MODELS = {"allergy": Allergy, "disease": Disease, "goal": HealthGoal}
