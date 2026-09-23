"""query_weight_trend：查近 N 天体重变化趋势（TREND 卡）。

PRD 二期查询动作：「我这一个月瘦了吗」→ 逐次体重折线 + 涨跌结论；
PRD 4.8 趋势卡：结论 + 关键数字 + 下一步入口（查看体重趋势页）。

数据来源与 routers/health_router.py 的 /weight-trend 一致：weight_records 按
measured_at 升序；这里只做「趋势结论」这一件事，不直接调用该路由函数。
"""

import logging
from datetime import date, datetime, timedelta
from typing import Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

# 跳转映射（PRD 4.8）：趋势卡 → 体重趋势页
JUMP_PAGE = "weight_trend"
# 判定「基本持平」的阈值（kg）：变化绝对值小于该值视为稳定
STABLE_THRESHOLD_KG = 0.2


class QueryWeightTrendArgs(BaseModel):
    """query_weight_trend 入参（不含 user_id）"""

    days: Optional[int] = Field(
        default=None, description="统计天数：这周=7、这一个月=30；未提及按 30 天"
    )


SPEC = ActionSpec(
    name="query_weight_trend",
    description="查询用户近 N 天的体重变化趋势（涨了还是瘦了、变化多少）",
    kind=ActionKind.QUERY,
    args_schema=QueryWeightTrendArgs,
    card_type=CardType.TREND,
    requires_confirmation=False,
    undoable=False,
    examples=["我这一个月瘦了吗", "这周体重有变化吗", "最近体重降了多少"],
    notes=(
        "查询类动作，不写数据、不需要确认；只回答问题本身，不要顺便记录体重。"
        "用户说「这周」用 days=7、「这个月」用 days=30。记录太少时如实说明看不出趋势，"
        "不要编造体重数值。"
    ),
)


def _normalize_days(raw: Optional[int]) -> int:
    """归一统计天数：缺省 30，限制在 1~365 天，避免异常入参"""
    try:
        days = int(raw) if raw is not None else 30
    except (TypeError, ValueError):
        days = 30
    return max(1, min(days, 365))


async def query_weight_trend(
    params: QueryWeightTrendArgs, ctx: ActionContext
) -> ActionResult:
    """汇总近 N 天体重记录，给出涨跌结论"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    days = _normalize_days(params.days)
    today = date.today()
    start_dt = datetime.combine(today - timedelta(days=days - 1), datetime.min.time())
    end_dt = datetime.combine(today, datetime.max.time())

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.user_models import UserProfile, WeightRecord

        records = (
            db.query(WeightRecord)
            .filter(
                WeightRecord.user_id == ctx.user_id,
                WeightRecord.measured_at >= start_dt,
                WeightRecord.measured_at <= end_dt,
            )
            .order_by(WeightRecord.measured_at.asc())
            .all()
        )

        points = [
            {
                "date": record.measured_at.date().isoformat(),
                "value": round(float(record.weight or 0), 2),
            }
            for record in records
        ]

        profile = db.query(UserProfile).filter(UserProfile.user_id == ctx.user_id).first()
        profile_weight = (
            round(float(profile.weight), 2) if profile and profile.weight else None
        )
    except Exception as e:
        logger.exception("query_weight_trend 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    if points:
        current = points[-1]["value"]
        previous = points[0]["value"]
        change = round(current - previous, 2)
        if change > STABLE_THRESHOLD_KG:
            direction = "up"
        elif change < -STABLE_THRESHOLD_KG:
            direction = "down"
        else:
            direction = "stable"
        days_tracked = (
            date.fromisoformat(points[-1]["date"]) - date.fromisoformat(points[0]["date"])
        ).days
    else:
        current = None
        previous = None
        change = 0.0
        direction = "stable"
        days_tracked = 0

    if not points:
        message = f"近 {days} 天还没有体重记录，暂时看不出变化趋势。"
    elif len(points) < 2:
        message = f"近 {days} 天只有 1 条体重记录（{current:g}kg），记录太少，还看不出趋势。"
    elif direction == "down":
        message = f"近 {days} 天体重下降 {abs(change):g}kg（{previous:g}→{current:g}kg）。"
    elif direction == "up":
        message = f"近 {days} 天体重上涨 {abs(change):g}kg（{previous:g}→{current:g}kg）。"
    else:
        message = f"近 {days} 天体重基本持平（{current:g}kg）。"

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.TREND,
        message=message,
        data={
            "points": points,
            "unit": "kg",
            "current": current,
            "previous": previous,
            "change": change,
            "direction": direction,
            "days_tracked": days_tracked,
            "days": days,
            "profile_weight": profile_weight,
            "jump": {"page": JUMP_PAGE, "days": days},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_weight_trend 动作（PRD 二期）"""
    registry.register(SPEC, query_weight_trend)
