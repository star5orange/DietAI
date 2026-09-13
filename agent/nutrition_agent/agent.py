from langgraph.graph import StateGraph, END
from langgraph.prebuilt import ToolNode, tools_condition
from agent.common_utils.configuration import Configuration
from agent.nutrition_agent.utils.nodes import *
from agent.nutrition_agent.utils.states import AgentState, InputState, OutputState

workflow = StateGraph(
    state_schema=AgentState,
    config_schema=Configuration,
    input=InputState,
    output=OutputState,
)

workflow.add_node("state_init", state_init)
# 添加节点
workflow.add_node("analyze_image", analyze_image)
workflow.add_node("analyze_text", analyze_text)
workflow.add_node("extract_nutrition", extract_nutrition_info)
# 预置营养值分支（包装食品营养成分表：跳过 AI 估算，直接用标注精确值）
workflow.add_node("use_preset_nutrition", use_preset_nutrition)
workflow.add_node("retrieve_nutrition_knowledge", retrieve_nutrition_knowledge)
workflow.add_node("generate_advice", generate_nutrition_advice)
workflow.add_node("check_allergy", check_allergy_cross_contamination)
workflow.add_node("format_response", format_final_response)
workflow.add_node("generate_dependencies", generate_dependencies)

# 定义路由函数：预置营养值优先（包装食品标签）；否则有文字描述走文字分析；否则走图片分析
def route_after_init(state: AgentState) -> str:
    if state.get("preset_nutrition"):
        return "use_preset_nutrition"
    if state.get("text_description") and not state.get("image_data"):
        return "analyze_text"
    return "analyze_image"

# 定义工作流
workflow.set_entry_point("state_init")
workflow.add_conditional_edges("state_init", route_after_init, {
    "use_preset_nutrition": "use_preset_nutrition",
    "analyze_text": "analyze_text",
    "analyze_image": "analyze_image",
})
workflow.add_edge("analyze_text", "extract_nutrition")
workflow.add_edge("analyze_image", "extract_nutrition")
workflow.add_edge("use_preset_nutrition", "retrieve_nutrition_knowledge")
workflow.add_edge("extract_nutrition", "retrieve_nutrition_knowledge")
workflow.add_edge("retrieve_nutrition_knowledge", "generate_dependencies")
workflow.add_edge("generate_dependencies", "generate_advice")
workflow.add_edge("generate_advice", "check_allergy")
workflow.add_edge("check_allergy", "format_response")
workflow.add_edge("format_response", END)
graph = workflow.compile()
