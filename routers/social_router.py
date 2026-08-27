"""社交关系路由 - Milestone 4 家庭健康管理"""
from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, cast, String, func
from typing import List, Optional
from datetime import date, timedelta
import logging
import traceback

from shared.models.database import get_db
from shared.models.schemas import (
    BaseResponse,
    FriendRequestCreate, FriendRequestResponse,
    UserRelationResponse, UserRelationWithProfile,
    FamilyAddRequest, UserSearchResult, FriendListResponse,
    RelationNoteUpdate,
)
from shared.utils.auth import get_current_user
from shared.models.user_models import User, UserProfile, _blind_index
from shared.models.social_models import UserRelationship, DataPermission
from shared.models.food_models import DailyNutritionSummary
from shared.models.water_models import WaterIntakeRecord
from shared.models.pet_models import VirtualPetState
from shared.models.exercise_models import ExerciseRecord
from shared.utils.permission import get_visible_fields, field_hidden

router = APIRouter(prefix="/social", tags=["社交关系"])
logger = logging.getLogger(__name__)


# ============================================================
# 关系称谓互逆映射（一方确认称谓后，另一方自动同步，参考性别）
# gender: 1=男 2=女 3=其他（UserProfile.gender）
# 二元组 = (设置者为男性时的互逆称谓, 设置者为女性时的互逆称谓)
# ============================================================
RELATIONSHIP_LABEL_INVERSES = {
    # 亲子
    "妈妈": ("儿子", "女儿"),
    "母亲": ("儿子", "女儿"),
    "爸爸": ("儿子", "女儿"),
    "父亲": ("儿子", "女儿"),
    "儿子": ("爸爸", "妈妈"),
    "女儿": ("爸爸", "妈妈"),
    # 祖孙
    "爷爷": ("孙子", "孙女"),
    "奶奶": ("孙子", "孙女"),
    "外公": ("外孙", "外孙女"),
    "外婆": ("外孙", "外孙女"),
    # 兄弟姐妹
    "哥哥": ("弟弟", "妹妹"),
    "姐姐": ("弟弟", "妹妹"),
    "弟弟": ("哥哥", "姐姐"),
    "妹妹": ("哥哥", "姐姐"),
    # 叔伯姑舅
    "叔叔": ("侄子", "侄女"),
    "伯父": ("侄子", "侄女"),
    "婶婶": ("侄子", "侄女"),
    "姑姑": ("侄子", "侄女"),
    "舅舅": ("外甥", "外甥女"),
    "舅妈": ("外甥", "外甥女"),
    "姨妈": ("外甥", "外甥女"),
    "阿姨": ("外甥", "外甥女"),
    # 夫妻（固定互逆，与性别无关）
    "老公": ("老婆", "老婆"),
    "丈夫": ("妻子", "妻子"),
    "老婆": ("老公", "老公"),
    "妻子": ("丈夫", "丈夫"),
}


def _get_user_gender(db: Session, user_id: int) -> Optional[int]:
    """获取用户性别：1=男 2=女 3=其他，未设置返回 None"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    return profile.gender if profile else None


def _inverse_relationship_label(label: Optional[str], setter_gender: Optional[int]) -> Optional[str]:
    """根据称谓设置者的性别返回互逆称谓；无法映射或性别未知返回 None"""
    if not label:
        return None
    inverses = RELATIONSHIP_LABEL_INVERSES.get(label)
    if not inverses:
        return None
    if setter_gender == 1:  # 男
        return inverses[0]
    if setter_gender == 2:  # 女
        return inverses[1]
    return None  # 性别未知：不自动同步，避免错误称谓


def _auto_sync_labels(db: Session, relation: UserRelationship):
    """一方确认称谓后，自动同步另一方的互逆称谓（参考称谓设置者的性别）。
    仅当另一方尚未设置称谓时补充，不覆盖对方已设置的称谓。"""
    # 方向1：user 设置了其对 related 的称谓 -> 自动补 related 对 user 的称谓
    if relation.note_from_user:
        inverse = _inverse_relationship_label(
            relation.note_from_user, _get_user_gender(db, relation.user_id)
        )
        if inverse and not relation.note_from_related:
            relation.note_from_related = inverse
    # 方向2：related 设置了其对 user 的称谓 -> 自动补 user 对 related 的称谓
    if relation.note_from_related:
        inverse = _inverse_relationship_label(
            relation.note_from_related, _get_user_gender(db, relation.related_user_id)
        )
        if inverse and not relation.note_from_user:
            relation.note_from_user = inverse


async def _notify_relation_request(db: Session, target_user_id: int, from_user: User, relation_type: str):
    """向目标用户推送好友/家人申请通知（FCM）"""
    try:
        from shared.services.push_service import send_push_to_user
        type_text = "家人" if relation_type == "family" else "好友"
        await send_push_to_user(
            db=db,
            user_id=target_user_id,
            title=f"新的{type_text}申请",
            body=f"{from_user.username} 请求添加您为{type_text}",
            data={
                "type": "relation_request",
                "relation_type": relation_type,
                "from_user_id": from_user.id,
                "from_username": from_user.username,
            },
            reminder_type="relation_request"
        )
    except Exception as e:
        logger.warning(f"发送申请通知失败: {e}")


# ============================================================
# 搜索用户
# ============================================================

@router.get("/search", response_model=BaseResponse)
async def search_users(
    keyword: str = Query(..., min_length=1, max_length=50, description="用户名/ID/手机号"),
    phone: Optional[str] = Query(None, max_length=20, description="手机号精确搜索"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """搜索用户（通过用户名/ID/手机号）"""
    try:
        # keyword 兼容三种匹配：username 包含、id 精确、phone 精确
        # phone 列为加密存储（历史数据可能为明文），无法用 SQL 直接比较明文，
        # 精确匹配统一走盲索引 phone_hash（与登录逻辑一致）
        or_conditions = [
            User.username.ilike(f"%{keyword}%"),
            cast(User.id, String) == keyword,
            User.phone_hash == _blind_index(keyword),
        ]
        # 显式 phone 参数：手机号精确匹配
        if phone:
            or_conditions.append(User.phone_hash == _blind_index(phone))

        # 搜索用户（排除自己）
        users = db.query(User).filter(
            User.id != current_user.id,
            User.status == 1,
            or_(*or_conditions)
        ).limit(20).all()

        # 获取当前用户的关系（包括 pending 和 accepted）
        relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.status.in_(["accepted", "pending"])
        ).all()

        friend_ids = set()
        family_ids = set()
        pending_friend_ids = set()
        pending_family_ids = set()
        for rel in relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            if rel.status == "accepted":
                if rel.relationship_type == "friend":
                    friend_ids.add(other_id)
                elif rel.relationship_type == "family":
                    family_ids.add(other_id)
            elif rel.status == "pending":
                # 只有当前用户是发起方（user_id）时才算"已发送"
                if rel.user_id == current_user.id:
                    if rel.relationship_type == "friend":
                        pending_friend_ids.add(other_id)
                    elif rel.relationship_type == "family":
                        pending_family_ids.add(other_id)

        results = []
        for user in users:
            profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
            results.append(UserSearchResult(
                id=user.id,
                username=user.username,
                real_name=profile.real_name if profile else None,
                avatar_url=user.avatar_url,
                gender=profile.gender if profile else None,
                is_friend=user.id in friend_ids,
                is_family=user.id in family_ids,
                pending_friend=user.id in pending_friend_ids,
                pending_family=user.id in pending_family_ids,
            ))

        return BaseResponse(
            success=True,
            message="搜索成功",
            data=[r.dict() for r in results]
        )
    except Exception as e:
        logger.error(f"搜索用户失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="搜索用户失败"
        )


# ============================================================
# 好友申请
# ============================================================

@router.post("/friend-request", response_model=BaseResponse)
async def send_friend_request(
    request: FriendRequestCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """发送好友申请"""
    try:
        # 检查目标用户是否存在
        target_user = db.query(User).filter(
            User.id == request.target_user_id,
            User.status == 1
        ).first()
        if not target_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目标用户不存在"
            )

        # 检查是否已有关系
        existing = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == request.target_user_id
                ),
                and_(
                    UserRelationship.user_id == request.target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            )
        ).first()

        if existing:
            if existing.status == "accepted":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="已经是好友/家人"
                )
            elif existing.status == "pending":
                if existing.relationship_type == "family":
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="已有待处理的家人申请"
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="已有待处理的好友申请"
                    )

        # 创建好友申请
        relation = UserRelationship(
            user_id=current_user.id,
            related_user_id=request.target_user_id,
            relationship_type="friend",
            status="pending",
            note_from_user=request.relationship_label,
        )
        db.add(relation)
        # 我方确认称谓后，自动同步对方的互逆称谓（参考我方性别）
        _auto_sync_labels(db, relation)
        db.commit()

        # 通知目标用户（FCM 推送）
        await _notify_relation_request(db, request.target_user_id, current_user, "friend")

        return BaseResponse(
            success=True,
            message="好友申请已发送",
            data={"request_id": relation.id}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送好友申请失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送好友申请失败"
        )


@router.put("/friend-request/{request_id}", response_model=BaseResponse)
async def handle_friend_request(
    request_id: int,
    action: str = Query(..., description="accept|reject"),
    relationship_label: Optional[str] = Query(None, max_length=50, description="我（接收方）对对方的关系称谓，接受家人申请时可选填"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """处理好友申请"""
    try:
        if action not in ["accept", "reject"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="action 必须是 accept 或 reject"
            )

        # 查找申请记录
        relation = db.query(UserRelationship).filter(
            UserRelationship.id == request_id,
            UserRelationship.related_user_id == current_user.id,
            UserRelationship.status == "pending"
        ).first()

        if not relation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="好友申请不存在或已处理"
            )

        if action == "accept":
            relation.status = "accepted"
            # 接收方可设置自己对对方的关系称谓
            if relationship_label:
                relation.note_from_related = relationship_label
            if relation.relationship_type == "family":
                # 升级为家人：删除原有的好友记录，避免同一人出现在两个列表
                old_friend = db.query(UserRelationship).filter(
                    or_(
                        and_(
                            UserRelationship.user_id == relation.user_id,
                            UserRelationship.related_user_id == relation.related_user_id,
                            UserRelationship.relationship_type == "friend",
                            UserRelationship.status == "accepted"
                        ),
                        and_(
                            UserRelationship.user_id == relation.related_user_id,
                            UserRelationship.related_user_id == relation.user_id,
                            UserRelationship.relationship_type == "friend",
                            UserRelationship.status == "accepted"
                        )
                    )
                ).first()
                if old_friend:
                    # 迁移旧好友记录中发起方的称谓到家人记录，避免丢失
                    if not relation.note_from_user and old_friend.note_from_user:
                        relation.note_from_user = old_friend.note_from_user
                    if not relation.note_from_related and old_friend.note_from_related:
                        relation.note_from_related = old_friend.note_from_related
                    db.delete(old_friend)
                message = "已接受家人邀请，你们现在是家人了"
            else:
                message = "已接受好友申请"
            # 一方确认称谓后，自动同步对方的互逆称谓（参考确认者性别）
            _auto_sync_labels(db, relation)
        else:
            # 拒绝：直接删除该申请记录
            # 如果是家人升级申请，删除后双方仍保持好友关系
            # 如果是好友申请，删除后双方无关系
            db.delete(relation)
            if relation.relationship_type == "family":
                message = "已拒绝家人邀请，保持好友关系"
            else:
                message = "已拒绝好友申请"

        db.commit()

        return BaseResponse(
            success=True,
            message=message,
            data=None
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"处理好友申请失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="处理好友申请失败"
        )


# ============================================================
# 添加家人
# ============================================================

@router.post("/family", response_model=BaseResponse)
async def add_family_member(
    request: FamilyAddRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """添加家人（需对方确认）"""
    try:
        # 检查目标用户是否存在
        target_user = db.query(User).filter(
            User.id == request.target_user_id,
            User.status == 1
        ).first()
        if not target_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目标用户不存在"
            )

        # 检查是否已有关系
        existing = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == request.target_user_id
                ),
                and_(
                    UserRelationship.user_id == request.target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            )
        ).first()

        if existing:
            if existing.status == "accepted":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="已经是好友/家人"
                )
            elif existing.status == "pending":
                if existing.relationship_type == "family":
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="已有待处理的家人申请"
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="已有待处理的好友申请"
                    )

        # 创建家人申请
        relation = UserRelationship(
            user_id=current_user.id,
            related_user_id=request.target_user_id,
            relationship_type="family",
            status="pending",
            note_from_user=request.relationship_label,
        )
        db.add(relation)
        # 我方确认称谓后，自动同步对方的互逆称谓（参考我方性别）
        _auto_sync_labels(db, relation)
        db.commit()

        # 通知目标用户（FCM 推送）
        await _notify_relation_request(db, request.target_user_id, current_user, "family")

        return BaseResponse(
            success=True,
            message="家人申请已发送，等待对方确认",
            data={"request_id": relation.id}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"添加家人失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="添加家人失败"
        )


# ============================================================
# 好友升级为家人
# ============================================================

@router.post("/upgrade-to-family/{target_user_id}", response_model=BaseResponse)
async def upgrade_friend_to_family(
    target_user_id: int,
    relationship_label: Optional[str] = Query(None, max_length=50, description="对方与我的关系称谓（如：妈妈、爸爸）"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """将好友升级为家人（需对方确认）"""
    try:
        # 检查目标用户是否存在
        target_user = db.query(User).filter(
            User.id == target_user_id,
            User.status == 1
        ).first()
        if not target_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="目标用户不存在"
            )

        # 不能对自己操作
        if target_user_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不能将自己升级为家人"
            )

        # 查找现有好友关系（双向查找）
        existing = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            )
        ).first()

        if not existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="还不是好友，请先添加好友"
            )

        if existing.status != "accepted":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="好友关系尚未确认"
            )

        # 检查是否已经是家人
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id,
                    UserRelationship.relationship_type == "family",
                    UserRelationship.status == "accepted"
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id,
                    UserRelationship.relationship_type == "family",
                    UserRelationship.status == "accepted"
                )
            )
        ).first()
        if is_family:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="已经是家人关系"
            )

        # 检查是否已有待处理的家人申请
        pending_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id,
                    UserRelationship.relationship_type == "family",
                    UserRelationship.status == "pending"
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id,
                    UserRelationship.relationship_type == "family",
                    UserRelationship.status == "pending"
                )
            )
        ).first()
        if pending_family:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="已有待处理的家人申请"
            )

        # 保留原有好友关系不变，新建一条家人申请记录
        # user_id = 发起方(current_user), related_user_id = 接收方(target)
        # 未填称谓时，继承旧好友记录中对应视角的称谓
        note_from_user = relationship_label
        note_from_related = None
        if existing.user_id == current_user.id:
            # 好友记录由我方发起：note_from_user 是我方视角的称谓
            if not note_from_user and existing.note_from_user:
                note_from_user = existing.note_from_user
            if not note_from_related and existing.note_from_related:
                note_from_related = existing.note_from_related
        else:
            # 好友记录由对方发起：note_from_user 是对方视角的称谓
            if not note_from_related and existing.note_from_user:
                note_from_related = existing.note_from_user
            if not note_from_user and existing.note_from_related:
                note_from_user = existing.note_from_related
        upgrade_relation = UserRelationship(
            user_id=current_user.id,
            related_user_id=target_user_id,
            relationship_type="family",
            status="pending",
            note_from_user=note_from_user,
            note_from_related=note_from_related,
        )
        db.add(upgrade_relation)
        # 我方确认称谓后，自动同步对方的互逆称谓（参考我方性别）
        _auto_sync_labels(db, upgrade_relation)
        db.commit()

        # 通知目标用户（FCM 推送）
        await _notify_relation_request(db, target_user_id, current_user, "family")

        return BaseResponse(
            success=True,
            message="已发送家人邀请，等待对方确认",
            data={"request_id": upgrade_relation.id}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"好友升级为家人失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="好友升级为家人失败"
        )


# ============================================================
# 好友列表
# ============================================================

@router.get("/friends", response_model=BaseResponse)
async def get_friend_list(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取好友列表（分组显示：家人/好友）"""
    try:
        # 查询所有已接受的关系
        relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.status == "accepted"
        ).all()

        family_list = []
        friend_list = []

        for rel in relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            other_user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            # 我方对该关系的称谓：我作为 user_id 时看 note_from_user，否则看 note_from_related
            my_note = rel.note_from_user if rel.user_id == current_user.id else rel.note_from_related

            item = UserRelationWithProfile(
                relation_id=rel.id,
                user_id=other_id,
                username=other_user.username if other_user else "",
                real_name=profile.real_name if profile else None,
                avatar_url=other_user.avatar_url if other_user else None,
                gender=profile.gender if profile else None,
                relationship_type=rel.relationship_type,
                status=rel.status,
                note=my_note,
                created_at=rel.created_at
            )

            if rel.relationship_type == "family":
                family_list.append(item)
            else:
                friend_list.append(item)

        return BaseResponse(
            success=True,
            message="获取好友列表成功",
            data=FriendListResponse(
                family=family_list,
                friends=friend_list
            ).dict()
        )
    except Exception as e:
        logger.error(f"获取好友列表失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取好友列表失败"
        )


# ============================================================
# 好友基础健康信息
# ============================================================

@router.get("/friend-health/{target_user_id}", response_model=BaseResponse)
async def get_friend_health_summary(
    target_user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取好友基础健康信息（今日热量摄入、喝水达标、宠物心情）"""
    try:
        # 校验好友关系
        is_friend = db.query(UserRelationship).filter(
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
            UserRelationship.relationship_type == "friend",
            UserRelationship.status == "accepted"
        ).first()

        if not is_friend:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能查看好友的健康信息"
            )

        profile = db.query(UserProfile).filter(UserProfile.user_id == target_user_id).first()
        today = date.today()

        # 今日热量摄入
        today_summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == target_user_id,
            DailyNutritionSummary.summary_date == today
        ).first()
        total_calories = float(today_summary.total_calories) if today_summary else 0
        target_calories = profile.target_calories if profile and profile.target_calories else 2000

        # 今日饮水量（达标/未达标）
        today_water = db.query(func.sum(WaterIntakeRecord.amount_ml)).filter(
            WaterIntakeRecord.user_id == target_user_id,
            func.date(WaterIntakeRecord.record_time) == today
        ).scalar() or 0
        water_goal = profile.daily_water_goal if profile and profile.daily_water_goal else 2000

        # 宠物心情
        pet_state = db.query(VirtualPetState).filter(
            VirtualPetState.user_id == target_user_id
        ).first()
        pet_mood = pet_state.mood if pet_state else "normal"
        pet_name = pet_state.pet_name if pet_state and pet_state.pet_name else "桌宠"

        # 数据权限过滤：若 target 对 current_user 配置了字段隐藏（家人升级后保留好友关系时可能配置），
        # 好友通道同样遵守权限配置，被隐藏字段返回 None
        visible = get_visible_fields(db, target_user_id, current_user.id)
        if field_hidden(visible, "calories"):
            total_calories = None
            target_calories = None
        if field_hidden(visible, "water"):
            today_water = None
            water_goal = None
        if field_hidden(visible, "virtual_pet"):
            pet_mood = None
            pet_name = None

        return BaseResponse(
            success=True,
            message="获取好友健康信息成功",
            data={
                "user_id": target_user_id,
                "total_calories": total_calories,
                "target_calories": target_calories,
                "water_intake": int(today_water) if today_water is not None else None,
                "water_goal": water_goal,
                "pet_mood": pet_mood,
                "pet_name": pet_name,
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取好友健康信息失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取好友健康信息失败"
        )


# ============================================================
# 好友饮食排行榜
# ============================================================

@router.get("/leaderboard", response_model=BaseResponse)
async def get_friend_leaderboard(
    days: int = Query(7, ge=1, le=30, description="统计天数（默认近7天）"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """好友饮食排行榜：按近N天运动消耗热量排名"""
    try:
        # 查询所有好友
        relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.relationship_type == "friend",
            UserRelationship.status == "accepted"
        ).all()

        start_date = date.today() - timedelta(days=days - 1)
        leaderboard = []

        for rel in relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            # 近N天运动消耗热量
            weekly_burned = db.query(
                func.coalesce(func.sum(ExerciseRecord.calories_burned), 0)
            ).filter(
                ExerciseRecord.user_id == other_id,
                ExerciseRecord.record_date >= start_date,
                ExerciseRecord.record_date <= date.today()
            ).scalar() or 0

            # 近N天运动次数
            exercise_count = db.query(func.count(ExerciseRecord.id)).filter(
                ExerciseRecord.user_id == other_id,
                ExerciseRecord.record_date >= start_date,
                ExerciseRecord.record_date <= date.today()
            ).scalar() or 0

            # 数据权限过滤：对方隐藏"运动记录"时，不显示其运动消耗数据
            visible = get_visible_fields(db, other_id, current_user.id)
            if field_hidden(visible, "exercise"):
                weekly_burned = None
                exercise_count = None

            leaderboard.append({
                "user_id": other_id,
                "username": user.username if user else "",
                "real_name": profile.real_name if profile and profile.real_name else None,
                "avatar_url": user.avatar_url if user else None,
                "weekly_burned_calories": round(float(weekly_burned), 1) if weekly_burned is not None else None,
                "exercise_count": exercise_count,
            })

        # 按消耗热量降序排名（权限隐藏的数据排末尾）
        leaderboard.sort(
            key=lambda x: x["weekly_burned_calories"]
            if x["weekly_burned_calories"] is not None else -1,
            reverse=True
        )

        return BaseResponse(
            success=True,
            message="获取好友排行榜成功",
            data={"leaderboard": leaderboard}
        )
    except Exception as e:
        logger.error(f"获取好友排行榜失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取好友排行榜失败"
        )


# ============================================================
# 移除关系
# ============================================================

@router.delete("/relation/{relation_id}", response_model=BaseResponse)
async def remove_relation(
    relation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """移除好友/解除家人关系"""
    try:
        relation = db.query(UserRelationship).filter(
            UserRelationship.id == relation_id,
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            )
        ).first()

        if not relation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="关系不存在"
            )

        db.delete(relation)
        db.commit()

        return BaseResponse(
            success=True,
            message="已移除关系",
            data=None
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"移除关系失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="移除关系失败"
        )


# ============================================================
# 编辑关系称谓
# ============================================================

@router.put("/relation/{relation_id}/note", response_model=BaseResponse)
async def update_relation_note(
    relation_id: int,
    body: RelationNoteUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新我方对该关系的称谓（若对方尚未设置称谓，自动同步互逆称谓，参考我方性别）"""
    try:
        relation = db.query(UserRelationship).filter(
            UserRelationship.id == relation_id,
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            )
        ).first()

        if not relation:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="关系不存在"
            )

        if relation.user_id == current_user.id:
            relation.note_from_user = body.relationship_label
        else:
            relation.note_from_related = body.relationship_label

        # 我方确认称谓后，自动同步对方的互逆称谓（参考我方性别）
        _auto_sync_labels(db, relation)
        db.commit()

        return BaseResponse(
            success=True,
            message="关系称谓已更新",
            data={"relation_id": relation_id, "note": body.relationship_label}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新关系称谓失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新关系称谓失败"
        )


# ============================================================
# 待处理申请
# ============================================================

@router.get("/pending-requests", response_model=BaseResponse)
async def get_pending_requests(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取待处理的好友/家人申请"""
    try:
        requests = db.query(UserRelationship).filter(
            UserRelationship.related_user_id == current_user.id,
            UserRelationship.status == "pending"
        ).all()

        result = []
        for req in requests:
            sender = db.query(User).filter(User.id == req.user_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == req.user_id).first()
            result.append({
                "request_id": req.id,
                "sender_id": req.user_id,
                "sender_username": sender.username if sender else "",
                "sender_real_name": profile.real_name if profile else None,
                "sender_avatar_url": sender.avatar_url if sender else None,
                "sender_gender": profile.gender if profile else None,
                "relationship_type": req.relationship_type,
                "relationship_label": req.note_from_user,
                "created_at": req.created_at.isoformat()
            })

        return BaseResponse(
            success=True,
            message="获取待处理申请成功",
            data=result
        )
    except Exception as e:
        logger.error(f"获取待处理申请失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取待处理申请失败"
        )


# ============================================================
# 数据权限管理
# ============================================================

@router.put("/permission/{target_user_id}", response_model=BaseResponse)
async def update_data_permission(
    target_user_id: int,
    visible_fields: List[str] = Body(..., embed=True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新数据权限 - 设置哪些数据对指定家人可见"""
    try:
        # 检查是否是家人关系
        relation = db.query(UserRelationship).filter(
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
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not relation:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能为家人设置数据权限"
            )

        # 验证字段名
        allowed_fields = [
            "calories", "water", "weight", "exercise", "health_goal",
            "virtual_pet", "real_pet", "exam_report", "dietary_preferences"
        ]
        invalid_fields = [f for f in visible_fields if f not in allowed_fields]
        if invalid_fields:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"无效的字段名: {', '.join(invalid_fields)}"
            )

        # 创建或更新权限
        permission = db.query(DataPermission).filter(
            DataPermission.user_id == current_user.id,
            DataPermission.target_user_id == target_user_id
        ).first()

        if permission:
            permission.visible_fields = visible_fields
        else:
            permission = DataPermission(
                user_id=current_user.id,
                target_user_id=target_user_id,
                visible_fields=visible_fields
            )
            db.add(permission)

        db.commit()

        return BaseResponse(
            success=True,
            message="权限更新成功",
            data={"visible_fields": visible_fields}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"更新数据权限失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="更新数据权限失败"
        )


@router.get("/permission/{target_user_id}", response_model=BaseResponse)
async def get_data_permission(
    target_user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取对指定家人的数据权限"""
    try:
        permission = db.query(DataPermission).filter(
            DataPermission.user_id == current_user.id,
            DataPermission.target_user_id == target_user_id
        ).first()

        # 默认所有字段可见
        visible_fields = permission.visible_fields if permission else [
            "calories", "water", "weight", "exercise", "health_goal",
            "virtual_pet", "real_pet", "exam_report", "dietary_preferences"
        ]

        return BaseResponse(
            success=True,
            message="获取权限成功",
            data={"visible_fields": visible_fields}
        )
    except Exception as e:
        logger.error(f"获取数据权限失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取数据权限失败"
        )


# ============================================================
# 邀请码添加家人
# ============================================================

@router.get("/invite-code", response_model=BaseResponse)
async def get_invite_code(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取当前用户的邀请码"""
    try:
        # 如果用户还没有邀请码，生成一个
        if not current_user.invite_code:
            import secrets
            while True:
                code = secrets.token_hex(3).upper()
                if not db.query(User).filter(User.invite_code == code).first():
                    current_user.invite_code = code
                    db.commit()
                    break

        return BaseResponse(
            success=True,
            message="获取邀请码成功",
            data={
                "invite_code": current_user.invite_code,
                "username": current_user.username
            }
        )
    except Exception as e:
        logger.error(f"获取邀请码失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取邀请码失败"
        )


@router.post("/join-family", response_model=BaseResponse)
async def join_family_by_invite(
    invite_code: str = Body(..., embed=True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """通过邀请码直接添加为家人（无需对方确认）"""
    try:
        # 查找邀请码对应的用户
        invite_user = db.query(User).filter(
            User.invite_code == invite_code,
            User.status == 1
        ).first()

        if not invite_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="邀请码无效"
            )

        # 不能邀请自己
        if invite_user.id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不能使用自己的邀请码"
            )

        # 检查是否已经是家人
        existing = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == invite_user.id
                ),
                and_(
                    UserRelationship.user_id == invite_user.id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="你们已经是家人了"
            )

        # 检查是否已有好友关系
        friend_relation = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == invite_user.id
                ),
                and_(
                    UserRelationship.user_id == invite_user.id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.status == "accepted"
        ).first()

        # 创建家人关系（单向记录）
        # 与好友/家人申请流程一致：仅创建一条记录，双方通过 or_(user_id, related_user_id) 查询可见
        # 注意：不能创建双向两条记录，否则 /friends、/dashboard、/alerts 中同一成员会重复出现
        relation1 = UserRelationship(
            user_id=invite_user.id,
            related_user_id=current_user.id,
            relationship_type="family",
            status="accepted"
        )
        db.add(relation1)

        # 如果之前是好友，删除好友记录
        if friend_relation:
            db.delete(friend_relation)

        db.commit()

        return BaseResponse(
            success=True,
            message=f"已成功加入 {invite_user.username} 的家庭",
            data={
                "family_member_id": invite_user.id,
                "family_member_username": invite_user.username
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"通过邀请码添加家人失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="通过邀请码添加家人失败"
        )
