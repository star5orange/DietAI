"""家庭关怀服务 - V5 PRD 3.2 老人线 Must

三类主动关怀能力的统一实现（由 shared/tasks/scheduler.py 定时调用）：
1. 饭点关怀询问：饭点给老人发一条询问消息（只询问、不代记，符合 PRD D9 写操作红线）
2. 异常主动提醒：把家庭异常主动推给子女（不再依赖"进看板才算"）
3. 父母日报：每天把父母当日三餐/热量/饮水摘要推给子女

推送统一为「创建 Message + WebSocket 实时推送」，与「提醒家人」同源，
前端消息中心即可展示与跳转（PRD 4.8 家人状态卡同一数据来源）。

家庭关系口径（对齐 schemas/social.py 与 family_router）：
- user_id 侧为关注方（子女），related_user_id 侧为被关注方（老人/被照护者）；
- 只有 status=accepted 且 relationship_type=family 的关系参与推送；
- 老人可见字段仍按 DataPermission 过滤（PRD 5.4：子女仅可查看，不可代改）。
"""

import logging
from datetime import date, datetime, timedelta
from typing import Any, Optional

from sqlalchemy import or_, func
from sqlalchemy.orm import Session

from shared.models.food_models import DailyNutritionSummary, FoodRecord
from shared.models.message_models import Message
from shared.models.social_models import UserRelationship
from shared.models.user_models import User, UserProfile
from shared.models.water_models import WaterIntakeRecord
from shared.utils.permission import get_visible_fields, field_hidden

logger = logging.getLogger(__name__)

# 餐次口径与全 App 一致：1早餐 2午餐 3晚餐 4加餐 5夜宵
MEAL_TYPE_LABELS = {1: "早餐", 2: "午餐", 3: "晚餐", 4: "加餐", 5: "夜宵"}

# 饭点关怀询问的时段（小时 -> 餐次）
CARE_MEAL_SLOTS = {9: 1, 13: 2, 19: 3}

DEFAULT_WATER_GOAL_ML = 2000
DEFAULT_TARGET_CALORIES = 2000


# ============================================================
# 家庭关系
# ============================================================

def _accepted_family_relations(db: Session):
    """全部已建立（accepted）的家庭关系"""
    return db.query(UserRelationship).filter(
        UserRelationship.relationship_type == "family",
        UserRelationship.status == "accepted",
    ).all()


def list_family_ids(db: Session, user_id: int) -> list[int]:
    """与 user_id 建立家庭关系的对端用户ID（双向）"""
    relations = _accepted_family_relations(db)
    result = []
    for rel in relations:
        if rel.user_id == user_id:
            result.append(rel.related_user_id)
        elif rel.related_user_id == user_id:
            result.append(rel.user_id)
    return result


def _display_name(db: Session, user_id: int) -> str:
    """用户展示名：优先真实姓名，回退用户名"""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if profile and profile.real_name:
        return profile.real_name
    user = db.query(User).filter(User.id == user_id).first()
    return user.username if user else f"用户{user_id}"


def list_care_targets(db: Session) -> list[dict[str, Any]]:
    """列出需要关怀的老人及其子女（PRD 3.2 老人线）

    口径：家庭关系中「被关注方」（related_user_id）视为老人/被照护者，
    「关注方」（user_id）视为子女。同一对关系只取一条。
    """
    targets: list[dict[str, Any]] = []
    for rel in _accepted_family_relations(db):
        if rel.user_id == rel.related_user_id:
            continue
        targets.append(
            {
                "elder_id": rel.related_user_id,
                "guardian_id": rel.user_id,
                "elder_name": _display_name(db, rel.related_user_id),
            }
        )
    return targets


# ============================================================
# 家庭异常判定（family_router /family/alerts 与本服务共用）
# ============================================================

def collect_alerts(db: Session, viewer_id: int) -> list[dict[str, Any]]:
    """收集 viewer 可见的家人异常（饮水不足/热量超标/桌宠饥饿/体检异常）

    判定口径与原 family_router.get_family_alerts 完全一致；
    仅当字段对 viewer 可见时才生成提醒（PRD 5.4 授权范围）。
    """
    from shared.models.exam_models import ExamReport
    from shared.models.pet_models import VirtualPetState

    alerts: list[dict[str, Any]] = []
    today = date.today()

    for other_id in list_family_ids(db, viewer_id):
        user = db.query(User).filter(User.id == other_id).first()
        if not user:
            continue
        profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()
        real_name = profile.real_name if profile and profile.real_name else user.username

        visible = get_visible_fields(db, other_id, viewer_id)
        show_water_alert = not field_hidden(visible, "water")
        show_calories_alert = not field_hidden(visible, "calories")
        show_pet_alert = not field_hidden(visible, "virtual_pet")
        show_exam_alert = not field_hidden(visible, "exam_report")

        # 饮水不足（<50% 目标）
        today_water = db.query(func.sum(WaterIntakeRecord.amount_ml)).filter(
            WaterIntakeRecord.user_id == other_id,
            func.date(WaterIntakeRecord.record_time) == today,
        ).scalar() or 0

        water_goal = (
            profile.daily_water_goal
            if profile and profile.daily_water_goal
            else DEFAULT_WATER_GOAL_ML
        )
        if show_water_alert and today_water < water_goal * 0.5:
            alerts.append({
                "type": "water_insufficient",
                "user_id": other_id,
                "user_name": real_name,
                "message": f"{real_name}今日喝水不足（{int(today_water)}ml/{water_goal}ml）",
                "severity": "warning",
            })

        # 热量超标（>120% 目标）
        today_summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == other_id,
            DailyNutritionSummary.summary_date == today,
        ).first()

        if today_summary and show_calories_alert:
            total_calories = float(today_summary.total_calories or 0)
            target_calories = (
                profile.target_calories
                if profile and profile.target_calories
                else DEFAULT_TARGET_CALORIES
            )
            if total_calories > target_calories * 1.2:
                alerts.append({
                    "type": "calorie_excess",
                    "user_id": other_id,
                    "user_name": real_name,
                    "message": f"{real_name}今日热量超标（{int(total_calories)}/{target_calories}kcal）",
                    "severity": "warning",
                })

        # 虚拟桌宠饥饿
        pet_state = db.query(VirtualPetState).filter(
            VirtualPetState.user_id == other_id
        ).first()

        if pet_state and pet_state.mood in ["hungry", "weak"] and show_pet_alert:
            hunger_hours = 0
            if pet_state.last_feed_at:
                hunger_hours = max(
                    0,
                    int((datetime.now() - pet_state.last_feed_at).total_seconds() // 3600),
                )
            hour_text = f" {hunger_hours} 小时" if hunger_hours else ""
            alerts.append({
                "type": "pet_hungry",
                "user_id": other_id,
                "user_name": real_name,
                "message": f"{real_name}的桌宠已饥饿{hour_text}",
                "severity": "info",
            })

        # 体检异常 / 复查临近
        if show_exam_alert:
            latest_exam = db.query(ExamReport).filter(
                ExamReport.user_id == other_id
            ).order_by(ExamReport.exam_date.desc()).first()
            if latest_exam:
                if latest_exam.abnormal_count and latest_exam.abnormal_count > 0:
                    alerts.append({
                        "type": "exam_abnormal",
                        "user_id": other_id,
                        "user_name": real_name,
                        "message": (
                            f"{real_name}最近体检有 {latest_exam.abnormal_count} 项异常"
                            f"（{latest_exam.exam_date.isoformat()}）"
                        ),
                        "severity": "warning",
                    })
                if latest_exam.followup_date:
                    days_until = (latest_exam.followup_date - today).days
                    if 0 <= days_until <= 14:
                        alerts.append({
                            "type": "exam_followup",
                            "user_id": other_id,
                            "user_name": real_name,
                            "message": (
                                f"{real_name}的体检复查日期临近"
                                f"（还有 {days_until} 天，{latest_exam.followup_date.isoformat()}）"
                            ),
                            "severity": "info",
                        })

    return alerts


# ============================================================
# 父母日报
# ============================================================

def build_daily_report(db: Session, elder_id: int, viewer_id: Optional[int] = None) -> dict[str, Any]:
    """生成父母当日饮食摘要（三餐/热量/饮水 + 异常条数）

    viewer_id 传入时按数据权限过滤；为 None 表示本人视角（不做过滤）。
    """
    today = date.today()
    elder_name = _display_name(db, elder_id)

    visible = get_visible_fields(db, elder_id, viewer_id) if viewer_id else set()
    show_calories = viewer_id is None or not field_hidden(visible, "calories")
    show_water = viewer_id is None or not field_hidden(visible, "water")

    records = db.query(FoodRecord).filter(
        FoodRecord.user_id == elder_id,
        FoodRecord.record_date == today,
    ).order_by(FoodRecord.meal_type, FoodRecord.created_at).all()

    meals: list[dict[str, Any]] = []
    for meal_type in (1, 2, 3):
        foods = [
            (r.food_name or r.description or "记录")
            for r in records
            if r.meal_type == meal_type
        ]
        meals.append({
            "meal_type": meal_type,
            "meal_name": MEAL_TYPE_LABELS[meal_type],
            "foods": foods,
            "recorded": bool(foods),
        })

    summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == elder_id,
        DailyNutritionSummary.summary_date == today,
    ).first()

    profile = db.query(UserProfile).filter(UserProfile.user_id == elder_id).first()
    target_calories = (
        profile.target_calories
        if profile and profile.target_calories
        else DEFAULT_TARGET_CALORIES
    )
    water_goal = (
        profile.daily_water_goal
        if profile and profile.daily_water_goal
        else DEFAULT_WATER_GOAL_ML
    )

    today_water = db.query(func.sum(WaterIntakeRecord.amount_ml)).filter(
        WaterIntakeRecord.user_id == elder_id,
        func.date(WaterIntakeRecord.record_time) == today,
    ).scalar() or 0

    alerts = collect_alerts(db, viewer_id) if viewer_id else []
    elder_alerts = [a for a in alerts if a["user_id"] == elder_id]

    calories = float(summary.total_calories or 0) if summary else 0.0

    return {
        "date": today.isoformat(),
        "elder_id": elder_id,
        "elder_name": elder_name,
        "meals": meals,
        "recorded_meal_count": sum(1 for m in meals if m["recorded"]),
        "calories": calories if show_calories else None,
        "target_calories": target_calories,
        "water_ml": int(today_water) if show_water else None,
        "water_goal_ml": water_goal,
        "alerts_count": len(elder_alerts),
        "alerts": elder_alerts,
    }


def format_daily_report(report: dict[str, Any]) -> str:
    """把日报数据转成给子女看的一句话摘要（人话化，PRD 3.2 普通人群同款要求）"""
    parts = []
    for meal in report["meals"]:
        foods = meal["foods"]
        text = "、".join(foods) if foods else "未记录"
        parts.append(f"{meal['meal_name']} {text}")

    lines = [f"{report['elder_name']} {report['date']} 饮食日报：{'；'.join(parts)}。"]

    metrics = []
    if report.get("calories") is not None:
        metrics.append(f"热量 {int(report['calories'])}/{report['target_calories']}kcal")
    if report.get("water_ml") is not None:
        metrics.append(f"饮水 {report['water_ml']}/{report['water_goal_ml']}ml")
    if metrics:
        lines.append("，".join(metrics) + "。")

    if report["recorded_meal_count"] == 0:
        lines.append("今天还没有任何饮食记录，可以打个电话问问。")
    elif report["alerts_count"]:
        lines.append(f"另有 {report['alerts_count']} 项需要留意的提醒。")

    return "".join(lines)


# ============================================================
# 推送（Message + WebSocket）
# ============================================================

async def push_message(
    db: Session,
    sender_id: int,
    receiver_id: int,
    content: str,
    extra: Optional[dict[str, Any]] = None,
) -> Optional[int]:
    """创建消息并实时推送（离线用户仍可在消息中心看到，PRD 4.8）"""
    sender = db.query(User).filter(User.id == sender_id).first()
    if not sender:
        logger.warning(f"推送跳过：发送者不存在 sender_id={sender_id}")
        return None

    msg = Message(
        sender_id=sender_id,
        receiver_id=receiver_id,
        content=content,
        message_type="text",
        extra_data=extra,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    try:
        from routers.message_router import manager
        from datetime import timezone

        created_at = msg.created_at
        if created_at.tzinfo is None:
            created_at = created_at.replace(tzinfo=timezone.utc)

        await manager.send_to_user(receiver_id, {
            "type": "new_message",
            "data": {
                "id": msg.id,
                "sender_id": sender_id,
                "receiver_id": receiver_id,
                "content": content,
                "message_type": "text",
                "extra_data": extra,
                "created_at": created_at.isoformat(),
                "sender_username": sender.username,
                "sender_avatar_url": sender.avatar_url,
            },
        })
    except Exception as ws_error:  # 推送失败不影响消息落库
        logger.warning(f"关怀消息 WebSocket 推送失败: {ws_error}")

    return msg.id


def _already_pushed_today(
    db: Session, receiver_id: int, push_type: str, day: date
) -> bool:
    """当天是否已推送过同类消息（避免重复定时任务造成骚扰）"""
    day_start = datetime.combine(day, datetime.min.time())
    return db.query(Message).filter(
        Message.receiver_id == receiver_id,
        Message.extra_data["type"].astext == push_type,
        Message.extra_data["date"].astext == day.isoformat(),
        Message.created_at >= day_start,
    ).first() is not None


# ============================================================
# 定时任务入口
# ============================================================

async def ask_meal_care(meal_type: Optional[int] = None) -> int:
    """饭点关怀询问：给老人发一条询问消息（只询问，不代记）

    meal_type 为空时按当前小时自动判定餐次。
    """
    from shared.models.database import SessionLocal

    if meal_type is None:
        meal_type = CARE_MEAL_SLOTS.get(datetime.now().hour)
    if meal_type is None:
        logger.info("当前不在饭点时段，跳过关怀询问")
        return 0

    meal_name = MEAL_TYPE_LABELS[meal_type]
    today = date.today()
    db = SessionLocal()
    sent = 0
    try:
        for target in list_care_targets(db):
            elder_id = target["elder_id"]
            guardian_id = target["guardian_id"]

            if _already_pushed_today(db, elder_id, "care_ask", today):
                continue

            # 已完成记录就不再打扰
            recorded = db.query(FoodRecord).filter(
                FoodRecord.user_id == elder_id,
                FoodRecord.record_date == today,
                FoodRecord.meal_type == meal_type,
            ).first()
            if recorded:
                continue

            content = (
                f"🍚 到饭点啦，{meal_name}吃了吗？"
                f"吃了跟我说一声，我帮你记上；不方便说话也没关系～"
            )
            msg_id = await push_message(
                db,
                sender_id=guardian_id,
                receiver_id=elder_id,
                content=content,
                extra={
                    "type": "care_ask",
                    "date": today.isoformat(),
                    "meal_type": meal_type,
                    "meal_name": meal_name,
                },
            )
            if msg_id:
                sent += 1
                logger.info(f"[饭点关怀] 已询问 老人={elder_id} 餐次={meal_name}")

        logger.info(f"饭点关怀询问完成：发送 {sent} 条")
        return sent
    finally:
        db.close()


async def push_family_alerts() -> int:
    """异常主动提醒：把 warning 级家庭异常主动推给子女（每天推送一次）"""
    from shared.models.database import SessionLocal

    today = date.today()
    db = SessionLocal()
    sent = 0
    try:
        guardians = {t["guardian_id"] for t in list_care_targets(db)}
        for guardian_id in guardians:
            for alert in collect_alerts(db, guardian_id):
                if alert["severity"] != "warning":
                    continue

                push_type = f"family_alert_{alert['type']}"
                if _already_pushed_today(db, guardian_id, push_type, today):
                    continue

                msg_id = await push_message(
                    db,
                    sender_id=alert["user_id"],
                    receiver_id=guardian_id,
                    content=f"⚠️ {alert['message']}",
                    extra={
                        "type": push_type,
                        "date": today.isoformat(),
                        "alert_type": alert["type"],
                        "user_id": alert["user_id"],
                        "user_name": alert["user_name"],
                    },
                )
                if msg_id:
                    sent += 1

        logger.info(f"家庭异常主动提醒完成：发送 {sent} 条")
        return sent
    finally:
        db.close()


async def push_daily_reports() -> int:
    """父母日报：每天为子女生成父母当日摘要并推送"""
    from shared.models.database import SessionLocal

    today = date.today()
    db = SessionLocal()
    sent = 0
    try:
        for target in list_care_targets(db):
            elder_id = target["elder_id"]
            guardian_id = target["guardian_id"]

            if _already_pushed_today(db, guardian_id, "family_daily_report", today):
                continue

            report = build_daily_report(db, elder_id, viewer_id=guardian_id)
            if report["recorded_meal_count"] == 0 and report["alerts_count"] == 0:
                # 完全无数据不推送，避免制造"空日报"骚扰
                continue

            msg_id = await push_message(
                db,
                sender_id=elder_id,
                receiver_id=guardian_id,
                content=format_daily_report(report),
                extra={
                    "type": "family_daily_report",
                    "date": today.isoformat(),
                    "elder_id": elder_id,
                    "elder_name": report["elder_name"],
                    "meals": report["meals"],
                    "calories": report["calories"],
                    "target_calories": report["target_calories"],
                    "water_ml": report["water_ml"],
                    "water_goal_ml": report["water_goal_ml"],
                    "alerts_count": report["alerts_count"],
                },
            )
            if msg_id:
                sent += 1

        logger.info(f"父母日报推送完成：发送 {sent} 条")
        return sent
    finally:
        db.close()
