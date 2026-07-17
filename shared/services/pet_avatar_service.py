"""M3 AI 宠物形象生成服务 — 通义万相 + rembg 抠图 pipeline"""
import io
import logging
import os
import threading
import time
import traceback
from datetime import datetime
from typing import Optional, Dict, Any

from sqlalchemy.orm import Session

from shared.models.pet_models import PetProfile, PetAvatar
from shared.models.database import SessionLocal
from shared.config.minio_config import minio_client
from shared.services.real_pet_service import get_pet

logger = logging.getLogger(__name__)

# DashScope 配置
DASHSCOPE_API_KEY = os.environ.get("DASHSCOPE_API_KEY", "")
DASHSCOPE_IMAGE_MODEL = "wan2.1-t2i-plus"

# 本地位图存储目录（开发环境降级用）
LOCAL_AVATAR_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "avatar_output")
os.makedirs(LOCAL_AVATAR_DIR, exist_ok=True)

# MinIO bucket 路径前缀
MINIO_AVATAR_PREFIX = "pet_avatars"

# 预设品种兜底形象（需求文档 5.5）
PRESET_AVATARS: Dict[str, Dict[str, str]] = {
    "cat": {
        "英短": "https://minio.example.com/pet_avatars/presets/cat_british_shorthair.png",
        "布偶": "https://minio.example.com/pet_avatars/presets/cat_ragdoll.png",
        "暹罗": "https://minio.example.com/pet_avatars/presets/cat_siamese.png",
        "橘猫": "https://minio.example.com/pet_avatars/presets/cat_orange.png",
        "default": "https://minio.example.com/pet_avatars/presets/cat_default.png",
    },
    "dog": {
        "default": "https://minio.example.com/pet_avatars/presets/dog_default.png",
    },
}

# ============================================================
# 情绪 Prompt 模板（需求文档 5.3.2）
# ============================================================
EMOTION_PROMPTS = {
    "base": (
        "将这只宠物转换为Q版卡通形象："
        "保留宠物的品种特征和毛色花纹位置，保留瞳色，"
        "风格：扁平化矢量插画风，纯白色背景 #FFFFFF，正面全身，"
        "保持原宠物辨识度，让人一看就知道是同一只。"
    ),
    "happy": (
        "同一只Q版卡通宠物，开心表情：眯眼笑、耳朵竖起、尾巴上翘，"
        "纯白色背景 #FFFFFF，正面全身，保持角色完全一致。"
    ),
    "normal": (
        "同一只Q版卡通宠物，自然表情：安静站立、眼睛自然睁开，"
        "纯白色背景 #FFFFFF，正面全身，保持角色完全一致。"
    ),
    "hungry": (
        "同一只Q版卡通宠物，饥饿表情：可怜巴巴、低头、耳朵下垂、看向食物碗，"
        "纯白色背景 #FFFFFF，正面全身，保持角色完全一致。"
    ),
    "weak": (
        "同一只Q版卡通宠物，虚弱状态：趴下、眼睛半闭、精神不佳，"
        "纯白色背景 #FFFFFF，正面全身，保持角色完全一致。"
    ),
}

EMOTION_KEYS = ["base", "happy", "normal", "hungry", "weak"]
EMOTION_URL_FIELDS = {
    "base": "base_image_url",
    "happy": "emotion_happy_url",
    "normal": "emotion_normal_url",
    "hungry": "emotion_hungry_url",
    "weak": "emotion_weak_url",
}


# ============================================================
# 公共入口
# ============================================================

def trigger_avatar_generation(
    pet_id: int, user_id: int,
    mode: str = "description",
    photo: Optional[str] = None,
    description: Optional[str] = None,
) -> str:
    """触发异步生成，返回 task_id"""
    db = SessionLocal()
    try:
        pet = get_pet(db, pet_id, user_id)
        if not pet:
            raise ValueError("宠物不存在")

        # 获取或创建 avatar 记录
        avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
        if not avatar:
            avatar = PetAvatar(pet_id=pet_id)
            db.add(avatar)

        avatar.status = "processing"
        avatar.error_message = None
        db.commit()
        db.refresh(avatar)

        task_id = f"gen_{pet_id}_{int(datetime.utcnow().timestamp())}"

        # 后台线程执行
        thread = threading.Thread(
            target=_run_generation_pipeline,
            args=(pet_id, user_id, mode, photo, description),
            daemon=True,
        )
        thread.start()

        logger.info(f"Avatar generation started: pet_id={pet_id}, task_id={task_id}")
        return task_id

    except Exception as e:
        logger.error(f"Failed to trigger avatar generation: {e}")
        raise
    finally:
        db.close()


def get_generation_status(task_id: str) -> Dict[str, Any]:
    """查询生成任务状态"""
    try:
        pet_id = int(task_id.split("_")[1])
    except (IndexError, ValueError):
        return {"task_id": task_id, "status": "not_found"}

    db = SessionLocal()
    try:
        avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
        if not avatar:
            return {"task_id": task_id, "status": "not_found"}

        result = {
            "task_id": task_id,
            "status": avatar.status,
            "progress": "done" if avatar.status == "done" else avatar.status,
        }
        if avatar.status == "done":
            result["result"] = {
                "base_image_url": avatar.base_image_url,
                "emotions": {
                    "happy": avatar.emotion_happy_url,
                    "normal": avatar.emotion_normal_url,
                    "hungry": avatar.emotion_hungry_url,
                    "weak": avatar.emotion_weak_url,
                },
                "seed": avatar.generation_seed,
                "has_gif": avatar.has_gif,
                "gif_url": avatar.gif_url,
            }
        elif avatar.status == "failed":
            result["error_message"] = avatar.error_message

        return result
    finally:
        db.close()


def regenerate_emotion(pet_id: int, user_id: int, emotion: str) -> Dict[str, Any]:
    """重新生成单个情绪变体"""
    if emotion not in ("happy", "normal", "hungry", "weak"):
        raise ValueError(f"无效的情绪类型: {emotion}")

    db = SessionLocal()
    try:
        pet = get_pet(db, pet_id, user_id)
        if not pet:
            raise ValueError("宠物不存在")

        avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
        if not avatar or not avatar.base_image_url:
            raise ValueError("请先生成基础形象")

        seed = (pet_id * 10000) + EMOTION_KEYS.index(emotion)

        # 生成单个情绪变体
        img_bytes = _call_dashscope_image(
            prompt=EMOTION_PROMPTS[emotion],
            reference_image=avatar.base_image_url,
            seed=seed,
            breed=pet.breed or "",
        )

        # 抠图
        img_bytes = _remove_background(img_bytes)

        # 上传
        object_name = f"{MINIO_AVATAR_PREFIX}/pet_{pet_id}_{emotion}_{int(time.time())}.png"
        upload_ok = minio_client.upload_file(object_name, img_bytes, "image/png")
        if not upload_ok:
            raise RuntimeError("MinIO 上传失败")

        url = minio_client.get_file_url(object_name)
        setattr(avatar, EMOTION_URL_FIELDS[emotion], url)
        db.commit()

        logger.info(f"Emotion regenerated: pet_id={pet_id}, emotion={emotion}")
        return {"status": "done", "emotion": emotion, "url": url}
    finally:
        db.close()


def upgrade_to_gif(pet_id: int, user_id: int) -> Dict[str, Any]:
    """生成 4 帧微变体 → FFmpeg 合成 GIF（P1）"""
    db = SessionLocal()
    try:
        pet = get_pet(db, pet_id, user_id)
        if not pet:
            raise ValueError("宠物不存在")

        avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
        if not avatar or not avatar.emotion_happy_url:
            raise ValueError("请先生成情绪变体")

        import subprocess
        import tempfile

        base_seed = pet_id * 10000

        # 生成 4 帧微变体
        frames = []
        micro_prompts = [
            "同一只Q版卡通宠物，尾巴微微向左摆",
            "同一只Q版卡通宠物，尾巴摆到最左边",
            "同一只Q版卡通宠物，尾巴摆回中间",
            "同一只Q版卡通宠物，尾巴微微向右摆",
        ]

        for i, prompt in enumerate(micro_prompts):
            full_prompt = f"{prompt}，纯白色背景 #FFFFFF，正面全身，保持角色完全一致。"
            frame_bytes = _call_dashscope_image(
                prompt=full_prompt,
                reference_image=avatar.emotion_happy_url,
                seed=base_seed + 100 + i,
                breed=pet.breed or "",
            )
            frame_bytes = _remove_background(frame_bytes)
            frames.append(frame_bytes)

        # FFmpeg 合成 GIF
        with tempfile.TemporaryDirectory() as tmpdir:
            for i, f in enumerate(frames):
                path = os.path.join(tmpdir, f"frame_{i:03d}.png")
                with open(path, "wb") as fh:
                    fh.write(f)

            gif_path = os.path.join(tmpdir, "output.gif")
            subprocess.run([
                "ffmpeg", "-y",
                "-framerate", "4",
                "-i", os.path.join(tmpdir, "frame_%03d.png"),
                "-vf", "fps=12,scale=512:512",
                gif_path,
            ], check=True, capture_output=True)

            with open(gif_path, "rb") as fh:
                gif_bytes = fh.read()

        # 上传 GIF
        object_name = f"{MINIO_AVATAR_PREFIX}/pet_{pet_id}_happy.gif"
        upload_ok = minio_client.upload_file(object_name, gif_bytes, "image/gif")
        if not upload_ok:
            raise RuntimeError("MinIO GIF 上传失败")

        gif_url = minio_client.get_file_url(object_name)
        avatar.has_gif = True
        avatar.gif_url = gif_url
        db.commit()

        logger.info(f"GIF generated: pet_id={pet_id}")
        return {"status": "done", "gif_url": gif_url}
    except Exception as e:
        logger.error(f"GIF generation failed: {e}")
        raise
    finally:
        db.close()


# ============================================================
# 后台生成 Pipeline
# ============================================================

def _run_generation_pipeline(
    pet_id: int, user_id: int, mode: str,
    photo: Optional[str], description: Optional[str],
):
    """后台线程执行完整生成流程"""
    db = SessionLocal()
    try:
        pet = get_pet(db, pet_id, user_id)
        if not pet:
            _fail_avatar(db, pet_id, "宠物不存在")
            return

        avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
        if not avatar:
            _fail_avatar(db, pet_id, "Avatar 记录不存在")
            return

        breed_desc = pet.breed or ""
        species_desc = f"{pet.species} " if pet.species else ""

        try:
            # ---- Step a: 生成基础形象 ----
            _update_progress(avatar)
            base_prompt = f"一只{species_desc}{breed_desc}的Q版卡通形象，{EMOTION_PROMPTS['base']}"
            if description:
                base_prompt = f"{description}的Q版卡通形象，{EMOTION_PROMPTS['base']}"

            base_seed = pet_id * 10000
            base_img = _call_dashscope_image(
                prompt=base_prompt,
                reference_image=photo,
                seed=base_seed,
                breed=breed_desc,
            )

            # ---- Step b: 并行生成情绪变体 ----
            emotion_images: Dict[str, bytes] = {"base": base_img}
            for emotion in ["happy", "normal", "hungry", "weak"]:
                idx = EMOTION_KEYS.index(emotion)
                emotion_seed = base_seed + idx
                img = _call_dashscope_image(
                    prompt=EMOTION_PROMPTS[emotion],
                    reference_image=photo or description,
                    seed=emotion_seed,
                    breed=breed_desc,
                )
                emotion_images[emotion] = img
                _update_progress(avatar)

            # ---- Step c: rembg 抠图 ----
            for emotion, img in list(emotion_images.items()):
                try:
                    emotion_images[emotion] = _remove_background(img)
                except Exception as e:
                    logger.warning(f"rembg failed for {emotion}, using original: {e}")
                    # 保留原始图片，不中断流程

            # ---- Step d: 上传 MinIO ----
            urls: Dict[str, str] = {}
            timestamp = int(time.time())
            for emotion in EMOTION_KEYS:
                img_bytes = emotion_images.get(emotion)
                if not img_bytes:
                    continue
                object_name = f"{MINIO_AVATAR_PREFIX}/pet_{pet_id}_{emotion}_{timestamp}.png"
                upload_ok = minio_client.upload_file(object_name, img_bytes, "image/png")
                if upload_ok:
                    urls[emotion] = minio_client.get_file_url(object_name)
                else:
                    logger.error(f"MinIO upload failed for {emotion}")

            # ---- Step e: 更新数据库 ----
            avatar.base_image_url = urls.get("base")
            avatar.emotion_happy_url = urls.get("happy")
            avatar.emotion_normal_url = urls.get("normal")
            avatar.emotion_hungry_url = urls.get("hungry")
            avatar.emotion_weak_url = urls.get("weak")
            avatar.generation_seed = base_seed
            avatar.prompt_used = base_prompt
            avatar.ai_model = DASHSCOPE_IMAGE_MODEL
            avatar.status = "done"
            avatar.error_message = None
            db.commit()

            logger.info(f"Avatar generation done: pet_id={pet_id}")

        except _AIApiUnavailableError as e:
            logger.warning(f"AI API unavailable, falling back to preset: {e}")
            _fallback_to_preset(db, pet, avatar)

        except Exception as e:
            logger.error(f"Generation pipeline failed: {e}\n{traceback.format_exc()}")
            _fail_avatar(db, pet_id, str(e)[:500])

    except Exception as e:
        logger.error(f"Pipeline outer error: {e}")
        try:
            _fail_avatar(db, pet_id, str(e)[:500])
        except Exception:
            pass
    finally:
        db.close()


# ============================================================
# DashScope API 调用
# ============================================================

class _AIApiUnavailableError(Exception):
    """AI API 不可用（欠费/网络等），触发兜底降级"""
    pass


def _call_dashscope_image(
    prompt: str,
    reference_image: Optional[str] = None,
    seed: Optional[int] = None,
    breed: str = "",
) -> bytes:
    """调用通义万相 API 生成图片，返回图片 bytes"""
    if not DASHSCOPE_API_KEY:
        raise _AIApiUnavailableError("DASHSCOPE_API_KEY not set")

    try:
        import dashscope
        from dashscope import ImageSynthesis

        kwargs = {
            "model": DASHSCOPE_IMAGE_MODEL,
            "prompt": prompt,
            "n": 1,
            "size": "1024*1024",
        }
        if seed is not None:
            kwargs["seed"] = seed
        if reference_image:
            # 如果 reference_image 是 base64，直接传入
            if reference_image.startswith("data:") or len(reference_image) > 500:
                kwargs["ref_img"] = reference_image
            # 如果只有一个 base 调用，则用纯文生图模式（ref_image 传空也行）

        response = ImageSynthesis.call(**kwargs)

        if response.status_code != 200:
            raise _AIApiUnavailableError(
                f"DashScope API error: code={response.status_code}, msg={response.message}"
            )

        # 提取图片 URL 并下载
        results = response.output.get("results", [])
        if not results:
            raise RuntimeError("DashScope 返回空结果")

        img_url = results[0].get("url", "")
        if not img_url:
            raise RuntimeError("DashScope 返回的图片 URL 为空")

        # 下载图片
        import requests as http_requests
        resp = http_requests.get(img_url, timeout=30)
        if resp.status_code != 200:
            raise RuntimeError(f"下载生成图片失败: HTTP {resp.status_code}")

        return resp.content

    except _AIApiUnavailableError:
        raise
    except ImportError:
        raise _AIApiUnavailableError("dashscope SDK not installed")
    except Exception as e:
        error_msg = str(e).lower()
        if any(kw in error_msg for kw in ("auth", "unauthorized", "quota", "balance", "insufficient")):
            raise _AIApiUnavailableError(f"AI API 不可用: {e}")
        raise


# ============================================================
# rembg 抠图
# ============================================================

def _remove_background(img_bytes: bytes) -> bytes:
    """rembg 抠图：输入 PNG bytes，返回透明背景 PNG bytes"""
    try:
        from rembg import remove
        return remove(img_bytes)
    except ImportError:
        logger.warning("rembg not installed, skipping background removal")
        return img_bytes
    except Exception as e:
        logger.warning(f"rembg failed: {e}, using original image")
        return img_bytes


# ============================================================
# 兜底逻辑
# ============================================================

def _fallback_to_preset(db: Session, pet: PetProfile, avatar: PetAvatar):
    """AI 不可用时降级为预设品种形象"""
    species_map = PRESET_AVATARS.get(pet.species, PRESET_AVATARS.get("cat", {}))
    preset_url = species_map.get(pet.breed, species_map.get("default"))

    # 尝试对预设图也抠图（如果文件是本地可访问的）
    try:
        if preset_url and not preset_url.startswith("http"):
            with open(preset_url, "rb") as f:
                preset_bytes = f.read()
            preset_bytes = _remove_background(preset_bytes)
            object_name = f"{MINIO_AVATAR_PREFIX}/pet_{pet.id}_preset_nobg.png"
            minio_client.upload_file(object_name, preset_bytes, "image/png")
            preset_url = minio_client.get_file_url(object_name)
    except Exception:
        pass  # 兜底图不可抠也不影响

    now = datetime.utcnow()
    avatar.status = "done"
    avatar.base_image_url = preset_url
    avatar.emotion_happy_url = preset_url
    avatar.emotion_normal_url = preset_url
    avatar.emotion_hungry_url = preset_url
    avatar.emotion_weak_url = preset_url
    avatar.generation_seed = pet.id * 10000
    avatar.prompt_used = f"preset_fallback: {pet.species}/{pet.breed}"
    avatar.ai_model = "preset_fallback"
    avatar.updated_at = now
    db.commit()
    logger.info(f"Fallback preset applied for pet_id={pet.id}")


def _fail_avatar(db: Session, pet_id: int, error_msg: str):
    """标记生成失败"""
    avatar = db.query(PetAvatar).filter(PetAvatar.pet_id == pet_id).first()
    if avatar:
        avatar.status = "failed"
        avatar.error_message = error_msg
        db.commit()


def _update_progress(avatar: PetAvatar):
    """更新进度时间戳（通过 updated_at 反映进度）"""
    avatar.updated_at = datetime.utcnow()
