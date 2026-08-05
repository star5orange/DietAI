"""消息 Pydantic 模型 - Milestone 4"""
from pydantic import BaseModel, Field
from typing import Optional, List, Any, Dict
from datetime import datetime
from enum import Enum


class MessageType(str, Enum):
    """消息类型"""
    TEXT = "text"
    EMOJI = "emoji"
    FOOD_CARD = "food_card"
    POKE = "poke"
    SYSTEM = "system"
    IMAGE = "image"


# ============================================================
# 消息发送
# ============================================================

class MessageSend(BaseModel):
    """发送消息"""
    receiver_id: int = Field(..., description="接收者ID")
    content: str = Field(..., max_length=2000, description="消息内容")
    message_type: MessageType = Field(MessageType.TEXT, description="消息类型")
    extra_data: Optional[Dict[str, Any]] = Field(None, description="附加数据")


# ============================================================
# 消息响应
# ============================================================

class MessageResponse(BaseModel):
    """消息响应"""
    id: int
    sender_id: int
    receiver_id: Optional[int] = None
    content: str
    message_type: str
    extra_data: Optional[Dict[str, Any]] = None
    read_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class MessageWithSender(MessageResponse):
    """消息（含发送者信息）"""
    sender_username: Optional[str] = None
    sender_avatar_url: Optional[str] = None


# ============================================================
# 聊天列表
# ============================================================

class ChatRoomResponse(BaseModel):
    """聊天室（会话列表项）"""
    user_id: int
    username: str
    real_name: Optional[str] = None
    avatar_url: Optional[str] = None
    last_message: Optional[str] = None
    last_message_time: Optional[datetime] = None
    unread_count: int = Field(0, description="未读消息数")


# ============================================================
# 消息历史
# ============================================================

class MessageHistoryRequest(BaseModel):
    """消息历史请求"""
    target_user_id: int = Field(..., description="对方用户ID")
    before_id: Optional[int] = Field(None, description="加载此ID之前的消息")
    limit: int = Field(20, ge=1, le=100, description="加载数量")


class MessageHistoryResponse(BaseModel):
    """消息历史响应"""
    messages: List[MessageWithSender]
    has_more: bool = Field(False, description="是否还有更多消息")


# ============================================================
# 戳一戳
# ============================================================

class PokeRequest(BaseModel):
    """戳一戳请求"""
    target_user_id: int = Field(..., description="目标用户ID")
    poke_type: str = Field("water", description="poke类型：water|eat|general")


# ============================================================
# WebSocket 消息
# ============================================================

class WSMessage(BaseModel):
    """WebSocket消息格式"""
    type: str = Field(..., description="message|read|typing|online|offline")
    data: Dict[str, Any] = Field(default_factory=dict)
