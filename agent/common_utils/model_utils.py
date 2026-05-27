import os
from functools import lru_cache

from dotenv import load_dotenv
from langchain.chat_models import init_chat_model
from langchain_anthropic import ChatAnthropic
from langchain_community.chat_models import ChatTongyi

from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain_qwq import ChatQwQ, ChatQwen

from agent.utils.configuration import *

DASHSCOPE_API_BASE = "https://dashscope.aliyuncs.com/compatible-mode/v1"


def _get_provider_value(model_provider) -> str:
    if isinstance(model_provider, Enum):
        return model_provider.value
    return str(model_provider)


@lru_cache(maxsize=4)
def get_model(model_provider: Enum, model_name: str):
    load_dotenv(".env", override=True)
    dashscope_api_key = os.getenv("DASHSCOPE_API_KEY", "")
    provider_val = _get_provider_value(model_provider)

    match provider_val:
        case "anthropic":
            return ChatAnthropic(model_name=model_name)
        case "openai":
            return ChatOpenAI(model_name=model_name, streaming=False)
        case "qwen":
            if dashscope_api_key:
                return ChatOpenAI(
                    model=model_name,
                    base_url=DASHSCOPE_API_BASE,
                    api_key=dashscope_api_key,
                    streaming=False,
                    extra_body={
                        "enable_thinking": False,
                    },
                )
            return ChatQwen(
                model=model_name,
                model_kwargs={
                    "enable_thinking": True,
                },
                streaming=True,
            )
        case "deepseek":
            return init_chat_model(model_name)
        case _:
            raise ValueError(f"Unsupported model type: {model_provider}")
