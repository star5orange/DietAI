"""record_disease：记录一条疾病（V6 健康档案扩权，写操作，可撤销）。

高敏感档案改动 —— **任何输入都先出确认卡**（`always_confirm=True`）：
即使说了「帮我记录」，也只能由用户在卡片上点确认后，由系统回填
`confirmed_by_user=True` 才落库。模型自行填 true 无效（入参描述里写明必须留空）。

名称匹配必须走 `health_profile_common`（`disease_name` 是加密列，SQL 匹配失效）。
只允许追加，不提供删除：用户要求删除时引导去「健康」页手动操作。
"""

import logging
from datetime import date, datetime, timedelta
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


class RecordDiseaseArgs(BaseModel):
    """record_disease 入参（不含 user_id）"""

    disease_name: str = Field(description="疾病名称，按用户原话填写（如「腕部骨折」「高血压」）")
    severity_level: Optional[int] = Field(
        default=None,
        ge=1,
        le=3,
        description="严重程度：1=轻度，2=中度，3=重度；用户没说留空，不要自行判断",
    )
    diagnosed_date: Optional[str] = Field(
        default=None,
        description="诊断日期，按用户原话填（如「今天」「上周三」「2026-10-01」）；未提及留空",
    )
    notes: Optional[str] = Field(default=None, description="补充说明，如医生叮嘱；用户没说留空")
    confirmed_by_user: bool = Field(
        default=False,
        description="系统内部参数，**你必须始终留空**：只能由用户在确认卡上点「帮我记录」后由系统回填",
    )


SPEC = ActionSpec(
    name="record_disease",
    description="把用户提到的疾病记入健康档案（写入疾病信息，写操作）",
    kind=ActionKind.WRITE,
    args_schema=RecordDiseaseArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    always_confirm=True,
    undoable=True,
    sessions=("human",),
    examples=["我外婆手腕骨折了", "帮我记录：我妈有高血压"],
    notes=(
        "只记录、不诊断、不给治疗方案（PRD 5.4 合规红线）；用户问「这是什么病 / 该吃什么药」时"
        "不要调用本动作，只回答「建议及时就医」。"
        "confirmed_by_user 必须留空 —— 本动作任何输入都会先出一张确认卡，用户确认后才落库。"
        "只允许新增，不能删除已有档案；用户要求删掉某条疾病时，引导去「健康」页手动删除，不要声称已删除。"
    ),
)


def _parse_diagnosed_date(raw: Optional[str]) -> Optional[date]:
    """诊断日期：支持 ISO 日期与「今天/昨天」，识别不出就留空（不猜）"""
    text = (raw or "").strip()
    if not text:
        return None
    today = date.today()
    if "今天" in text or "今日" in text:
        return today
    if "昨天" in text or "昨日" in text:
        return today - timedelta(days=1)
    for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            parsed = datetime.strptime(text[:10], fmt).date()
        except ValueError:
            continue
        # 未来日期不是诊断日期，留空让用户自己核对
        return parsed if parsed <= today else None
    return None


async def record_disease(params: RecordDiseaseArgs, ctx: ActionContext) -> ActionResult:
    """写入一条疾病档案，并登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未记录")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物健康档案请使用宠物工具，不写入本人的疾病记录"
        )

    name = (params.disease_name or "").strip()
    if not name:
        return ActionResult.failure(SPEC.name, "没听清是什么疾病，请说具体名称（如「腕部骨折」）")

    confirm_params = {
        "disease_name": name,
        "severity_level": params.severity_level,
        "diagnosed_date": params.diagnosed_date,
        "notes": params.notes,
    }

    # 一律先出确认卡（老人线不弹卡），模型填的 confirmed_by_user 不生效
    if not params.confirmed_by_user and not ctx.is_elder_channel:
        confirm_token = await register_record_confirm(
            ctx.user_id,
            action=SPEC.name,
            label=name,
            params=confirm_params,
            confirm_field="confirmed_by_user",
        )
        return build_record_confirm_card(
            action=SPEC.name,
            what=name,
            params=confirm_params,
            confirm_token=confirm_token,
        )

    from shared.models.database import SessionLocal
    from shared.models.user_models import Disease

    when = _parse_diagnosed_date(params.diagnosed_date)

    db = SessionLocal()
    try:
        # 加密列不能 SQL 匹配：整表取回该用户的档案后在 Python 侧比对（用解密后的值）
        rows = db.query(Disease).filter(Disease.user_id == ctx.user_id).all()
        hits = match_indices_by_name([row.disease_name for row in rows], name)
        existing = rows[hits[0]] if hits else None
        if existing is not None and existing.is_current:
            return ActionResult.failure(
                SPEC.name,
                f"健康档案里已有「{existing.disease_name}」（当前患病），无需重复记录；"
                "如果它已经好了，可以说「那XX已经好了」让我标记痊愈",
            )

        disease = Disease(
            user_id=ctx.user_id,
            disease_name=name,
            severity_level=params.severity_level,
            diagnosed_date=when,
            is_current=True,
            notes=params.notes,
        )
        db.add(disease)
        db.commit()
        db.refresh(disease)
        disease_id = disease.id
    except Exception as e:
        db.rollback()
        logger.exception("record_disease 写库失败")
        return ActionResult.failure(SPEC.name, f"记录失败：{e}")
    finally:
        db.close()

    course = f"（诊断于 {when.isoformat()}）" if when else ""
    message = f"已记入健康档案：{name}{course}。健康页会据此生成康复建议。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(disease_id),
        summary=f"疾病「{name}」",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "disease_id": disease_id,
            "disease_name": name,
            "diagnosed_date": when.isoformat() if when else None,
            "detail": name + (f" · 诊断于 {when.isoformat()}" if when else ""),
            "jump": {"page": "health"},
        },
        undo_token=str(disease_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 record_disease 动作（V6 健康档案扩权）"""
    registry.register(SPEC, record_disease)