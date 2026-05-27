"""
Enhanced Nutrition Agent Graph Definition

Workflow:
enhanced_state_init → load_shared_memory → analyze_image → extract_nutrition
                   → retrieve_knowledge → generate_dependencies
                   → generate_advice_with_context → save_to_nutrition_md
                   → format_response → END

This agent extends the original nutrition_agent with memory-aware capabilities
while maintaining the same core analysis pipeline.
"""

from langgraph.graph import StateGraph, END

from agent.enhanced_nutrition.states import (
    EnhancedNutritionState,
    EnhancedInputState,
    EnhancedOutputState
)
from agent.enhanced_nutrition.enhanced_nodes import (
    enhanced_state_init,
    load_shared_memory,
    generate_advice_with_context,
    save_to_nutrition_md
)
# Reuse original nodes for core analysis
from agent.utils.nodes import (
    analyze_image,
    extract_nutrition_info,
    retrieve_nutrition_knowledge,
    generate_dependencies,
    format_final_response
)
from agent.utils.configuration import Configuration


# Create the enhanced workflow
enhanced_workflow = StateGraph(
    state_schema=EnhancedNutritionState,
    config_schema=Configuration,
    input=EnhancedInputState,
    output=EnhancedOutputState
)

# Add nodes
# New memory-aware nodes
enhanced_workflow.add_node("state_init", enhanced_state_init)
enhanced_workflow.add_node("load_memory", load_shared_memory)

# Reused analysis nodes (cast state as needed)
enhanced_workflow.add_node("analyze_image", analyze_image)
enhanced_workflow.add_node("extract_nutrition", extract_nutrition_info)
enhanced_workflow.add_node("retrieve_knowledge", retrieve_nutrition_knowledge)
enhanced_workflow.add_node("generate_dependencies", generate_dependencies)

# New memory-aware advice generation
enhanced_workflow.add_node("generate_advice", generate_advice_with_context)
enhanced_workflow.add_node("save_to_nutrition_md", save_to_nutrition_md)

# Final formatting
enhanced_workflow.add_node("format_response", format_final_response)

# Define the workflow edges
enhanced_workflow.set_entry_point("state_init")
enhanced_workflow.add_edge("state_init", "load_memory")
enhanced_workflow.add_edge("load_memory", "analyze_image")
enhanced_workflow.add_edge("analyze_image", "extract_nutrition")
enhanced_workflow.add_edge("extract_nutrition", "retrieve_knowledge")
enhanced_workflow.add_edge("retrieve_knowledge", "generate_dependencies")
enhanced_workflow.add_edge("generate_dependencies", "generate_advice")
enhanced_workflow.add_edge("generate_advice", "save_to_nutrition_md")
enhanced_workflow.add_edge("save_to_nutrition_md", "format_response")
enhanced_workflow.add_edge("format_response", END)

# Compile the graph
enhanced_graph = enhanced_workflow.compile()
