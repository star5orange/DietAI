"""家庭成员路由 — V6 多成员归属（契约 C1 成员列表 / 1.3 成员 CRUD / C7 归属纠错）

鉴权双模式（C1）：用户 JWT（App 用）或 device_token（设备用）。
设备模式下家庭由令牌决定（devices.home_user_id，缺失时回退原 user_id）。
"""
from fastapi import APIRouter, Depends, Request, HTTPException, status
from sqlalchemy.orm import Session
from typing import Optional
import logging
import traceback

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.models.schemas.family_member import (
    FamilyMemberCreate, FamilyMemberUpdate, AttributionChangeRequest,
)
from shared.models.family_models import FamilyMember
from shared.models.food_models import FoodRecord
from shared.models.water_models import WaterIntakeRecord
from shared.models.device_models import Device
from shared.models.user_models import User
from shared.utils.auth import get_current_user, AuthService
from shared.services.family_member_service import (
    get_member_version, bump_member_version, get_default_member_id,
    get_member_in_family, ensure_member_capacity,
)

router = APIRouter(prefix="/family", tags=["家庭成员"])
logger = logging.getLogger(__name__)

# C7 attributed_by 允许值（设备纠错 / App 手动改）
ATTRIBUTION_CHANGE_SOURCES = {"screen", "manual"}


# ============================================================
# 令牌上下文：识别设备模式，解析家庭
# ============================================================

def _resolve_request_context(
    request: Request, current_user: User, db: Session
) -> dict:
    """从 Authorization 头解析调用方上下文。

    返回 {"user", "home_user_id", "device"}；
    device 为 None 表示 App 用户 JWT 模式。
    """
    auth_header = request.headers.get("Authorization", "")
    token = auth_header[7:].strip() if auth_header.lower().startswith("bearer ") else ""
    device = None
    try:
        payload = AuthService.verify_token(token)
        if payload.get("type") == "device":
            device_id = payload.get("sub")
            if device_id is not None:
                device = db.query(Device).filter(Device.id == int(device_id)).first()
    except Exception:
        device = None

    if device is not None:
        # 设备模式：家庭由令牌决定（home_user_id 迁移自 user_id 换算，缺失时回退）
        home_user_id = device.home_user_id or device.user_id
    else:
        home_user_id = current_user.id
    return {"user": current_user, "home_user_id": home_user_id, "device": device}


def _member_to_dict(m: FamilyMember, full: bool) -> dict:
    """设备视角精简字段（契约 C1）；full=True 时附加 App 视角字段"""
    data = {
        "id": m.id,
        "display_name": m.display_name,
        "alias": m.alias,
        "member_type": m.member_type,
        "sort_order": m.sort_order,
        "is_managed": m.is_managed,
    }
    if full:
        data.update({
            "avatar": m.avatar,
            "birth_year": m.birth_year,
            "is_active": m.is_active,
            "created_at": m.created_at.isoformat() if m.created_at else None,
            "updated_at": m.updated_at.isoformat() if m.updated_at else None,
        })
    return data


# ============================================================
# C1：家庭成员列表（设备拉取 + NVS 缓存 / App 成员管理共用）
# ============================================================

@router.get("/members", response_model=BaseResponse)
async def get_family_members(
    request: Request,
    if_version: Optional[int] = None,
    include_inactive: bool = False,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """家庭成员列表。

    - if_version 与服务端版本一致 → data=null, message="unchanged"（省流量）
    - current_member_id：device_token 调用 = 该设备自己的当前成员；App 调用恒为 null
    - default_member_id：家庭默认成员（首个创建），无启用成员时 null
    """
    try:
        ctx = _resolve_request_context(request, current_user, db)
        home_user_id = ctx["home_user_id"]
        if home_user_id is None:
            return BaseResponse(success=True, message="unchanged", data=None)

        version = get_member_version(db, home_user_id)
        if if_version is not None and if_version == version:
            return BaseResponse(success=True, message="unchanged", data=None)

        query = db.query(FamilyMember).filter(FamilyMember.home_user_id == home_user_id)
        if not include_inactive:
            query = query.filter(FamilyMember.is_active == True)  # noqa: E712
        members = query.order_by(
            FamilyMember.sort_order.asc(), FamilyMember.id.asc()
        ).all()

        device = ctx["device"]
        data = {
            "version": version,
            "current_member_id": device.current_member_id if device else None,
            "locked_member_id": device.locked_member_id if device else None,
            "default_member_id": get_default_member_id(db, home_user_id),
            "members": [_member_to_dict(m, full=True) for m in members],
        }
        return BaseResponse(success=True, message="获取家庭成员列表成功", data=data)
    except Exception as e:
        logger.error(f"获取家庭成员列表失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="获取家庭成员列表失败")


# ============================================================
# 1.3：成员 CRUD（创建 / 编辑 / 停用）——仅 App 用户可操作
# ============================================================

@router.post("/members", response_model=BaseResponse)
async def create_family_member(
    body: FamilyMemberCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """创建家庭成员（上限 8 人；成员不需要注册账号）"""
    try:
        try:
            ensure_member_capacity(db, current_user.id)
        except ValueError as ve:
            return BaseResponse(success=False, message=str(ve), data=None)

        member = FamilyMember(home_user_id=current_user.id, **body.model_dump())
        db.add(member)
        db.commit()
        db.refresh(member)
        bump_member_version(current_user.id)

        return BaseResponse(
            success=True,
            message="创建成员成功",
            data=_member_to_dict(member, full=True),
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"创建家庭成员失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="创建家庭成员失败")


@router.patch("/members/{member_id}", response_model=BaseResponse)
async def update_family_member(
    member_id: int,
    body: FamilyMemberUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """编辑成员（部分更新）；停用后历史记录保留、不可再新增归属（F1）"""
    try:
        member, reason = get_member_in_family(db, current_user.id, member_id)
        # 停用的成员允许再编辑（改回启用 / 改资料），只挡"不存在/非本家庭"
        if member is None and reason == "inactive":
            member = db.query(FamilyMember).filter(
                FamilyMember.id == member_id,
                FamilyMember.home_user_id == current_user.id,
            ).first()
        if member is None:
            return BaseResponse(success=False, message="成员不存在或不属于本家庭", data=None)

        updates = body.model_dump(exclude_unset=True)
        for field, value in updates.items():
            setattr(member, field, value)
        db.commit()
        db.refresh(member)
        bump_member_version(current_user.id)

        return BaseResponse(
            success=True,
            message="更新成员成功",
            data=_member_to_dict(member, full=True),
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"更新家庭成员失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="更新家庭成员失败")


# ============================================================
# C7：记录归属修改（设备短按纠错 screen / App 手动改 manual 共用）
# ============================================================

@router.post("/attribution/change", response_model=BaseResponse)
async def change_record_attribution(
    body: AttributionChangeRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """修改已落库记录的归属（F5 纠错）。

    - operator_user_id 由后端从令牌派生，不接受客户端传入（防冒充）
    - 双重校验：记录属于本家庭 + 目标成员属于本家庭且 is_active
    - 设备模式同时更新 devices.current_member_id（纠错切人 = 当前成员变了）
    - 幂等：同一 record_id 重复纠错以最后一次为准
    """
    try:
        ctx = _resolve_request_context(request, current_user, db)
        home_user_id = ctx["home_user_id"]
        device = ctx["device"]

        if body.attributed_by not in ATTRIBUTION_CHANGE_SOURCES:
            return BaseResponse(
                success=False,
                message=f"attributed_by 仅允许 {'/'.join(sorted(ATTRIBUTION_CHANGE_SOURCES))}",
                data=None,
            )

        # 操作者派生：App JWT → 当前用户；device_token → 绑定账号
        operator_user_id = device.user_id if device is not None else current_user.id

        # 目标成员校验（member_id 空 = 归属账号本人，合法）
        member = None
        if body.member_id is not None:
            member, reason = get_member_in_family(db, home_user_id, body.member_id)
            if member is None:
                msg = (
                    "目标成员已停用，不可作为归属对象"
                    if reason == "inactive"
                    else "目标成员不属于本家庭"
                )
                return BaseResponse(success=False, message=msg, data=None)

        # 记录定位与归属校验
        model = {"food": FoodRecord, "water": WaterIntakeRecord}.get(body.record_type)
        if model is None:
            return BaseResponse(success=False, message="record_type 仅支持 food / water", data=None)
        record = db.query(model).filter(
            model.id == body.record_id,
            model.user_id == home_user_id,
        ).first()
        if record is None:
            return BaseResponse(success=False, message="记录不存在或不属于本家庭", data=None)

        record.member_id = member.id if member else None
        record.attributed_by = body.attributed_by
        record.attribution_confidence = 1.0  # 人工纠错视为确定
        record.recorded_by_user_id = operator_user_id  # F12 操作者落库（复用 M4 代记录列）

        # 设备纠错切人 → C4 方向一等效，联动当前成员
        member_id_changed = False
        if device is not None:
            new_current = member.id if member else None
            if device.current_member_id != new_current:
                device.current_member_id = new_current
                member_id_changed = True

        db.commit()
        if member_id_changed and device is not None:
            bump_member_version(device.home_user_id or device.user_id)

        return BaseResponse(
            success=True,
            message="归属修改成功",
            data={
                "record_type": body.record_type,
                "record_id": body.record_id,
                "member_id": member.id if member else None,
                "member_name": member.display_name if member else None,
                "attributed_by": body.attributed_by,
                "operator_user_id": operator_user_id,
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"记录归属修改失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(status_code=500, detail="记录归属修改失败")
