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


# 「要帮你记录吗？」确认卡的两个按钮（叙述性提及未明确要求记录时弹出，PRD 4.2）
RECORD_CONFIRM_OPTIONS: tuple[dict[str, Any], ...] = (
    {"label": "帮我记录", "value": True},
    {"label": "先不记了", "value": False},
)


def build_record_confirm_card(
    action: str,
    what: str,
    params: dict[str, Any],
    analysis: Optional[dict[str, Any]] = None,
) -> ActionResult:
    """叙述性提及但未明确要求记录时的确认卡（PRD 4.2 / 需求 2026-09-26）。

    用户只是「说」到吃了/喝了/称了重，没让帮忙记：弹这张卡给出
    「帮我记录 / 先不记了」两个按钮，也可以直接忽略不答。
    点「帮我记录」后，前端把按钮文案作为下一条消息发给 LLM，
    LLM 会带上 explicit_request=true 重新调用对应写操作真正落库。

    老人线（hardware）不弹卡，走下方直接记录逻辑。

    message 写给 LLM 看：指引它先用 analysis 里带的营养/上下文数据做简短分析，
    再提示用户点按钮；analysis 会被提升到 data 顶层，方便 LLM 读取。
    """
    question = f"要我帮你记录一下吗？将把「{what}」记入你的数据。"
    data: dict[str, Any] = {
        "question": question,
        "action": action,
        "field": "explicit_request",
        "params": params,
        "options": list(RECORD_CONFIRM_OPTIONS),
    }
    if analysis:
        data.update(analysis)
    message = (
        f"已识别到用户叙述了「{what}」。若返回值 data 中带 nutrition / today_total_ml / "
        "previous_weight_kg 等分析数据，请基于它们做一两句简短分析"
        "（如热量、钠、当日进度、较上次变化），再提示用户点击按钮决定是否记录；本轮不要落库。"
    )
    return ActionResult(
        ok=True,
        action=action,
        card_type=CardType.PENDING_CONFIRM,
        message=message,
        data=data,
    )


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
