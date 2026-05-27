import os
from enum import Enum
from functools import lru_cache

from dotenv import load_dotenv
from langchain_anthropic import ChatAnthropic
from langchain_openai import ChatOpenAI, OpenAIEmbeddings


def _provider_value(model_provider: Enum | str) -> str:
    return model_provider.value if isinstance(model_provider, Enum) else str(model_provider)


def _env(name: str, default: str | None = None) -> str | None:
    return os.environ.get(name) or os.environ.get(f"DIETAI_{name}") or default


def _required_env(*names: str) -> str:
    for name in names:
        value = _env(name)
        if value:
            return value
    raise RuntimeError(f"Missing required environment variable: {' or '.join(names)}")


@lru_cache(maxsize=8)
def get_model(model_provider: Enum | str, model_name: str):
    load_dotenv(".env", override=True)
    load_dotenv(".env.dev", override=True)

    provider = _provider_value(model_provider).lower()

    match provider:
        case "anthropic":
            return ChatAnthropic(model_name=model_name)
        case "openai":
            kwargs = {"model": model_name, "streaming": False}
            base_url = _env("OPENAI_API_BASE") or _env("OPENAI_BASE_URL")
            if base_url:
                kwargs["base_url"] = base_url
            return ChatOpenAI(**kwargs)
        case "deepseek":
            return ChatOpenAI(
                model=model_name,
                api_key=_required_env("DEEPSEEK_API_KEY"),
                base_url=_env("DEEPSEEK_API_BASE", "https://api.deepseek.com"),
                streaming=False,
            )
        case "qwen":
            return ChatOpenAI(
                model=model_name,
                api_key=_required_env("DASHSCOPE_API_KEY"),
                base_url=_env("DASHSCOPE_API_BASE", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
                streaming=False,
            )
        case _:
            raise ValueError(f"Unsupported model type: {model_provider}")
