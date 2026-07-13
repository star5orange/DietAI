"""宠物自定义提示语服务（合规控制）"""
import logging
import re
from typing import Dict, Any, List, Tuple

logger = logging.getLogger(__name__)

# 禁止词汇列表（情感诱导、不合规称呼）
FORBIDDEN_WORDS = [
    "主人", "奴隶", "臣服", "爱恋", "痴迷", "迷恋", "亲爱的", "宝贝", "心肝",
    "老公", "老婆", "男友", "女友", "恋人", "情人", "情侣",
    "我想你", "我爱你", "我好喜欢你", "你是我的",
    "服从", "跪下", "听话", "惩罚", "奖励",
    "小主", "奴家", "臣妾", "本宫", "朕",
    "心爱", "挚爱", "最爱", "唯一", "独占",
]

# 敏感词检测正则模式（情感诱导、拟人化表达）
SENSITIVE_PATTERNS = [
    r"我想.*[爱恋喜欢]",
    r"[你我].*属于",
    r"永远.*在一起",
    r"你的.*[心肝宝贝]",
    r"[亲爱宝].*的",
    r"为你.*[付出牺牲]",
    r"只.*你",
]

# 预设合规提示语模板（用户可参考）
PRESET_MESSAGES = {
    "feed": {
        "normal": "今天按时吃饭了，继续保持哦！",
        "happy": "营养均衡的一餐，健康加分！",
        "motivation": "坚持规律饮食，身体会感谢你～",
    },
    "water": {
        "normal": "今天喝水达标了，皮肤也会水润哦！",
        "motivation": "多喝水，保持活力满满！",
    },
    "exercise": {
        "normal": "今天的运动很棒，继续保持！",
        "motivation": "运动让身体更有活力～",
    },
    "good_habit": {
        "3day": "连续3天坚持了！解锁新动作奖励～",
        "7day": "连续7天达标！解锁新皮肤！",
        "motivation": "坚持就是胜利，加油！",
    },
    "level_up": {
        "normal": "恭喜升级！解锁新装扮～",
        "motivation": "继续努力，解锁更多奖励！",
    },
}

# 场景列表（用户可自定义的场景）
ALLOWED_SCENES = [
    "feed_success",  # 喂食成功
    "water_success",  # 喝水达标
    "good_habit_streak",  # 连续达标
    "level_up",  # 升级
    "motivation",  # 激励（互动时随机触发）
]


def validate_custom_message(message: str) -> Tuple[bool, str]:
    """验证用户自定义提示语是否合规

    Args:
        message: 用户输入的提示语

    Returns:
        (is_valid, error_message)
    """
    if not message or not message.strip():
        return False, "提示语不能为空"

    # 检查长度
    if len(message) > 100:
        return False, "提示语长度不能超过100字"

    # 检查禁止词汇
    for word in FORBIDDEN_WORDS:
        if word in message:
            return False, f"提示语包含不合规词汇：'{word}'"

    # 检查敏感模式
    for pattern in SENSITIVE_PATTERNS:
        if re.search(pattern, message):
            return False, "提示语包含情感诱导或不合规表达"

    # 检查拟人化情感表达（过度拟人）
    if any(kw in message for kw in ["我的心", "我的爱", "我的心意", "我的感情"]):
        return False, "提示语不应包含过度拟人的情感表达"

    # 通过验证
    return True, ""


def sanitize_custom_messages(messages: Dict[str, str]) -> Dict[str, Any]:
    """批量验证和清理自定义提示语

    Args:
        messages: 用户提交的提示语字典 {"scene": "message"}

    Returns:
        {
            "valid_messages": {},  # 合规的提示语
            "invalid_scenes": [],  # 不合规的场景列表
            "error_details": {},  # 每个场景的错误详情
        }
    """
    valid_messages = {}
    invalid_scenes = []
    error_details = {}

    for scene, message in messages.items():
        # 检查场景是否允许
        if scene not in ALLOWED_SCENES:
            invalid_scenes.append(scene)
            error_details[scene] = f"不支持的场景：'{scene}'"
            continue

        # 验证提示语合规性
        is_valid, error_msg = validate_custom_message(message)
        if is_valid:
            # 添加合规后缀（可选）
            valid_messages[scene] = _add_compliant_suffix(message)
        else:
            invalid_scenes.append(scene)
            error_details[scene] = error_msg

    return {
        "valid_messages": valid_messages,
        "invalid_scenes": invalid_scenes,
        "error_details": error_details,
    }


def _add_compliant_suffix(message: str) -> str:
    """为合规提示语添加友好的后缀（可选）

    Args:
        message: 已验证合规的提示语

    Returns:
        添加了合规后缀的提示语
    """
    # 如果提示语已经包含激励性结尾，不重复添加
    if any(suffix in message for suffix in ["加油", "继续", "坚持", "～", "！"]):
        return message

    # 随机添加一个合规后缀
    suffixes = [
        "要坚持哦～",
        "加油！",
        "继续努力！",
        "保持下去～",
    ]
    import random
    return message + " " + random.choice(suffixes)


def get_default_messages() -> Dict[str, str]:
    """获取默认提示语模板（供用户参考）

    Returns:
        默认提示语字典
    """
    # 从预设模板中提取常用的提示语
    defaults = {}
    for scene, messages in PRESET_MESSAGES.items():
        for mood, text in messages.items():
            key = f"{scene}_{mood}"
            defaults[key] = text

    return defaults


def get_message_for_scene(
    custom_messages: Dict[str, str],
    scene: str,
    fallback_to_default: bool = True
) -> str:
    """根据场景获取提示语（优先使用自定义，否则使用默认）

    Args:
        custom_messages: 用户自定义提示语字典
        scene: 场景名称
        fallback_to_default: 是否回退到默认提示语

    Returns:
        提示语文本
    """
    # 优先使用用户自定义
    if custom_messages and scene in custom_messages:
        return custom_messages[scene]

    # 回退到默认提示语
    if fallback_to_default:
        defaults = get_default_messages()
        return defaults.get(scene, "做得很好！继续加油～")

    # 无提示语
    return ""