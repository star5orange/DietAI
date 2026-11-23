"""家庭成员 Pydantic schemas（V6 多成员归属，PRD §5.1）"""
from typing import Optional
from datetime import datetime

from pydantic import BaseModel, Field


# --- 请求 ---

class FamilyMemberCreate(BaseModel):
    """创建家庭成员"""
    display_name: str = Field(..., min_length=1, max_length=32, description="显示名")
    alias: Optional[str] = Field(None, max_length=128, description="别名，逗号分隔（语音匹配用）")
    avatar: Optional[str] = Field(None, max_length=256, description="头像 URL")
    birth_year: Optional[int] = Field(None, ge=1900, le=2100, description="出生年")
    member_type: int = Field(0, ge=0, le=3, description="0 成人 / 1 老人 / 2 儿童 / 3 其他")
    is_managed: bool = Field(True, description="是否由主账号代管（无账号成员为 true）")
    sort_order: int = Field(0, ge=0, description="设备端展示顺序")


class FamilyMemberUpdate(BaseModel):
    """编辑家庭成员（部分更新；停用传 is_active=false）"""
    display_name: Optional[str] = Field(None, min_length=1, max_length=32)
    alias: Optional[str] = Field(None, max_length=128)
    avatar: Optional[str] = Field(None, max_length=256)
    birth_year: Optional[int] = Field(None, ge=1900, le=2100)
    member_type: Optional[int] = Field(None, ge=0, le=3)
    is_managed: Optional[bool] = None
    is_active: Optional[bool] = Field(None, description="停用标记：false 后历史保留、不可再新增归属")
    sort_order: Optional[int] = Field(None, ge=0)


class AttributionChangeRequest(BaseModel):
    """记录归属修改（契约 C7：设备纠错 screen / App 手动 manual）"""
    record_type: str = Field(..., description="food / water")
    record_id: int = Field(..., ge=1)
    member_id: Optional[int] = Field(None, ge=1, description="目标成员；空=归属账号本人")
    attributed_by: str = Field(..., description="screen（设备纠错）/ manual（App 手动改）")


# --- 响应 ---

class FamilyMemberOut(BaseModel):
    """App 视角完整字段"""
    id: int
    display_name: str
    alias: Optional[str] = None
    avatar: Optional[str] = None
    birth_year: Optional[int] = None
    member_type: int
    is_managed: bool
    is_active: bool
    sort_order: int
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
