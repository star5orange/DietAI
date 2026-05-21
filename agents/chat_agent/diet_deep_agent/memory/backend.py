"""
CompositeBackend 创建逻辑

路由规则：
  /memories/*  → StoreBackend  → MarkdownStore → 持久 MD 文件（跨会话）
  /* (默认)    → StateBackend  → MarkdownCheckpointSaver → 会话 MD 文件

Agent 视角的虚拟路径：
  /memories/profile.md       用户画像与健康档案
  /memories/goals.md         目标、BMR/TDEE、每日配额
  /memories/nutrition.md     饮食摘要、高频食物、营养趋势
  /memories/preferences.md   对话偏好、行为模式
  /memories/insights.md      Agent 综合洞察
  /scratch/*                 当前分析中间结果、膳食规划草稿
  /todos.md                  Deep Agent 原生任务规划
"""

from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

from agents.chat_agent.diet_deep_agent.memory.namespaces import MEMORY_PREFIX


def create_diet_backend(rt):
    """
    创建 Deep Agent 的 CompositeBackend。

    路由规则：
      /memories/*  → StoreBackend  → 跨会话持久化
      /* (默认)    → StateBackend  → 仅当前会话
    """
    return CompositeBackend(
        default=StateBackend(rt),
        routes={MEMORY_PREFIX: StoreBackend(rt)},
    )
