"""Fasting advisor tool for DietDeepAgent"""
from langchain_core.tools import tool
from typing import Optional, Dict, Any

from agent.diet_deep_agent.skills.fast_advisor.fasting_advisor_skill import (
    FastingAdvisorSkill,
)

_fasting_skill = FastingAdvisorSkill()


@tool
def generate_fasting_plan_tool(
    plan_type: str = "16_8",
    target_weight: Optional[float] = None,
    start_date: Optional[str] = None,
    health_assessment: Optional[Dict[str, Any]] = None,
) -> str:
    """生成轻断食/辟谷计划

    根据用户选择的断食类型和健康评估数据，生成个性化的断食计划。
    支持三种类型：16_8（16:8间歇性断食）、5_2（5:2轻断食）、basic_fasting（基础辟谷引导）。

    Args:
        plan_type: 断食类型 16_8/5_2/basic_fasting
        target_weight: 目标体重（kg），可选
        start_date: 开始日期 YYYY-MM-DD，可选
        health_assessment: 健康评估数据（BMI、是否糖尿病、是否怀孕等），可选

    Returns:
        生成的断食计划文本（JSON格式）
    """
    try:
        result = _fasting_skill.generate_fasting_plan(
            plan_type=plan_type,
            target_weight=target_weight,
            start_date=start_date,
            health_assessment=health_assessment,
        )
        return str(result)
    except Exception as e:
        return f"生成断食计划失败: {str(e)}"


@tool
def generate_checkin_feedback_tool(
    weight: Optional[float] = None,
    feeling: str = "normal",
    discomfort: Optional[Dict[str, bool]] = None,
    previous_weight: Optional[float] = None,
    streak_days: int = 0,
) -> str:
    """生成轻断食打卡反馈

    根据用户的打卡数据，生成个性化反馈和风险预警。
    如果出现不适症状会自动触发预警提示。

    Args:
        weight: 当前体重（kg），可选
        feeling: 体感 good/normal/tired/uncomfortable
        discomfort: 不适症状，如 {'dizziness': True, 'low_sugar': False, 'palpitation': False}
        previous_weight: 上次体重（kg），可选
        streak_days: 连续打卡天数

    Returns:
        打卡反馈文本
    """
    try:
        result = _fasting_skill.generate_checkin_feedback(
            weight=weight,
            feeling=feeling,
            discomfort=discomfort,
            previous_weight=previous_weight,
            streak_days=streak_days,
        )
        return str(result)
    except Exception as e:
        return f"生成打卡反馈失败: {str(e)}"


@tool
def generate_refeed_guide_tool(plan_type: str = "16_8") -> str:
    """生成复食指导方案

    当用户完成断食计划后，生成分阶段的复食指导方案。

    Args:
        plan_type: 断食类型 16_8/5_2/basic_fasting

    Returns:
        复食指导方案文本
    """
    try:
        result = _fasting_skill.generate_refeed_guide(plan_type=plan_type)
        return str(result)
    except Exception as e:
        return f"生成复食指导失败: {str(e)}"


FASTING_ADVISOR_TOOLS = [
    generate_fasting_plan_tool,
    generate_checkin_feedback_tool,
    generate_refeed_guide_tool,
]
