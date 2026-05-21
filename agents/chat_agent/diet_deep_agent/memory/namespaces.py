"""
记忆命名空间 & 虚拟路径常量定义

Agent 视角的虚拟路径 ←→ 物理存储路径 映射关系。
"""

# ──────────────────────────────────────────
# Agent 虚拟路径（用于 read_file / write_file）
# ──────────────────────────────────────────

# 持久记忆路径（/memories/* → StoreBackend → MarkdownStore → MD 文件）
MEMORY_PREFIX = "/memories/"
MEMORY_PROFILE = "/memories/profile.md"
MEMORY_GOALS = "/memories/goals.md"
MEMORY_NUTRITION = "/memories/nutrition.md"
MEMORY_PREFERENCES = "/memories/preferences.md"
MEMORY_INSIGHTS = "/memories/insights.md"

# 临时工作区路径（/scratch/* → StateBackend → MarkdownCheckpointSaver）
SCRATCH_PREFIX = "/scratch/"
SCRATCH_ANALYSIS = "/scratch/analysis.md"
SCRATCH_PLAN = "/scratch/plan.md"

# 任务规划（Deep Agent 原生）
TODOS_PATH = "/todos.md"

# ──────────────────────────────────────────
# Store 命名空间（StoreBackend 内部使用）
# ──────────────────────────────────────────

# Store namespace 格式: ("memories", "{user_id}")
STORE_NAMESPACE_PREFIX = "memories"

# ──────────────────────────────────────────
# 虚拟文件名 → MemoryManager workspace 映射
# ──────────────────────────────────────────

VIRTUAL_FILE_TO_WORKSPACE = {
    "profile.md": "shared",
    "goals.md": "goal_tracking",
    "nutrition.md": "nutrition",
    "preferences.md": "chat",
    "insights.md": "insights",  # 新增 workspace
}

# MemoryManager workspace → 虚拟文件名 反向映射
WORKSPACE_TO_VIRTUAL_FILE = {v: k for k, v in VIRTUAL_FILE_TO_WORKSPACE.items()}

# ──────────────────────────────────────────
# 物理路径模板
# ──────────────────────────────────────────

# 持久记忆物理路径: {base_path}/{user_id}/memories/{filename}
MEMORIES_DIR = "memories"

# 会话物理路径: {base_path}/{user_id}/sessions/{thread_id}/
SESSIONS_DIR = "sessions"

# 历史快照路径: {base_path}/{user_id}/history/
HISTORY_DIR = "history"

# ──────────────────────────────────────────
# 所有持久记忆文件清单
# ──────────────────────────────────────────

ALL_MEMORY_FILES = [
    MEMORY_PROFILE,
    MEMORY_GOALS,
    MEMORY_NUTRITION,
    MEMORY_PREFERENCES,
    MEMORY_INSIGHTS,
]
