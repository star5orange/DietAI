"""消息路由 - Milestone 4 实时消息系统"""
from fastapi import APIRouter, Depends, HTTPException, status, Query, WebSocket, WebSocketDisconnect, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, desc, func
from typing import List, Optional, Dict, Set
from datetime import datetime, timezone
import logging
import traceback
import json
import uuid
import asyncio

from shared.models.database import get_db
from shared.models.schemas import (
    BaseResponse,
    MessageSend, MessageResponse, MessageWithSender,
    ChatRoomResponse, MessageHistoryRequest, MessageHistoryResponse,
    PokeRequest,
)
from shared.utils.auth import get_current_user
from shared.models.user_models import User, UserProfile
from shared.models.message_models import Message
from shared.models.social_models import UserRelationship
from shared.models.food_models import FoodRecord
from shared.config.minio_config import minio_client

router = APIRouter(prefix="/messages", tags=["消息"])
logger = logging.getLogger(__name__)


# ============================================================
# 图片上传
# ============================================================

@router.post("/upload-image", response_model=BaseResponse)
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """上传图片并返回图片URL"""
    try:
        # 验证文件类型
        if not file.content_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只能上传图片文件"
            )

        # 验证文件大小（限制10MB）
        file_size = 0
        content = await file.read()
        file_size = len(content)
        if file_size > 10 * 1024 * 1024:  # 10MB
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="图片大小不能超过10MB"
            )

        # 生成唯一文件名
        file_ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
        object_name = f"chat-images/{current_user.id}/{uuid.uuid4()}.{file_ext}"

        # 上传到MinIO
        success = minio_client.upload_file(object_name, content, file.content_type)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="图片上传失败"
            )

        # 获取图片URL
        image_url = minio_client.get_file_url(object_name)
        if not image_url:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="获取图片URL失败"
            )

        return BaseResponse(
            success=True,
            message="图片上传成功",
            data={
                "image_url": image_url,
                "object_name": object_name
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"图片上传失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"图片上传失败: {str(e)}"
        )


# ============================================================
# WebSocket 连接管理器
# ============================================================

class ConnectionManager:
    """WebSocket 连接管理器"""
    
    def __init__(self):
        # user_id -> Set[WebSocket]
        self.active_connections: Dict[int, Set[WebSocket]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: int):
        """接受连接"""
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        logger.info(f"用户 {user_id} 已连接 WebSocket，当前连接数: {len(self.active_connections[user_id])}")
    
    def disconnect(self, websocket: WebSocket, user_id: int):
        """断开连接"""
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]
        logger.info(f"用户 {user_id} 已断开 WebSocket")
    
    async def send_to_user(self, user_id: int, message: dict):
        """向指定用户发送消息"""
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.error(f"发送消息给用户 {user_id} 失败: {e}")
    
    async def broadcast(self, message: dict, exclude_user: Optional[int] = None):
        """广播消息给所有在线用户"""
        for user_id, connections in self.active_connections.items():
            if exclude_user and user_id == exclude_user:
                continue
            for connection in connections:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.error(f"广播消息给用户 {user_id} 失败: {e}")
    
    def is_user_online(self, user_id: int) -> bool:
        """检查用户是否在线"""
        return user_id in self.active_connections and len(self.active_connections[user_id]) > 0


manager = ConnectionManager()


def _update_last_online(user_id: int):
    """持久化用户最后在线时间（WebSocket 连接建立/断开时更新）"""
    from shared.models.database import SessionLocal
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if user:
            user.last_online_at = datetime.now()
            db.commit()
    except Exception as e:
        logger.warning(f"更新最后在线时间失败: {e}")
    finally:
        db.close()


async def _notify_friends_online_status(user_id: int, is_online: bool):
    """向该用户的所有好友/家人广播在线状态变化事件"""
    from shared.models.database import SessionLocal
    db = SessionLocal()
    try:
        relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == user_id,
                UserRelationship.related_user_id == user_id,
            ),
            UserRelationship.status == "accepted"
        ).all()

        event = {
            "type": "online_status",
            "data": {
                "user_id": user_id,
                "is_online": is_online,
            }
        }
        for rel in relations:
            other_id = rel.related_user_id if rel.user_id == user_id else rel.user_id
            if other_id != user_id:
                await manager.send_to_user(other_id, event)
    finally:
        db.close()


async def _push_message_event(db: Session, msg: Message, sender_user: Optional[User] = None):
    """消息实时推送：接收者在线推 WS new_message，离线推 FCM 通知"""
    try:
        created_at = msg.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        if manager.is_user_online(msg.receiver_id):
            await manager.send_to_user(msg.receiver_id, {
                "type": "new_message",
                "data": {
                    "id": msg.id,
                    "sender_id": msg.sender_id,
                    "receiver_id": msg.receiver_id,
                    "content": msg.content,
                    "message_type": msg.message_type,
                    "extra_data": msg.extra_data,
                    "read_at": msg.read_at.isoformat() if msg.read_at else None,
                    "created_at": created_at.isoformat(),
                    "sender_username": sender_user.username if sender_user else None,
                    "sender_avatar_url": getattr(sender_user, "avatar_url", None) if sender_user else None,
                }
            })
        else:
            from shared.services.push_service import send_push_to_user
            await send_push_to_user(
                db=db,
                user_id=msg.receiver_id,
                title=f"{sender_user.username if sender_user else '家人'} 发来新消息",
                body=msg.content[:50],
                data={
                    "type": "new_chat_message",
                    "sender_id": msg.sender_id,
                    "sender_username": sender_user.username if sender_user else None,
                    "message_type": msg.message_type,
                },
            )
    except Exception as e:
        logger.warning(f"消息实时推送失败: {e}")


# ============================================================
# 发送消息
# ============================================================

@router.post("/send", response_model=BaseResponse)
async def send_message(
    message: MessageSend,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """发送消息"""
    try:
        # 检查接收者是否存在
        receiver = db.query(User).filter(
            User.id == message.receiver_id,
            User.status == 1
        ).first()
        if not receiver:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="接收者不存在"
            )

        # 检查是否是好友/家人关系
        is_related = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == message.receiver_id
                ),
                and_(
                    UserRelationship.user_id == message.receiver_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.status == "accepted"
        ).first()

        if not is_related:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能给好友/家人发送消息"
            )

        # 创建消息
        msg = Message(
            sender_id=current_user.id,
            receiver_id=message.receiver_id,
            content=message.content,
            message_type=message.message_type.value,
            extra_data=message.extra_data
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        # 确保 created_at 带 UTC 时区信息
        created_at = msg.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        # 接收者在线时通过 WebSocket 实时推送；不在线时发送 FCM 推送通知
        if manager.is_user_online(message.receiver_id):
            try:
                await manager.send_to_user(message.receiver_id, {
                    "type": "new_message",
                    "data": {
                        "id": msg.id,
                        "sender_id": msg.sender_id,
                        "receiver_id": msg.receiver_id,
                        "content": msg.content,
                        "message_type": msg.message_type,
                        "extra_data": msg.extra_data,
                        "read_at": msg.read_at.isoformat() if msg.read_at else None,
                        "created_at": created_at.isoformat(),
                        "sender_username": current_user.username,
                        "sender_avatar_url": getattr(current_user, "avatar_url", None),
                    }
                })
            except Exception as e:
                logger.warning(f"聊天消息 WebSocket 推送失败: {e}")
        else:
            try:
                from shared.services.push_service import send_push_to_user
                await send_push_to_user(
                    db=db,
                    user_id=message.receiver_id,
                    title=f"{current_user.username} 发来新消息",
                    body=message.content[:50],
                    data={
                        "type": "new_chat_message",
                        "sender_id": current_user.id,
                        "sender_username": current_user.username,
                        "message_type": msg.message_type,
                    },
                )
            except Exception as e:
                logger.warning(f"聊天消息推送失败: {e}")

        return BaseResponse(
            success=True,
            message="消息发送成功",
            data={
                "id": msg.id,
                "sender_id": msg.sender_id,
                "receiver_id": msg.receiver_id,
                "content": msg.content,
                "message_type": msg.message_type,
                "extra_data": msg.extra_data,
                "read_at": msg.read_at.isoformat() if msg.read_at else None,
                "created_at": created_at.isoformat(),
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送消息失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送消息失败"
        )


# ============================================================
# 聊天列表
# ============================================================

@router.get("/chat-list", response_model=BaseResponse)
async def get_chat_list(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取聊天列表（按最近消息排序）"""
    try:
        # 查询所有好友/家人
        relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.status == "accepted"
        ).all()

        chat_rooms = []
        for rel in relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            other_user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            # 获取最后一条消息
            last_msg = db.query(Message).filter(
                or_(
                    and_(Message.sender_id == current_user.id, Message.receiver_id == other_id),
                    and_(Message.sender_id == other_id, Message.receiver_id == current_user.id)
                )
            ).order_by(desc(Message.created_at)).first()

            # 获取未读消息数
            unread_count = db.query(func.count(Message.id)).filter(
                Message.sender_id == other_id,
                Message.receiver_id == current_user.id,
                Message.read_at.is_(None)
            ).scalar() or 0

            # 确保 last_message_time 带 UTC 时区信息
            last_message_time = None
            if last_msg:
                last_message_time = last_msg.created_at
                if last_message_time.tzinfo is None:
                    last_message_time = last_message_time.replace(tzinfo=timezone.utc)

            chat_rooms.append({
                "user_id": other_id,
                "username": other_user.username if other_user else "",
                "real_name": profile.real_name if profile else None,
                "avatar_url": other_user.avatar_url if other_user else None,
                "last_message": last_msg.content if last_msg else None,
                "last_message_time": last_message_time.isoformat() if last_message_time else None,
                "unread_count": unread_count,
            })

        # 按最后消息时间排序
        chat_rooms.sort(key=lambda x: x.get("last_message_time") or "", reverse=True)

        return BaseResponse(
            success=True,
            message="获取聊天列表成功",
            data=chat_rooms
        )
    except Exception as e:
        logger.error(f"获取聊天列表失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取聊天列表失败"
        )


# ============================================================
# 消息历史
# ============================================================

@router.get("/history/{target_user_id}", response_model=BaseResponse)
async def get_message_history(
    target_user_id: int,
    limit: int = Query(20, ge=1, le=100, description="加载数量"),
    before_id: Optional[int] = Query(None, description="加载此ID之前的消息"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取与某用户的消息历史"""
    try:
        # 检查是否是好友/家人关系
        is_related = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.status == "accepted"
        ).first()

        if not is_related:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能查看好友/家人的消息历史"
            )

        # 查询消息
        query = db.query(Message).filter(
            or_(
                and_(Message.sender_id == current_user.id, Message.receiver_id == target_user_id),
                and_(Message.sender_id == target_user_id, Message.receiver_id == current_user.id)
            )
        )

        if before_id:
            query = query.filter(Message.id < before_id)

        messages = query.order_by(desc(Message.created_at)).limit(limit + 1).all()

        has_more = len(messages) > limit
        messages = messages[:limit]

        # 反转顺序（按时间正序）
        messages.reverse()

        # 标记为已读
        db.query(Message).filter(
            Message.sender_id == target_user_id,
            Message.receiver_id == current_user.id,
            Message.read_at.is_(None)
        ).update({Message.read_at: datetime.now()}, synchronize_session=False)
        db.commit()

        # 获取发送者信息
        result_messages = []
        for msg in messages:
            sender = db.query(User).filter(User.id == msg.sender_id).first()

            # 确保 created_at 带 UTC 时区信息
            created_at = msg.created_at
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)

            read_at = msg.read_at
            if read_at and read_at.tzinfo is None:
                read_at = read_at.replace(tzinfo=timezone.utc)

            result_messages.append({
                "id": msg.id,
                "sender_id": msg.sender_id,
                "receiver_id": msg.receiver_id,
                "content": msg.content,
                "message_type": msg.message_type,
                "extra_data": msg.extra_data,
                "read_at": read_at.isoformat() if read_at else None,
                "created_at": created_at.isoformat(),
                "sender_username": sender.username if sender else "",
                "sender_avatar_url": sender.avatar_url if sender else None,
            })

        return BaseResponse(
            success=True,
            message="获取消息历史成功",
            data={
                "messages": result_messages,
                "has_more": has_more,
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取消息历史失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取消息历史失败"
        )


# ============================================================
# 戳一戳
# ============================================================

@router.post("/poke", response_model=BaseResponse)
async def send_poke(
    poke: PokeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """发送戳一戳"""
    try:
        # 检查接收者是否存在
        receiver = db.query(User).filter(
            User.id == poke.target_user_id,
            User.status == 1
        ).first()
        if not receiver:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="接收者不存在"
            )

        # 检查是否是好友/家人关系
        is_related = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == poke.target_user_id
                ),
                and_(
                    UserRelationship.user_id == poke.target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.status == "accepted"
        ).first()

        if not is_related:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能给好友/家人发送戳一戳"
            )

        # 创建戳一戳消息
        poke_content = {
            "water": "戳了戳你，提醒你喝水 💧",
            "eat": "戳了戳你，提醒你吃饭 🍚",
            "general": "戳了戳你 👋"
        }.get(poke.poke_type, "戳了戳你 👋")

        msg = Message(
            sender_id=current_user.id,
            receiver_id=poke.target_user_id,
            content=poke_content,
            message_type="poke",
            extra_data={"poke_type": poke.poke_type}
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        # 实时推送（接收者在线推 WS，离线推 FCM）
        await _push_message_event(db, msg, current_user)

        # 确保 created_at 带 UTC 时区信息
        created_at = msg.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        return BaseResponse(
            success=True,
            message="戳一戳发送成功",
            data={
                "id": msg.id,
                "sender_id": msg.sender_id,
                "receiver_id": msg.receiver_id,
                "content": msg.content,
                "message_type": msg.message_type,
                "extra_data": msg.extra_data,
                "read_at": msg.read_at.isoformat() if msg.read_at else None,
                "created_at": created_at.isoformat(),
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送戳一戳失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送戳一戳失败"
        )


# ============================================================
# 食物分享
# ============================================================

@router.post("/share-food", response_model=BaseResponse)
async def share_food_record(
    food_record_id: int = Query(..., description="食物记录ID"),
    receiver_id: int = Query(..., description="接收者ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """分享食物记录给好友/家人"""
    try:
        # 检查接收者是否存在
        receiver = db.query(User).filter(
            User.id == receiver_id,
            User.status == 1
        ).first()
        if not receiver:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="接收者不存在"
            )

        # 检查是否是好友/家人关系
        is_related = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == receiver_id
                ),
                and_(
                    UserRelationship.user_id == receiver_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.status == "accepted"
        ).first()

        if not is_related:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能给好友/家人分享食物"
            )

        # 检查食物记录是否存在且属于当前用户
        food_record = db.query(FoodRecord).filter(
            FoodRecord.id == food_record_id,
            FoodRecord.user_id == current_user.id
        ).first()

        if not food_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        # 构建食物卡片内容
        food_card_content = f"{food_record.food_name} {food_record.calories}卡"

        # 构建额外数据
        extra_data = {
            "food_record_id": food_record.id,
            "food_name": food_record.food_name,
            "calories": float(food_record.calories) if food_record.calories else 0,
            "protein": float(food_record.protein) if food_record.protein else 0,
            "fat": float(food_record.fat) if food_record.fat else 0,
            "carbohydrates": float(food_record.carbohydrates) if food_record.carbohydrates else 0,
            "image_url": food_record.image_url,
            "recorded_at": food_record.recorded_at.isoformat() if food_record.recorded_at else None
        }

        # 创建食物卡片消息
        msg = Message(
            sender_id=current_user.id,
            receiver_id=receiver_id,
            content=food_card_content,
            message_type="food_card",
            extra_data=extra_data
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        # 实时推送（接收者在线推 WS，离线推 FCM）
        await _push_message_event(db, msg, current_user)

        # 确保 created_at 带 UTC 时区信息
        created_at = msg.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        return BaseResponse(
            success=True,
            message="食物分享成功",
            data={
                "id": msg.id,
                "sender_id": msg.sender_id,
                "receiver_id": msg.receiver_id,
                "content": msg.content,
                "message_type": msg.message_type,
                "extra_data": msg.extra_data,
                "read_at": msg.read_at.isoformat() if msg.read_at else None,
                "created_at": created_at.isoformat(),
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"分享食物失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="分享食物失败"
        )


# ============================================================
# 未读消息数
# ============================================================

@router.get("/unread-count", response_model=BaseResponse)
async def get_unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取未读消息总数"""
    try:
        count = db.query(func.count(Message.id)).filter(
            Message.receiver_id == current_user.id,
            Message.read_at.is_(None)
        ).scalar() or 0

        return BaseResponse(
            success=True,
            message="获取未读消息数成功",
            data={"unread_count": count}
        )
    except Exception as e:
        logger.error(f"获取未读消息数失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取未读消息数失败"
        )


# ============================================================
# WebSocket 实时消息
# ============================================================

@router.websocket("/ws/{token}")
async def websocket_endpoint(websocket: WebSocket, token: str):
    """WebSocket 实时消息端点"""
    from shared.utils.auth import decode_access_token
    
    # 验证 token
    payload = decode_access_token(token)
    if not payload:
        await websocket.close(code=4001, reason="Invalid token")
        return
    
    # device token: sub=device_id, user_id=绑定的用户; user token: sub=user_id
    if payload.get("type") == "device":
        user_id = int(payload.get("user_id"))
    else:
        user_id = int(payload.get("sub"))
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token payload")
        return
    
    await manager.connect(websocket, user_id)

    # 持久化最后在线时间
    _update_last_online(user_id)

    # 广播上线事件给所有好友/家人
    await _notify_friends_online_status(user_id, True)

    try:
        while True:
            # 接收客户端消息（60 秒无任何消息则超时断开）
            data = await asyncio.wait_for(websocket.receive_text(), timeout=60)
            
            try:
                message_data = json.loads(data)
                msg_type = message_data.get("type")
                
                if msg_type == "ping":
                    # 心跳响应
                    await websocket.send_json({"type": "pong"})
                
                elif msg_type == "send_message":
                    # 发送消息
                    receiver_id = message_data.get("receiver_id")
                    content = message_data.get("content")
                    message_type = message_data.get("message_type", "text")
                    
                    if not receiver_id or not content:
                        await websocket.send_json({
                            "type": "error",
                            "message": "Missing receiver_id or content"
                        })
                        continue
                    
                    # 创建消息记录
                    from shared.models.database import SessionLocal
                    db = SessionLocal()
                    try:
                        # 校验接收者存在且为好友/家人关系
                        receiver = db.query(User).filter(
                            User.id == receiver_id,
                            User.status == 1
                        ).first()
                        if not receiver:
                            await websocket.send_json({
                                "type": "error",
                                "message": "接收者不存在"
                            })
                            continue

                        is_related = db.query(UserRelationship).filter(
                            or_(
                                and_(
                                    UserRelationship.user_id == user_id,
                                    UserRelationship.related_user_id == receiver_id
                                ),
                                and_(
                                    UserRelationship.user_id == receiver_id,
                                    UserRelationship.related_user_id == user_id
                                )
                            ),
                            UserRelationship.status == "accepted"
                        ).first()
                        if not is_related:
                            await websocket.send_json({
                                "type": "error",
                                "message": "只能给好友/家人发送消息"
                            })
                            continue

                        msg = Message(
                            sender_id=user_id,
                            receiver_id=receiver_id,
                            content=content,
                            message_type=message_type
                        )
                        db.add(msg)
                        db.commit()
                        db.refresh(msg)

                        # 接收者不在线时发送 FCM 推送通知
                        if not manager.is_user_online(receiver_id):
                            try:
                                from shared.services.push_service import send_push_to_user
                                sender_user = db.query(User).filter(User.id == user_id).first()
                                await send_push_to_user(
                                    db=db,
                                    user_id=receiver_id,
                                    title=f"{sender_user.username if sender_user else '家人'} 发来新消息",
                                    body=content[:50],
                                    data={
                                        "type": "new_chat_message",
                                        "sender_id": user_id,
                                        "sender_username": sender_user.username if sender_user else None,
                                        "message_type": message_type,
                                    },
                                )
                            except Exception as e:
                                logger.warning(f"WS 聊天消息推送失败: {e}")
                        
                        # 获取发送者信息
                        sender = db.query(User).filter(User.id == user_id).first()

                        # 确保 created_at 带 UTC 时区信息
                        created_at = msg.created_at
                        if created_at.tzinfo is None:
                            created_at = created_at.replace(tzinfo=timezone.utc)

                        # 构建消息响应
                        message_response = {
                            "type": "new_message",
                            "data": {
                                "id": msg.id,
                                "sender_id": user_id,
                                "receiver_id": receiver_id,
                                "content": content,
                                "message_type": message_type,
                                "created_at": created_at.isoformat(),
                                "sender_username": sender.username if sender else None,
                                "sender_avatar_url": sender.avatar_url if sender else None,
                            }
                        }
                        
                        # 发送给接收者（如果在线）
                        await manager.send_to_user(receiver_id, message_response)
                        
                        # 发送确认给发送者
                        await websocket.send_json({
                            "type": "message_sent",
                            "data": message_response["data"]
                        })
                    finally:
                        db.close()
                
                elif msg_type == "typing":
                    # 输入中状态
                    receiver_id = message_data.get("receiver_id")
                    if receiver_id:
                        await manager.send_to_user(receiver_id, {
                            "type": "user_typing",
                            "data": {
                                "user_id": user_id,
                                "receiver_id": receiver_id
                            }
                        })
                
                else:
                    await websocket.send_json({
                        "type": "error",
                        "message": f"Unknown message type: {msg_type}"
                    })
            
            except json.JSONDecodeError:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON"
                })
    
    except (asyncio.TimeoutError, WebSocketDisconnect):
        manager.disconnect(websocket, user_id)
        # 持久化最后在线时间
        _update_last_online(user_id)
        await _notify_friends_online_status(user_id, False)
        logger.info(f"用户 {user_id} WebSocket 连接断开（心跳超时或正常断开）")
    except Exception as e:
        logger.error(f"WebSocket 错误: {e}\n{traceback.format_exc()}")
        manager.disconnect(websocket, user_id)
        # 持久化最后在线时间
        _update_last_online(user_id)
        await _notify_friends_online_status(user_id, False)


@router.get("/online-status/{user_id}", response_model=BaseResponse)
async def get_online_status(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """检查用户是否在线"""
    try:
        is_online = manager.is_user_online(user_id)

        # 获取最后在线时间
        last_online_at = None
        target_user = db.query(User).filter(User.id == user_id).first()
        if target_user and target_user.last_online_at:
            last_online_at = target_user.last_online_at
            if last_online_at.tzinfo is None:
                last_online_at = last_online_at.replace(tzinfo=timezone.utc)
            last_online_at = last_online_at.isoformat()

        return BaseResponse(
            success=True,
            message="获取在线状态成功",
            data={
                "user_id": user_id,
                "is_online": is_online,
                "last_online_at": last_online_at,
            }
        )
    except Exception as e:
        logger.error(f"获取在线状态失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取在线状态失败"
        )


# ============================================================
# 离线消息（拉取所有未读消息）
# ============================================================

@router.get("/offline-messages", response_model=BaseResponse)
async def get_offline_messages(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取离线期间的所有未读消息（用户上线后调用）"""
    try:
        # 查询所有未读消息
        unread_messages = db.query(Message).filter(
            Message.receiver_id == current_user.id,
            Message.read_at.is_(None)
        ).order_by(desc(Message.created_at)).limit(100).all()

        # 按发送者分组
        messages_by_sender: Dict[int, list] = {}
        for msg in unread_messages:
            if msg.sender_id not in messages_by_sender:
                messages_by_sender[msg.sender_id] = []
            messages_by_sender[msg.sender_id].append(msg)

        # 构建响应
        result = []
        for sender_id, messages in messages_by_sender.items():
            sender = db.query(User).filter(User.id == sender_id).first()

            # 确保 created_at 带 UTC 时区信息
            for msg in messages:
                created_at = msg.created_at
                if created_at.tzinfo is None:
                    created_at = created_at.replace(tzinfo=timezone.utc)
                msg.created_at = created_at

            result.append({
                "sender_id": sender_id,
                "sender_username": sender.username if sender else "",
                "sender_avatar_url": sender.avatar_url if sender else None,
                "messages": [
                    {
                        "id": msg.id,
                        "sender_id": msg.sender_id,
                        "receiver_id": msg.receiver_id,
                        "content": msg.content,
                        "message_type": msg.message_type,
                        "extra_data": msg.extra_data,
                        "created_at": msg.created_at.isoformat(),
                    }
                    for msg in messages
                ],
                "unread_count": len(messages)
            })

        # 按消息数量降序排序
        result.sort(key=lambda x: x["unread_count"], reverse=True)

        # 拉取离线消息视为已读，避免每次进入聊天页重复拉取同一批消息
        if unread_messages:
            for msg in unread_messages:
                msg.read_at = datetime.now()
            db.commit()

        return BaseResponse(
            success=True,
            message="获取离线消息成功",
            data={
                "total_unread": len(unread_messages),
                "senders": result
            }
        )
    except Exception as e:
        logger.error(f"获取离线消息失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取离线消息失败"
        )
