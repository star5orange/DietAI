import os
from functools import lru_cache

from dotenv import load_dotenv
from langchain.chat_models import init_chat_model
from langchain_anthropic import ChatAnthropic
from langchain_community.chat_models import ChatTongyi

from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_qwq import ChatQwQ, ChatQwen

from agent.utils.configuration import *
from shared.config.settings import get_settings

DASHSCOPE_API_BASE = "https://dashscope.aliyuncs.com/compatible-mode/v1"
DEEPSEEK_API_BASE = "https://api.deepseek.com"


def _get_provider_value(model_provider) -> str:
    if isinstance(model_provider, Enum):
        return model_provider.value
    return str(model_provider)


def _llm_resilience_kwargs() -> dict:
    """LLM 统一超时/重试参数（PRD 5.1：外部依赖必须有超时与降级）。"""
    try:
        settings = get_settings()
        return {
            "timeout": settings.llm_request_timeout,
            "max_retries": settings.llm_max_retries,
        }
    except Exception:
        return {"timeout": 60, "max_retries": 2}


def _build_chat_model(model_cls, **kwargs):
    """构造 Chat 模型实例并附加统一超时/重试参数。

    个别 provider 若不支持 timeout/max_retries 参数，则退化为原始参数构造，
    保证不会因参数不支持而报错。
    """
    try:
        return model_cls(**kwargs, **_llm_resilience_kwargs())
    except Exception:
        return model_cls(**kwargs)


@lru_cache(maxsize=4)
def get_model(model_provider: Enum, model_name: str):
    load_dotenv(".env", override=True, encoding="utf-8")
    dashscope_api_key = os.getenv("DASHSCOPE_API_KEY", "")
    deepseek_api_key = os.getenv("DEEPSEEK_API_KEY", "") or os.getenv("DEEPSEEK_API_BASE", "")
    provider_val = _get_provider_value(model_provider)

    match provider_val:
        case "anthropic":
            return _build_chat_model(ChatAnthropic, model_name=model_name)
        case "openai":
            return _build_chat_model(ChatOpenAI, model_name=model_name, streaming=False)
        case "qwen":
            if dashscope_api_key:
                return _build_chat_model(
                    ChatOpenAI,
                    model=model_name,
                    base_url=DASHSCOPE_API_BASE,
                    api_key=dashscope_api_key,
                    streaming=False,
                    extra_body={
                        "enable_thinking": False,
                    },
                )
            return _build_chat_model(
                ChatQwen,
                model=model_name,
                model_kwargs={
                    "enable_thinking": True,
                },
                streaming=True,
            )
        case "deepseek":
            return _build_chat_model(
                ChatOpenAI,
                model=model_name,
                base_url=DEEPSEEK_API_BASE,
                api_key=deepseek_api_key,
                streaming=True,
            )
        case _:
            raise ValueError(f"Unsupported model type: {model_provider}")
