"""query_family：查家人的今日饮食状态（V5.1 查询动作，FAMILY_STATUS 卡）。

PRD 3.1「我妈今天吃了吗」→ 老人线核心；PRD 4.8 家人状态卡：父母今日三餐摘要，
下一步入口「查看父母详情 → 家人健康页」。

数据来源与 routers/family_router.py 的家庭看板一致：
UserRelationship(relationship_type="family", status="accepted") + 当日 DailyNutritionSummary
+ 当日饮水求和。这里只做「今日三餐摘要」这一件事，不引入体检 / 宠物等其它模块。
"""

import logging
from datetime import date, datetime, timedelta
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.definitions.record_food import MEAL_LABELS
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

DEFAULT_CALORIE_TARGET = 2000
DEFAULT_WATER_TARGET_ML = 2000
# 跳转映射（PRD 4.8）：家人状态卡 → 家人健康页
JUMP_PAGE = "family_health"


class QueryFamilyArgs(BaseModel):
    """query_family 入参（不含 user_id）"""

    relation: Optional[str] = Field(
        default=None,
        description="家人称谓，用用户原话（如「我妈」「我爸」「爷爷」「儿子」）；没提具体人可留空",
    )
    name: Optional[str] = Field(
        default=None, description="家人姓名（用户直接说了名字才填），用于精确匹配"
    )
    day: Optional[str] = Field(
        default=None, description="查询日期：今天/昨天/前天，或 YYYY-MM-DD；未提及按今天"
    )


SPEC = ActionSpec(
    name="query_family",
    description="查询家人的饮食状态（今天吃了几餐、吃了什么、喝了多少水）",
    kind=ActionKind.QUERY,
    args_schema=QueryFamilyArgs,
    card_type=CardType.FAMILY_STATUS,
    requires_confirmation=False,
    undoable=False,
    examples=["我妈今天吃了吗", "我爸今天吃了什么", "家里人今天吃得好吗"],
    notes=(
        "查询类动作，不写数据、不需要确认。只查已建立家庭关系的家人；"
        "用户没指定是哪个家人时会返回全部家人的摘要，不要替用户编造家人的饮食内容。"
        "称谓按同义组归一匹配（「我妈」可命中登记的「母亲/妈妈」），"
        "查不到时不要编造，按失败提示引导用户去「家人健康」页确认称谓。"
    ),
)


def _resolve_day(raw: Optional[str]) -> date:
    """解析日期（PRD 4.7 时间归属）：今天/昨天/前天/YYYY-MM-DD，缺省按今天"""
    today = date.today()
    if not raw:
        return today
    text = str(raw).strip()
    aliases = {"今天": 0, "今日": 0, "昨天": 1, "昨日": 1, "前天": 2}
    if text in aliases:
        return today - timedelta(days=aliases[text])
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        logger.warning(f"无法解析查询日期={raw}，按今天处理")
        return today


def _family_relations(db, user_id: int) -> list:
    """取已建立且已接受的家庭关系（双向，与家庭看板口径一致）"""
    from sqlalchemy import or_

    from shared.models.social_models import UserRelationship

    return (
        db.query(UserRelationship)
        .filter(
            or_(
                UserRelationship.user_id == user_id,
                UserRelationship.related_user_id == user_id,
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted",
        )
        .all()
    )


def _member_note(rel, current_user_id: int) -> Optional[str]:
    """取「我方对该家人的称谓」（与 family_router._get_family_note 一致）"""
    if rel.user_id == current_user_id:
        return rel.note_from_user
    return rel.note_from_related


# 称谓同义组（每组首个为该组规范名）：更具体的称谓必须排在前面，
# 否则「姑妈」「姨妈」会被归到「妈」，把用户问的妈妈匹配成姑妈。
_RELATION_GROUPS: tuple[tuple[str, ...], ...] = (
    ("姑妈", "姑姑", "姑母"),
    ("姨妈", "姨母", "阿姨", "小姨"),
    ("舅妈", "舅母", "婶婶", "伯母", "伯父", "叔叔", "舅舅"),
    ("妈", "妈妈", "母亲", "老妈", "娘", "娘亲"),
    ("爸", "爸爸", "父亲", "老爸", "爹", "爹地"),
    ("儿子", "犬子"),
    ("女儿", "闺女"),
    ("老婆", "妻子", "太太", "媳妇"),
    ("老公", "丈夫", "爱人"),
    ("爷爷", "祖父"),
    ("奶奶", "祖母"),
    ("外公", "姥爷", "外祖父"),
    ("外婆", "姥姥", "外祖母"),
    ("哥哥", "大哥"),
    ("弟弟", "小弟"),
    ("姐姐", "大姐"),
    ("妹妹", "小妹"),
    ("孙子", "孙女"),
)


def _canonical_relation(term: Optional[str]) -> Optional[str]:
    """把口语称谓归一到同义组的规范名（「我妈」「母亲」→「妈」）；非称谓返回 None"""
    if not term:
        return None
    raw = str(term).strip()
    if not raw:
        return None
    for group in _RELATION_GROUPS:
        if any(word in raw for word in group):
            return group[0]
    return None


def _match_member(
    spoken: Optional[str], display_name: str, note: Optional[str], username: str
) -> bool:
    """把用户口语（「我妈」「小明」）与家人的姓名 / 称谓比对。

    用户没指定是哪个家人时不过滤，返回全部家人（PRD：子女一句「家里人今天吃得怎么样」）。
    先按姓名/称谓直接匹配，再按称谓同义组归一匹配（「我妈」↔ 登记的「母亲/妈妈」）。
    """
    if not spoken:
        return True
    keyword = str(spoken).strip()
    if keyword.startswith("我"):
        keyword = keyword[1:].strip()
    if not keyword:
        return True

    fields = (display_name, note, username)
    if any(keyword in (field or "") for field in fields):
        return True

    canonical = _canonical_relation(keyword)
    if canonical is None:
        return False
    return any(_canonical_relation(field) == canonical for field in fields)


def _member_summary(db, member_id: int, note: Optional[str], member_name: str, day: date) -> dict:
    """单个家人的当日三餐摘要 + 饮水"""
    from sqlalchemy import func

    from shared.models.food_models import DailyNutritionSummary, FoodRecord
    from shared.models.user_models import UserProfile
    from shared.models.water_models import WaterIntakeRecord

    summary = (
        db.query(DailyNutritionSummary)
        .filter(
            DailyNutritionSummary.user_id == member_id,
            DailyNutritionSummary.summary_date == day,
        )
        .first()
    )
    profile = db.query(UserProfile).filter(UserProfile.user_id == member_id).first()
    target = int(profile.target_calories) if profile and profile.target_calories else DEFAULT_CALORIE_TARGET
    water_goal = (
        int(profile.daily_water_goal) if profile and profile.daily_water_goal else DEFAULT_WATER_TARGET_ML
    )

    records = (
        db.query(FoodRecord)
        .filter(
            FoodRecord.user_id == member_id,
            FoodRecord.record_date == day,
        )
        .order_by(FoodRecord.record_time.asc(), FoodRecord.id.asc())
        .all()
    )

    meals: dict[int, dict[str, Any]] = {}
    for record in records:
        bucket = meals.setdefault(
            record.meal_type,
            {
                "meal_type": record.meal_type,
                "meal_type_label": MEAL_LABELS.get(record.meal_type, "其他"),
                "items": [],
            },
        )
        if record.food_name:
            bucket["items"].append(record.food_name)

    water_total = (
        db.query(func.sum(WaterIntakeRecord.amount_ml))
        .filter(
            WaterIntakeRecord.user_id == member_id,
            func.date(WaterIntakeRecord.record_time) == day,
        )
        .scalar()
        or 0
    )

    meal_list = [meals[key] for key in sorted(meals.keys())]
    return {
        "user_id": member_id,
        "name": member_name,
        "note": note,
        "calories": {
            "intake": round(float(summary.total_calories or 0), 2) if summary else 0.0,
            "target": float(target),
        },
        "water": {"intake_ml": int(water_total), "goal_ml": water_goal},
        "meal_count": len(meal_list),
        "meals": meal_list,
    }


async def query_family(params: QueryFamilyArgs, ctx: ActionContext) -> ActionResult:
    """汇总家人的当日饮食状态"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    target_date = _resolve_day(params.day)

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.user_models import User, UserProfile

        relations = _family_relations(db, ctx.user_id)
        if not relations:
            return ActionResult.failure(
                SPEC.name,
                "还没有建立家庭关系，无法查询家人状态。可在「家人健康」页添加家人后再试。",
            )

        members: list[dict] = []
        for rel in relations:
            member_id = (
                rel.related_user_id if rel.user_id == ctx.user_id else rel.user_id
            )
            note = _member_note(rel, ctx.user_id)
            user = db.query(User).filter(User.id == member_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == member_id).first()
            real_name = (profile.real_name if profile and profile.real_name else "") or ""
            username = (user.username if user else "") or ""
            display_name = real_name or note or username or "家人"

            if not _match_member(params.name or params.relation, display_name, note, username):
                continue

            members.append(_member_summary(db, member_id, note, display_name, target_date))
    except Exception as e:
        logger.exception("query_family 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    if not members:
        who = params.name or params.relation or "这位家人"
        return ActionResult.failure(
            SPEC.name,
            f"没找到「{who}」的家庭关系，可先在「家人健康」页确认是否已添加为家人。",
        )

    day_label = "今天" if target_date == date.today() else target_date.strftime("%m月%d日")
    lines = []
    for member in members:
        label = member["note"] or member["name"]
        if member["meal_count"] == 0:
            lines.append(f"{label}{day_label}还没有饮食记录")
            continue
        detail = "、".join(
            f"{meal['meal_type_label']}{'/'.join(meal['items'][:3]) if meal['items'] else '已记录'}"
            for meal in member["meals"]
        )
        lines.append(f"{label}{day_label}已吃 {member['meal_count']} 餐：{detail}")

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.FAMILY_STATUS,
        message="；".join(lines) + "。",
        data={
            "date": target_date.isoformat(),
            "members": members,
            "jump": {"page": JUMP_PAGE, "date": target_date.isoformat()},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_family 动作（V5.1）"""
    registry.register(SPEC, query_family)
