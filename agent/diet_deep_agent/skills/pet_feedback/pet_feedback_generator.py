"""
宠物反馈文案生成器
根据用户当日饮食/饮水达标情况生成宠物5种mood对应的反馈文案

mood类型：
1. happy（开心）- 达标状态良好
2. normal（正常）- 基本达标
3. hungry（饥饿）- 饮食记录不足
4. anxious（焦虑）- 记录不规律
5. weak（虚弱）- 营养摄入不足

功能：
- 根据达标情况生成mood对应反馈
- 根据连续达标天数生成额外鼓励
- 解锁提示文案
"""

from typing import Dict, List, Optional
from enum import Enum
import random


class PetMood(Enum):
    """宠物心情状态"""
    HAPPY = "happy"  # 开心
    NORMAL = "normal"  # 正常
    HUNGRY = "hungry"  # 饥饿
    ANXIOUS = "anxious"  # 焦虑
    WEAK = "weak"  # 虚弱


class PetFeedbackGenerator:
    """宠物反馈文案生成器"""

    # 各心情对应的反馈文案模板
    FEEDBACK_TEMPLATES = {
        PetMood.HAPPY: [
            "太棒了！你今天的饮食很健康，宠物开心地转圈圈！✨",
            "完美达标！宠物为你感到骄傲，继续保持！🎉",
            "你的坚持让宠物活力满满，它很喜欢你的努力！💪",
            "今天的营养摄入很均衡，宠物笑容满面！😊",
            "饮食达标啦！宠物开心地跳舞庆祝！💃",
            "你做得很棒，宠物已经迫不及待想看到明天的表现了！🌟",
        ],
        PetMood.NORMAL: [
            "今天的饮食还不错，宠物状态正常，继续保持！👍",
            "宠物看起来心情平稳，明天可以做得更好哦！😊",
            "基本达标了，宠物今天过得还算不错！🙂",
            "不错的记录习惯，宠物为你点赞！👏",
            "今天的状态还可以，宠物期待明天更精彩！🌟",
        ],
        PetMood.HUNGRY: [
            "宠物有点饿了，记得按时吃饭哦！😋",
            "你的宠物在提醒你：别忘记今天的三餐！🍽️",
            "今天的饮食记录不太够，宠物有点小饿呢！🤔",
            "宠物肚子咕咕叫了，快去补充能量吧！⚡",
            "今天吃得有点少，宠物期待你更丰富的饮食！🥗",
        ],
        PetMood.ANXIOUS: [
            "宠物有点焦虑，可能是你今天吃得不太规律，明天调整一下吧！📅",
            "宠物期待你更稳定的饮食习惯，它会很支持你的！💪",
            "今天的饮食时间不太规律，宠物有点担心呢！🤨",
            "宠物想提醒你：规律饮食对健康很重要哦！💡",
            "别担心，明天调整一下时间，宠物会很开心的！😊",
        ],
        PetMood.WEAK: [
            "宠物看起来有点虚弱，可能是营养不够，记得补充蛋白质哦！🥚",
            "宠物需要你的照顾，今天的营养摄入可以再丰富一些！🥦",
            "今天的蛋白质摄入偏低，宠物需要营养补充！💪",
            "宠物活力有点不足，多吃点健康食物吧！🥗",
            "营养不够会让宠物虚弱，明天记得吃得更丰富哦！😊",
        ],
    }

    # 连续达标鼓励文案
    STREAK_ENCOURAGEMENTS = {
        3: ["连续达标3天了！宠物为你鼓掌！👏", "3天坚持，宠物开始信任你了！🌟"],
        5: ["连续5天达标！宠物超级开心！🎉", "5天的坚持，宠物已经爱上你了！💕"],
        7: ["连续一周达标！宠物为你骄傲！🏆", "7天不间断，宠物已经把你当成榜样了！✨"],
        10: ["连续10天达标！太厉害了！宠物为你欢呼！🎊", "10天的坚持，宠物已经离不开你了！💖"],
        14: ["连续两周达标！宠物为你点赞！👍👍", "14天的坚持，宠物已经把你看作健康专家了！🌟"],
    }

    # 解锁提示文案
    UNLOCK_MESSAGES = [
        "🎉 你解锁了新装扮！快去看看吧！",
        "✨ 宠物解锁了新动作！它迫不及待想展示给你！",
        "🌟 恭喜！宠物获得新外观，快去宠物详情页看看！",
        "💪 解锁新成就！宠物为你准备了惊喜！",
        "🎊 新解锁！宠物的世界又丰富了一点！",
    ]

    def __init__(self):
        """初始化生成器"""
        pass

    def generate_feedback(
        self,
        mood: str,
        streak_days: int = 0,
        unlocked: bool = False,
        diet_completion_rate: Optional[float] = None,
        water_completion_rate: Optional[float] = None,
        custom_context: Optional[Dict] = None
    ) -> Dict:
        """
        生成宠物反馈文案

        Args:
            mood: 宠物心情（happy/normal/hungry/anxious/weak）
            streak_days: 连续达标天数
            unlocked: 是否有解锁
            diet_completion_rate: 饮食达标率
            water_completion_rate: 饮水达标率
            custom_context: 自定义上下文

        Returns:
            Dict: 反馈文案和相关信息
        """
        # 解析心情类型
        try:
            mood_enum = PetMood(mood)
        except ValueError:
            mood_enum = PetMood.NORMAL

        # 选择基础反馈文案
        templates = self.FEEDBACK_TEMPLATES[mood_enum]
        base_feedback = random.choice(templates)

        # 构建完整反馈
        feedback_parts = [base_feedback]

        # 添加连续达标鼓励
        streak_encouragement = self._get_streak_encouragement(streak_days)
        if streak_encouragement:
            feedback_parts.append(streak_encouragement)

        # 添加解锁提示
        unlock_message = self._get_unlock_message(unlocked)
        if unlock_message:
            feedback_parts.append(unlock_message)

        # 添加具体达标信息
        completion_info = self._build_completion_info(
            diet_completion_rate, water_completion_rate
        )
        if completion_info:
            feedback_parts.append(completion_info)

        # 组合完整文案
        full_feedback = "\n".join(feedback_parts)

        return {
            "success": True,
            "mood": mood,
            "feedback_text": full_feedback,
            "streak_days": streak_days,
            "unlocked": unlocked,
            "encouragement_level": self._calculate_encouragement_level(
                mood_enum, streak_days
            ),
        }

    def _get_streak_encouragement(self, streak_days: int) -> Optional[str]:
        """
        获取连续达标鼓励文案

        Args:
            streak_days: 连续达标天数

        Returns:
            Optional[str]: 鼓励文案
        """
        if streak_days < 3:
            return None

        # 找到最接近的里程碑
        milestones = sorted(self.STREAK_ENCOURAGEMENTS.keys(), reverse=True)
        for milestone in milestones:
            if streak_days >= milestone:
                return random.choice(self.STREAK_ENCOURAGEMENTS[milestone])

        return None

    def _get_unlock_message(self, unlocked: bool) -> Optional[str]:
        """
        获取解锁提示文案

        Args:
            unlocked: 是否有解锁

        Returns:
            Optional[str]: 解锁文案
        """
        if not unlocked:
            return None

        return random.choice(self.UNLOCK_MESSAGES)

    def _build_completion_info(
        self,
        diet_completion_rate: Optional[float],
        water_completion_rate: Optional[float]
    ) -> Optional[str]:
        """
        构建达标信息提示

        Args:
            diet_completion_rate: 饮食达标率
            water_completion_rate: 饮水达标率

        Returns:
            Optional[str]: 达标信息
        """
        if not diet_completion_rate and not water_completion_rate:
            return None

        parts = []

        if diet_completion_rate:
            if diet_completion_rate >= 100:
                parts.append("饮食满分！")
            elif diet_completion_rate >= 80:
                parts.append(f"饮食达标率{diet_completion_rate:.0f}%，很棒！")
            else:
                parts.append(f"饮食达标率{diet_completion_rate:.0f}%，可以再努力！")

        if water_completion_rate:
            if water_completion_rate >= 100:
                parts.append("饮水满分！")
            elif water_completion_rate >= 80:
                parts.append(f"饮水达标率{water_completion_rate:.0f}%，不错！")
            else:
                parts.append(f"饮水达标率{water_completion_rate:.0f}%，记得多喝水！")

        return " ".join(parts)

    def _calculate_encouragement_level(
        self,
        mood: PetMood,
        streak_days: int
    ) -> str:
        """
        计算鼓励等级

        Args:
            mood: 宠物心情
            streak_days: 连续达标天数

        Returns:
            str: 鼓励等级（high/medium/low）
        """
        if mood == PetMood.HAPPY and streak_days >= 7:
            return "high"
        elif mood == PetMood.HAPPY and streak_days >= 3:
            return "medium"
        elif mood in [PetMood.NORMAL, PetMood.HAPPY]:
            return "medium"
        else:
            return "low"

    def generate_mood_based_reminder(self, mood: str) -> str:
        """
        根据心情生成提醒文案

        Args:
            mood: 宠物心情

        Returns:
            str: 提醒文案
        """
        try:
            mood_enum = PetMood(mood)
        except ValueError:
            mood_enum = PetMood.NORMAL

        reminders = {
            PetMood.HAPPY: "继续保持今天的良好状态，宠物很喜欢！",
            PetMood.NORMAL: "明天可以做得更好，宠物期待你的进步！",
            PetMood.HUNGRY: "记得按时吃饭，宠物不想饿肚子哦！",
            PetMood.ANXIOUS: "规律饮食很重要，宠物在等你调整！",
            PetMood.WEAK: "营养均衡对宠物很重要，明天记得吃得更丰富！",
        }

        return reminders[mood_enum]

    def get_available_moods(self) -> List[str]:
        """
        获取所有可用的心情类型

        Returns:
            List[str]: 心情类型列表
        """
        return [mood.value for mood in PetMood]


# 导出单例实例
pet_feedback_generator = PetFeedbackGenerator()


# 便捷函数
def generate_feedback(
    mood: str,
    streak_days: int = 0,
    unlocked: bool = False,
    diet_completion_rate: Optional[float] = None,
    water_completion_rate: Optional[float] = None,
    custom_context: Optional[Dict] = None
) -> Dict:
    """便捷函数：生成宠物反馈"""
    return pet_feedback_generator.generate_feedback(
        mood, streak_days, unlocked, diet_completion_rate, water_completion_rate, custom_context
    )


def generate_mood_based_reminder(mood: str) -> str:
    """便捷函数：生成心情提醒"""
    return pet_feedback_generator.generate_mood_based_reminder(mood)


if __name__ == "__main__":
    # 测试代码
    generator = PetFeedbackGenerator()

    # 测试各心情反馈
    print("=" * 60)
    print("测试：生成宠物反馈文案")
    print("=" * 60)

    for mood in ["happy", "normal", "hungry", "anxious", "weak"]:
        print(f"\n心情: {mood}")
        feedback = generator.generate_feedback(
            mood=mood,
            streak_days=5,
            unlocked=True,
            diet_completion_rate=95.0,
            water_completion_rate=100.0
        )
        print(f"反馈文案: {feedback['feedback_text']}")
        print(f"鼓励等级: {feedback['encouragement_level']}")

    # 测试连续达标鼓励
    print("\n" + "=" * 60)
    print("测试：连续达标鼓励")
    print("=" * 60)
    for streak in [3, 5, 7, 10, 14]:
        feedback = generator.generate_feedback(
            mood="happy",
            streak_days=streak
        )
        print(f"\n连续{streak}天: {feedback['feedback_text']}")

    # 测试心情提醒
    print("\n" + "=" * 60)
    print("测试：心情提醒")
    print("=" * 60)
    for mood in generator.get_available_moods():
        reminder = generator.generate_mood_based_reminder(mood)
        print(f"{mood}: {reminder}")