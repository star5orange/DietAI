from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.config.settings import get_settings
from shared.models.schemas import BaseResponse
import uuid
import json
import base64
import time
import os
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
