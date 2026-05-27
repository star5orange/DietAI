"""
DietDeepAgent 主入口

基于 LangChain Deep Agents 构建统一的"私人营养师"。
提供 create_diet_deep_agent() 工厂函数和可导出的 agent 图。
"""

import logging
import os

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

    # 构建 LLM 实例（DashScope 使用 OpenAI 兼容接口）
    api_key = os.environ.get(config.primary_model_api_key_env, "")
    model = init_chat_model(
        config.primary_model,
        base_url=config.primary_model_base_url,
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
        # 用户数据
        get_user_profile,
        get_diet_history,
        get_health_summary,
        # 记忆学习
        learn_preference,
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
        system_prompt=DIET_DEEP_SYSTEM_PROMPT,
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
