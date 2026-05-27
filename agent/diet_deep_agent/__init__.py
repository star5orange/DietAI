"""
DietDeepAgent - 统一的私人营养师 Deep Agent

基于 LangChain Deep Agents 构建，核心目标：越用越懂用户。
"""

__all__ = ["create_diet_deep_agent"]


def create_diet_deep_agent(config=None):
    """延迟导入，避免模块加载时触发 agent 创建"""
    from agent.diet_deep_agent.deep_agent import create_diet_deep_agent as _create
    return _create(config)
