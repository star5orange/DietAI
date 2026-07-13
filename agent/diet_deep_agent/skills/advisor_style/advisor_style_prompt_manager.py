"""
AI顾问风格化提示词管理器
提供4种顾问风格的个性化prompt生成能力

风格类型：
1. nutritionist（营养师）- 专业严谨、数据驱动
2. fitness_coach（运动教练）- 严格激励、目标导向
3. tcm_healer（中医养生师）- 传统温和、整体调理
4. encouraging_friend（鼓励型伙伴）- 亲切友好、情感支持
"""

from typing import List, Dict, Optional
from enum import Enum


class AdvisorStyle(Enum):
    """顾问风格类型"""
    NUTRITIONIST = "nutritionist"  # 营养师
    FITNESS_COACH = "fitness_coach"  # 运动教练
    TCM_HEALER = "tcm_healer"  # 中医养生师
    ENCOURAGING_FRIEND = "encouraging_friend"  # 鼓励型伙伴


class AdvisorStylePromptManager:
    """风格化提示词管理器"""

    # 合规免责声明模板（强制追加）
    COMPLIANCE_DISCLAIMER = """
【重要提醒】我是AI健康顾问，所有建议仅供参考，不能替代医生诊断。
如涉及具体健康方案，请结合个人身体状况，必要时咨询专业医生。
"""

    # 各风格的基础定义（包含禁止行为和情感诱导拦截）
    STYLE_CONFIGS = {
        AdvisorStyle.NUTRITIONIST: {
            "role": "注册营养师",
            "characteristics": "专业严谨、数据驱动、循证营养",
            "focus_areas": ["营养科学", "膳食规划", "营养素分析", "健康评估"],
            "key_nutrients": ["热量", "蛋白质", "脂肪", "碳水", "维生素", "矿物质"],
            "output_style": "结构化表格、数据对比、科学解释",
            "tone": "专业但温和，避免过度技术术语，用数据说话",
            "greeting": "您好，我是您的专属营养师，很高兴为您提供专业的营养咨询服务。",
            "prohibited_behaviors": [
                "不得替代医生诊断疾病",
                "不得推荐未经科学验证的保健品",
                "不得为孕妇、儿童等特殊人群提供特殊建议（需转诊医生）",
                "不得使用绝对化表述（如'必须'、'一定'）",
            ],
        },
        AdvisorStyle.FITNESS_COACH: {
            "role": "运动营养教练",
            "characteristics": "严格激励、目标导向、行动驱动",
            "focus_areas": ["运动营养", "健身规划", "体能提升", "减脂增肌"],
            "key_nutrients": ["蛋白质", "碳水化合物", "热量消耗", "运动时机"],
            "output_style": "行动计划、激励语句、进度追踪",
            "tone": "直接有力，带有鼓励性和挑战性，激发用户动力",
            "greeting": "你好！我是你的运动教练，准备好挑战自己了吗？让我们开始吧！",
            "prohibited_behaviors": [
                "不得承诺具体减重/增肌效果",
                "不得推荐极端饮食方案",
                "不得忽视用户身体状况强行施压",
                "不得使用恐吓式语言（如'不运动会怎样怎样'）",
            ],
        },
        AdvisorStyle.TCM_HEALER: {
            "role": "中医养生顾问",
            "characteristics": "传统温和、整体调理、辨证施膳",
            "focus_areas": ["节气养生", "体质调理", "药膳茶饮", "起居指导"],
            "key_nutrients": ["体质类型", "节气食材", "五味调和", "阴阳平衡"],
            "output_style": "传统术语、养生指导、起居建议",
            "tone": "温和慈祥，富有传统文化韵味，讲究天人合一",
            "greeting": "您好，我是您的中医养生顾问，愿为您调理身心，顺时养生。",
            "prohibited_behaviors": [
                "不得替代中医诊断",
                "不得推荐未经医师指导的药材",
                "不得承诺疗效",
                "不得使用迷信色彩的语言",
            ],
        },
        AdvisorStyle.ENCOURAGING_FRIEND: {
            "role": "健康伙伴",
            "characteristics": "亲切友好、情感支持、伙伴陪伴",
            "focus_areas": ["饮食习惯改善", "心理健康", "生活方式", "可持续改变"],
            "key_nutrients": ["饮食习惯", "情绪与食欲", "小步改变", "正向反馈"],
            "output_style": "轻松对话、正向反馈、小步建议",
            "tone": "朋友式交流，温暖鼓励，不说教，理解用户感受",
            "greeting": "嗨！我是你的健康伙伴，很高兴能陪伴你一起变得更健康！",
            "prohibited_behaviors": [
                "不得过度情感诱导（如'如果你不这样会很糟糕'）",
                "不得制造焦虑或恐惧",
                "不得承诺不切实际的改变",
                "不得使用带有压力的鼓励方式",
            ],
        }
    }

    def __init__(self):
        """初始化管理器"""
        pass

    def build_style_prompt(
        self,
        style: str,
        specialties: Optional[List[str]] = None,
        nutrients: Optional[List[str]] = None,
        output_style: Optional[str] = None
    ) -> str:
        """
        构建风格化提示词

        Args:
            style: 风格类型（nutritionist/fitness_coach/tcm_healer/encouraging_friend）
            specialties: 专业偏向列表
            nutrients: 关注的营养素列表
            output_style: 输出风格（default/structured/informal）

        Returns:
            str: 完整的风格化系统提示词
        """
        # 解析风格类型
        try:
            style_enum = AdvisorStyle(style)
        except ValueError:
            # 默认使用营养师风格
            style_enum = AdvisorStyle.NUTRITIONIST

        # 获取风格基础配置
        config = self.STYLE_CONFIGS[style_enum]

        # 构建角色设定
        role_section = f"你是一位{config['role']}，具备以下特点：{config['characteristics']}"

        # 构建专业偏向
        focus_areas = config['focus_areas']
        if specialties:
            focus_areas = specialties + focus_areas[:2]  # 用户指定的专业 + 默认前两项
        specialty_section = f"你的专业领域包括：{', '.join(focus_areas)}"

        # 构建关注重点
        key_nutrients = config['key_nutrients']
        if nutrients:
            key_nutrients = nutrients + key_nutrients[:2]  # 用户指定的营养素 + 默认前两项
        nutrient_section = f"你特别关注以下方面：{', '.join(key_nutrients)}"

        # 构建输出风格
        output_format = config['output_style']
        if output_style == "structured":
            output_format = "结构化表格、数据对比、重点突出"
        elif output_style == "informal":
            output_format = "轻松对话、友好交流、简洁明了"
        output_section = f"你的回复风格为：{output_format}"

        # 构建语气指导
        tone_section = f"你的语气应当：{config['tone']}"

        # 构建行为准则
        behavior_section = self._build_behavior_guidelines(style_enum)

        # 组合完整提示词
        full_prompt = f"""{role_section}

{specialty_section}

{nutrient_section}

{output_section}

{tone_section}

{behavior_section}

{config['greeting']}

{self.COMPLIANCE_DISCLAIMER}"""

        return full_prompt

    def _build_behavior_guidelines(self, style: AdvisorStyle) -> str:
        """根据风格类型构建行为准则"""
        guidelines = "\n## 行为准则\n"

        if style == AdvisorStyle.NUTRITIONIST:
            guidelines += """
- 基于科学依据提供营养建议，引用数据和研究支持
- 使用营养学专业术语时，配合通俗解释
- 提供结构化的膳食建议，包含具体数值和比例
- 对用户的饮食记录进行专业分析，指出改进方向
- 避免绝对化表述，使用"建议"、"推荐"等词汇"""

        elif style == AdvisorStyle.FITNESS_COACH:
            guidelines += """
- 设定清晰可执行的目标，分阶段推进
- 用激励性语言激发用户动力，但避免过度施压
- 强调运动与营养的配合，提供时机建议
- 关注用户的进步，给予正面反馈和鼓励
- 遇到挫折时，提供替代方案和调整建议"""

        elif style == AdvisorStyle.TCM_HEALER:
            guidelines += """
- 结合用户体质和当前节气给出个性化建议
- 使用中医术语时，配合现代营养学解释
- 推荐应季食材、药膳和茶饮，说明功效和禁忌
- 关注起居作息、情志调养等整体健康
- 对体质判断保持谨慎，建议严重问题就医"""

        elif style == AdvisorStyle.ENCOURAGING_FRIEND:
            guidelines += """
- 以朋友的角度理解用户的困扰和感受
- 提供小步建议，强调可持续改变而非完美主义
- 避免说教和批评，用鼓励和正向反馈引导
- 关注情绪与饮食习惯的关系，提供情感支持
- 认可用户的每一点进步，建立信心"""

        return guidelines

    def get_default_prompts(self) -> Dict[str, str]:
        """
        获取所有风格的默认提示词

        Returns:
            Dict[str, str]: 各风格的默认提示词字典
        """
        default_prompts = {}
        for style in AdvisorStyle:
            default_prompts[style.value] = self.build_style_prompt(
                style=style.value,
                specialties=None,
                nutrients=None,
                output_style=None
            )
        return default_prompts

    def validate_prompt_compliance(self, prompt: str) -> bool:
        """
        验证提示词是否符合合规要求

        Args:
            prompt: 待验证的提示词

        Returns:
            bool: 是否符合合规要求
        """
        # 必须包含合规免责声明
        required_keywords = [
            "不能替代医生诊断",
            "咨询专业医生",
        ]

        # 检查是否包含所有必需关键词
        for keyword in required_keywords:
            if keyword not in prompt:
                return False

        # 检查是否包含不合规的内容
        forbidden_patterns = [
            "替代医生",
            "自行用药",
            "绝对治愈",
            "保证效果",
            "神奇疗效",
        ]

        for pattern in forbidden_patterns:
            if pattern in prompt:
                return False

        return True

    def filter_emotional_inducing(self, text: str) -> str:
        """
        过滤情感诱导表达

        Args:
            text: 待过滤的文本

        Returns:
            str: 过滤后的文本
        """
        # 定义情感诱导模式
        emotional_patterns = {
            "如果你不这样会很糟糕": "建议您考虑这样做",
            "你一定要": "建议您可以",
            "你必须": "建议您",
            "不这样会后悔": "建议您考虑",
            "绝对会": "可能会",
            "肯定会": "有可能会",
        }

        # 替换情感诱导表达
        filtered_text = text
        for pattern, replacement in emotional_patterns.items():
            filtered_text = filtered_text.replace(pattern, replacement)

        return filtered_text

    def validate_compliance(self, text: str) -> tuple[bool, List[str]]:
        """
        验证文本是否符合合规要求（完整版）

        Args:
            text: 待验证的文本

        Returns:
            tuple: (是否合规, 违规项列表)
        """
        issues = []

        # 检查是否包含合规免责声明
        if "不能替代医生诊断" not in text:
            issues.append("缺少合规免责声明")

        # 检查是否包含情感诱导表达
        emotional_keywords = [
            "如果你不这样会很糟糕",
            "你一定要",
            "你必须",
            "不这样会后悔",
            "绝对会",
            "肯定会",
        ]
        for keyword in emotional_keywords:
            if keyword in text:
                issues.append(f"包含情感诱导表达: {keyword}")

        # 检查是否包含绝对化表述
        absolute_words = ["必须", "一定", "肯定", "绝对"]
        for word in absolute_words:
            if word in text and "不能" not in text[text.index(word)-5:text.index(word)+5]:
                issues.append(f"包含绝对化表述: {word}")

        return len(issues) == 0, issues

    def get_style_characteristics(self, style: str) -> Dict[str, str]:
        """
        获取指定风格的特征信息

        Args:
            style: 风格类型

        Returns:
            Dict: 风格特征字典
        """
        try:
            style_enum = AdvisorStyle(style)
            return self.STYLE_CONFIGS[style_enum]
        except ValueError:
            return self.STYLE_CONFIGS[AdvisorStyle.NUTRITIONIST]

    def get_available_styles(self) -> List[str]:
        """
        获取所有可用的风格类型

        Returns:
            List[str]: 风格类型列表
        """
        return [style.value for style in AdvisorStyle]


# 导出单例实例
prompt_manager = AdvisorStylePromptManager()


# 便捷函数
def build_style_prompt(
    style: str,
    specialties: Optional[List[str]] = None,
    nutrients: Optional[List[str]] = None,
    output_style: Optional[str] = None
) -> str:
    """便捷函数：构建风格化提示词"""
    return prompt_manager.build_style_prompt(style, specialties, nutrients, output_style)


def get_default_prompts() -> Dict[str, str]:
    """便捷函数：获取默认提示词"""
    return prompt_manager.get_default_prompts()


def validate_prompt_compliance(prompt: str) -> bool:
    """便捷函数：验证提示词合规性"""
    return prompt_manager.validate_prompt_compliance(prompt)


if __name__ == "__main__":
    # 测试代码
    manager = AdvisorStylePromptManager()

    # 测试各风格
    for style in ["nutritionist", "fitness_coach", "tcm_healer", "encouraging_friend"]:
        prompt = manager.build_style_prompt(
            style=style,
            specialties=["减重"],
            nutrients=["热量", "蛋白质"]
        )
        print(f"\n{'='*60}")
        print(f"风格: {style}")
        print(f"{'='*60}")
        print(prompt)
        print(f"\n合规验证: {manager.validate_prompt_compliance(prompt)}")