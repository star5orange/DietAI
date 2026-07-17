"""
宠物反馈文案生成器

根据用户当日饮食/饮水达标情况生成宠物反馈文案，
支持 5 种 mood 状态的正向/提醒文案。

Milestone 2 P2 模块
"""

from typing import Optional
from datetime import datetime
import random


class PetMood(str):
    """宠物心情状态"""
    NORMAL = "normal"  # 正常
    HAPPY = "happy"  # 开心
    HUNGRY = "hungry"  # 饥饿
    ANXIOUS = "anxious"  # 焦虑
    WEAK = "weak"  # 虚弱


# 各心情的反馈文案模板
PET_FEEDBACK_TEMPLATES = {
    PetMood.HAPPY: [
        "太棒了！你今天的饮食很健康，宠物开心地转圈圈！🎉",
        "完美达标！宠物为你感到骄傲，继续加油！💪",
        "你的坚持让宠物活力满满，它很喜欢你的努力！✨",
        "今天的饮食记录很完整，宠物在为你欢呼！👏",
        "营养均衡的一天！宠物今天心情超级好！🌟",
    ],
    
    PetMood.NORMAL: [
        "今天的饮食还不错，宠物状态正常，继续保持！😊",
        "宠物看起来心情平稳，明天可以做得更好哦！📈",
        "还不错的一天，宠物在期待你明天的表现！🎯",
        "今天的数据记录完整，宠物状态稳定！📊",
    ],
    
    PetMood.HUNGRY: [
        "宠物有点饿了，记得按时吃饭哦！🍽️",
        "你的宠物在提醒你：别忘记今天的三餐！⏰",
        "今天的饮食记录还不够完整，宠物在等你喂它！🥣",
        "宠物肚子咕咕叫了，快去记录你的美食吧！🍳",
    ],
    
    PetMood.ANXIOUS: [
        "宠物有点焦虑，可能是你今天吃得不太规律，明天调整一下吧！📅",
        "宠物期待你更稳定的饮食习惯，它会很支持你的！💪",
        "今天的饮食时间有点不规律，宠物有点担心你！😟",
        "不规律的饮食让宠物有点不安，明天试试按时吃饭？🌅",
    ],
    
    PetMood.WEAK: [
        "宠物看起来有点虚弱，可能是营养不够，记得补充蛋白质哦！🥚",
        "宠物需要你的照顾，今天的营养摄入可以再丰富一些！🥗",
        "今天的热量摄入偏低，宠物希望你多吃一点！🍞",
        "营养不足会让宠物担心，明天要好好吃饭哦！🥦",
    ]
}

# 连续达标里程碑文案
STREAK_MILESTONES = {
    3: "连续 3 天达标！宠物解锁了新动作！🎊",
    5: "连续 5 天达标！宠物变得更开心了！🌟",
    7: "连续 7 天达标！一周完美坚持，太厉害了！🏆",
    14: "连续 14 天达标！两周的坚持，宠物为你骄傲！👑",
    30: "连续 30 天达标！一个月的完美记录！🎖️",
}

# 新解锁提示
UNLOCK_FEEDBACK = [
    "🎉 你解锁了新装扮！快去看看吧！",
    "✨ 宠物获得了新外观！去详情页查看！",
    "🎁 恭喜解锁新内容！宠物很开心！",
]


def generate_feedback(
    mood: str,
    streak_days: int = 0,
    unlocked: bool = False,
    food_progress: float = 0.0,
    water_progress: float = 0.0
) -> dict:
    """
    生成宠物反馈
    
    Args:
        mood: 宠物心情状态
        streak_days: 连续达标天数
        unlocked: 是否有新解锁
        food_progress: 饮食达标率 (0.0-1.0)
        water_progress: 饮水达标率 (0.0-1.0)
        
    Returns:
        包含反馈信息的字典
    """
    templates = PET_FEEDBACK_TEMPLATES.get(mood, PET_FEEDBACK_TEMPLATES[PetMood.NORMAL])
    feedback = random.choice(templates)
    
    # 添加解锁提示
    if unlocked:
        unlock_msg = random.choice(UNLOCK_FEEDBACK)
        feedback += f"\n{unlock_msg}"
    
    # 添加连续达标里程碑
    if streak_days > 0:
        milestone_msg = STREAK_MILESTONES.get(streak_days)
        if milestone_msg:
            feedback += f"\n{milestone_msg}"
        elif streak_days > 30:
            feedback += f"\n连续 {streak_days} 天达标，太厉害了！🔥"
    
    # 构建详细反馈
    details = []
    if food_progress > 0:
        details.append(f"饮食达标率: {(food_progress * 100):.0f}%")
    if water_progress > 0:
        details.append(f"饮水达标率: {(water_progress * 100):.0f}%")
    
    return {
        "success": True,
        "mood": mood,
        "feedback": feedback,
        "streak_days": streak_days,
        "has_new_unlock": unlocked,
        "details": details,
        "generated_at": datetime.now().isoformat()
    }


def calculate_mood(
    food_progress: float,
    water_progress: float,
    streak_days: int = 0,
    last_meal_hours: Optional[int] = None
) -> str:
    """
    根据达标情况计算宠物心情
    
    Args:
        food_progress: 饮食达标率 (0.0-1.0)
        water_progress: 饮水达标率 (0.0-1.0)
        streak_days: 连续达标天数
        last_meal_hours: 距离上次用餐小时数
        
    Returns:
        心情状态字符串
    """
    # 综合达标率
    avg_progress = (food_progress + water_progress) / 2
    
    # 如果很久没吃饭，显示饥饿
    if last_meal_hours and last_meal_hours > 6:
        return PetMood.HUNGRY
    
    # 根据达标率判断
    if avg_progress >= 0.9:
        return PetMood.HAPPY
    elif avg_progress >= 0.6:
        return PetMood.NORMAL
    elif avg_progress >= 0.4:
        # 判断是不足还是过量
        if food_progress < 0.5:
            return PetMood.WEAK
        else:
            return PetMood.ANXIOUS
    else:
        return PetMood.WEAK


def get_mood_display_name(mood: str) -> str:
    """获取心情的中文显示名称"""
    mood_names = {
        "happy": "开心",
        "normal": "正常",
        "hungry": "饥饿",
        "anxious": "焦虑",
        "weak": "虚弱"
    }
    return mood_names.get(mood, "正常")


def get_mood_emoji(mood: str) -> str:
    """获取心情对应的 emoji"""
    mood_emojis = {
        "happy": "😄",
        "normal": "😊",
        "hungry": "🍔",
        "anxious": "😟",
        "weak": "😔"
    }
    return mood_emojis.get(mood, "😊")


def get_mood_color(mood: str) -> str:
    """获取心情对应的颜色（十六进制）"""
    mood_colors = {
        "happy": "#4CAF50",  # 绿色
        "normal": "#2196F3",  # 蓝色
        "hungry": "#FF9800",  # 橙色
        "anxious": "#9C27B0",  # 紫色
        "weak": "#F44336"  # 红色
    }
    return mood_colors.get(mood, "#2196F3")