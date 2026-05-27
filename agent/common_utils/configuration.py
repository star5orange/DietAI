import os
from dataclasses import dataclass, fields
from enum import Enum
from typing import Any, Optional

from langchain_core.runnables import RunnableConfig


class VisionModel(Enum):
    QWEN = "qwen"
    OPENAI = "openai"
    DEEPSEEK = "deepseek"


class AnalysisModel(Enum):
    QWEN = "qwen"
    OPENAI = "openai"
    DEEPSEEK = "deepseek"


@dataclass(kw_only=True)
class Configuration:
    vision_model_provider: VisionModel = VisionModel.QWEN
    vision_model: str = "qwen-vl-max"
    analysis_model_provider: AnalysisModel = AnalysisModel.DEEPSEEK
    analysis_model: str = "deepseek-v4-flash"

    @classmethod
    def from_runnable_config(
            cls, config: Optional[RunnableConfig] = None
    ) -> "Configuration":
        """从RunnableConfig创建Configuration实例"""
        configurable = (
            config["configurable"] if config and "configurable" in config else {}
        )
        values: dict[str, Any] = {
            f.name: (
                os.environ.get(f.name.upper())
                or os.environ.get(f"DIETAI_{f.name.upper()}")
                or configurable.get(f.name)
            )
            for f in fields(cls)
            if f.init
        }
        return cls(**{k: v for k, v in values.items() if v})


def get_env_value(name: str, default: Optional[str] = None) -> Optional[str]:
    """Read both plain and DIETAI_ prefixed environment variables."""
    return os.environ.get(name) or os.environ.get(f"DIETAI_{name}") or default


def get_agent_model_config(*, include_vision: bool = True) -> dict[str, str]:
    """Shared LangGraph configurable model settings.

    DeepSeek does not provide a generally available image-understanding model
    through its OpenAI-compatible chat API, so image analysis keeps a separate
    vision provider while text/reasoning defaults to DeepSeek.
    """
    config = {
        "analysis_model_provider": get_env_value("ANALYSIS_MODEL_PROVIDER", "deepseek"),
        "analysis_model": get_env_value("ANALYSIS_MODEL", "deepseek-v4-flash"),
    }

    if include_vision:
        config.update({
            "vision_model_provider": get_env_value("VISION_MODEL_PROVIDER", "qwen"),
            "vision_model": get_env_value("VISION_MODEL", "qwen-vl-max"),
        })

    return config
