"""DashScope qwen-vl 视觉模型调用公共工具（包装食品 / 宠物食品 OCR 共用）

提供：
- API Key 获取（优先 Settings，回退环境变量）
- 模型回退链（账号额度/开通情况因模型而异，逐个尝试直到成功）
- 图片 + Prompt → 结构化 JSON 的调用与解析

背景（2026-09 实测）：账号下 qwen-vl-plus 免费额度已耗尽（403
AllocationQuota.FreeTierOnly），而 qwen-vl-max 可用。若写死单个模型，
OCR 会静默失败并返回兜底空值，前端只看到"未识别"，难以排查。
"""

import json
import logging
import os
import re

from openai import OpenAI

from shared.config.settings import get_settings

logger = logging.getLogger("dashscope_vl_ocr")

DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"

# 默认模型回退链：优先用实测可用的模型，逐个降级尝试
DEFAULT_MODELS = ("qwen-vl-max", "qwen-vl-plus", "qwen-vl-ocr")


def get_api_key() -> str:
    """获取 DashScope API Key：Settings（已加载 .env/.env.dev）优先，其次环境变量"""

    try:
        key = get_settings().dashscope_api_key or ""
    except Exception:  # 配置异常时不阻塞调用方，退回环境变量
        key = ""
    return key or os.getenv("DASHSCOPE_API_KEY", "")


def candidate_models(env_var: str) -> list:
    """返回按优先级排序、去重后的候选模型列表

    Args:
        env_var: 可选的环境变量名，用于显式指定模型（覆盖默认回退链）
    """

    configured = os.getenv(env_var, "").strip()
    models = ([configured] if configured else []) + list(DEFAULT_MODELS)
    seen, result = set(), []
    for model in models:
        if model and model not in seen:
            seen.add(model)
            result.append(model)
    return result


def call_vl_json(
    image_base64: str,
    prompt: str,
    *,
    max_tokens: int = 600,
    temperature: float = 0.1,
    env_var: str = "DIETAI_VL_OCR_MODEL",
) -> dict:
    """调用 qwen-vl 视觉模型并解析返回的 JSON

    Returns:
        {"data": dict | None, "raw_text": str, "model": str}
        data 为 None 表示模型有响应但不是 JSON
    Raises:
        RuntimeError: 所有候选模型均调用失败（消息内含最后一个错误原因）
    """

    api_key = get_api_key()
    if not api_key:
        raise RuntimeError("未配置 DASHSCOPE_API_KEY")

    client = OpenAI(api_key=api_key, base_url=DASHSCOPE_BASE_URL)

    last_error = ""
    for model in candidate_models(env_var):
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[{
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"}
                        },
                        {"type": "text", "text": prompt},
                    ]
                }],
                max_tokens=max_tokens,
                temperature=temperature,
            )

            content = response.choices[0].message.content or ""
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                try:
                    data = json.loads(json_match.group(0))
                except json.JSONDecodeError:
                    last_error = f"{model} 返回 JSON 解析失败"
                    logger.warning(f"[{model}] JSON 解析失败: {content[:200]}")
                    continue
                return {"data": data, "raw_text": content, "model": model}

            last_error = f"{model} 返回非 JSON 内容"
            logger.warning(f"[{model}] 返回非 JSON: {content[:200]}")

        except Exception as e:
            last_error = f"{model}: {type(e).__name__} {str(e)[:160]}"
            logger.warning(f"[{model}] 视觉模型调用失败: {e}")

    raise RuntimeError(last_error or "无可用视觉模型")
