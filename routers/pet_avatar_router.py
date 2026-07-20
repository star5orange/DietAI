"""M3 AI 宠物形象生成路由"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.services.pet_avatar_service import (
    trigger_avatar_generation,
    get_generation_status,
    regenerate_emotion,
    upgrade_to_gif,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/pets", tags=["AI宠物形象"])


# ========== 请求模型 ==========

class GenerateAvatarRequest(BaseModel):
    mode: str = Field("description", description="photo / description")
    photo: Optional[str] = Field(None, description="Base64 编码的宠物照片")
    description: Optional[str] = Field(None, description="文字描述（品种/毛色/瞳色等）")


class RegenerateEmotionRequest(BaseModel):
    emotion: str = Field(..., description="happy / normal / hungry / weak")


# ========== 路由 ==========

@router.post("/{pet_id}/generate-avatar", response_model=BaseResponse)
async def api_generate_avatar(
    pet_id: int,
    request: GenerateAvatarRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """触发 AI 生成宠物专属形象（异步）

    接收 mode=photo（传照片 base64）或 mode=description（传文字描述），
    立即返回 202 + task_id，后台执行：
    1. 通义万相生成基础卡通形象
    2. 并行生成 4 种情绪变体（开心/正常/饥饿/虚弱）
    3. rembg 自动抠图 → 透明背景 PNG
    4. 上传 MinIO → 更新数据库

    AI 不可用时自动降级为预设品种形象。
    """
    if request.mode not in ("photo", "description"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="mode 必须是 photo 或 description")

    try:
        task_id = trigger_avatar_generation(
            pet_id=pet_id,
            user_id=current_user.id,
            mode=request.mode,
            photo=request.photo,
            description=request.description,
        )
        return BaseResponse(
            success=True,
            message="生成任务已提交",
            data={"task_id": task_id, "status": "processing", "estimated_seconds": 35},
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception as e:
        logger.error(f"生成任务提交失败: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/generation-tasks/{task_id}", response_model=BaseResponse)
async def api_get_generation_task(
    task_id: str,
    current_user: User = Depends(get_current_user),
):
    """查询 AI 形象生成任务状态

    - status=processing: 正在生成中
    - status=done: 生成完成，result 包含各情绪图 URL
    - status=failed: 生成失败，error_message 包含原因
    """
    try:
        result = get_generation_status(task_id)
        return BaseResponse(success=True, message="查询成功", data=result)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/{pet_id}/regenerate-emotion", response_model=BaseResponse)
async def api_regenerate_emotion(
    pet_id: int,
    request: RegenerateEmotionRequest,
    current_user: User = Depends(get_current_user),
):
    """重新生成单个情绪变体（P1）

    需先生成基础形象。emotion 可选：happy / normal / hungry / weak
    """
    if request.emotion not in ("happy", "normal", "hungry", "weak"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="emotion 必须是 happy/normal/hungry/weak")

    try:
        result = regenerate_emotion(pet_id, current_user.id, request.emotion)
        return BaseResponse(success=True, message="情绪变体已重新生成", data=result)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"重生成情绪失败: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/{pet_id}/upgrade-to-gif", response_model=BaseResponse)
async def api_upgrade_to_gif(
    pet_id: int,
    current_user: User = Depends(get_current_user),
):
    """触发 GIF 真动画生成（P1 可选）

    生成 4 帧微变体图 → FFmpeg 运动补偿插值合成 GIF → 存 MinIO。
    需先生成基础形象和情绪变体。
    """
    try:
        result = upgrade_to_gif(pet_id, current_user.id)
        return BaseResponse(success=True, message="GIF 生成完成", data=result)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"GIF 生成失败: {e}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
