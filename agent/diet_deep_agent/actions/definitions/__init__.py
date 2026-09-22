"""动作定义汇总。

V6 新增动作 = 新增一个定义模块（spec + handler + register）+ 在 _MODULES 中登记一行，
注册表本身不改（PRD 4.1：只加定义，不改架构）。
"""

from agent.diet_deep_agent.actions.definitions import (
    generate_weekly_report,
    open_page,
    query_cost,
    query_exam,
    query_family,
    query_nutrition,
    query_pet,
    query_today,
    query_weight_trend,
    record_food,
    record_pet_feeding,
    record_water,
    record_weight,
    send_reminder_to_family,
    set_reminder,
    undo,
)
from agent.diet_deep_agent.actions.registry import ActionRegistry

# V5.1 一期动作（PRD 3.1）：写操作 3 个 + 查询 2 个 + 撤销 1 个
_V51_MODULES = (record_food, record_water, record_weight, query_today, query_family, undo)

# V5.2 二期动作（PRD 3.1）：写操作 3 个 + 查询 6 个（合计 15 个动作）
_V52_MODULES = (
    # 营养 / 体重 / 花销
    query_nutrition,
    query_weight_trend,
    query_cost,
    # 宠物
    record_pet_feeding,
    query_pet,
    # 体检 / 提醒 / 周报
    query_exam,
    set_reminder,
    generate_weekly_report,
    send_reminder_to_family,
)

# V5.2 引导卡：Agent 判断需要页面级操作时一键直达（只跳转，零数据写入）
_GUIDE_MODULES = (open_page,)

_MODULES = _V51_MODULES + _V52_MODULES + _GUIDE_MODULES


def register_all(registry: ActionRegistry) -> None:
    """把所有动作定义注册到给定注册表"""
    for module in _MODULES:
        module.register(registry)
