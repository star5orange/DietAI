"""set_reminder：给自己设一条喝水/吃饭提醒（V6 写操作，可撤销）。

PRD 二期动作：用户一句「明早 7 点提醒我喝水」→ 直接落库一条提醒（reminders 表），
并登记撤销凭证（PRD 4.5）。仅给自己设提醒，不支持代家人设置。

时间解析（PRD 4.7 时间归属）在动作内完成，不依赖模型换算：
「明早 7 点」→ 07:00、「下午 3 点」→ 15:00、「晚上 9 点半」→ 21:30。
解析不出来（没给具体时间 / 超出 0-23 点）时返回需要澄清的失败，绝不瞎猜。
"""

import logging
import re
from datetime import date, time, timedelta
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
from agent.diet_deep_agent.actions.undo_journal import UndoEntry, undo_journal

logger = logging.getLogger(__name__)

# 跳转映射（PRD 4.8）：操作确认卡「管理提醒」→ 提醒设置页
JUMP_PAGE = "reminder"

# 中文数字（点/分口语），支持「十」「十一」「十二」
_CN_NUM = {
    "零": 0,
    "一": 1,
    "二": 2,
    "两": 2,
    "三": 3,
    "四": 4,
    "五": 5,
    "六": 6,
    "七": 7,
    "八": 8,
    "九": 9,
    "十": 10,
    "十一": 11,
    "十二": 12,
}
# 时段关键词（顺序敏感：先长后短，避免「晚安」这类误伤；不使用单字「早」「晚」）
_DAWN_WORDS = ("凌晨",)
_MORNING_WORDS = ("早上", "早晨", "清晨", "上午", "今早", "明早")
_NOON_WORDS = ("中午", "正午")
_AFTERNOON_WORDS = ("下午", "午后")
_EVENING_WORDS = ("晚上", "傍晚", "夜里", "今晚", "明晚")

_TIME_RE = re.compile(r"(\d{1,2})\s*[:：]\s*(\d{1,2})")
_POINT_RE = re.compile(
    r"([0-9一二两三四五六七八九十]{1,3})\s*点\s*"
    r"(半|[0-9一二三四五六七八九十]{1,3}\s*分?)?"
)


class SetReminderArgs(BaseModel):
    """set_reminder 入参（不含 user_id）"""

    reminder_type: str = Field(
        description="提醒类型：用户说「提醒我喝水」填 water，「提醒我吃饭」填 meal"
    )
    time_text: str = Field(
        description="用户原话里的时间（如「明早7点」「每天21:30」「晚上9点半」），按原话填写，不要自行换算"
    )
    repeat: Optional[str] = Field(
        default=None,
        description="重复方式：daily（每天，默认）/ once（只一次）/ weekdays（工作日）；用户没说留空按每天",
    )
    title: Optional[str] = Field(
        default=None, description="提醒标题（如「起床喝水」）；用户没说留空"
    )


SPEC = ActionSpec(
    name="set_reminder",
    description="给用户自己设置喝水或吃饭提醒（写入提醒设置，写操作）",
    kind=ActionKind.WRITE,
    args_schema=SetReminderArgs,
    card_type=CardType.ACTION_CONFIRM,
    requires_confirmation=True,
    undoable=True,
    examples=["明早 7 点提醒我喝水", "每天 21:30 提醒我别吃夜宵", "下午 3 点提醒我喝水"],
    notes=(
        "只给自己设提醒，不能帮家人设（帮家人提醒请用 send_reminder_to_family）。"
        "把时间原话填进 time_text，**不要自己换算成 HH:MM**，换算由系统完成；"
        "用户没说具体钟点时不要瞎猜，系统会返回需要澄清的提示。"
    ),
)


def _cn_to_int(token: Optional[str]) -> Optional[int]:
    """中文/阿拉伯数字转 int；无法识别返回 None"""
    text = (token or "").strip()
    if not text:
        return None
    if text.isdigit():
        return int(text)
    if text in _CN_NUM:
        return _CN_NUM[text]
    if "十" in text:  # 二十 / 二十三 这类
        head, _, tail = text.partition("十")
        tens = _CN_NUM.get(head, 1) if head else 1
        ones = _CN_NUM.get(tail, 0) if tail else 0
        return tens * 10 + ones
    return None


def _period_of(text: str) -> Optional[str]:
    """识别时段：dawn / morning / noon / afternoon / evening；未提及返回 None"""
    if any(word in text for word in _DAWN_WORDS):
        return "dawn"
    if any(word in text for word in _MORNING_WORDS):
        return "morning"
    if any(word in text for word in _NOON_WORDS):
        return "noon"
    if any(word in text for word in _AFTERNOON_WORDS):
        return "afternoon"
    if any(word in text for word in _EVENING_WORDS):
        return "evening"
    return None


def _apply_period(hour: int, period: Optional[str]) -> int:
    """按口语时段把钟点归一到 0-23（下午 3 点→15、晚上 9 点→21、晚上 12 点→0）"""
    if period == "noon":
        return hour + 12 if hour < 11 else hour
    if period == "afternoon":
        return hour + 12 if hour < 12 else hour
    if period == "evening":
        if hour == 12:
            return 0
        return hour + 12 if hour < 12 else hour
    if period == "dawn":
        return 0 if hour == 12 else hour
    return hour


def _parse_time_text(text: Optional[str]) -> Optional[time]:
    """把中文口语时间解析成 time；解析不出来返回 None（绝不猜）"""
    raw = (text or "").strip()
    if not raw:
        return None

    hour: Optional[int] = None
    minute = 0

    match = _TIME_RE.search(raw)
    if match:
        hour = _cn_to_int(match.group(1))
        minute = _cn_to_int(match.group(2)) or 0
    else:
        point = _POINT_RE.search(raw)
        if point is None:
            return None
        hour = _cn_to_int(point.group(1))
        tail = (point.group(2) or "").strip()
        if tail.startswith("半"):
            minute = 30
        elif tail:
            minute = _cn_to_int(re.sub(r"分$", "", tail).strip()) or 0

    if hour is None:
        return None
    hour = _apply_period(hour, _period_of(raw))
    if not (0 <= hour <= 23) or not (0 <= minute <= 59):
        return None
    return time(hour, minute)


def _day_offset(text: str) -> int:
    """相对天数：今天/今早/今晚→0，明天/明早/明晚→1，后天→2"""
    if any(word in text for word in ("后天",)):
        return 2
    if any(word in text for word in ("明天", "明日", "明早", "明晚")):
        return 1
    return 0


def _resolve_repeat(repeat: Optional[str], text: str) -> str:
    """确定重复方式：daily / weekdays / once（入参优先，其次从原话推断）"""
    chosen = (repeat or "").strip().lower()
    if chosen in ("daily", "每天", "每日"):
        return "daily"
    if chosen in ("weekdays", "工作日"):
        return "weekdays"
    if chosen in ("once", "一次", "只一次", "单次"):
        return "once"
    if any(word in text for word in ("每天", "天天", "每日")):
        return "daily"
    if "工作日" in text:
        return "weekdays"
    if any(word in text for word in ("明天", "明早", "明晚", "今晚", "今早", "后天", "一次")):
        return "once"
    return "daily"


def _repeat_days(repeat: str, target_date: date) -> int:
    """bitmask：0=周日…6=周六；weekdays=周一~周五(62)；once=该日单日 bit；daily=127"""
    if repeat == "weekdays":
        return 62  # bit1~bit5：周一/周二/周三/周四/周五
    if repeat == "once":
        bit = (target_date.weekday() + 1) % 7  # 周一(0)→1，周日(6)→0
        return 1 << bit
    return 127


def _normalize_type(reminder_type: str) -> Optional[str]:
    """归一提醒类型到 water / meal；无法识别返回 None"""
    text = (reminder_type or "").strip().lower()
    if text in ("water", "meal"):
        return text
    if "水" in text or "喝" in text:
        return "water"
    if any(word in text for word in ("饭", "餐", "吃")):
        return "meal"
    return None


async def set_reminder(params: SetReminderArgs, ctx: ActionContext) -> ActionResult:
    """解析时间并写入一条提醒，登记撤销凭证"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），未设置提醒")
    if ctx.is_pet_session:
        return ActionResult.failure(
            SPEC.name, "当前是宠物会话，宠物提醒请使用宠物提醒工具，不设置本人的提醒"
        )

    reminder_type = _normalize_type(params.reminder_type)
    if reminder_type is None:
        return ActionResult.failure(
            SPEC.name, "没听清是喝水提醒还是吃饭提醒，请说「提醒我喝水」或「提醒我吃饭」"
        )

    remind_time = _parse_time_text(params.time_text)
    if remind_time is None:
        return ActionResult.failure(
            SPEC.name,
            f"没听清具体提醒时间（「{params.time_text or ''}」），"
            "请说一个明确的钟点，比如「明早 7 点」「每天 21:30」「下午 3 点半」",
        )

    repeat = _resolve_repeat(params.repeat, params.time_text or "")
    days_bitmask = _repeat_days(repeat, date.today() + timedelta(days=_day_offset(params.time_text or "")))

    type_label = "喝水" if reminder_type == "water" else "吃饭"
    title = (params.title or "").strip() or f"{type_label}提醒"

    from shared.models.database import SessionLocal
    from shared.models.schemas.reminder import ReminderCreate

    db = SessionLocal()
    try:
        from shared.services.reminder_service import create_reminder

        reminder = create_reminder(
            db,
            ctx.user_id,
            ReminderCreate(
                reminder_type=reminder_type,
                remind_time=remind_time,
                repeat_days=days_bitmask,
                is_enabled=True,
                title=title,
                description=None,
            ),
        )
        reminder_id = reminder.id
    except Exception as e:
        db.rollback()
        logger.exception("set_reminder 写库失败")
        return ActionResult.failure(SPEC.name, f"设置提醒失败：{e}")
    finally:
        db.close()

    clock = remind_time.strftime("%H:%M")
    if repeat == "daily":
        when_label = "每天"
    elif repeat == "weekdays":
        when_label = "每个工作日"
    else:
        when_label = {0: "今天", 1: "明天", 2: "后天"}.get(
            _day_offset(params.time_text or ""), "单次"
        )
    message = f"已设置：{when_label} {clock} 提醒你{type_label}。10 分钟内可撤销。"

    entry = UndoEntry(
        action=SPEC.name,
        undo_token=str(reminder_id),
        summary=f"{when_label} {clock} {type_label}提醒",
    )
    await undo_journal.push(ctx.user_id, entry)

    return ActionResult(
        ok=True,
        action=SPEC.name,
        card_type=CardType.ACTION_CONFIRM,
        message=message,
        data={
            "reminder_id": reminder_id,
            "reminder_type": reminder_type,
            "remind_time": clock,
            "repeat": repeat,
            "repeat_days": days_bitmask,
            "title": title,
            "jump": {"page": JUMP_PAGE},
        },
        undo_token=str(reminder_id),
        undo_deadline=entry.deadline_iso(),
    )


def register(registry: ActionRegistry) -> None:
    """注册 set_reminder 动作（V6 二期）"""
    registry.register(SPEC, set_reminder)
