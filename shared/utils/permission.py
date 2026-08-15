"""家庭数据权限工具 - visible_fields 可见性过滤

数据权限语义：用户 A 可对家人 B 配置"哪些数据对 B 可见"（data_permissions 表）。
本模块提供统一的可见性查询，各家人数据接口在返回前按字段过滤。
无配置记录时默认全部可见（与需求"默认全部可见"一致）。
"""
from typing import Set

from sqlalchemy.orm import Session

# 与前端 permission_page.dart _allFields 的 key 保持一致
ALL_PERMISSION_FIELDS: Set[str] = {
    "calories",       # 热量摄入
    "water",          # 饮水记录
    "weight",         # 体重数据
    "exercise",       # 运动记录
    "health_goal",    # 健康目标
    "virtual_pet",    # 虚拟桌宠状态
    "real_pet",       # 真实宠物状态
    "exam_report",    # 体检报告
    "dietary_preferences",  # 饮食偏好
}


def get_visible_fields(db: Session, owner_id: int, viewer_id: int) -> Set[str]:
    """获取 owner 允许 viewer 查看的字段集合；无配置记录时默认全部可见"""
    from shared.models.social_models import DataPermission

    perm = db.query(DataPermission).filter(
        DataPermission.user_id == owner_id,
        DataPermission.target_user_id == viewer_id,
    ).first()
    if not perm:
        return set(ALL_PERMISSION_FIELDS)
    # 注意：visible_fields 为空列表表示 owner 显式配置"全部隐藏"，不能当成未配置
    return set(perm.visible_fields)


def field_hidden(visible: Set[str], key: str) -> bool:
    """字段是否被隐藏"""
    return key not in visible
