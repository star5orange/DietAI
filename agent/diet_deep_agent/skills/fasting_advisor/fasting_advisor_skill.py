"""
轻断食/辟谷科学引导技能

提供断食计划生成、禁忌筛查、打卡反馈、复食指导等功能。
所有输出强制包含安全提示和免责声明。

Milestone 2 核心技能
"""

from typing import Optional
from enum import Enum
from datetime import date, timedelta
import json


class FastingPlanType(str, Enum):
    """断食计划类型"""
    SIXTEEN_EIGHT = "16_8"  # 16:8 轻断食
    FIVE_TWO = "5_2"  # 5:2 轻断食
    BASIC_FASTING = "basic_fasting"  # 基础辟谷


class FeelingType(str, Enum):
    """感受类型"""
    GOOD = "good"  # 良好
    NORMAL = "normal"  # 一般
    TIRED = "tired"  # 疲惫
    UNCOMFORTABLE = "uncomfortable"  # 不适


# 禁忌人群定义
CONTRAINDICATIONS = {
    "pregnant": {
        "name": "孕妇",
        "check": lambda assessment: assessment.get("is_pregnant", False),
        "message": "孕妇不建议进行任何形式的断食，请咨询医生。"
    },
    "breastfeeding": {
        "name": "哺乳期女性",
        "check": lambda assessment: assessment.get("is_breastfeeding", False),
        "message": "哺乳期女性不建议断食，会影响乳汁分泌。"
    },
    "minor": {
        "name": "未成年人",
        "check": lambda assessment: assessment.get("is_minor", False) or assessment.get("age", 18) < 18,
        "message": "未成年人身体尚在发育，不建议进行断食。"
    },
    "diabetes": {
        "name": "糖尿病患者",
        "check": lambda assessment: assessment.get("has_diabetes", False),
        "message": "糖尿病患者断食存在低血糖风险，必须在医生指导下进行。"
    },
    "eating_disorder": {
        "name": "进食障碍患者",
        "check": lambda assessment: assessment.get("has_eating_disorder", False),
        "message": "有进食障碍史的用户不建议进行断食。"
    },
    "low_bmi": {
        "name": "BMI过低",
        "check": lambda assessment: assessment.get("bmi", 22) < 18.5,
        "message": "BMI低于18.5的用户不建议断食，可能存在营养不良风险。"
    }
}

# 断食计划模板
FASTING_PLAN_TEMPLATES = {
    FastingPlanType.SIXTEEN_EIGHT: {
        "name": "16:8 轻断食",
        "description": "每天禁食16小时，在8小时进食窗口内完成三餐",
        "default_window": {"start": "08:00", "end": "16:00"},
        "daily_tips": [
            "进食窗口内保证营养均衡",
            "禁食期间可喝水、茶、黑咖啡（无糖）",
            "避免进食窗口内暴饮暴食",
            "保持规律作息，避免熬夜"
        ],
        "warnings": [
            "如出现头晕、心悸等不适症状请立即停止",
            "断食期间避免剧烈运动",
            "保证充足饮水（每天2-3升）"
        ]
    },
    FastingPlanType.FIVE_TWO: {
        "name": "5:2 轻断食",
        "description": "每周5天正常饮食，2天低热量摄入（500-600大卡）",
        "default_window": {"start": "00:00", "end": "23:59"},
        "daily_tips": [
            "低热量日选择高蛋白、高纤维食物",
            "分散在2-3餐完成，避免过饿",
            "正常饮食日不要暴饮暴食",
            "低热量日避免社交聚餐"
        ],
        "warnings": [
            "连续两天低热量日建议间隔安排",
            "低热量日避免高强度运动",
            "如感到强烈不适可适当增加热量"
        ]
    },
    FastingPlanType.BASIC_FASTING: {
        "name": "基础辟谷引导",
        "description": "循序渐进的辟谷引导，从12小时逐步延长",
        "default_window": {"start": "06:00", "end": "18:00"},
        "daily_tips": [
            "第一周：12小时禁食",
            "第二周：14小时禁食",
            "第三周：16小时禁食",
            "配合冥想和轻柔运动"
        ],
        "warnings": [
            "辟谷期间如有任何强烈不适请立即停止",
            "不建议超过24小时连续禁食",
            "复食必须循序渐进"
        ]
    }
}

# 不适症状风险等级
DISCOMFORT_RISK_LEVELS = {
    "dizziness": {"level": "medium", "advice": "请立即补充糖分并休息，如持续请停止断食"},
    "low_sugar": {"level": "high", "advice": "低血糖症状明显，请立即停止断食并补充糖分"},
    "palpitation": {"level": "high", "advice": "心悸可能是身体警告信号，请停止断食并咨询医生"},
    "nausea": {"level": "medium", "advice": "恶心感可能是血糖过低，建议补充少量食物"},
    "headache": {"level": "low", "advice": "轻度头痛可能是正常反应，多喝水并休息"},
    "insomnia": {"level": "low", "advice": "如影响睡眠，可适当调整进食时间"}
}

# 复食指导模板
REFEED_GUIDE_TEMPLATE = {
    "phases": [
        {
            "day": "1-2",
            "name": "温和启动",
            "description": "清淡流质饮食，让肠胃逐步适应",
            "foods": ["温水", "淡盐水", "蔬菜汁", "燕麦粥", "蒸蛋"],
            "avoid": ["固体食物", "油腻", "辛辣", "高蛋白"],
            "tips": "少量多餐，每2-3小时进食一次"
        },
        {
            "day": "3-5",
            "name": "轻食过渡",
            "description": "逐渐增加食物种类和份量",
            "foods": ["全谷物粥", "蒸蔬菜", "瘦肉丝", "豆腐", "酸奶"],
            "avoid": ["油炸", "甜食", "酒精", "咖啡"],
            "tips": "每口细嚼慢咽，避免一次性吃太多"
        },
        {
            "day": "6-7",
            "name": "正常恢复",
            "description": "逐步恢复到正常饮食结构",
            "foods": ["糙米饭", "蒸鱼", "煮蔬菜", "豆类", "水果"],
            "avoid": ["暴饮暴食", "过度节食"],
            "tips": "保持健康饮食习惯，继续记录饮食"
        }
    ],
    "disclaimer": "复食期间如出现任何不适，请立即咨询医生"
}


def check_contraindications(health_assessment: dict) -> dict:
    """
    检查禁忌人群
    
    Args:
        health_assessment: 健康评估数据
        
    Returns:
        包含筛查结果的字典
    """
    contraindications_found = []
    
    for key, contra in CONTRAINDICATIONS.items():
        if contra["check"](health_assessment):
            contraindications_found.append({
                "type": key,
                "name": contra["name"],
                "message": contra["message"]
            })
    
    return {
        "can_fasting": len(contraindications_found) == 0,
        "contraindications": contraindications_found,
        "message": "通过禁忌筛查" if len(contraindications_found) == 0 else "存在禁忌情况，不建议断食"
    }


def generate_fasting_plan(
    plan_type: str,
    target_weight: Optional[float] = None,
    health_assessment: Optional[dict] = None,
    eating_window_start: str = "08:00",
    eating_window_end: str = "16:00"
) -> dict:
    """
    生成断食计划
    
    Args:
        plan_type: 计划类型
        target_weight: 目标体重
        health_assessment: 健康评估数据
        eating_window_start: 进食窗口开始时间
        eating_window_end: 进食窗口结束时间
        
    Returns:
        断食计划字典
    """
    plan_key = FastingPlanType(plan_type) if plan_type in [e.value for e in FastingPlanType] else FastingPlanType.SIXTEEN_EIGHT
    template = FASTING_PLAN_TEMPLATES.get(plan_key, FASTING_PLAN_TEMPLATES[FastingPlanType.SIXTEEN_EIGHT])
    
    # 检查禁忌人群
    if health_assessment:
        contraindication_check = check_contraindications(health_assessment)
        if not contraindication_check["can_fasting"]:
            return {
                "success": False,
                "error": "CONTRAINDICATIONS_FOUND",
                "message": "存在禁忌情况，不建议断食",
                "contraindications": contraindication_check["contraindications"]
            }
    
    plan = {
        "success": True,
        "plan_type": plan_type,
        "name": template["name"],
        "description": template["description"],
        "eating_window": {
            "start": eating_window_start,
            "end": eating_window_end
        },
        "target_weight": target_weight,
        "daily_tips": template["daily_tips"],
        "warnings": template["warnings"],
        "disclaimer": "本计划仅供参考，如有不适请立即停止并咨询医生"
    }
    
    if target_weight:
        # 简单估算周期（每周减重0.5-1kg为健康范围）
        estimated_weeks = max(4, int(target_weight * 2))
        plan["estimated_duration"] = f"{estimated_weeks} 周"
    
    return plan


def generate_checkin_feedback(
    feeling: str,
    completed: bool,
    discomfort: Optional[dict] = None,
    weight_change: Optional[float] = None,
    days_elapsed: int = 1
) -> dict:
    """
    生成打卡反馈
    
    Args:
        feeling: 今日感受
        completed: 是否完成断食
        discomfort: 不适症状
        weight_change: 体重变化
        days_elapsed: 已进行天数
        
    Returns:
        打卡反馈字典
    """
    feedback = {
        "success": True,
        "message": "",
        "encouragement": "",
        "warning": None,
        "advice": []
    }
    
    # 检查不适症状
    if discomfort:
        warnings = []
        high_risk = False
        for symptom, present in discomfort.items():
            if present and symptom in DISCOMFORT_RISK_LEVELS:
                risk_info = DISCOMFORT_RISK_LEVELS[symptom]
                warnings.append({
                    "symptom": symptom,
                    "level": risk_info["level"],
                    "advice": risk_info["advice"]
                })
                if risk_info["level"] == "high":
                    high_risk = True
        
        if warnings:
            feedback["warning"] = {
                "has_warning": True,
                "high_risk": high_risk,
                "symptoms": warnings,
                "message": "出现不适症状，请注意身体状况" if not high_risk else "出现高风险症状，建议立即停止断食"
            }
    
    # 根据感受生成反馈
    feeling_messages = {
        "good": [
            "太棒了！今天的断食进行得很顺利！",
            "状态良好，继续保持这个节奏！",
            "你的坚持正在带来改变！"
        ],
        "normal": [
            "今天的表现还不错，继续加油！",
            "断食需要适应期，你已经做得很好了！"
        ],
        "tired": [
            "有些疲惫是正常的，记得多休息。",
            "如果持续疲惫，可以考虑缩短禁食时间。"
        ],
        "uncomfortable": [
            "身体出现不适反应，请密切关注。",
            "如不适持续，请停止断食并咨询医生。"
        ]
    }
    
    messages = feeling_messages.get(feeling, feeling_messages["normal"])
    feedback["message"] = messages[days_elapsed % len(messages)]
    
    # 鼓励语
    if completed:
        feedback["encouragement"] = f"已完成第 {days_elapsed} 天断食！"
        if weight_change and weight_change < 0:
            feedback["encouragement"] += f" 体重变化：{weight_change:.1f}kg"
    
    # 建议
    if days_elapsed <= 3:
        feedback["advice"].append("前几天是适应期，多喝水、保证休息")
    elif days_elapsed <= 7:
        feedback["advice"].append("保持规律作息，避免熬夜")
    else:
        feedback["advice"].append("坚持下去，你已经建立了良好的节奏")
    
    return feedback


def generate_refeed_guide(plan_type: str, duration_days: int = 7) -> dict:
    """
    生成复食指导方案
    
    Args:
        plan_type: 计划类型
        duration_days: 复食天数
        
    Returns:
        复食指导字典
    """
    guide = {
        "plan_type": plan_type,
        "duration_days": duration_days,
        "phases": REFEED_GUIDE_TEMPLATE["phases"],
        "general_tips": [
            "复食期间保持温和饮食，避免刺激性食物",
            "少量多餐，让肠胃逐步适应",
            "继续记录饮食和体重变化",
            "如有不适立即停止并咨询医生"
        ],
        "disclaimer": REFEED_GUIDE_TEMPLATE["disclaimer"]
    }
    
    # 根据计划类型调整
    if plan_type == "basic_fasting":
        guide["duration_days"] = max(7, duration_days)
        guide["phases"][0]["day"] = "1-3"
        guide["phases"][1]["day"] = "4-7"
        guide["phases"][2]["day"] = "8-10"
    
    return guide


def get_plan_type_display_name(plan_type: str) -> str:
    """获取计划类型显示名称"""
    names = {
        "16_8": "16:8 轻断食",
        "5_2": "5:2 轻断食",
        "basic_fasting": "基础辟谷引导"
    }
    return names.get(plan_type, plan_type)


def get_available_plan_types() -> list[dict]:
    """获取所有可用的计划类型"""
    return [
        {
            "id": "16_8",
            "name": "16:8 轻断食",
            "description": "每日禁食16小时，进食8小时",
            "difficulty": "easy"
        },
        {
            "id": "5_2",
            "name": "5:2 轻断食",
            "description": "每周5天正常吃，2天低热量",
            "difficulty": "medium"
        },
        {
            "id": "basic_fasting",
            "name": "基础辟谷引导",
            "description": "循序渐进的辟谷引导",
            "difficulty": "advanced"
        }
    ]