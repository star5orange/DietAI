"""首页模块布局服务

职责：
1. 维护首页模块注册表（前后端一致的模块 id / 标题 / 是否可隐藏 / 区域）
2. 采集用户画像信号（是否有宠物、体检报告、消费数据、体质、收藏等）
3. 按规则推导默认布局（自动分群），再叠加用户手动定制（覆盖）
4. 读写用户定制（user_home_layouts）

设计要点：
- 规则只看**稳定信号**（画像字段），不看"今天有没有数据"，避免首页每天变样
- 关键模块（热量目标、饮食记录）锁定不可隐藏，防止用户关成空白首页
- 用户自定义后以用户配置为准（可把规则隐藏的模块重新打开）；可 reset 回自动
"""

import logging
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from shared.models.home_layout_models import UserHomeLayout
from shared.models.pet_models import PetProfile
from shared.models.exam_models import ExamReport
from shared.models.saved_meal_models import SavedMeal
from shared.models.food_models import FoodRecord
from shared.models.user_models import UserProfile

logger = logging.getLogger("home_layout_service")

# ============================================================
# 模块注册表
# ============================================================
# region: header=顶部固定区（宠物切换），body=滚动主体
# locked: True 表示用户不可隐藏（保底模块）
# modes:  该模块在哪些布局模式下默认展示
#         normal=常规用户；onboarding=新用户引导态
NORMAL = "normal"
ONBOARDING = "onboarding"

HOME_MODULES: List[Dict[str, Any]] = [
    # ---------- 常规模块 ----------
    {"id": "pet_switcher", "title": "宠物切换入口", "locked": False, "region": "header", "default_order": 5,
     "modes": [NORMAL], "description": "“我的健康 / 宠物”切换（无宠物时自动隐藏）"},
    {"id": "crowd_tag", "title": "人群标签卡", "locked": False, "region": "body", "default_order": 10,
     "modes": [NORMAL], "description": "根据减脂/健身/均衡维持展示的重点提示"},
    {"id": "exam_entry", "title": "体检报告入口", "locked": False, "region": "body", "default_order": 20,
     "modes": [NORMAL], "description": "无体检记录时自动变为紧凑入口"},
    {"id": "calorie", "title": "热量目标", "locked": True, "region": "body", "default_order": 30,
     "modes": [NORMAL, ONBOARDING], "description": "今日热量与宏量营养素（保底模块）"},
    {"id": "water", "title": "今日饮水", "locked": False, "region": "body", "default_order": 40,
     "modes": [NORMAL], "description": "饮水记录与快捷加水"},
    {"id": "solar_term", "title": "节气养生", "locked": False, "region": "body", "default_order": 50,
     "modes": [NORMAL], "description": "节气变化与养生建议（未测体质时自动下沉）"},
    {"id": "cost", "title": "消费概览", "locked": False, "region": "body", "default_order": 60,
     "modes": [NORMAL], "description": "本周饮食消费统计（无预算且无消费记录时自动隐藏）"},
    {"id": "favorites", "title": "常用餐食", "locked": False, "region": "body", "default_order": 70,
     "modes": [NORMAL], "description": "收藏的菜品快捷记录（无收藏时自动隐藏）"},
    {"id": "food_intake", "title": "饮食记录", "locked": True, "region": "body", "default_order": 80,
     "modes": [NORMAL, ONBOARDING], "description": "早/午/晚/加餐记录（保底模块）"},
    # ---------- 新用户引导模块（仅在引导态展示，条件满足后自动消失）----------
    {"id": "onboarding_preference", "title": "定制我的首页", "locked": False, "region": "body", "default_order": 1,
     "modes": [ONBOARDING], "description": "回答 2 个问题，首页只留你关心的功能"},
    {"id": "onboarding_record", "title": "记录第一餐", "locked": False, "region": "body", "default_order": 3,
     "modes": [ONBOARDING], "description": "拍一张或描述一句话，AI 自动算出营养"},
    {"id": "onboarding_profile", "title": "完善健康档案", "locked": False, "region": "body", "default_order": 6,
     "modes": [ONBOARDING], "description": "填好身高体重和目标，热量建议才准确"},
    {"id": "onboarding_constitution", "title": "体质自测", "locked": False, "region": "body", "default_order": 7,
     "modes": [ONBOARDING], "description": "9 道题测出体质，解锁应季养生建议"},
    {"id": "onboarding_add_pet", "title": "添加宠物", "locked": False, "region": "body", "default_order": 8,
     "modes": [ONBOARDING], "description": "给毛孩子建立健康档案，可选"},
]

MODULE_IDS: List[str] = [m["id"] for m in HOME_MODULES]
_MODULE_MAP: Dict[str, Dict[str, Any]] = {m["id"]: m for m in HOME_MODULES}
LOCKED_MODULE_IDS: List[str] = [m["id"] for m in HOME_MODULES if m.get("locked")]

# 未测体质时，节气养生模块的排序值（下沉到末尾）
_SOLAR_TERM_SUNK_ORDER = 95

# 引导态：这些常规模块一律隐藏（新用户无数据，展示只会占位）
_ONBOARDING_HIDDEN = {
    "pet_switcher", "crowd_tag", "exam_entry", "water", "solar_term", "cost", "favorites",
}

# 按人群标签微调默认顺序（常规态）
_CROWD_ORDER_OVERRIDES: Dict[str, Dict[str, int]] = {
    # 减脂：热量卡与饮食记录置顶，消费概览下沉（更关心热量而非花销）
    "减脂": {"calorie": 2, "food_intake": 3, "cost": 90},
    # 健身：热量卡置顶，饮水与饮食记录紧随（训练出汗多、蛋白需记录）
    "健身": {"calorie": 2, "water": 4, "food_intake": 6},
}

# ============================================================
# 引导问卷偏好（新用户回答后直接决定模块显示与优先级）
# ============================================================
# 问卷以"情境/习惯"方式提问（问倾向，不直接问要哪些功能），
# 由服务端把答案推导成 focus（人群标签）与 interests（要展示的模块）。
#
# 题目与选项（前端展示文案见 HomePreferencePage）：
#   goal     身体目标倾向: leaner / stronger / keep
#   checkup  体检习惯:     recent / long_ago / never
#   spending 花销习惯:     track / sometimes / never
#   wellness 时令养生:     follow / casual / no
#   pet      养宠情况:     have / plan / no

# 身体目标倾向 → 人群标签（同时写回 UserProfile.crowd_tag，让热量目标/AI 建议一致）
FOCUS_CROWD_TAG: Dict[str, str] = {
    "fat_loss": "减脂",
    "fitness": "健身",
    "balanced": "均衡维持",
}
CROWD_TAG_FOCUS: Dict[str, str] = {v: k for k, v in FOCUS_CROWD_TAG.items()}

# 答案 → focus
ANSWER_FOCUS: Dict[str, str] = {
    "leaner": "fat_loss",
    "stronger": "fitness",
    "keep": "balanced",
}

# 答案 → 关注模块（选中即"强制展示"，覆盖"无数据自动隐藏"）
ANSWER_INTERESTS: Dict[str, Dict[str, List[str]]] = {
    "spending": {"track": ["cost"], "sometimes": ["cost"], "never": []},
    "wellness": {"follow": ["wellness"], "casual": [], "no": []},
    "pet": {"have": ["pet"], "plan": ["pet"], "no": []},
    # 很久没体检/从没体检 → 展示体检入口（可拍照上传，顺带提醒）
    "checkup": {"long_ago": ["exam"], "never": ["exam"]},
}

# 答案 → 排序提升（让相关模块更靠前）
ANSWER_BOOST: Dict[str, Dict[str, str]] = {
    # 有记账习惯 → 消费概览上浮
    "spending": {"track": "cost", "sometimes": "cost"},
    # 关注时令养生 → 节气养生气上浮
    "wellness": {"follow": "solar_term"},
    # 很久没体检/从没体检 → 体检入口上浮提醒
    "checkup": {"long_ago": "exam_entry", "never": "exam_entry"},
}

# 兼容：直接指定关注点（旧接口/后台配置用）
INTEREST_MODULE_MAP: Dict[str, List[str]] = {
    "cost": ["cost"],
    "wellness": ["solar_term"],
    "exam": ["exam_entry"],
    "water": ["water"],
    "pet": ["pet_switcher"],
}

# 关注模块的排序加权（取 min，避免把本来就靠前的模块往后推）
INTEREST_ORDER_BOOST: Dict[str, int] = {
    "cost": 33,
    "solar_term": 34,
    "exam_entry": 35,
    "water": 36,
    "pet_switcher": 8,
}


# ============================================================
# 用户信号采集
# ============================================================

def collect_signals(db: Session, user_id: int) -> Dict[str, Any]:
    """采集用于分群的用户信号（全部为稳定画像/资产信号）"""

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()

    has_real_pet = db.query(PetProfile.id).filter(
        PetProfile.user_id == user_id
    ).first() is not None

    has_exam_report = db.query(ExamReport.id).filter(
        ExamReport.user_id == user_id
    ).first() is not None

    has_saved_meals = db.query(SavedMeal.id).filter(
        SavedMeal.user_id == user_id
    ).first() is not None

    monthly_budget = float(profile.monthly_food_budget or 0) if profile else 0.0
    has_cost_record = db.query(FoodRecord.id).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.cost.isnot(None),
        FoodRecord.cost > 0,
    ).first() is not None

    constitution = (profile.constitution_type or "").strip() if profile else ""

    has_food_record = db.query(FoodRecord.id).filter(
        FoodRecord.user_id == user_id
    ).first() is not None

    onboarding_completed = bool(profile.onboarding_completed) if profile else False
    has_body_data = bool(
        profile and profile.height is not None and profile.weight is not None
    )

    return {
        "has_real_pet": has_real_pet,
        "has_exam_report": has_exam_report,
        "has_saved_meals": has_saved_meals,
        "monthly_food_budget": monthly_budget,
        "has_cost_record": has_cost_record,
        "has_cost_data": monthly_budget > 0 or has_cost_record,
        "has_constitution": bool(constitution),
        "crowd_tag": (profile.crowd_tag or "").strip() if profile else "",
        # ---- 新用户引导态判定 ----
        "onboarding_completed": onboarding_completed,
        "has_food_record": has_food_record,
        "has_body_data": has_body_data,
        # 未完成引导，或从未记录过饮食 → 视为新用户
        "is_new_user": (not onboarding_completed) or (not has_food_record),
    }


# ============================================================
# 布局解析（纯函数，便于单测）
# ============================================================

def resolve_layout(
    signals: Dict[str, Any],
    hidden_modules: Optional[List[str]] = None,
    module_order: Optional[List[str]] = None,
    preferences: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """按规则推导默认布局，再叠加引导问卷偏好与用户定制

    优先级：用户手动定制 > 引导问卷偏好 > 画像自动信号

    Args:
        signals: collect_signals 的产物
        hidden_modules: 用户隐藏列表；None 表示未自定义（走规则）
        module_order: 用户自定义顺序；None 表示未自定义（走规则）
        preferences: 引导问卷偏好 {focus, interests}

    Returns:
        {order, hidden, variants, modules, locked, is_customized, mode, preferences}
    """

    # ---------- 0. 判定布局模式 ----------
    mode = ONBOARDING if signals.get("is_new_user") else NORMAL

    # ---------- 1. 规则推导默认 ----------
    default_order_map: Dict[str, int] = {m["id"]: m["default_order"] for m in HOME_MODULES}
    rule_hidden: set = set()
    variants: Dict[str, str] = {}

    # 1.1 模式不适用的模块全部隐藏（引导模块仅在引导态出现，反之亦然）
    for m in HOME_MODULES:
        if mode not in m.get("modes", [NORMAL, ONBOARDING]):
            rule_hidden.add(m["id"])

    if mode == ONBOARDING:
        # 新用户：数据型常规模块一律不展示，只保留引导 + 保底模块
        rule_hidden |= _ONBOARDING_HIDDEN
        # 引导卡按"还没做的事"逐个消失
        if signals.get("has_body_data"):
            rule_hidden.add("onboarding_profile")
        if signals.get("has_constitution"):
            rule_hidden.add("onboarding_constitution")
        if signals.get("has_real_pet"):
            rule_hidden.add("onboarding_add_pet")
        # 引导态无需体检入口降级
    else:
        # 常规态规则
        if not signals.get("has_real_pet"):
            rule_hidden.add("pet_switcher")
        if not signals.get("has_cost_data"):
            rule_hidden.add("cost")
        if not signals.get("has_saved_meals"):
            rule_hidden.add("favorites")
        if not signals.get("has_exam_report"):
            # 无体检记录：大按钮降级为紧凑入口（而非完全隐藏，保留可发现性）
            variants["exam_entry"] = "compact"
        if not signals.get("has_constitution"):
            # 未测体质：节气养生下沉到末尾
            default_order_map["solar_term"] = _SOLAR_TERM_SUNK_ORDER
        else:
            # 已测体质：节气养生适当前置
            default_order_map["solar_term"] = 45

        # 1.2 按人群标签差异化默认顺序
        crowd_tag = signals.get("crowd_tag") or ""
        for tag, overrides in _CROWD_ORDER_OVERRIDES.items():
            if tag in crowd_tag:
                default_order_map.update(overrides)
                break

    # ---------- 1.3 应用引导问卷偏好（用户明说 > 隐式信号）----------
    prefs = preferences or {}
    answers = {
        k: str(v).strip()
        for k, v in (prefs.get("answers") or {}).items() if v
    }

    # 由"身体目标倾向"推导人群标签；兼容直接指定 focus
    focus = ANSWER_FOCUS.get(answers.get("goal", ""), "") or str(prefs.get("focus") or "").strip()

    # 关注点 = 习惯类答案推导 + 显式指定
    interests: List[str] = []
    for question, mapping in ANSWER_INTERESTS.items():
        interests.extend(mapping.get(answers.get(question, ""), []))
    interests.extend(
        i for i in (prefs.get("interests") or []) if i in INTEREST_MODULE_MAP
    )
    interests = list(dict.fromkeys(interests))

    prefs_saved = bool(focus or interests or answers)

    # 关注的模块 → 强制展示 + 排序加权
    pref_visible: set = set()
    for interest in interests:
        pref_visible.update(INTEREST_MODULE_MAP[interest])

    # 习惯类答案带来的排序提升（记账→消费上浮；关注养生→节气上浮；久未体检→体检入口上浮提醒）
    for question, mapping in ANSWER_BOOST.items():
        mid = mapping.get(answers.get(question, ""))
        if mid and mid in INTEREST_ORDER_BOOST:
            default_order_map[mid] = min(
                default_order_map.get(mid, 999), INTEREST_ORDER_BOOST[mid]
            )

    # 人群差异化排序只在常规态生效：引导态要让引导卡保持在前，
    # 否则新用户一选"减脂"，引导卡就被热量卡挤到了后面
    if mode == NORMAL and focus in FOCUS_CROWD_TAG:
        focus_tag = FOCUS_CROWD_TAG[focus]
        for tag, overrides in _CROWD_ORDER_OVERRIDES.items():
            if tag in focus_tag:
                default_order_map.update(overrides)
                break

    for mid in pref_visible:
        if mid in INTEREST_ORDER_BOOST:
            default_order_map[mid] = min(
                default_order_map.get(mid, 999), INTEREST_ORDER_BOOST[mid]
            )

    # 用户明确关注 → 覆盖"无数据自动隐藏"
    rule_hidden -= pref_visible

    if mode == ONBOARDING and prefs_saved:
        # 已答过问卷，引导卡不再展示
        rule_hidden.add("onboarding_preference")

    rule_order = sorted(MODULE_IDS, key=lambda mid: (default_order_map[mid], MODULE_IDS.index(mid)))

    # ---------- 2. 叠加用户定制（存在即覆盖规则）----------
    is_customized = hidden_modules is not None or module_order is not None

    if is_customized:
        user_hidden = {
            mid for mid in (hidden_modules or [])
            if mid in _MODULE_MAP and mid not in LOCKED_MODULE_IDS
        }
        # 模式不适用 + 引导卡"已完成"的隐藏逻辑始终生效，避免引导卡残留在常规态
        hidden = user_hidden | _mode_hidden(mode, signals, pref_visible, prefs_saved)
    else:
        hidden = set(rule_hidden)

    # 锁定模块永不可隐藏
    hidden -= set(LOCKED_MODULE_IDS)

    if is_customized and module_order:
        ordered = [mid for mid in module_order if mid in MODULE_IDS]
        # 补齐（老用户升级后新增的模块追加到末尾，避免模块凭空消失）
        ordered += [mid for mid in rule_order if mid not in ordered]
        final_order = ordered
    else:
        final_order = rule_order

    return {
        "order": final_order,
        "hidden": sorted(hidden),
        "variants": variants,
        "modules": HOME_MODULES,
        "locked": LOCKED_MODULE_IDS,
        "is_customized": is_customized,
        "mode": mode,
        "preferences": {
            "focus": focus,
            "interests": interests,
            "answers": answers,
        },
    }


def _mode_hidden(
    mode: str,
    signals: Dict[str, Any],
    pref_visible: Optional[set] = None,
    prefs_saved: bool = False,
) -> set:
    """与用户定制无关的"结构性隐藏"：模式不适用的模块 + 已完成的引导卡"""

    hidden: set = set()
    for m in HOME_MODULES:
        if mode not in m.get("modes", [NORMAL, ONBOARDING]):
            hidden.add(m["id"])

    if mode == ONBOARDING:
        if signals.get("has_body_data"):
            hidden.add("onboarding_profile")
        if signals.get("has_constitution"):
            hidden.add("onboarding_constitution")
        if signals.get("has_real_pet"):
            hidden.add("onboarding_add_pet")
        if prefs_saved:
            hidden.add("onboarding_preference")
        # 引导态下数据型常规模块始终隐藏（用户手动开启也无效，避免空模块占位）
        hidden |= _ONBOARDING_HIDDEN

    # 问卷里明确关注的模块 → 强制展示
    hidden -= (pref_visible or set())

    return hidden


# ============================================================
# 读写
# ============================================================

def _get_record(db: Session, user_id: int) -> Optional[UserHomeLayout]:
    return db.query(UserHomeLayout).filter(UserHomeLayout.user_id == user_id).first()


def build_layout(db: Session, user_id: int) -> Dict[str, Any]:
    """完整布局：信号 + 用户定制 + 规则推导"""

    signals = collect_signals(db, user_id)
    record = _get_record(db, user_id)

    layout = resolve_layout(
        signals,
        hidden_modules=record.hidden_modules if record else None,
        module_order=record.module_order if record else None,
        preferences=record.preferences if record else None,
    )
    # 记录存在但没有手动定制（隐藏/顺序都为空）→ 视为未定制（仅问卷偏好不算定制）
    if record and not record.hidden_modules and not record.module_order:
        layout["is_customized"] = False
    layout["signals"] = signals
    return layout


def save_layout(
    db: Session,
    user_id: int,
    hidden_modules: Optional[List[str]] = None,
    module_order: Optional[List[str]] = None,
    preferences: Optional[Dict[str, Any]] = None,
    reset: bool = False,
) -> Dict[str, Any]:
    """保存用户布局定制（部分更新语义）

    - hidden_modules=None：不修改已保存的隐藏列表
    - module_order=None：不修改已保存的顺序（用户只切开关时不会冻结默认排序）
    - module_order=[]：清除自定义顺序，恢复按规则的默认顺序
    - preferences=None：不修改引导问卷偏好（focus/interests）
    - reset=True：清除全部定制，回到按画像自动布局
    """

    record = _get_record(db, user_id)

    if reset:
        if record:
            db.delete(record)
            db.commit()
        return build_layout(db, user_id)

    if record is None:
        record = UserHomeLayout(user_id=user_id, hidden_modules=[], module_order=None)
        db.add(record)

    if hidden_modules is not None:
        cleaned_hidden = [
            mid for mid in hidden_modules
            if mid in _MODULE_MAP and mid not in LOCKED_MODULE_IDS
        ]
        record.hidden_modules = list(dict.fromkeys(cleaned_hidden))

    if module_order is not None:
        cleaned_order = [
            mid for mid in module_order if mid in MODULE_IDS
        ]
        record.module_order = list(dict.fromkeys(cleaned_order)) or None

    if preferences is not None:
        answers = {
            k: str(v).strip()
            for k, v in (preferences.get("answers") or {}).items() if v
        }
        # focus：优先由"身体目标倾向"推导，也兼容直接指定
        focus = ANSWER_FOCUS.get(answers.get("goal", ""), "") \
            or str(preferences.get("focus") or "").strip()
        interests: List[str] = []
        for question, mapping in ANSWER_INTERESTS.items():
            interests.extend(mapping.get(answers.get(question, ""), []))
        interests.extend(
            i for i in (preferences.get("interests") or [])
            if i in INTEREST_MODULE_MAP
        )

        record.preferences = {
            "answers": answers,
            "focus": focus if focus in FOCUS_CROWD_TAG else "",
            "interests": list(dict.fromkeys(interests)),
        }
        # 身体目标倾向同步到人群标签，让热量目标与 AI 建议保持一致
        if focus in FOCUS_CROWD_TAG:
            _sync_crowd_tag(db, user_id, FOCUS_CROWD_TAG[focus])

    db.commit()
    return build_layout(db, user_id)


def _sync_crowd_tag(db: Session, user_id: int, crowd_tag: str) -> None:
    """把问卷选择的主要目标写回 UserProfile.crowd_tag"""

    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
        if profile and (profile.crowd_tag or "") != crowd_tag:
            profile.crowd_tag = crowd_tag
    except Exception as e:  # 同步失败不影响布局保存
        logger.warning(f"同步人群标签失败: {e}")
