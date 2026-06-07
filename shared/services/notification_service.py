import logging
from datetime import datetime, date, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func

from shared.models.notification_models import NotificationResponse
from shared.models.schemas.notification import NotificationResponseCreate
from shared.models.water_models import WaterIntakeRecord
from shared.models.reminder_models import Reminder
from shared.models.food_models import DailyNutritionSummary

logger = logging.getLogger(__name__)


def create_notification_response(
    db: Session,
    user_id: int,
    response: NotificationResponseCreate
) -> NotificationResponse:
    """记录提醒响应，并根据动作类型联动更新相关记录。

    - drank: 自动创建喝水记录（默认250ml），更新当日饮水汇总
    - ate: 记录吃饭响应
    - snooze: 记录延迟
    - skipped: 记录跳过

    安全校验：验证提醒属于当前用户，防止越权操作。
    """
    # 验证提醒归属（防越权）
    reminder = db.query(Reminder).filter(
        Reminder.id == response.reminder_id,
        Reminder.user_id == user_id,
    ).first()
    if not reminder:
        raise PermissionError("提醒不存在或不属于当前用户")

    db_resp = NotificationResponse(
        user_id=user_id,
        reminder_id=response.reminder_id,
        action_type=response.action_type,
        responded_at=datetime.now()
    )
    db.add(db_resp)
    db.flush()

    # 根据动作类型执行联动操作
    if response.action_type == "drank":
        _handle_drank_action(db, user_id, response.reminder_id)
    elif response.action_type == "ate":
        _handle_ate_action(db, user_id, response.reminder_id)

    db.commit()
    db.refresh(db_resp)
    return db_resp


def _handle_drank_action(db: Session, user_id: int, reminder_id: int):
    """处理喝水响应：自动创建喝水记录"""
    try:
        # 获取提醒信息
        reminder = db.query(Reminder).filter(Reminder.id == reminder_id).first()

        # 创建喝水记录（默认250ml）
        water_record = WaterIntakeRecord(
            user_id=user_id,
            amount_ml=250,
            record_time=datetime.now(),
            drink_type="水",
        )
        db.add(water_record)

        # 更新每日饮水汇总
        today = date.today()
        summary = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == user_id,
            DailyNutritionSummary.summary_date == today
        ).first()

        if summary:
            current_water = float(summary.water_intake or 0)
            summary.water_intake = current_water + 0.25  # 250ml = 0.25L
        else:
            summary = DailyNutritionSummary(
                user_id=user_id,
                summary_date=today,
                water_intake=0.25,
            )
            db.add(summary)

        logger.info(f"用户 {user_id} 喝水提醒响应: +250ml, 提醒ID={reminder_id}")
    except Exception as e:
        logger.error(f"处理喝水响应失败: {e}")


def _handle_ate_action(db: Session, user_id: int, reminder_id: int):
    """处理吃饭响应：记录响应信息"""
    logger.info(f"用户 {user_id} 吃饭提醒响应: 提醒ID={reminder_id}")


def get_response_stats(db: Session, user_id: int, days: int = 7) -> dict:
    """获取用户提醒响应统计。

    返回各类型提醒的响应率、连续响应天数等。
    """
    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    # 查询该时间段内的所有响应
    responses = db.query(NotificationResponse).filter(
        NotificationResponse.user_id == user_id,
        func.date(NotificationResponse.responded_at) >= start_date,
        func.date(NotificationResponse.responded_at) <= end_date
    ).all()

    # 统计各动作类型数量
    action_counts = {"drank": 0, "ate": 0, "snooze": 0, "skipped": 0}
    for r in responses:
        if r.action_type in action_counts:
            action_counts[r.action_type] += 1

    total = sum(action_counts.values()) or 1
    positive = action_counts["drank"] + action_counts["ate"]

    # 计算连续响应天数
    response_dates = set(r.responded_at.date() for r in responses if r.responded_at)

    streak = 0
    check_date = end_date
    for _ in range(days):
        if check_date in response_dates:
            streak += 1
            check_date -= timedelta(days=1)
        else:
            if streak == 0 and check_date == end_date:
                check_date -= timedelta(days=1)
                continue
            break

    return {
        "total_responses": total - 1 + 1,  # 实际总数
        "actual_total": len(responses),
        "action_breakdown": action_counts,
        "positive_rate": round(positive / max(total, 1) * 100, 1),
        "response_streak_days": streak,
        "period_days": days,
    }
