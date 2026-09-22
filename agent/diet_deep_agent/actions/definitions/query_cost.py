"""query_cost：查本周/本月吃饭花销（COST 卡）。

PRD 二期查询动作：「这周吃饭花了多少钱」→ 总花销 + 日均 + 餐次/来源分布；
PRD 4.8 成本卡：结论 + 关键数字 + 下一步入口（查看花销统计 → 成本页）。

数据来源：shared/services/cost_service.get_cost_stats（已存在，直接复用），
这里只做「结论 + 卡片数据整型」，不改动统计口径。
"""

import logging
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

# 跳转映射（PRD 4.8）：成本卡 → 成本页
JUMP_PAGE = "cost"
# 统计周期中文标签
PERIOD_LABELS = {"week": "本周", "month": "本月"}
# 未知餐次（cost_service 里的 other）的兜底标签
OTHER_MEAL_LABEL = "其他"


class QueryCostArgs(BaseModel):
    """query_cost 入参（不含 user_id）"""

    period: Optional[str] = Field(
        default=None, description="统计周期：week（本周）/ month（本月）；未提及按 week"
    )


SPEC = ActionSpec(
    name="query_cost",
    description="查询用户本周/本月吃饭花销（总额、日均、餐次与来源分布、预算剩余）",
    kind=ActionKind.QUERY,
    args_schema=QueryCostArgs,
    card_type=CardType.COST,
    requires_confirmation=False,
    undoable=False,
    examples=["这周吃饭花了多少钱", "这个月吃饭花销多少", "我这周外卖花了多少"],
    notes=(
        "查询类动作，不写数据、不需要确认；只回答问题本身，不要顺便记录。"
        "用户说「这周」用 period=week、「这个月」用 period=month。"
        "只统计填了金额的记录；没有数据时如实说明，不要编造花销金额。"
    ),
)


def _normalize_period(raw: Optional[str]) -> str:
    """归一统计周期：缺省 week；出现「月」相关表述按 month"""
    if not raw:
        return "week"
    text = str(raw).strip().lower()
    if text == "month" or "月" in text:
        return "month"
    return "week"


def _meal_breakdown(by_meal_time: dict) -> list[dict[str, Any]]:
    """把 {breakfast: 12.5, ...} 转为 [{餐次名, 金额}]，餐次按 1-5 排序，未知餐次置后"""
    from shared.services.cost_service import MEAL_TYPE_MAP

    key_to_type = {label: meal_type for meal_type, label in MEAL_TYPE_MAP.items()}

    items: list[dict[str, Any]] = []
    for key, cost in (by_meal_time or {}).items():
        meal_type = key_to_type.get(key)
        label = MEAL_LABELS.get(meal_type, OTHER_MEAL_LABEL) if meal_type else OTHER_MEAL_LABEL
        items.append(
            {
                "meal_type": meal_type,
                "meal_type_label": label,
                "cost": round(float(cost or 0), 2),
            }
        )
    items.sort(key=lambda item: (item["meal_type"] is None, item["meal_type"] or 0))
    return items


async def query_cost(params: QueryCostArgs, ctx: ActionContext) -> ActionResult:
    """汇总本周/本月吃饭花销并给出结论"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    period = _normalize_period(params.period)

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.services.cost_service import get_cost_stats

        stats = get_cost_stats(db, ctx.user_id, period=period)
    except Exception as e:
        logger.exception("query_cost 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()

    period_label = PERIOD_LABELS.get(period, "本周")
    total_cost = round(float(stats.get("total_cost") or 0), 2)
    daily_avg = round(float(stats.get("daily_avg") or 0), 2)
    record_count = int(stats.get("record_count") or 0)

    if record_count == 0:
        message = f"{period_label}还没有带金额的饮食记录。"
    else:
        message = f"{period_label}共花 {total_cost:g} 元，日均 {daily_avg:g} 元。"

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.COST,
        message=message,
        data={
            "period": period,
            "total_cost": total_cost,
            "daily_avg": daily_avg,
            "record_count": record_count,
            "by_meal_time": _meal_breakdown(stats.get("by_meal_time") or {}),
            "by_source": stats.get("by_source") or {},
            "budget": stats.get("budget"),
            "budget_remaining": stats.get("budget_remaining"),
            "jump": {"page": JUMP_PAGE, "period": period},
        },
    )


def register(registry: ActionRegistry) -> None:
    """注册 query_cost 动作（PRD 二期）"""
    registry.register(SPEC, query_cost)
