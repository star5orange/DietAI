from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException
from pydantic import BaseModel, Field
from shared.models.database import get_db, SessionLocal
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.config.settings import get_settings
from shared.models.schemas import BaseResponse
import uuid
import json
import base64
import time
import os
import logging
import requests as http_requests

settings = get_settings()
router = APIRouter(prefix="/voice", tags=["语音识别"])

# 豆包录音文件识别标准版 API
ASR_SUBMIT_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit"
ASR_QUERY_URL = "https://openspeech.bytedance.com/api/v3/auc/bigmodel/query"


@router.post("/recognize", summary="语音识别")
async def recognize_voice(
    audio: UploadFile = File(..., description="音频文件(wav/mp3/ogg)"),
    current_user: User = Depends(get_current_user),
):
    """上传音频文件，调用豆包 Seed-ASR 2.0 标准版识别为文字（base64 直传）"""
    api_key = settings.volc_asr_api_key
    if not api_key:
        raise HTTPException(status_code=500, detail="语音识别服务未配置")

    # 1. 读取上传的音频数据并 base64 编码
    content = await audio.read()
    suffix = os.path.splitext(audio.filename or "audio.wav")[1] or ".wav"
    audio_format = suffix.lstrip(".").lower()

    print(f"[ASR] 收到音频: filename={audio.filename}, size={len(content)} bytes, format={audio_format}")

    if len(content) == 0:
        raise HTTPException(status_code=400, detail="音频文件为空，请重新录音")

    audio_b64 = base64.b64encode(content).decode("utf-8")

    # 2. 提交识别任务
    task_id = str(uuid.uuid4())
    resource_id = settings.volc_asr_resource_id

    headers = {
        "X-Api-Key": api_key,
        "X-Api-Resource-Id": resource_id,
        "X-Api-Request-Id": task_id,
        "X-Api-Sequence": "-1",
        "Content-Type": "application/json",
    }

    body = {
        "user": {"uid": str(current_user.id)},
        "audio": {
            "data": audio_b64,
            "format": audio_format,
        },
        "request": {
            "model_name": "bigmodel",
            "enable_itn": True,
            "enable_punc": True,
            "enable_ddc": True,
            "show_utterances": False,
        },
    }

    try:
        # 提交任务
        resp = http_requests.post(
            ASR_SUBMIT_URL,
            data=json.dumps(body),
            headers=headers,
            timeout=30,
        )

        status_code = resp.headers.get("X-Api-Status-Code", "")
        message = resp.headers.get("X-Api-Message", "")

        if status_code != "20000000":
            # 尝试从响应体获取更详细的错误信息
            try:
                error_body = resp.json()
                detail_msg = error_body.get("message", message)
            except Exception:
                detail_msg = message
            raise HTTPException(
                status_code=500,
                detail=f"提交识别任务失败: [{status_code}] {detail_msg}"
            )

        logid = resp.headers.get("X-Tt-Logid", "")

        # 3. 轮询查询结果（最多 60 秒）
        query_headers = {
            "X-Api-Key": api_key,
            "X-Api-Resource-Id": resource_id,
            "X-Api-Request-Id": task_id,
            "Content-Type": "application/json",
        }
        if logid:
            query_headers["X-Tt-Logid"] = logid

        for _ in range(30):
            time.sleep(2)
            q_resp = http_requests.post(
                ASR_QUERY_URL,
                data=json.dumps({}),
                headers=query_headers,
                timeout=30,
            )
            q_status = q_resp.headers.get("X-Api-Status-Code", "")

            if q_status == "20000000":
                result = q_resp.json()
                text = result.get("result", {}).get("text", "")
                if text:
                    return BaseResponse(success=True, message="识别成功", data={"text": text})
                else:
                    raise HTTPException(status_code=500, detail="未识别到语音内容，请重新录音")
            elif q_status in ("20000001", "20000002"):
                continue  # 处理中，继续轮询
            else:
                q_msg = q_resp.headers.get("X-Api-Message", "未知错误")
                # 静音音频 - 返回更友好的提示
                if "silence" in q_msg.lower() or "no valid speech" in q_msg.lower():
                    raise HTTPException(
                        status_code=400,
                        detail="未检测到语音，请对着麦克风说话后重试"
                    )
                raise HTTPException(
                    status_code=500,
                    detail=f"识别失败: [{q_status}] {q_msg}"
                )

        raise HTTPException(status_code=408, detail="识别超时，请重试")

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"识别失败: {str(e)}")


# ===== 硬件专用: 非流式食物分析 (异步提交 + 轮询) =====

class AnalyzeFoodRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=200, description="ASR 识别文字")

# 内存中的分析任务存储 (key=task_id, value={status, data, error})
_analyze_tasks: dict[str, dict] = {}


async def _run_analysis(task_id: str, text: str, user_id: int):
    """后台执行硬件专用 Agent 分析 (hardware_nutrition_agent, 精简快速)"""
    logging.warning(f"[HW_AGENT] START task={task_id[:8]}... text={text[:30]}...")

    from langgraph_sdk import get_client
    from routers.food_router import get_user_preferences, get_agent_model_config

    db = SessionLocal()
    try:
        user_prefs = await get_user_preferences(db, user_id)
        logging.warning(f"[HW_AGENT] user_prefs ok, connecting to {settings.ai_service_url}")

        client = get_client(url=settings.ai_service_url)
        assistant = await client.assistants.create(
            graph_id="hardware_nutrition_agent",
            config={"configurable": get_agent_model_config()}
        )
        logging.warning(f"[HW_AGENT] assistant created: {assistant['assistant_id'][:16]}...")

        thread = await client.threads.create()
        logging.warning(f"[HW_AGENT] thread created, streaming...")

        result = None
        chunk_count = 0
        async for chunk in client.runs.stream(
            assistant_id=assistant["assistant_id"],
            thread_id=thread['thread_id'],
            input={
                "text_description": text,
                "user_preferences": user_prefs
            },
            stream_mode="values"
        ):
            chunk_count += 1
            if chunk.data is not None:
                step = chunk.data.get("current_step", "?")
                if chunk_count <= 3 or step == "completed":
                    logging.warning(f"[HW_AGENT] chunk#{chunk_count} step={step}")
                if step == "completed":
                    result = chunk.data
                    logging.warning(f"[HW_AGENT] got completed!")
                    break

        logging.warning(f"[HW_AGENT] stream ended, {chunk_count} chunks, result={'yes' if result else 'no'}")

        if result is None:
            _analyze_tasks[task_id] = {"status": "failed", "data": None, "error": "AI 分析未返回结果"}
            return

        na = result.get("nutrition_analysis") or {}
        advice = result.get("nutrition_advice") or {}

        def to_dict(v):
            if hasattr(v, 'model_dump'): return v.model_dump()
            if hasattr(v, 'dict'): return v.dict()
            return v

        na_dict = to_dict(na)
        adv_dict = to_dict(advice)

        food_items = na_dict.get("food_items") or []
        # 硬件屏幕有限, 最多显示 5 个食物项
        if len(food_items) > 5:
            food_items = food_items[:5]
        total_cal = na_dict.get("total_calories") or 0

        recs = adv_dict.get("recommendations") or []
        tips = adv_dict.get("dietary_tips") or []
        warnings = adv_dict.get("warnings") or []
        best_rec = recs[0] if recs else (tips[0] if tips else (warnings[0] if warnings else ""))

        short_comment = best_rec if best_rec else ""

        _analyze_tasks[task_id] = {
            "status": "done",
            "data": {
                "food_items": food_items,
                "total_calories": total_cal,
                "short_comment": short_comment,
            },
            "error": None,
        }
        logging.warning(f"[HW_AGENT] done: {food_items} | {total_cal}kcal | {short_comment[:30]}...")

    except Exception as e:
        import traceback
        logging.warning(f"[HW_AGENT] EXCEPTION: {e}")
        traceback.print_exc()
        _analyze_tasks[task_id] = {"status": "failed", "data": None, "error": f"分析失败: {str(e)}"}
    finally:
        db.close()


@router.post("/analyze-food", summary="提交食物分析任务（硬件专用）")
async def analyze_food_submit(
    req: AnalyzeFoodRequest,
    current_user: User = Depends(get_current_user),
):
    """提交 ASR 文字, 立即返回 task_id; Agent 在后台异步分析"""
    import asyncio as _asyncio

    task_id = str(uuid.uuid4())
    _analyze_tasks[task_id] = {"status": "processing", "data": None, "error": None}
    logging.warning(f"[HW_AGENT] SUBMIT task_id={task_id[:8]}... text={req.text[:30]}...")

    _asyncio.create_task(_run_analysis(task_id, req.text, current_user.id))
    logging.warning(f"[HW_AGENT] async task scheduled")

    return BaseResponse(success=True, message="任务已提交", data={"task_id": task_id})


@router.get("/analyze-food/{task_id}", summary="查询分析结果（硬件专用）")
async def analyze_food_query(task_id: str):
    """轮询分析结果: status=processing/done/failed"""
    task = _analyze_tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在或已过期")

    if task["status"] == "processing":
        return BaseResponse(success=True, message="处理中", data={"status": "processing"})
    if task["status"] == "failed":
        return BaseResponse(success=False, message=task.get("error") or "未知错误",
                          data={"status": "failed"})

    return BaseResponse(success=True, message="分析完成",
                      data={"status": "done", **task["data"]})


# ============================================================
# 文本转语音 (TTS)
# ============================================================

# 火山引擎 TTS API (v3 — 豆包语音合成 2.0)
TTS_V3_URL = "https://openspeech.bytedance.com/api/v3/tts/unidirectional/sse"


class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500, description="要转换的文本")
    format: str = Field(default="pcm", description="音频编码: mp3 / wav / pcm")
    voice_type: str = Field(default="zh_female_linjianvhai_moon_bigtts", description="TTS 音色ID (邻家女孩)")


@router.post("/tts", summary="文本转语音 (豆包 TTS 2.0 v3 API)")
async def text_to_speech(
    req: TTSRequest,
    current_user: User = Depends(get_current_user),
):
    """将文本转换为语音并返回音频 (v3 SSE 单向流式)"""
    tts_api_key = settings.volc_tts_api_key or settings.volc_asr_api_key

    if not tts_api_key:
        raise HTTPException(status_code=500, detail="TTS 语音服务未配置")

    encoding = req.format.lower()
    if encoding not in ("mp3", "wav", "pcm"):
        raise HTTPException(status_code=400, detail="format 仅支持 mp3 / wav / pcm")

    # v3 API 请求头
    tts_resource_id = settings.volc_tts_resource_id or "seed-tts-1.0"
    is_tts_2 = tts_resource_id.startswith("seed-tts-2")

    headers = {
        "X-Api-Key": tts_api_key,
        "X-Api-Resource-Id": tts_resource_id,
        "Content-Type": "application/json",
    }

    # TTS 2.0 需要 model 字段, 1.0 不需要

    req_params = {
            "speaker": req.voice_type,
            "text": req.text,
            "audio_params": {
                "format": encoding,
                "sample_rate": 24000,
                "speech_rate": 0,
                # 降低 TTS 输出音量, 防止 MAX98357 功放 (GAIN=15dB) 削波导致声音沙哑
                # 取值范围 [-1, 1], 0=原始音量, 负值降低
                "volume_rate": -0.4,
            },
            "additions": json.dumps({
                "uid": str(current_user.id),
            }),
    }
    if is_tts_2:
        req_params["model"] = "seed-tts-2.0-standard"

    body = {"req_params": req_params}

    try:
        logging.warning(f"[TTS] v3 SSE: text={req.text[:40]}... format={encoding} speaker={req.voice_type}")
        resp = http_requests.post(
            TTS_V3_URL,
            data=json.dumps(body),
            headers=headers,
            timeout=30,
            stream=True,
        )

        if resp.status_code != 200:
            logging.warning(f"[TTS] Volcano HTTP {resp.status_code}, body={resp.text[:500]}")
            raise HTTPException(status_code=500,
                detail=f"TTS 请求失败: {resp.status_code}, 详情: {resp.text[:300]}")

        # v3 SSE 响应: event-type + data JSON 流
        # event 352 = 音频数据 (code=0, data=base64_audio)
        # event 351 = 句子信息 (code=0, sentence=...)
        # event 152 = 会话结束 (code=20000000, message="OK")
        audio_chunks = []
        current_event_type = None
        for line in resp.iter_lines(decode_unicode=True):
            if not line:
                continue
            # 解析 SSE event: 行
            if line.startswith("event:"):
                current_event_type = int(line[6:].strip())
                continue
            # 解析 SSE data: 行
            if not line.startswith("data:"):
                continue
            try:
                event = json.loads(line[5:].strip())
                code = event.get("code")

                # event 352 + code 0 → 音频数据
                if current_event_type == 352 and code == 0:
                    audio_b64 = event.get("data", "")
                    if audio_b64:
                        audio_chunks.append(base64.b64decode(audio_b64))
                    continue

                # event 152 + code 20000000 → 会话结束 (成功)
                if current_event_type == 152 and code == 20000000:
                    logging.info("[TTS] SSE session finish: OK")
                    break

                # event 351 → 句子信息, 跳过
                if current_event_type == 351:
                    continue

                # 其他未知事件
                if code not in (0, 3001, 3002, 3003):
                    msg = event.get("message", "未知错误")
                    logging.warning(f"[TTS] SSE unexpected event type={current_event_type} code={code}: {msg}")
            except (json.JSONDecodeError, AttributeError):
                continue

        if not audio_chunks:
            raise HTTPException(status_code=500, detail="TTS 未返回音频数据")

        audio_bytes = b"".join(audio_chunks)
        logging.warning(f"[TTS] Success: {len(audio_bytes)} bytes ({encoding})")

    except HTTPException:
        raise
    except Exception as e:
        logging.warning(f"[TTS] Unexpected error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"TTS 转换失败: {str(e)}")

    from fastapi.responses import Response

    mime_map = {"mp3": "audio/mpeg", "wav": "audio/wav", "pcm": "audio/pcm"}
    ext_map = {"mp3": "speech.mp3", "wav": "speech.wav", "pcm": "speech.pcm"}

    return Response(
        content=audio_bytes,
        media_type=mime_map.get(encoding, "audio/pcm"),
        headers={
            "Content-Disposition": f"inline; filename={ext_map.get(encoding, 'speech.pcm')}"
        }
    )
