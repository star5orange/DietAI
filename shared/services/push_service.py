"""
FCM 推送通知服务

使用 Firebase Admin SDK 向用户设备发送推送通知。
支持：喝水提醒、吃饭提醒、节气切换通知等。
"""

import logging
from typing import Optional, List
import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.orm import Session

from shared.config.settings import get_settings
from shared.models.device_token_models import DeviceToken

logger = logging.getLogger(__name__)

_firebase_app: Optional[firebase_admin.App] = None


def _get_firebase_app() -> Optional[firebase_admin.App]:
    """获取 Firebase App 实例（懒加载）"""
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    settings = get_settings()
    if not settings.fcm_enabled:
        logger.info("FCM 推送未启用")
        return None

    try:
        cred = credentials.Certificate(settings.fcm_service_account_path)
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK 初始化成功")
        return _firebase_app
    except Exception as e:
        logger.error(f"Firebase Admin SDK 初始化失败: {e}")
        return None


def _get_user_tokens(db: Session, user_id: int) -> List[str]:
    """获取用户的所有有效 FCM token"""
    tokens = (
        db.query(DeviceToken)
        .filter(
            DeviceToken.user_id == user_id,
            DeviceToken.is_active == True,
        )
        .all()
    )
    return [t.token for t in tokens]


async def send_push_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Optional[dict] = None,
    reminder_id: Optional[int] = None,
    reminder_type: Optional[str] = None,
) -> int:
    """
    向指定用户发送 FCM 推送通知。

    Args:
        db: 数据库会话
        user_id: 用户ID
        title: 通知标题
        body: 通知内容
        data: 附加数据（可选，将作为 payload 传递）
        reminder_id: 关联的提醒ID（可选）
        reminder_type: 提醒类型 water/meal（可选）

    Returns:
        成功发送的消息数
    """
    app = _get_firebase_app()
    if app is None:
        logger.warning("FCM 未初始化，跳过推送")
        return 0

    tokens = _get_user_tokens(db, user_id)
    if not tokens:
        logger.debug(f"用户 {user_id} 无有效的 FCM token")
        return 0

    # 构建消息数据
    payload = {
        "reminder_id": str(reminder_id) if reminder_id else "",
        "reminder_type": reminder_type or "",
        **(data or {}),
    }

    success_count = 0
    for token in tokens:
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={k: str(v) for k, v in payload.items()},
                token=token,
                android=messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="dietai_reminders",
                        priority="high",
                        default_sound=True,
                        default_vibrate_timings=True,
                    ),
                ),
                apns=messaging.APNSConfig(
                    headers={"apns-priority": "10"},
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(
                            sound="default",
                            badge=1,
                        ),
                    ),
                ),
            )
            messaging.send(message, app=app)
            success_count += 1
            logger.info(f"FCM 推送成功: user={user_id}, title={title}")
        except messaging.UnregisteredError:
            # Token 已失效，标记为非活跃
            logger.info(f"FCM token 已失效: user={user_id}, token={token[:20]}...")
            db.query(DeviceToken).filter(
                DeviceToken.token == token
            ).update({"is_active": False})
            db.commit()
        except Exception as e:
            logger.error(f"FCM 推送失败: user={user_id}, error={e}")

    return success_count


async def send_multicast_push(
    db: Session,
    user_ids: List[int],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> int:
    """
    向多个用户批量发送 FCM 推送（如节气切换通知）。
    """
    app = _get_firebase_app()
    if app is None:
        return 0

    success_count = 0
    for user_id in user_ids:
        count = await send_push_to_user(db, user_id, title, body, data)
        success_count += count

    return success_count


def cleanup_invalid_tokens(db: Session) -> int:
    """清理数据库中已失效的 token"""
    count = db.query(DeviceToken).filter(
        DeviceToken.is_active == False
    ).delete()
    db.commit()
    if count:
        logger.info(f"清理了 {count} 个失效的 FCM token")
    return count
