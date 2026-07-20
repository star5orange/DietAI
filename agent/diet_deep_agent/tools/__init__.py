"""DietDeepAgent tools - 自定义工具集"""

from agent.diet_deep_agent.tools.food_analysis import analyze_food_image, lookup_food_database
from agent.diet_deep_agent.tools.goal_tracking import calculate_targets, get_daily_status, record_weight
from agent.diet_deep_agent.tools.memory_tools import learn_preference
from agent.diet_deep_agent.tools.nutrition_rag import query_nutrition_knowledge
from agent.diet_deep_agent.tools.user_data import get_diet_history, get_health_summary, get_user_profile
from agent.diet_deep_agent.tools.wellness_rag import query_wellness_knowledge, get_current_season_wellness
from agent.diet_deep_agent.tools.pet_data import (
    get_pet_profile,
    get_user_pets,
    get_pet_weight_trend,
    get_pet_feeding_records,
    calculate_pet_nutrition_target,
    get_pet_daily_summary,
)
from agent.diet_deep_agent.tools.pet_diet_trend import (
    analyze_weight_trend_alert,
    analyze_weekly_diet_trend,
)

__all__ = [
    "analyze_food_image",
    "lookup_food_database",
    "get_daily_status",
    "calculate_targets",
    "record_weight",
    "query_nutrition_knowledge",
    "get_user_profile",
    "get_diet_history",
    "get_health_summary",
    "learn_preference",
    "query_wellness_knowledge",
    "get_current_season_wellness",
    # 宠物健康
    "get_pet_profile",
    "get_user_pets",
    "get_pet_weight_trend",
    "get_pet_feeding_records",
    "calculate_pet_nutrition_target",
    "get_pet_daily_summary",
    "analyze_weight_trend_alert",
    "analyze_weekly_diet_trend",
]
