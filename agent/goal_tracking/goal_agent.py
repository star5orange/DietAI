"""
Goal Tracking Agent Graph Definition

Workflow:
load_user_context → calculate_bmr_tdee → calculate_daily_targets
                 → track_today_progress → generate_suggestions
                 → save_to_goals_md → format_output → END
"""

from langgraph.graph import StateGraph, END

from agent.goal_tracking.states import (
    GoalTrackingState,
    GoalTrackingInput,
    GoalTrackingOutput
)
from agent.goal_tracking.nodes import (
    load_user_context,
    calculate_bmr_tdee_node,
    calculate_daily_targets_node,
    track_today_progress_node,
    generate_suggestions_node,
    save_to_goals_md_node,
    format_output_node
)
from agent.utils.configuration import Configuration


# Create the workflow
goal_workflow = StateGraph(
    state_schema=GoalTrackingState,
    config_schema=Configuration,
    input=GoalTrackingInput,
    output=GoalTrackingOutput
)

# Add nodes
goal_workflow.add_node("load_user_context", load_user_context)
goal_workflow.add_node("calculate_bmr_tdee", calculate_bmr_tdee_node)
goal_workflow.add_node("calculate_daily_targets", calculate_daily_targets_node)
goal_workflow.add_node("track_today_progress", track_today_progress_node)
goal_workflow.add_node("generate_suggestions", generate_suggestions_node)
goal_workflow.add_node("save_to_goals_md", save_to_goals_md_node)
goal_workflow.add_node("format_output", format_output_node)

# Define the workflow edges
goal_workflow.set_entry_point("load_user_context")
goal_workflow.add_edge("load_user_context", "calculate_bmr_tdee")
goal_workflow.add_edge("calculate_bmr_tdee", "calculate_daily_targets")
goal_workflow.add_edge("calculate_daily_targets", "track_today_progress")
goal_workflow.add_edge("track_today_progress", "generate_suggestions")
goal_workflow.add_edge("generate_suggestions", "save_to_goals_md")
goal_workflow.add_edge("save_to_goals_md", "format_output")
goal_workflow.add_edge("format_output", END)

# Compile the graph
goal_graph = goal_workflow.compile()
