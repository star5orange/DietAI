"""
子代理定义

由于现有 agent 图的 state 没有 messages 字段，
不能直接用 CompiledSubAgent 封装。

设计决策：
- 现有 agent（nutrition_agent, chat_agent, goal_agent）通过 tools 调用
- 新能力（pattern-detector）用字典定义的子代理，由主 LLM 驱动
"""

from deepagents.middleware.subagents import SubAgent

# pattern-detector 子代理定义（字典形式，使用主 agent 的 LLM）
pattern_subagent: SubAgent = {
    "name": "pattern-detector",
    "description": (
        "分析用户的长期饮食和行为模式：营养缺口、饮食多样性、作息规律、趋势变化。"
        "在累积足够数据后或用户请求健康报告时使用。"
    ),
    "system_prompt": (
        "你是一个饮食模式分析专家。分析用户的饮食历史数据，识别以下模式：\n"
        "1. 营养缺口：连续 7+ 天某营养素低于目标的 70%\n"
        "2. 饮食多样性：top-3 食物是否占比超过 60%\n"
        "3. 作息规律：是否经常跳餐、用餐时间是否稳定\n"
        "4. 趋势变化：摄入量的周环比/月环比变化\n"
        "5. 周末偏差：工作日 vs 周末的差异\n\n"
        "输出格式：每个模式包含 type, description, confidence(0-1), recommendation\n\n"
        "使用 get_diet_history 获取饮食历史，get_health_summary 获取健康概要。"
    ),
    "tools": [],  # 子代理继承主 agent 的工具，无需额外指定
}

# 所有子代理列表
ALL_SUBAGENTS: list[SubAgent] = [pattern_subagent]
