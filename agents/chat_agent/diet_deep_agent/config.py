"""
DietDeepAgent 配置模块

定义 DietDeepAgent 的所有可配置参数。
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class DietDeepConfig:
    """DietDeepAgent 配置"""

    # 主 LLM 模型（Deep Agent 使用）
    # 使用 DashScope (通义千问) 兼容 OpenAI 接口
    primary_model: str = "openai:qwen3.5-plus"
    primary_model_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    primary_model_api_key_env: str = "DASHSCOPE_API_KEY"

    # 子代理可独立指定模型，None 表示继承 primary_model
    subagent_model: Optional[str] = None

    # 记忆基础路径
    memory_base_path: str = "agents/UserMemory"

    # LangGraph Agent Service URL（用于调用现有编译图）
    agent_service_url: str = "http://127.0.0.1:2024"

    # Skills 目录
    skills_dir: str = "agents/chat_agent/diet_deep_agent/skills/"

    # 记忆相关配置
    max_memory_file_size: int = 50_000  # 单个记忆文件最大字符数
    insight_trigger_interval: int = 10  # 每 N 次交互触发洞察合成

    # 模式检测阈值
    pattern_min_days: int = 7        # 最少数据天数才触发模式检测
    nutrient_gap_threshold: float = 0.7  # 营养缺口阈值（低于目标的 70%）
    food_diversity_threshold: float = 0.6  # 饮食多样性阈值（top-3 占比 > 60%）

    # vision 模型配置（传递给子代理）
    vision_model_provider: str = "openai"
    vision_model: str = "gpt-4.1-nano-2025-04-14"
    analysis_model_provider: str = "openai"
    analysis_model: str = "o3-mini-2025-01-31"

    @property
    def agent_config(self) -> dict:
        """生成传递给 LangGraph agent 的 configurable dict"""
        return {
            "vision_model_provider": self.vision_model_provider,
            "vision_model": self.vision_model,
            "analysis_model_provider": self.analysis_model_provider,
            "analysis_model": self.analysis_model,
        }
