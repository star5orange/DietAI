"""断食顾问技能（fast_advisor）安全红线单元测试 —— 纯进程内，不需要后端 / LLM。

对应验收用例 TC-057 的逻辑层（SKILL.md 合规要求）：
- 强制免责声明必须包含禁忌人群与「不适立即停止就医」话术
- 禁忌人群（糖尿病/孕妇/哺乳期/未成年/进食障碍/BMI<18.5/严重疾病）命中时不出计划
- 正常人群生成计划时必须携带免责声明 + 不适即停警示
- 无效计划类型拒绝
"""

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import pytest

from agent.diet_deep_agent.skills.fast_advisor.fasting_advisor_skill import (
    FastingAdvisorSkill,
)

skill = FastingAdvisorSkill()


def test_disclaimer_contains_mandatory_phrases():
    text = skill.MANDATORY_DISCLAIMER
    for phrase in ("孕妇", "哺乳期", "未成年人", "糖尿病", "进食障碍", "18.5", "立即停止", "就医"):
        assert phrase in text, phrase


@pytest.mark.parametrize(
    "assessment, expected_reason",
    [
        ({"has_diabetes": True}, "糖尿病"),
        ({"is_pregnant": True}, "孕妇"),
        ({"is_breastfeeding": True}, "哺乳期"),
        ({"is_minor": True}, "未成年人"),
        ({"has_eating_disorder": True}, "进食障碍"),
        ({"has_severe_disease": True}, "遵医嘱"),
    ],
)
def test_contraindication_blocks_plan(assessment, expected_reason):
    """禁忌人群命中：不出计划（DISABLED_FOR_USER），携带原因与免责声明"""
    result = skill.generate_fasting_plan("16_8", health_assessment=assessment)
    assert result["success"] is False
    assert result["error"] == "DISABLED_FOR_USER"
    assert expected_reason in result["message"]
    assert result["disclaimer"] == skill.MANDATORY_DISCLAIMER


def test_low_bmi_blocked():
    result = skill.generate_fasting_plan("16_8", health_assessment={"bmi": 17.0})
    assert result["success"] is False
    assert any(c["reason"] == "low_bmi" for c in result["contraindications"])


def test_healthy_user_gets_plan_with_disclaimer_and_stop_conditions():
    """正常人群：出计划，且免责声明与不适即停警示必须带上（不可关闭）"""
    result = skill.generate_fasting_plan(
        "16_8",
        current_weight=70.0,
        target_weight=66.0,
        health_assessment={"bmi": 22.5},
    )
    assert result["success"] is True
    assert result["disclaimer"] == skill.MANDATORY_DISCLAIMER
    assert "立即停止" in result["stop_conditions"]
    assert isinstance(result.get("warnings"), list)


def test_invalid_plan_type_rejected():
    result = skill.generate_fasting_plan("OMAD")
    assert result["success"] is False
    assert result["error"] == "INVALID_PLAN_TYPE"
