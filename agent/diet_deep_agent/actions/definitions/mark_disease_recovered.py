"""mark_disease_recovered：把一条疾病标记为已痊愈（V6 健康档案扩权，写操作，可撤销）。

「改状态」而非「删除」：只把 `Disease.is_current` 置为 False，记录仍在档案里。
健康页的康复建议卡只渲染 is_current=True 的疾病，因此标记痊愈后卡片会自动收起；
撤销（置回 True）后卡片恢复。

高敏感改动 —— **任何输入都先出确认卡**（`always_confirm=True`），与 record_disease 同理。
"""

import logging

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


class MarkDiseaseRecoveredArgs(BaseModel):
    """mark_disease_recovered 入参（不含 user_id）"""

    disease_name: str = Field(description="要标记为已痊愈的疾病名称，按用户原话填写（如「骨折」）")
    confirmed_by_user: bool = Field(
        default=False,
        description="系统内部参数，**你必须始终留空**：只能由用户在确认卡上点「帮我记录」后由系统回填",
    )


SPEC = ActionSpec(
    name="mark_disease_recovered",
    description="把用户健康档案里的某条疾病标记为「已痊愈」（改状态，不删除记录，写操作）",
    kind=ActionKind.WRITE,
    args_schema=MarkDiseaseRecoveredArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    always_confirm=True,
    undoable=True,
    sessions=("human",),
    examples=["骨折已经好了", "我妈的高血压控制住了，不用记着了", "我感冒好了"],
    notes=(
        "只在用户明确表示某病已经好转/痊愈时调用（如「已经好了」「愈合了」「不用记了」）；"
        "只是不再提起不算痊愈。这是改状态、不是删除，档案里仍保留这条记录。"
        "confirmed_by_user 必须留空 —— 本动作任何输入都会先出一张确认卡，用户确认后才落库。"
        "找不到匹配的当前患病时动作会失败，此时提示用户去「健康」页核对疾病名称。"
    ),
)


async def mark_disease_recovered(
    params: MarkDiseaseRecoveredArgs, ctx: ActionContext
) -> ActionResult:
    """把匹配到的当前患病置为已痊愈，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未执行")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物健康档案请使用宠物工具，不改动本人的疾病记录"
        )

    name = (params.disease_name or "").strip()
    if not name:
        return ActionResult.failure(SPEC.name, "没听清是哪条疾病，请说出疾病名称（如「骨折」）")

    from shared.models.database import SessionLocal
    from shared.models.user_models import Disease

    db = SessionLocal()
    try:
        # 只看当前患病：已痊愈的再标记一次没有意义（加密列需 Python 侧比对）
        current_rows = (
            db.query(Disease)
            .filter(Disease.user_id == ctx.user_id, Disease.is_current.is_(True))
            .all()
        )
        hits = match_indices_by_name([row.disease_name for row in current_rows], name)
        if not hits:
            all_rows = db.query(Disease).filter(Disease.user_id == ctx.user_id).all()
            names = "、".join(r.disease_name for r in all_rows if r.disease_name) or "（空）"
            return ActionResult.failure(
                SPEC.name,
                f"档案里没有正在患病的「{name}」。当前记录：{names}。"
                "请到「健康」页核对疾病名称后再说一次",
            )
        disease = current_rows[hits[0]]
        matched_name = disease.disease_name

        confirm_params = {"disease_name": matched_name}

        # 一律先出确认卡（老人线不弹卡），模型填的 confirmed_by_user 不生效
        if not params.confirmed_by_user and not ctx.is_elder_channel:
            confirm_token = await register_record_confirm(
                ctx.user_id,
                action=SPEC.name,
                label=f"{matched_name} 已痊愈",
                params=confirm_params,
                confirm_field="confirmed_by_user",
            )
            return build_record_confirm_card(
                action=SPEC.name,
                what=f"{matched_name} 已痊愈",
                params=confirm_params,
                confirm_token=confirm_token,
            )

        disease.is_current = False
        db.commit()
        disease_id = disease.id
    except Exception as e:
        db.rollback()
        logger.exception("mark_disease_recovered 写库失败")
        return ActionResult.failure(SPEC.name, f"标记失败：{e}")
    finally:
        db.close()

    message = f"已把「{matched_name}」标记为已痊愈，健康页的康复建议会同步收起。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(disease_id),
        summary=f"标记「{matched_name}」痊愈",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "disease_id": disease_id,
            "disease_name": matched_name,
            "detail": f"{matched_name} · 已痊愈",
            "jump": {"page": "health"},
        },
        undo_token=str(disease_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 mark_disease_recovered 动作（V6 健康档案扩权）"""
    registry.register(SPEC, mark_disease_recovered)