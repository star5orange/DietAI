from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime


class ConversationSessionCreate(BaseModel):
    session_type: int = Field(1, ge=1, le=4, description="会话类型：1营养咨询2健康评估3食物识别4运动建议")
    title: Optional[str] = Field(None, max_length=200, description="会话标题")


class ConversationCreate(BaseModel):
    title: Optional[str] = Field(None, max_length=200, description="会话标题")
    context: Optional[Dict[str, Any]] = Field(None, description="上下文信息")


class ConversationResponse(BaseModel):
    id: int
    user_id: int
    session_id: str
    title: Optional[str]
    status: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ConversationMessageCreate(BaseModel):
    content: str = Field(..., description="消息内容")
    message_type: int = Field(..., ge=1, le=3, description="消息类型：1用户消息2助手消息3系统消息")
    message_metadata: Optional[Dict[str, Any]] = Field(None, description="消息元数据")


class MessageCreate(BaseModel):
    content: str = Field(..., description="消息内容")
    message_type: int = Field(..., ge=1, le=3, description="消息类型：1文本2图片3语音")
    message_metadata: Optional[Dict[str, Any]] = Field(None, description="消息元数据")


class MessageResponse(BaseModel):
    id: int
    session_id: str
    content: str
    message_type: int
    sender_type: int
    message_metadata: Optional[Dict[str, Any]]
    created_at: datetime

    class Config:
        from_attributes = True