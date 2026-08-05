"""消息模型 - Milestone 4 实时消息系统"""
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from .database import Base


class Message(Base):
    """消息表"""
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, comment="NULL表示群发/系统消息")
    content = Column(Text, nullable=False)
    message_type = Column(String(20), nullable=False, default="text", comment="text|emoji|food_card|poke|system")
    extra_data = Column(JSONB, nullable=True, comment="附加数据（如food_card的食物信息）")
    read_at = Column(DateTime, nullable=True, comment="NULL表示未读")
    created_at = Column(DateTime, nullable=False, default=func.now())

    __table_args__ = (
        Index("idx_message_sender", "sender_id"),
        Index("idx_message_receiver", "receiver_id"),
        Index("idx_message_created", "created_at"),
        Index("idx_message_unread", "receiver_id", "read_at"),
    )
