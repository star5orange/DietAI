"""
轻断食/辟谷顾问技能
提供科学的轻断食计划生成、禁忌筛查、打卡反馈、复食指导、风险预警

核心功能：
1. 断食计划生成（16:8、5:2、基础辟谷）
2. 禁忌人群筛查
3. 打卡反馈与风险预警
4. 复食指导方案
5. 强制合规免责声明

安全要求：
- 禁忌人群提示不可关闭
- 不适停止提示强制包含
- 所有输出必须包含免责声明
"""

from typing import Dict, List, Optional, Tuple
from enum import Enum
import json
from datetime import datetime, timedelta


class FastingPlanType(Enum):
    """断食计划类型"""
    SIXTEEN_EIGHT = "16_8"  # 16:8间歇性断食
    FIVE_TWO = "5_2"  # 5:2轻断食
    BASIC_FASTING = "basic_fasting"  # 基础辟谷引导


class FastingPhase(Enum):
    """断食阶段"""
    PREPARATION = "preparation"  # 准备阶段
    ACTIVE = "active"  # 活跃阶段
    REFEED = "refeed"  # 复食阶段
    COMPLETED = "completed"  # 完成阶段


class ContraindicationReason(Enum):
    """禁忌人群原因"""
    PREGNANT = "pregnant"  # 孕妇
    BREASTFEEDING = "breastfeeding"  # 哺乳期
    MINOR = "minor"  # 未成年人
    DIABETES = "diabetes"  # 糖尿病患者
    EATING_DISORDER = "eating_disorder"  # 进食障碍
    LOW_BMI = "low_bmi"  # BMI过低
    SEVERE_DISEASE = "severe_disease"  # 严重疾病


class FastingAdvisorSkill:
    """轻断食顾问技能"""

    # 强制免责声明（不可关闭）
    MANDATORY_DISCLAIMER = """
【重要声明】
本轻断食建议仅供参考，不能替代医生诊断。
每个人的身体状况不同，断食可能存在风险。
以下人群严禁断食：孕妇、哺乳期女性、未成年人、糖尿病患者、进食障碍患者、BMI<18.5者。
如有任何不适症状（头晕、心悸、低血糖等），请立即停止断食并就医。
"""

    # 禁忌人群列表
    CONTRAINDICATION_GROUPS = [
        ContraindicationReason.PREGNANT,
        ContraindicationReason.BREASTFEEDING,
        ContraindicationReason.MINOR,
        ContraindicationReason.DIABETES,
        ContraindicationReason.EATING_DISORDER,
        ContraindicationReason.LOW_BMI,
    ]

    # 风险症状列表
    WARNING_SYMPTOMS = [
        "头晕", "乏力", "心悸", "低血糖", "恶心", "失眠",
        "情绪波动", "注意力下降", "胃部不适", "脱水"
    ]

    # 断食模式配置
    FASTING_CONFIGS = {
        FastingPlanType.SIXTEEN_EIGHT: {
            "name": "16:8间歇性断食",
            "description": "每天16小时断食，8小时进食窗口",
            "eating_window_hours": 8,
            "fasting_hours": 16,
            "calorie_recommendation": "进食窗口内正常饮食",
            "difficulty": "中等",
            "suitable_for": ["减脂", "健康维持", "代谢改善"],
        },
        FastingPlanType.FIVE_TWO: {
            "name": "5:2轻断食",
            "description": "每周5天正常饮食，2天低热量（500-600kcal）",
            "fasting_days_per_week": 2,
            "fasting_day_calories": "500-600",
            "difficulty": "较难",
            "suitable_for": ["减脂", "体重控制"],
        },
        FastingPlanType.BASIC_FASTING: {
            "name": "基础辟谷引导",
            "description": "循序渐进的基础辟谷流程",
            "phases": ["准备期", "适应期", "活跃期", "复食期"],
            "max_duration_days": 7,
            "difficulty": "高难度",
            "suitable_for": ["养生", "深度净化"],
        },
    }

    def __init__(self):
        """初始化技能"""
        pass

    def generate_fasting_plan(
        self,
        plan_type: str,
        target_weight: Optional[float] = None,
        current_weight: Optional[float] = None,
        health_assessment: Optional[Dict] = None,
        duration_days: Optional[int] = None
    ) -> Dict:
        """
        生成断食计划

        Args:
            plan_type: 计划类型（16_8/5_2/basic_fasting）
            target_weight: 目标体重
            current_weight: 当前体重
            health_assessment: 健康评估数据
            duration_days: 计划天数

        Returns:
            Dict: 计划详情或禁忌提示
        """
        # 1. 禁忌人群筛查
        contraindication_result = self._check_contraindications(health_assessment)
        if not contraindication_result["safe"]:
            return {
                "success": False,
                "error": "DISABLED_FOR_USER",
                "message": contraindication_result["reason"],
                "contraindications": contraindication_result["contraindications"],
                "advice": "请选择其他健康的减重方式，如均衡饮食、适量运动等。",
                "disclaimer": self.MANDATORY_DISCLAIMER,
            }

        # 2. 解析计划类型
        try:
            plan_enum = FastingPlanType(plan_type)
        except ValueError:
            return {
                "success": False,
                "error": "INVALID_PLAN_TYPE",
                "message": f"无效的断食类型: {plan_type}",
            }

        # 3. 获取计划配置
        config = self.FASTING_CONFIGS[plan_enum]

        # 4. 生成详细计划
        plan_details = {
            "success": True,
            "plan_type": plan_type,
            "plan_name": config["name"],
            "description": config["description"],
            "difficulty": config["difficulty"],
            "suitable_for": config["suitable_for"],
        }

        # 5. 根据不同类型生成具体方案
        if plan_enum == FastingPlanType.SIXTEEN_EIGHT:
            plan_details.update(self._generate_16_8_plan(
                target_weight, current_weight, duration_days
            ))
        elif plan_enum == FastingPlanType.FIVE_TWO:
            plan_details.update(self._generate_5_2_plan(
                target_weight, current_weight, duration_days
            ))
        elif plan_enum == FastingPlanType.BASIC_FASTING:
            plan_details.update(self._generate_basic_fasting_plan(
                target_weight, current_weight, health_assessment, duration_days
            ))

        # 6. 添加强制警告和免责声明
        plan_details.update({
            "warnings": self._generate_warnings(plan_enum),
            "disclaimer": self.MANDATORY_DISCLAIMER,
            "stop_conditions": "如出现头晕、心悸、低血糖、严重乏力等不适症状，请立即停止断食并就医。",
        })

        return plan_details

    def _check_contraindications(self, health_assessment: Optional[Dict]) -> Dict:
        """
        检查禁忌人群

        Args:
            health_assessment: 健康评估数据

        Returns:
            Dict: 检查结果
        """
        if not health_assessment:
            return {"safe": True, "contraindications": [], "reason": ""}

        contraindications = []

        # 检查BMI
        bmi = health_assessment.get("bmi")
        if bmi and bmi < 18.5:
            contraindications.append({
                "reason": ContraindicationReason.LOW_BMI.value,
                "description": f"BMI过低（{bmi}），不建议断食",
            })

        # 检查禁忌人群
        if health_assessment.get("is_pregnant"):
            contraindications.append({
                "reason": ContraindicationReason.PREGNANT.value,
                "description": "孕妇严禁断食",
            })

        if health_assessment.get("is_breastfeeding"):
            contraindications.append({
                "reason": ContraindicationReason.BREASTFEEDING.value,
                "description": "哺乳期女性严禁断食",
            })

        if health_assessment.get("is_minor"):
            contraindications.append({
                "reason": ContraindicationReason.MINOR.value,
                "description": "未成年人严禁断食",
            })

        if health_assessment.get("has_diabetes"):
            contraindications.append({
                "reason": ContraindicationReason.DIABETES.value,
                "description": "糖尿病患者严禁断食",
            })

        if health_assessment.get("has_eating_disorder"):
            contraindications.append({
                "reason": ContraindicationReason.EATING_DISORDER.value,
                "description": "进食障碍患者严禁断食",
            })

        if health_assessment.get("has_severe_disease"):
            contraindications.append({
                "reason": ContraindicationReason.SEVERE_DISEASE.value,
                "description": "严重疾病患者请遵医嘱",
            })

        if contraindications:
            reason_text = "\n".join([c["description"] for c in contraindications])
            return {
                "safe": False,
                "contraindications": contraindications,
                "reason": f"您属于禁忌人群，不建议启用断食：\n{reason_text}",
            }

        return {"safe": True, "contraindications": [], "reason": ""}

    def _generate_16_8_plan(
        self,
        target_weight: Optional[float],
        current_weight: Optional[float],
        duration_days: Optional[int]
    ) -> Dict:
        """生成16:8断食计划"""
        duration = duration_days or 30

        plan = {
            "eating_window": "08:00-16:00",
            "eating_window_start": "08:00",
            "eating_window_end": "16:00",
            "duration_days": duration,
            "daily_schedule": {
                "morning": "08:00-10:00 早餐",
                "noon": "12:00-14:00 午餐",
                "afternoon": "15:00-16:00 下午加餐（可选）",
            },
            "meal_suggestions": [
                "早餐：高蛋白+全谷物（如鸡蛋+燕麦）",
                "午餐：均衡营养（蛋白质+蔬菜+少量碳水）",
                "下午加餐：坚果或水果",
            ],
            "hydration_reminder": "断食期间保持充足饮水（每天2-3L）",
        }

        if target_weight and current_weight:
            weight_diff = current_weight - target_weight
            plan["weight_goal"] = {
                "target": target_weight,
                "current": current_weight,
                "to_loss": weight_diff,
                "estimated_rate": "每周约0.5-1kg",
            }

        return plan

    def _generate_5_2_plan(
        self,
        target_weight: Optional[float],
        current_weight: Optional[float],
        duration_days: Optional[int]
    ) -> Dict:
        """生成5:2断食计划"""
        duration = duration_days or 60  # 5:2建议更长时间

        plan = {
            "fasting_days_per_week": 2,
            "duration_weeks": duration // 7,
            "fasting_day_calories": 500,
            "normal_day_calories": "维持正常热量摄入",
            "fasting_day_schedule": {
                "breakfast": "早餐：200kcal（如：1个鸡蛋+1杯牛奶）",
                "lunch": "午餐：200kcal（如：1份蔬菜沙拉+少量坚果）",
                "dinner": "晚餐：100kcal（如：1份清蒸蔬菜）",
            },
            "recommended_fasting_days": ["周一", "周四"],  # 建议固定的断食日
            "hydration_reminder": "断食日保持充足饮水",
        }

        if target_weight and current_weight:
            weight_diff = current_weight - target_weight
            plan["weight_goal"] = {
                "target": target_weight,
                "current": current_weight,
                "to_loss": weight_diff,
                "estimated_rate": "每周约0.3-0.5kg",
            }

        return plan

    def _generate_basic_fasting_plan(
        self,
        target_weight: Optional[float],
        current_weight: Optional[float],
        health_assessment: Optional[Dict],
        duration_days: Optional[int]
    ) -> Dict:
        """生成基础辟谷计划"""
        duration = min(duration_days or 7, 7)  # 基础辟谷不超过7天

        plan = {
            "duration_days": duration,
            "phases": [
                {
                    "phase": "准备期",
                    "duration": "1-2天",
                    "description": "逐步减少饮食，清淡饮食",
                    "instructions": [
                        "逐步减少每餐食量",
                        "避免油腻、辛辣食物",
                        "增加蔬菜水果摄入",
                        "保持充足饮水",
                    ],
                },
                {
                    "phase": "活跃期",
                    "duration": f"{duration-4}天",
                    "description": "主要断食阶段",
                    "instructions": [
                        "仅饮水和清淡汤品",
                        "每天饮水至少2L",
                        "避免剧烈运动",
                        "保持充足休息",
                        "记录每日感受",
                    ],
                },
                {
                    "phase": "复食期",
                    "duration": "3-4天",
                    "description": "循序渐进恢复饮食",
                    "instructions": [
                        "第一天：清淡流质（米汤、蔬菜汤）",
                        "第二天：半流质（粥、蒸蔬菜）",
                        "第三天：软固体食物（蒸蛋、豆腐）",
                        "第四天：逐步恢复正常饮食",
                        "避免立即恢复正常食量",
                    ],
                },
            ],
        }

        return plan

    def _generate_warnings(self, plan_type: FastingPlanType) -> List[str]:
        """生成警告提示"""
        warnings = [
            "请确保饮水充足（每天至少2L）",
            "如出现头晕、乏力、心悸请立即停止",
            "低血糖症状：立即补充糖分并就医",
            "不建议在断食期间进行剧烈运动",
            "保持规律作息，充足睡眠",
            "记录每日感受和体重变化",
        ]

        if plan_type == FastingPlanType.BASIC_FASTING:
            warnings.extend([
                "辟谷期间避免独自进行",
                "复食过程比断食更重要",
                "严禁超过建议天数",
            ])

        return warnings

    def generate_checkin_feedback(
        self,
        weight: Optional[float],
        feeling: str,
        completed: bool,
        discomfort: Optional[Dict] = None,
        previous_weight: Optional[float] = None,
        streak_days: int = 0
    ) -> Dict:
        """
        生成打卡反馈

        Args:
            weight: 今日体重
            feeling: 感受（good/normal/tired/uncomfortable）
            completed: 是否完成断食
            discomfort: 不适症状
            previous_weight: 上次体重
            streak_days: 连续打卡天数

        Returns:
            Dict: 反馈内容
        """
        feedback = {
            "success": True,
            "message": "",
            "weight_change": None,
            "streak_days": streak_days,
            "warning": None,
            "encouragement": "",
            "disclaimer": self.MANDATORY_DISCLAIMER,
        }

        # 体重变化计算
        if weight and previous_weight:
            weight_change = weight - previous_weight
            feedback["weight_change"] = weight_change

            if weight_change < 0:
                feedback["encouragement"] = f"体重减少了{abs(weight_change):.2f}kg，继续保持！"
            elif weight_change > 0:
                feedback["encouragement"] = "体重有所波动，这可能是正常的，请保持信心。"

        # 感受反馈
        if feeling == "good":
            feedback["message"] = "今日感觉良好，断食进展顺利！"
        elif feeling == "normal":
            feedback["message"] = "今日状态正常，保持稳定的节奏很重要。"
        elif feeling == "tired":
            feedback["message"] = "感到疲劳是正常的，建议多休息，保证充足饮水。"
        elif feeling == "uncomfortable":
            feedback["message"] = "感到不适需要引起重视。"

        # 连续打卡鼓励
        if streak_days >= 3:
            feedback["encouragement"] += f"\n连续打卡{streak_days}天，很棒！"
        if streak_days >= 7:
            feedback["encouragement"] += "\n坚持一周了，继续保持！"

        # 不适症状预警
        if discomfort and feeling == "uncomfortable":
            warning_result = self._check_discomfort_warning(discomfort)
            if warning_result["level"] == "high":
                feedback["warning"] = {
                    "level": "high",
                    "symptoms": warning_result["symptoms"],
                    "advice": "请立即停止断食并就医！您的身体出现了明显不适反应。",
                }
            elif warning_result["level"] == "medium":
                feedback["warning"] = {
                    "level": "medium",
                    "symptoms": warning_result["symptoms"],
                    "advice": "建议适当调整断食强度，如症状持续请停止并咨询医生。",
                }

        return feedback

    def _check_discomfort_warning(self, discomfort: Dict) -> Dict:
        """
        检查不适症状严重程度

        Args:
            discomfort: 不适症状字典

        Returns:
            Dict: 预警等级
        """
        high_risk_symptoms = ["头晕", "心悸", "低血糖", "严重脱水"]
        medium_risk_symptoms = ["乏力", "注意力下降", "情绪波动"]

        detected_symptoms = []
        for symptom, has_symptom in discomfort.items():
            if has_symptom:
                detected_symptoms.append(symptom)

        # 高风险症状检测
        high_risk_detected = [s for s in detected_symptoms if s in high_risk_symptoms]
        if high_risk_detected:
            return {
                "level": "high",
                "symptoms": high_risk_detected,
            }

        # 中风险症状检测
        medium_risk_detected = [s for s in detected_symptoms if s in medium_risk_symptoms]
        if medium_risk_detected:
            return {
                "level": "medium",
                "symptoms": medium_risk_detected,
            }

        return {"level": "low", "symptoms": detected_symptoms}

    def generate_refeed_guide(
        self,
        plan_type: str,
        fasting_duration_days: int
    ) -> Dict:
        """
        生成复食指导方案

        Args:
            plan_type: 断食类型
            fasting_duration_days: 断食持续天数

        Returns:
            Dict: 复食方案
        """
        refeed_duration = self._calculate_refeed_duration(fasting_duration_days)

        guide = {
            "success": True,
            "plan_type": plan_type,
            "refeed_duration": refeed_duration,
            "phases": [
                {
                    "phase": 1,
                    "name": "清淡流质阶段",
                    "duration": f"第1-{min(2, refeed_duration//4)}天",
                    "description": "逐步唤醒消化系统",
                    "recommended_foods": [
                        "米汤、稀粥",
                        "蔬菜清汤",
                        "蜂蜜水",
                        "新鲜果汁（稀释）",
                    ],
                    "avoid_foods": [
                        "油炸食品",
                        "辛辣刺激",
                        "高蛋白食物",
                        "固体食物",
                    ],
                    "tips": [
                        "每餐控制在100-150ml",
                        "每天3-4餐，间隔2-3小时",
                        "细嚼慢咽",
                    ],
                },
                {
                    "phase": 2,
                    "name": "半流质阶段",
                    "duration": f"第{min(2, refeed_duration//4)+1}-{min(5, refeed_duration//2)}天",
                    "description": "逐渐增加食物种类",
                    "recommended_foods": [
                        "燕麦粥、小米粥",
                        "蒸蛋羹",
                        "豆腐、豆制品",
                        "水煮蔬菜",
                        "软面条",
                    ],
                    "avoid_foods": [
                        "油炸食品",
                        "辛辣刺激",
                        "生冷食物",
                        "难消化食物",
                    ],
                    "tips": [
                        "逐渐增加进食量",
                        "每天3餐正常化",
                        "充分消化",
                    ],
                },
                {
                    "phase": 3,
                    "name": "软固体食物阶段",
                    "duration": f"第{min(5, refeed_duration//2)+1}-{refeed_duration}天",
                    "description": "过渡到正常饮食",
                    "recommended_foods": [
                        "蒸煮的鱼肉、鸡肉",
                        "煮蛋",
                        "全麦面包",
                        "水果",
                        "适量坚果",
                    ],
                    "avoid_foods": [
                        "暴饮暴食",
                        "高糖饮料",
                        "酒精",
                        "加工肉类",
                    ],
                    "tips": [
                        "可恢复日常三餐",
                        "注意控制总量",
                        "继续保持清淡口味",
                    ],
                },
            ],
            "general_tips": [
                "复食比断食更重要",
                "循序渐进是关键",
                "严禁暴饮暴食",
                "如有不适立即就医",
            ],
            "disclaimer": self.MANDATORY_DISCLAIMER + "\n复食期间如出现不适，请立即咨询医生。",
        }

        return guide

    def _calculate_refeed_duration(self, fasting_duration_days: int) -> int:
        """
        计算复食时长

        Args:
            fasting_duration_days: 断食天数

        Returns:
            int: 复食天数
        """
        # 复食时长建议为断食时长的1/3到1/2
        if fasting_duration_days <= 3:
            return 3
        elif fasting_duration_days <= 7:
            return 5
        elif fasting_duration_days <= 14:
            return 7
        else:
            return min(14, fasting_duration_days // 2)

    def get_available_plan_types(self) -> List[str]:
        """
        获取所有可用的断食类型

        Returns:
            List[str]: 断食类型列表
        """
        return [plan.value for plan in FastingPlanType]


# 导出单例实例
fasting_advisor = FastingAdvisorSkill()


# 便捷函数
def generate_fasting_plan(
    plan_type: str,
    target_weight: Optional[float] = None,
    current_weight: Optional[float] = None,
    health_assessment: Optional[Dict] = None,
    duration_days: Optional[int] = None
) -> Dict:
    """便捷函数：生成断食计划"""
    return fasting_advisor.generate_fasting_plan(
        plan_type, target_weight, current_weight, health_assessment, duration_days
    )


def generate_checkin_feedback(
    weight: Optional[float],
    feeling: str,
    completed: bool,
    discomfort: Optional[Dict] = None,
    previous_weight: Optional[float] = None,
    streak_days: int = 0
) -> Dict:
    """便捷函数：生成打卡反馈"""
    return fasting_advisor.generate_checkin_feedback(
        weight, feeling, completed, discomfort, previous_weight, streak_days
    )


def generate_refeed_guide(plan_type: str, fasting_duration_days: int) -> Dict:
    """便捷函数：生成复食指导"""
    return fasting_advisor.generate_refeed_guide(plan_type, fasting_duration_days)


if __name__ == "__main__":
    # 测试代码
    advisor = FastingAdvisorSkill()

    # 测试计划生成
    print("=" * 60)
    print("测试：生成16:8断食计划")
    print("=" * 60)
    plan = advisor.generate_fasting_plan(
        plan_type="16_8",
        target_weight=65.0,
        current_weight=70.0,
        health_assessment={"bmi": 23.0},
        duration_days=30
    )
    print(json.dumps(plan, indent=2, ensure_ascii=False))

    # 测试禁忌筛查
    print("\n" + "=" * 60)
    print("测试：禁忌人群筛查")
    print("=" * 60)
    contraindicated_plan = advisor.generate_fasting_plan(
        plan_type="16_8",
        health_assessment={"bmi": 17.5, "is_pregnant": True}
    )
    print(json.dumps(contraindicated_plan, indent=2, ensure_ascii=False))

    # 测试打卡反馈
    print("\n" + "=" * 60)
    print("测试：打卡反馈")
    print("=" * 60)
    feedback = advisor.generate_checkin_feedback(
        weight=68.5,
        feeling="good",
        completed=True,
        previous_weight=68.8,
        streak_days=3
    )
    print(json.dumps(feedback, indent=2, ensure_ascii=False))

    # 测试复食指导
    print("\n" + "=" * 60)
    print("测试：复食指导")
    print("=" * 60)
    refeed_guide = advisor.generate_refeed_guide("16_8", 7)
    print(json.dumps(refeed_guide, indent=2, ensure_ascii=False))