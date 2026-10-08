"""用户健康档案上下文构建。

原位于 routers/deep_router.py，迁出以便对话侧（Deep Agent System Prompt）与
康复建议生成（/health/rehab-advice）共用同一份口径，避免出现两套宜忌判断。
"""
import logging
from datetime import date

logger = logging.getLogger(__name__)


def build_user_health_context(user_id: int) -> str:
    """构建用户健康档案上下文，追加到营养师 System Prompt。

    Deep Agent 与 Chat Agent 不同，Router 层不会自动携带用户档案；
    体质类型（体质自测落库到 UserProfile.constitution_type）、人群标签、
    过敏原（Allergy）与疾病史（Disease）都需在此显式注入，
    否则模型做饮食分析时不知道用户的宜忌与风险。宠物会话不调用本函数。
    """
    try:
        from shared.models.database import SessionLocal
        from shared.models.user_models import Allergy, Disease, UserProfile

        db = SessionLocal()
        try:
            profile = db.query(UserProfile).filter(
                UserProfile.user_id == user_id
            ).first()
            from shared.models.schemas.constitution import normalize_constitution
            constitution = (
                normalize_constitution(profile.constitution_type)
                if profile and profile.constitution_type else None
            )
            crowd_tag = profile.crowd_tag if profile else None
            allergies = db.query(Allergy).filter(Allergy.user_id == user_id).all()
            # 只注入当前患病：骨折等有明确病程的急性状况，用户标记愈合后不再干扰饮食分析
            diseases = db.query(Disease).filter(
                Disease.user_id == user_id,
                Disease.is_current.is_(True),
            ).all()
        finally:
            db.close()

        lines = []
        if constitution:
            lines.append(f"- 体质类型: {constitution}（来自用户体质自测，中医九种体质）")
        if crowd_tag:
            lines.append(f"- 人群标签: {crowd_tag}")
        allergen_names = [a.allergen_name for a in allergies if a.allergen_name]
        if allergen_names:
            lines.append(
                f"- 过敏原: {'、'.join(allergen_names)}"
                "（提到含这些成分的食物时必须明确警示，不能只字不提）"
            )
        disease_entries = []
        today = date.today()
        for d in diseases:
            if not d.disease_name:
                continue
            if d.diagnosed_date:
                elapsed = (today - d.diagnosed_date).days
                disease_entries.append(
                    f"{d.disease_name}（诊断于 {d.diagnosed_date.isoformat()}，已 {elapsed} 天）"
                )
            else:
                disease_entries.append(d.disease_name)
        if disease_entries:
            lines.append(
                f"- 当前患病: {'、'.join(disease_entries)}"
                "（分析饮食时必须结合相应禁忌与康复营养需求，如骨折恢复需保证钙、"
                "维生素D、优质蛋白与维生素C 的摄入，并避免高盐、高糖、酒精与辛辣；"
                "请结合病程天数判断所处阶段）"
            )
        if not lines:
            return ""

        return (
            "\n\n## 用户健康档案（必须参考）\n"
            + "\n".join(lines)
            + "\n每次分析用户吃了什么、或给饮食建议时，都要结合这些宜忌与风险主动提醒；"
            "涉及体质养生、药膳茶饮等检索时，调用 query_wellness_knowledge "
            "应将该体质作为 constitution 过滤条件传入。"
        )
    except Exception as e:
        logger.warning(f"构建用户健康档案上下文失败 (非致命): {e}")
        return ""


def get_allergen_names(user_id: int) -> list[str]:
    """取用户过敏原名称列表（用于康复建议的输入签名与 prompt 约束）。"""
    try:
        from shared.models.database import SessionLocal
        from shared.models.user_models import Allergy

        db = SessionLocal()
        try:
            rows = db.query(Allergy).filter(Allergy.user_id == user_id).all()
            return sorted({a.allergen_name for a in rows if a.allergen_name})
        finally:
            db.close()
    except Exception as e:
        logger.warning(f"读取用户过敏原失败 (非致命): {e}")
        return []