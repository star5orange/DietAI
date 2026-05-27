from pydantic import BaseModel, Field
from typing import Optional, Any, Dict, TypeVar, Generic
from datetime import datetime, date

T = TypeVar('T')


class BaseResponse(BaseModel, Generic[T]):
    success: bool = Field(..., description="是否成功")
    message: str = Field(..., description="消息")
    data: Optional[Any] = Field(None, description="数据")
    timestamp: datetime = Field(default_factory=datetime.now, description="时间戳")


class PaginatedResponse(BaseResponse):
    pagination: Optional[Dict[str, Any]] = Field(None, description="分页信息")


class PaginationParams(BaseModel):
    page: int = Field(1, ge=1, description="页码")
    page_size: int = Field(20, ge=1, le=100, description="每页大小")
    sort_by: Optional[str] = Field(None, description="排序字段")
    sort_order: Optional[str] = Field("desc", description="排序顺序：asc,desc")


class DateRangeParams(BaseModel):
    start_date: Optional[date] = Field(None, description="开始日期")
    end_date: Optional[date] = Field(None, description="结束日期")


class FileUploadResponse(BaseModel):
    file_id: str
    file_name: str
    file_url: str
    file_size: int
    content_type: str
    upload_time: datetime
