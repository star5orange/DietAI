"""record_allergy：记录一条过敏原（V6 健康档案扩权，写操作，可撤销）。

过敏原会驱动全线饮食警告（含康复建议的致敏规避），错记的代价较高，
因此分类必须让用户看得见：确认卡上写清「将把「青霉素」记为药物过敏」，
用户发现归错类可以直接点「先不记了」。

只允许追加，不提供删除：用户要求删除时引导去「健康」页手动操作。
"""

import logging
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.health_profile_common import (
    match_indices_by_name,
)
from agent.diet_deep_agent.actions.pending import build_record_confirm_card
from agent.diet_deep_agent.actions.pending_store import register_record_confirm
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)
from agent.diet_deep_agent.actions.undo_journal import UndoEntry, undo_journal

logger = logging.getLogger(__name__)

# 过敏原类型：1 食物 / 2 药物 / 3 环境 / 4 其他
ALLERGEN_TYPE_LABELS = {1: "食物", 2: "药物", 3: "环境", 4: "其他"}


class RecordAllergyArgs(BaseModel):
    """record_allergy 入参（不含 user_id）"""

    allergen_name: str = Field(description="过敏原名称，按用户原话填写（如「青霉素」「花生」）")
    allergen_type: int = Field(
        description="过敏原类型：1=食物，2=药物，3=环境（花粉/尘螨等），4=其他。"
        "拿不准时用 4，不要瞎猜成食物",
        ge=1,
        le=4,
    )
    severity_level: Optional[int] = Field(
        default=None,
        ge=1,
        le=3,
        description="严重程度：1=轻度，2=中度，3=重度；用户没说留空，不要自行判断",
    )
    reaction_description: Optional[str] = Field(
        default=None, description="过敏反应描述（如「起疹子」「呼吸困难」）；用户没说留空"
    )
    explicit_request: bool = Field(
        default=False,
        description="用户是否明确要你帮记录（如「帮我记录」「记一下」）。"
        "叙述性提及（只是说自己对某物过敏，没让记）填 false —— 动作会弹「要帮你记录吗？」确认卡",
    )


SPEC = ActionSpec(
    name="record_allergy",
    description="把用户提到的过敏原记入健康档案（写入过敏信息，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordAllergyArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    undoable=True,
    sessions=("human",),
    examples=["我对青霉素过敏", "帮我记录：我吃花生会起疹子", "我花粉过敏"],
    notes=(
        "过敏原类型（allergen_type）必须给对：药物（青霉素等）填 2、食物填 1、花粉尘螨等填 3；"
        "真的拿不准填 4，不要一律按食物记 —— 归错类会长期影响饮食推荐与警告。"
        "只允许新增，不能删除已有档案；用户要求删掉某条过敏原时引导去「健康」页手动删除，"
        "不要声称已删除。"
    ),
)


async def record_allergy(params: RecordAllergyArgs, ctx: ActionContext) -> ActionResult:
    """写入一条过敏原，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物过敏请使用宠物工具，不写入本人的过敏记录"
        )

    name = (params.allergen_name or "").strip()
    if not name:
        return ActionResult.failure(SPEC.name, "没听清是什么过敏原，请说具体名称（如「青霉素」）")

    type_label = ALLERGEN_TYPE_LABELS.get(params.allergen_type)
    if type_label is None:
        return ActionResult.failure(SPEC.name, "过敏原类型只能是 1食物 / 2药物 / 3环境 / 4其他")

    what = f"{name}（{type_label}过敏）"
    confirm_params = {
        "allergen_name": name,
        "allergen_type": params.allergen_type,
        "severity_level": params.severity_level,
        "reaction_description": params.reaction_description,
    }

    # 叙述性提及但未明确要求记录 → 弹确认卡；老人线不弹卡，直接记录
    if not params.explicit_request and not ctx.is_elder_channel:
        confirm_token = await register_record_confirm(
            ctx.user_id, action=SPEC.name, label=what, params=confirm_params
        )
        return build_record_confirm_card(
            action=SPEC.name,
            what=what,
            params=confirm_params,
            confirm_token=confirm_token,
        )

    from shared.models.database import SessionLocal
    from shared.models.user_models import Allergy

    db = SessionLocal()
    try:
        # 加密列不能 SQL 匹配：整表取回该用户的过敏原后在 Python 侧比对
        rows = db.query(Allergy).filter(Allergy.user_id == ctx.user_id).all()
        hits = match_indices_by_name([row.allergen_name for row in rows], name)
        if hits:
            existing = rows[hits[0]]
            return ActionResult.failure(
                SPEC.name,
                f"健康档案里已有过敏原「{existing.allergen_name}」，无需重复记录；"
                "如需修改请到「健康」页操作",
            )

        allergy = Allergy(
            user_id=ctx.user_id,
            allergen_type=params.allergen_type,
            allergen_name=name,
            severity_level=params.severity_level,
            reaction_description=params.reaction_description,
        )
        db.add(allergy)
        db.commit()
        db.refresh(allergy)
        allergy_id = allergy.id
    except Exception as e:
        db.rollback()
        logger.exception("record_allergy 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    message = f"已记入健康档案：{what}。后续饮食分析与康复建议都会避开它。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(allergy_id),
        summary=f"{type_label}过敏「{name}」",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "allergy_id": allergy_id,
            "allergen_name": name,
            "allergen_type": params.allergen_type,
            "allergen_type_label": type_label,
            "detail": what,
            "jump": {"page": "health"},
        },
        undo_token=str(allergy_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_allergy 动作（V6 健康档案扩权）"""
    registry.register(SPEC, record_allergy)