"""
桌宠饥饿主动推送定时任务

每天 08:30 / 12:30 / 18:30 / 21:30 执行：
检查所有用户的虚拟桌宠（VirtualPetState），对饥饿时长 > 4 小时的桌宠：
1. 向主人推送："你的宠物饿了 X 小时了，记得喂它哦"
2. 向该主人的所有家人推送："XX 的宠物饿了 X 小时，提醒 TA 吃饭吧"
"""

import logging
from datetime import datetime, date

logger = logging.getLogger(__name__)

# 去重记录：进程内轻量 set，键为 "YYYY-MM-DD:user_id:pet_id"。
# 说明：
# - 每天 4 次定时执行，若不记录，同一桌宠一天会被推送 4 次相同内容；
# - 键包含日期，跨天自动失效，保证"每个用户每天最多收到一次"同一桌宠的饥饿提醒；
# - 相比 Redis/新增数据库表，进程内 set 更轻量；进程重启后同一天最多重复推送一次，
#   该提醒为提示性质，偶发重复可接受。
_pushed_keys: set = set()


def _cleanup_stale_keys(today: str) -> None:
    """清理非今天的去重键，避免内存无限增长"""
    for key in list(_pushed_keys):
        if not key.startswith(today):
            _pushed_keys.discard(key)


async def check_pet_starvation():
    """
    检查所有虚拟桌宠的饥饿时长，超过 4 小时则推送提醒给主人及其家人。
    """
    from shared.models.database import SessionLocal
    from shared.models.user_models import User, UserProfile
    from shared.models.pet_models import VirtualPetState
    from shared.models.social_models import UserRelationship
    from shared.services.push_service import send_push_to_user
    from sqlalchemy import or_

    logger.info("[桌宠饥饿提醒] 开始检查")

    db = SessionLocal()
    try:
        today = date.today().isoformat()
        _cleanup_stale_keys(today)

        now = datetime.now()
        pushed_count = 0
        # 只遍历有 last_feed_at 的桌宠（从未喂过的新宠不打扰）
        pet_states = db.query(VirtualPetState).filter(
            VirtualPetState.last_feed_at.isnot(None)
        ).all()

        for pet_state in pet_states:
            try:
                hunger_hours = max(
                    0, int((now - pet_state.last_feed_at).total_seconds() // 3600)
                )
                if hunger_hours <= 4:
                    continue

                user_id = pet_state.user_id
                dedup_key = f"{today}:{user_id}:{pet_state.id}"
                if dedup_key in _pushed_keys:
                    continue
                _pushed_keys.add(dedup_key)

                # 主人信息（推送文案用）
                owner = db.query(User).filter(User.id == user_id).first()
                owner_profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
                owner_name = owner_profile.real_name if owner_profile and owner_profile.real_name else (
                    owner.username if owner else f"用户{user_id}"
                )
                pet_name = pet_state.pet_name or "桌宠"

                # 1) 推送给主人
                await send_push_to_user(
                    db=db,
                    user_id=user_id,
                    title="桌宠饿了",
                    body=f"你的宠物{pet_name}饿了 {hunger_hours} 小时了，记得喂它哦",
                    data={
                        "type": "pet_starvation",
                        "pet_id": pet_state.id,
                        "hunger_hours": hunger_hours,
                    },
                    reminder_type="pet_starvation"
                )

                # 2) 推送给所有家人
                family_relations = db.query(UserRelationship).filter(
                    or_(
                        UserRelationship.user_id == user_id,
                        UserRelationship.related_user_id == user_id
                    ),
                    UserRelationship.relationship_type == "family",
                    UserRelationship.status == "accepted"
                ).all()
                for rel in family_relations:
                    family_member_id = rel.related_user_id if rel.user_id == user_id else rel.user_id
                    await send_push_to_user(
                        db=db,
                        user_id=family_member_id,
                        title="家人桌宠提醒",
                        body=f"{owner_name}的宠物饿了 {hunger_hours} 小时，提醒 TA 吃饭吧",
                        data={
                            "type": "pet_starvation_family",
                            "owner_id": user_id,
                            "pet_id": pet_state.id,
                            "hunger_hours": hunger_hours,
                        },
                        reminder_type="pet_starvation"
                    )

                pushed_count += 1
                logger.info(
                    f"[桌宠饥饿提醒] user_id={user_id}, pet_id={pet_state.id}, "
                    f"饥饿 {hunger_hours} 小时, 推送 {1 + len(family_relations)} 人"
                )

            except Exception as e:
                logger.error(f"[桌宠饥饿提醒] 处理桌宠 {pet_state.id} 失败: {e}")

        logger.info(f"[桌宠饥饿提醒] 检查完成，共提醒 {pushed_count} 只桌宠")

    except Exception as e:
        logger.error(f"[桌宠饥饿提醒] 任务执行失败: {e}")
    finally:
        db.close()
