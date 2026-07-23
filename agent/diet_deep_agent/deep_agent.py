"""
DietDeepAgent 主入口

基于 LangChain Deep Agents 构建统一的"私人营养师"。
提供 create_diet_deep_agent() 工厂函数和可导出的 agent 图。
"""

import logging
import os

from dotenv import load_dotenv
from deepagents import create_deep_agent
from langchain.chat_models import init_chat_model

from agent.diet_deep_agent.config import DietDeepConfig
from agent.diet_deep_agent.memory.backend import create_diet_backend
from agent.diet_deep_agent.memory.md_checkpointer import MarkdownCheckpointSaver
from agent.diet_deep_agent.memory.md_store import MarkdownStore
from agent.diet_deep_agent.prompts import DIET_DEEP_SYSTEM_PROMPT
from agent.diet_deep_agent.subagents.definitions import ALL_SUBAGENTS
from agent.diet_deep_agent.tools.food_analysis import analyze_food_image, lookup_food_database
from agent.diet_deep_agent.tools.goal_tracking import (
    calculate_targets,
    get_daily_status,
    record_weight,
)
from agent.diet_deep_agent.tools.memory_tools import learn_preference
from agent.diet_deep_agent.tools.nutrition_rag import query_nutrition_knowledge
from agent.diet_deep_agent.tools.user_data import (
    get_diet_history,
    get_health_summary,
    get_user_profile,
)
from agent.diet_deep_agent.tools.wellness_rag import (
    get_current_season_wellness,
    query_wellness_knowledge,
)

# Milestone 2: Fasting Advisor Skill
from agent.diet_deep_agent.skills.fasting_advisor.fasting_advisor_skill import (
    check_contraindications as fasting_check_contraindications,
    generate_fasting_plan,
    generate_checkin_feedback,
    generate_refeed_guide,
)

# 宠物健康工具
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
from agent.diet_deep_agent.tools.pet_reminder import (
    get_vaccine_records,
    get_vaccine_schedule,
    get_health_reminders,
)
from agent.diet_deep_agent.tools.pet_food_ocr import (
    parse_pet_food_ocr,
    compare_pet_foods,
    get_food_db,
    add_food_to_db,
)
from agent.diet_deep_agent.tools.pet_avatar_generator import (
    generate_pet_avatar,
    generate_emotion_variants,
    remove_background,
)
from agent.diet_deep_agent.tools.pet_feedback_tools import PET_FEEDBACK_TOOLS
# 宠物健康 System Prompt 不再在此处拼接，改为在 router 层根据 session_type 动态注入
# from agent.diet_deep_agent.prompts.pet_health_prompts import PET_HEALTH_SYSTEM_PROMPT


logger = logging.getLogger(__name__)


def create_diet_deep_agent(config: DietDeepConfig | None = None, use_custom_persistence: bool = True):  
    """
    创建 DietDeepAgent 实例。

    Args:
        config: 可选配置，默认使用 DietDeepConfig() 默认值
        use_custom_persistence: 是否使用自定义 checkpointer/store。
            LangGraph API 自带持久化，设为 False 以兼容 langgraph dev。

    Returns:
        编译好的 Deep Agent 图（CompiledStateGraph）
    """
    config = config or DietDeepConfig()
    load_dotenv(".env", override=True, encoding="utf-8")
    load_dotenv(".env.dev", override=True, encoding="utf-8")

    # 构建 LLM 实例（DashScope 使用 OpenAI 兼容接口）
    api_key = (
        os.environ.get(config.primary_model_api_key_env)
        or os.environ.get(f"DIETAI_{config.primary_model_api_key_env}")
        or ""
    )
    base_url = (
        os.environ.get("DEEPSEEK_API_BASE")
        or os.environ.get("DIETAI_DEEPSEEK_API_BASE")
        or config.primary_model_base_url
    )
    primary_model = (
        os.environ.get("DEEPSEEK_MODEL")
        or os.environ.get("DIETAI_DEEPSEEK_MODEL")
        or os.environ.get("ANALYSIS_MODEL")
        or os.environ.get("DIETAI_ANALYSIS_MODEL")
        or config.primary_model
    )
    if ":" not in primary_model:
        primary_model = f"openai:{primary_model}"

    model = init_chat_model(
        primary_model,
        base_url=base_url,
        api_key=api_key,
    )

    # 所有自定义工具
    tools = [
        # 食物分析
        analyze_food_image,
        lookup_food_database,
        # 目标追踪
        get_daily_status,
        calculate_targets,
        record_weight,
        # RAG 知识检索
        query_nutrition_knowledge,
        # 养生知识检索
        query_wellness_knowledge,
        get_current_season_wellness,
        # M2: 断食/辟谷引导
        fasting_check_contraindications,
        generate_fasting_plan,
        generate_checkin_feedback,
        generate_refeed_guide,

        # 用户数据
        get_user_profile,
        get_diet_history,
        get_health_summary,
        # 记忆学习
        learn_preference,

        # 宠物健康
        get_pet_profile,
        get_user_pets,
        get_pet_weight_trend,
        get_pet_feeding_records,
        calculate_pet_nutrition_target,
        get_pet_daily_summary,
        analyze_weight_trend_alert,
        analyze_weekly_diet_trend,
        # 宠物疫苗/提醒
        get_vaccine_records,
        get_vaccine_schedule,
        get_health_reminders,
        # 宠物食品OCR/换粮
        parse_pet_food_ocr,
        compare_pet_foods,
        get_food_db,
        add_food_to_db,
        # 宠物形象生成
        generate_pet_avatar,
        generate_emotion_variants,
        remove_background,
        # 宠物反馈
        *PET_FEEDBACK_TOOLS,
    ]

    extra_kwargs = {}
    if use_custom_persistence:
        # Layer 3: MD 文件持久化
        store = MarkdownStore(base_path=config.memory_base_path)
        checkpointer = MarkdownCheckpointSaver(base_path=config.memory_base_path)
        extra_kwargs["store"] = store
        extra_kwargs["checkpointer"] = checkpointer

    agent = create_deep_agent(
        model=model,
        tools=tools,
        # 不在此处烘焙任何人格 System Prompt
        # 人类营养师 / 宠物健康顾问的人格由 Router 层根据 session_type 动态注入
        system_prompt=(
            "你是 DietAI 智能助手。你的具体角色（营养师/宠物健康顾问）由系统在每次对话时动态指定。"
            "你可以使用虚拟文件系统 /memories/*、/scratch/*、/todos.md 管理记忆和任务。"
        ),
        skills=[config.skills_dir],
        subagents=ALL_SUBAGENTS,
        # Layer 2: Deep Agent 原生 Backend 路由
        backend=create_diet_backend,
        name="diet_deep_agent",
        **extra_kwargs,
    )

    return agent


# langgraph.json 注册时通过 module.__dict__["agent"] 查找，
# __getattr__ 会被绕过，因此必须在模块级直接赋值。
# LangGraph API 自带持久化，不允许自定义 checkpointer/store，
# 因此模块级导出的 agent 不传入这两个参数。
agent = create_diet_deep_agent(use_custom_persistence=False)
