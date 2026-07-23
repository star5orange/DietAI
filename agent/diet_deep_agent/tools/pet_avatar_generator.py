"""
宠物形象生成工具

调用通义万相API生成宠物卡通形象，使用rembg抠图，生成情绪变体。
"""

import base64
import logging
import os
import time
from io import BytesIO
from typing import Any

import httpx
from langchain_core.tools import tool

logger = logging.getLogger(__name__)

# 通义万相API配置
WANX_API_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/image-generation/generation"
DASHSCOPE_API_KEY = os.getenv("DASHSCOPE_API_KEY", "")

# MinIO配置（用于存储生成的图片）
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")
MINIO_BUCKET = "pet-avatars"


@tool
def generate_pet_avatar(
    pet_id: int,
    description: str = "",
    style: str = "cartoon",
) -> dict[str, Any]:
    """生成宠物卡通形象。

    Args:
        pet_id: 宠物 ID
        description: 宠物外观描述（如"橘猫，白手套，绿眼睛"）
        style: 生成风格（cartoon/anime/realistic）

    Returns:
        生成任务信息，包含 task_id 和预计耗时
    """
    if not DASHSCOPE_API_KEY:
        logger.warning("DASHSCOPE_API_KEY 未配置，返回模拟结果")
        return _generate_mock_result(pet_id)

    # 构建prompt
    style_prompts = {
        "cartoon": "卡通风格，Q版，可爱，柔和色调",
        "anime": "动漫风格，日系，精美",
        "realistic": "写实风格，细节丰富",
    }
    style_suffix = style_prompts.get(style, style_prompts["cartoon"])

    prompt = f"一只{description}的宠物，{style_suffix}，透明背景，全身照，面向镜头"

    try:
        # 调用通义万相API
        response = httpx.post(
            WANX_API_URL,
            headers={
                "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "wanx-v2",
                "input": {
                    "prompt": prompt,
                    "negative_prompt": "照片，真实，恐怖，暴力，模糊，低质量",
                },
                "parameters": {
                    "style": "<cartoon>" if style == "cartoon" else "<sketch>",
                    "size": "512*512",
                    "n": 1,
                },
            },
            timeout=60.0,
        )

        if response.status_code != 200:
            logger.error(f"通义万相API错误: {response.text}")
            return {"error": "生成失败，请稍后重试", "status": "failed"}

        result = response.json()
        task_id = result.get("output", {}).get("task_id", f"gen_{pet_id}_{int(time.time())}")

        return {
            "task_id": task_id,
            "status": "processing",
            "estimated_seconds": 35,
            "message": "正在生成专属形象...",
        }

    except Exception as e:
        logger.error(f"调用通义万相API失败: {e}")
        return _generate_mock_result(pet_id)


@tool
def generate_emotion_variants(
    pet_id: int,
    description: str = "",
    style: str = "cartoon",
    emotions: list[str] = None,
) -> dict[str, Any]:
    """为宠物生成多情绪卡通形象变体。

    基于宠物品种和描述，为每种情绪生成对应的形象。

    Args:
        pet_id: 宠物 ID
        description: 宠物外观描述
        style: 生成风格（cartoon/anime/realistic）
        emotions: 需要生成的情绪列表（默认：happy, normal, hungry, weak）

    Returns:
        情绪变体映射 {emotion: image_url}
    """
    if emotions is None:
        emotions = ["happy", "normal", "hungry", "weak"]

    # 为每个情绪生成专属图片
    emotion_prompts = {
        "happy": f"{description}的宠物，开心快乐的表情，{style}风格，可爱，透明背景",
        "normal": f"{description}的宠物，平静放松的表情，{style}风格，可爱，透明背景",
        "hungry": f"{description}的宠物，饥饿想吃东西的表情，{style}风格，可爱，透明背景",
        "weak": f"{description}的宠物，疲惫虚弱的姿态，{style}风格，可爱，透明背景",
    }

    variants = {}
    for emotion in emotions:
        prompt = emotion_prompts.get(emotion, f"{description}的宠物，{style}风格，透明背景")

        try:
            response = httpx.post(
                WANX_API_URL,
                headers={
                    "Authorization": f"Bearer {DASHSCOPE_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "wanx-v2",
                    "input": {"prompt": prompt},
                    "parameters": {"size": "512*512", "n": 1},
                },
                timeout=60.0,
            )

            if response.status_code == 200:
                result = response.json()
                task_id = result.get("output", {}).get("task_id", "")
                variants[emotion] = {
                    "task_id": task_id,
                    "status": "processing",
                }
            else:
                logger.warning(f"情绪{emotion}生成失败: {response.status_code}")
                variants[emotion] = {"status": "failed"}
        except Exception as e:
            logger.error(f"情绪{emotion}生成异常: {e}")
            variants[emotion] = {"status": "failed", "error": str(e)}

    return {
        "status": "processing" if any(v.get("status") == "processing" for v in variants.values()) else "completed",
        "variants": variants,
        "note": "各情绪变体正在异步生成，可稍后通过 get_generation_task 查询进度",
    }


@tool
def remove_background(image_url: str) -> dict[str, Any]:
    """使用rembg移除图片背景。

    Args:
        image_url: 原始图片URL

    Returns:
        处理后的图片URL
    """
    try:
        # 下载图片
        response = httpx.get(image_url, timeout=30.0)
        if response.status_code != 200:
            return {"error": "图片下载失败"}

        # 使用rembg处理
        try:
            from rembg import remove
            from PIL import Image

            input_image = Image.open(BytesIO(response.content))
            output_image = remove(input_image)

            # 转换为base64
            buffer = BytesIO()
            output_image.save(buffer, format="PNG")
            base64_image = base64.b64encode(buffer.getvalue()).decode()

            return {
                "status": "completed",
                "base64_image": base64_image,
                "message": "背景已移除",
            }

        except ImportError:
            logger.warning("rembg 未安装，返回原图")
            return {
                "status": "skipped",
                "message": "rembg 未安装，跳过背景移除",
                "original_url": image_url,
            }

    except Exception as e:
        logger.error(f"背景移除失败: {e}")
        return {"error": str(e)}


def _generate_mock_result(pet_id: int) -> dict[str, Any]:
    """生成模拟结果（用于开发测试）"""
    return {
        "task_id": f"mock_{pet_id}_{int(time.time())}",
        "status": "completed",
        "message": "使用模拟结果",
        "result": {
            "base_image_url": f"assets/pet/mock_pet_{pet_id}.gif",
            "emotions": {
                "happy": "assets/pet/happy.gif",
                "normal": "assets/pet/normal.gif",
                "hungry": "assets/pet/hungry.gif",
                "weak": "assets/pet/weak.gif",
            },
        },
        "generation_time_seconds": 3,
    }