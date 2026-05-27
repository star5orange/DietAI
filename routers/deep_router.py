"""
DietDeepAgent 统一 API 路由

提供 DietDeepAgent 的 HTTP 端点：
- POST /api/deep/chat          统一对话入口（文字+图片）
- POST /api/deep/analyze        食物图像分析
- GET  /api/deep/daily-status   今日营养状态
- GET  /api/deep/memory/{uid}   查看用户记忆（调试用）
"""

import json
import logging
import uuid
from typing import Any, AsyncGenerator, Optional

from fastapi import APIRouter, Depends, HTTPException, Form, UploadFile, File, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from shared.models.database import get_db
from shared.models import user_models
from shared.utils.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/deep", tags=["DietDeepAgent"])


async def _resolve_deep_chat_params(
    request: Request,
    message: str,
    session_id: Optional[str],
) -> tuple[str, Optional[str]]:
    body: dict[str, Any] = {}
    content_type = request.headers.get("content-type", "") if request else ""

    try:
        if request and "application/json" in content_type:
            payload = await request.json()
            if isinstance(payload, dict):
                body = payload
        elif request and "form" in content_type:
            form = await request.form()
            body = dict(form)
    except Exception:
        body = {}

    return str(body.get("message", message) or ""), body.get("session_id", session_id)


def _get_agent():
    """延迟加载 DietDeepAgent"""
    from agents.chat_agent.diet_deep_agent.deep_agent import create_diet_deep_agent
    return create_diet_deep_agent()


# 缓存 agent 实例
_cached_agent = None


def _get_cached_agent():
    global _cached_agent
    if _cached_agent is None:
        _cached_agent = _get_agent()
    return _cached_agent


@router.post("/chat")
async def deep_chat(
    request: Request,
    message: str = "",
    session_id: Optional[str] = None,
    current_user: user_models.User = Depends(get_current_user),
):
    """
    DietDeepAgent 统一对话入口。

    支持文字消息，Agent 自动规划任务并调用工具。
    返回 SSE 流式响应。
    """
    message, session_id = await _resolve_deep_chat_params(request, message, session_id)

    async def generate_response() -> AsyncGenerator[str, None]:
        try:
            agent = _get_cached_agent()

            # 使用或创建 thread_id
            thread_id = session_id or f"deep-{uuid.uuid4().hex[:12]}"

            # 发送会话信息
            yield f"data: {json.dumps({'type': 'session', 'thread_id': thread_id})}\n\n"

            # 调用 DietDeepAgent
            config = {
                "configurable": {
                    "thread_id": thread_id,
                    "user_id": str(current_user.id),
                }
            }

            result = await agent.ainvoke(
                {"messages": [{"role": "user", "content": message}]},
                config=config,
            )

            # 提取最终回复
            messages = result.get("messages", [])
            if messages:
                last_msg = messages[-1]
                content = (
                    last_msg.content
                    if hasattr(last_msg, "content")
                    else str(last_msg)
                )
                yield f"data: {json.dumps({'type': 'content', 'content': content}, ensure_ascii=False)}\n\n"

            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.error(f"deep_chat error: {e}")
            yield f"data: {json.dumps({'type': 'error', 'error': str(e)}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        generate_response(),
        media_type="text/event-stream",
    )


@router.post("/analyze")
async def deep_analyze(
    image: UploadFile = File(...),
    message: str = Form("帮我分析这张食物图片"),
    current_user: user_models.User = Depends(get_current_user),
):
    """
    食物图像分析（通过 DietDeepAgent）。

    上传图片后 Agent 自动执行完整分析流程：
    食物识别 → 营养提取 → 过敏检查 → 目标影响 → 个性化建议
    """
    import base64

    # 读取图片并编码
    image_bytes = await image.read()
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    async def generate_response() -> AsyncGenerator[str, None]:
        try:
            agent = _get_cached_agent()
            thread_id = f"analyze-{uuid.uuid4().hex[:12]}"

            yield f"data: {json.dumps({'type': 'session', 'thread_id': thread_id})}\n\n"
            yield f"data: {json.dumps({'type': 'status', 'message': '正在分析食物图片...'})}\n\n"

            # 构造包含图片的消息
            user_content = [
                {"type": "text", "text": message},
                {
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                },
            ]

            config = {
                "configurable": {
                    "thread_id": thread_id,
                    "user_id": str(current_user.id),
                }
            }

            result = await agent.ainvoke(
                {"messages": [{"role": "user", "content": user_content}]},
                config=config,
            )

            messages = result.get("messages", [])
            if messages:
                last_msg = messages[-1]
                content = (
                    last_msg.content
                    if hasattr(last_msg, "content")
                    else str(last_msg)
                )
                yield f"data: {json.dumps({'type': 'analysis', 'content': content}, ensure_ascii=False)}\n\n"

            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'done'}, ensure_ascii=False)}\n\n"

        except Exception as e:
            logger.error(f"deep_analyze error: {e}")
            yield f"data: {json.dumps({'type': 'error', 'error': str(e)}, ensure_ascii=False)}\n\n"
            yield f"data: {json.dumps({'type': 'complete'}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        generate_response(),
        media_type="text/event-stream",
    )


@router.get("/daily-status")
async def deep_daily_status(
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    获取今日营养状态（直接调用工具，不经过 LLM）。
    """
    try:
        from agents.chat_agent.diet_deep_agent.tools.goal_tracking import get_daily_status

        result = get_daily_status.invoke({"user_id": current_user.id})
        return {"success": True, **result}

    except Exception as e:
        logger.error(f"deep_daily_status error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/memory/{user_id}")
async def get_user_memory(
    user_id: int,
    current_user: user_models.User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    查看用户记忆文件（调试用）。

    仅允许查看自己的记忆，或管理员权限。
    """
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="只能查看自己的记忆")

    try:
        from agents.chat_agent.memory.memory_manager import MemoryManager
        from agents.chat_agent.diet_deep_agent.memory.md_store import MarkdownStore

        manager = MemoryManager(user_id)
        store = MarkdownStore()

        workspaces = await manager.get_all_workspaces()

        memories_ns = ("memories", str(user_id))
        memory_files = {}
        for filename in ["profile.md", "goals.md", "nutrition.md", "preferences.md", "insights.md"]:
            item = store.get(memories_ns, filename)
            if item:
                memory_files[filename] = item.value.get("content", "")[:500]

        return {
            "user_id": user_id,
            "workspaces": {
                k: (v[:500] + "..." if v and len(v) > 500 else v)
                for k, v in workspaces.items()
            },
            "deep_agent_memories": memory_files,
        }

    except Exception as e:
        logger.error(f"get_user_memory error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
