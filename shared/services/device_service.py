"""设备绑定服务 — 配对码生成、验证、device_token 颁发"""
import random
import logging
from datetime import datetime, timedelta
from typing import Optional, Tuple

from sqlalchemy.orm import Session
from jose import jwt

from shared.models.device_models import Device
from shared.models.user_models import User
from shared.utils.auth import AuthService

logger = logging.getLogger(__name__)

# 配对码有效期
PAIRING_CODE_TTL = timedelta(minutes=5)
# device_token 有效期 (365天)
DEVICE_TOKEN_EXPIRE_DAYS = 365


class AlreadyBoundError(Exception):
    """设备已绑定，携带 device_token"""
    def __init__(self, device_token: str):
        self.device_token = device_token
        super().__init__("设备已绑定")


def _generate_pairing_code() -> str:
    """生成 6 位数字配对码"""
    return f"{random.randint(0, 999999):06d}"


def request_pairing(db: Session, device_key: str) -> Tuple[str, int]:
    """
    ESP32 请求配对码。
    返回 (pairing_code, expires_in_seconds)
    """
    # 查找或创建设备记录
    device = db.query(Device).filter(Device.device_key == device_key).first()

    if device and device.is_bound and device.device_token:
        # 已绑定的设备重新请求 → 返回已有 token (可能 ESP32 NVS 被清空了)
        # 通过返回特殊标记让调用方知道
        raise AlreadyBoundError(device.device_token)

    now = datetime.utcnow()
    code = _generate_pairing_code()
    expires_at = now + PAIRING_CODE_TTL

    if device:
        # 更新已有记录的配对码
        device.pairing_code = code
        device.pairing_expires_at = expires_at
    else:
        # 新建设备记录
        device = Device(
            device_key=device_key,
            pairing_code=code,
            pairing_expires_at=expires_at,
            is_bound=False,
        )
        db.add(device)

    db.commit()
    db.refresh(device)

    logger.info(f"[Device] 配对码生成: device_key={device_key}, code={code}")
    return code, int(PAIRING_CODE_TTL.total_seconds())


def confirm_pairing(db: Session, user_id: int, pairing_code: str) -> Device:
    """
    App 确认配对。
    验证配对码 → 绑定用户 → 颁发 device_token → 返回 Device 对象
    """
    now = datetime.utcnow()

    # 查找配对码对应的设备
    device = db.query(Device).filter(
        Device.pairing_code == pairing_code,
        Device.is_bound == False,
        Device.pairing_expires_at > now,
    ).first()

    if not device:
        raise ValueError("配对码无效或已过期")

    # 单设备绑定：如果用户已有绑定设备，解绑旧设备
    old_device = db.query(Device).filter(
        Device.user_id == user_id,
        Device.is_bound == True,
    ).first()
    if old_device:
        old_device.is_bound = False
        old_device.user_id = None
        old_device.device_token = None
        logger.info(f"[Device] 旧设备解绑: device_id={old_device.id}")

    # 生成 device_token (长期 JWT, type=device)
    device_token = _create_device_token(device.id, user_id)

    # 绑定
    device.user_id = user_id
    device.is_bound = True
    device.device_token = device_token
    device.pairing_code = None
    device.pairing_expires_at = None
    device.last_seen_at = now

    db.commit()
    db.refresh(device)

    logger.info(f"[Device] 绑定成功: device_id={device.id}, user_id={user_id}")
    return device


def poll_pairing(db: Session, device_key: str) -> Optional[str]:
    """
    ESP32 轮询配对状态。
    返回 device_token (已绑定) 或 None (未绑定)
    """
    device = db.query(Device).filter(Device.device_key == device_key).first()

    if device and device.is_bound and device.device_token:
        # 更新最后在线时间
        device.last_seen_at = datetime.utcnow()
        db.commit()
        return device.device_token

    return None


def get_device_status(db: Session, user_id: int) -> Optional[Device]:
    """查询用户绑定的设备"""
    return db.query(Device).filter(
        Device.user_id == user_id,
        Device.is_bound == True,
    ).first()


def unbind_device(db: Session, user_id: int) -> bool:
    """解绑设备"""
    device = db.query(Device).filter(
        Device.user_id == user_id,
        Device.is_bound == True,
    ).first()

    if not device:
        return False

    device.is_bound = False
    device.user_id = None
    device.device_token = None
    db.commit()

    logger.info(f"[Device] 解绑: device_id={device.id}, user_id={user_id}")
    return True


def get_user_by_device_token(db: Session, device_token: str) -> Optional[User]:
    """通过 device_token 获取绑定的用户 (供 auth.py 调用)"""
    device = db.query(Device).filter(
        Device.device_token == device_token,
        Device.is_bound == True,
    ).first()

    if not device or not device.user_id:
        return None

    return db.query(User).filter(User.id == device.user_id).first()


def _create_device_token(device_id: int, user_id: int) -> str:
    """生成 device_token (长期 JWT)"""
    from shared.utils.auth import _get_signing_key, ALGORITHM
    from shared.config.settings import settings

    expire = datetime.utcnow() + timedelta(days=DEVICE_TOKEN_EXPIRE_DAYS)
    payload = {
        "sub": str(device_id),
        "user_id": user_id,
        "type": "device",
        "exp": expire,
    }
    return jwt.encode(payload, _get_signing_key(), algorithm=ALGORITHM)
