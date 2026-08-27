"""
Hardware Nutrition Agent — ESP32 智能硬件专用
流程: state_init → analyze_text → extract_nutrition → generate_hardware_advice → format_response
比 nutrition_agent 少 3 步 (无 RAG、无 dependencies、无 allergy), 速度快 ~50%
"""
from langgraph.graph import StateGraph, END

from agent.common_utils.configuration import Configuration
from agent.nutrition_agent.utils.states import AgentState, InputState, OutputState
from agent.nutrition_agent.utils.nodes import (
    state_init,
    analyze_text,
    extract_nutrition_info,
    format_final_response,
)
from agent.hardware_nutrition.nodes import generate_hardware_advice

workflow = StateGraph(
    state_schema=AgentState,
    config_schema=Configuration,
    input=InputState,
    output=OutputState,
)

# 4 个核心步骤 (vs 原版 7 步)
workflow.add_node("state_init", state_init)
workflow.add_node("analyze_text", analyze_text)              # 复用: 文字分析
workflow.add_node("extract_nutrition", extract_nutrition_info)  # 复用: 营养提取
workflow.add_node("generate_advice", generate_hardware_advice)  # 新: 简短建议
workflow.add_node("format_response", format_final_response)     # 复用: 格式化

# 硬件只走文字, 不分支
workflow.set_entry_point("state_init")
workflow.add_edge("state_init", "analyze_text")
workflow.add_edge("analyze_text", "extract_nutrition")
workflow.add_edge("extract_nutrition", "generate_advice")
workflow.add_edge("generate_advice", "format_response")
workflow.add_edge("format_response", END)

graph = workflow.compile()
