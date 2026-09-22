"""模糊量词追问机制（PRD 4.3 / 4.4 / D5 / D13）。

量词表是"单一事实来源"，两类渠道共用同一张表：
- App 端（默认）：出待确认卡（card_type=pending_confirm）+ 快捷选项，一次点击答完
- 老人线（input_channel=hardware，硬件语音）：取表里的默认值直接记录，事后可改

每项 = (量词, 追问文案, 快捷选项, 老人线默认值)，**顺序敏感**：长量词必须排在短量词前
（「小半杯」先于「半杯」先于「杯」），否则短量词会先命中。
"""

import logging
from typing import Any, Optional, Sequence

from agent.diet_deep_agent.actions.spec import ActionResult, CardType

logger = logging.getLogger(__name__)

# 量词表的一行：(量词, 追问文案, 快捷选项, 老人线默认值)
Quantifier = tuple[str, str, tuple[float, ...], float]


def detect_quantifier(table: Sequence[Quantifier], text: Optional[str]) -> Optional[Quantifier]:
    """从用户原话里识别量词（顺序敏感，长量词优先）"""
    if not text:
        return None
    raw = str(text).strip()
    for item in table:
        if item[0] in raw:
            return item
    return None


def _format_value(value: float) -> str:
    """数值文案：整数不带小数点（150 而不是 150.0）"""
    return f"{value:g}"


def build_options(pair: Sequence[float], unit: str) -> list[dict[str, Any]]:
    """构造快捷选项；末项「其他」= 让用户自己说数值（前端聚焦输入框）"""
    options = [{"label": f"{_format_value(v)}{unit}", "value": float(v)} for v in pair]
    options.append({"label": "其他", "value": None})
    return options


def build_pending_card(
    action: str,
    field: str,
    question: str,
    pair: Sequence[float],
    unit: str,
    params: dict[str, Any],
) -> ActionResult:
    """构造待确认卡（就地回答、无跳转，PRD 4.8）。

    data.action / data.field / data.params 是给模型看的"回填说明"：
    用户下一轮选了选项，就按 data.action 调用并把值填进 data.field，其余参数用 data.params。
    """
    return ActionResult(
        ok=True,
        action=action,
        card_type=CardType.PENDING_CONFIRM,
        message=question,
        data={
            "question": question,
            "action": action,
            "field": field,
            "params": params,
            "options": build_options(pair, unit),
        },
    )
