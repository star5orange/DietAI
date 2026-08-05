"""社交关系 Pydantic 模型 - Milestone 4"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class RelationshipType(str, Enum):
    """关系类型"""
    FAMILY = "family"
    FRIEND = "friend"


class RelationshipStatus(str, Enum):
    """关系状态"""
    PENDING = "pending"
    ACCEPTED = "accepted"
    BLOCKED = "blocked"


# ============================================================
# 好友申请相关
# ============================================================

class FriendRequestCreate(BaseModel):
    """发送好友申请"""
    target_user_id: int = Field(..., description="目标用户ID")
    message: Optional[str] = Field(None, max_length=200, description="申请留言")
    relationship_label: Optional[str] = Field(None, max_length=50, description="对方与我的关系称谓（如：妈妈、爸爸）")


class FriendRequestResponse(BaseModel):
    """处理好友申请"""
    request_id: int = Field(..., description="申请记录ID")
    action: str = Field(..., description="accept|reject")


# ============================================================
# 用户关系响应
# ============================================================

class UserRelationResponse(BaseModel):
    """用户关系响应"""
    id: int
    user_id: int
    related_user_id: int
    relationship_type: str
    status: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserRelationWithProfile(BaseModel):
    """用户关系（含对方资料）"""
    relation_id: int
    user_id: int
    username: str
    real_name: Optional[str] = None
    avatar_url: Optional[str] = None
    gender: Optional[int] = Field(None, description="对方性别：1=男 2=女 3=其他")
    relationship_type: str
    status: str
    note: Optional[str] = Field(None, description="我方对该关系的称谓（如：妈妈）")
    created_at: datetime


class RelationNoteUpdate(BaseModel):
    """更新关系称谓"""
    relationship_label: str = Field(..., max_length=50, description="我方对该关系的称谓（如：妈妈）")


# ============================================================
# 添加家人相关
# ============================================================

class FamilyAddRequest(BaseModel):
    """添加家人请求"""
    target_user_id: int = Field(..., description="目标用户ID")
    relationship_label: Optional[str] = Field(None, max_length=50, description="关系标签（如：妈妈、爸爸）")


# ============================================================
# 搜索用户
# ============================================================

class UserSearchResult(BaseModel):
    """用户搜索结果"""
    id: int
    username: str
    real_name: Optional[str] = None
    avatar_url: Optional[str] = None
    gender: Optional[int] = Field(None, description="对方性别：1=男 2=女 3=其他")
    is_friend: bool = Field(False, description="是否已是好友")
    is_family: bool = Field(False, description="是否已是家人")
    pending_friend: bool = Field(False, description="是否有待处理的好友申请（已发送）")
    pending_family: bool = Field(False, description="是否有待处理的家人申请（已发送）")


# ============================================================
# 好友列表
# ============================================================

class FriendListResponse(BaseModel):
    """好友列表响应"""
    family: List[UserRelationWithProfile] = Field(default_factory=list, description="家人列表")
    friends: List[UserRelationWithProfile] = Field(default_factory=list, description="好友列表")


# ============================================================
# 数据权限相关
# ============================================================

class DataPermissionUpdate(BaseModel):
    """更新数据权限"""
    target_user_id: int = Field(..., description="目标用户ID")
    visible_fields: List[str] = Field(..., description="可见字段列表")


class DataPermissionResponse(BaseModel):
    """数据权限响应"""
    target_user_id: int
    visible_fields: List[str]
