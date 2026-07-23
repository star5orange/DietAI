"""周报/月报健康报告定时推送任务

每周一 08:00 发送周报，每月1日 08:00 发送月报。
汇总用户饮食、体重、运动、饮水等数据，生成简洁的推送通知。
"""
import logging
from datetime import date, timedelta, datetime, time
from sqlalchemy import func, and_

from shared.models.database import SessionLocal
from shared.models.user_models import User, UserProfile, WeightRecord
from shared.models.food_models import FoodRecord, NutritionDetail
from shared.models.exercise_models import ExerciseRecord
from shared.models.water_models import WaterIntakeRecord
from shared.models.fasting_models import FastingPlan, FastingCheckin

logger = logging.getLogger(__name__)


def _send_push_sync(user_id: int, title: str, body: str, data: dict = None):
    """从同步任务中发送 FCM 推送"""
    import asyncio
    import concurrent.futures

    def _run():
        new_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(new_loop)
        db = SessionLocal()
        try:
            from shared.services.push_service import send_push_to_user
            push_data = {
                "reminder_type": "health_report",
                "click_action": "FLUTTER_NOTIFICATION_CLICK",
                **(data or {}),
            }
            count = new_loop.run_until_complete(
                send_push_to_user(
                    db=db, user_id=user_id, title=title, body=body,
                    data=push_data, reminder_type="health_report",
                )
            )
            if count > 0:
                logger.info(f"[FCM推送成功] user={user_id}, title={title}")
        except Exception as e:
            logger.error(f"[FCM推送失败] user={user_id}, error={e}")
        finally:
            new_loop.close()
            db.close()

    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(_run)
            future.result(timeout=30)
    except Exception as e:
        logger.error(f"FCM 推送线程异常: {e}")


def _get_active_user_ids(db, start: date, end: date) -> set:
    """获取在指定时段内有饮食记录的用户 ID 集合"""
    records = db.query(FoodRecord.user_id).filter(
        FoodRecord.record_date >= start,
        FoodRecord.record_date <= end,
    ).distinct().all()
    return {r[0] for r in records}


def _aggregate_food_data(db, user_id: int, start: date, end: date) -> dict:
    """聚合用户在时段内的饮食数据"""
    details = db.query(
        func.coalesce(func.sum(NutritionDetail.calories), 0),
        func.coalesce(func.sum(NutritionDetail.protein), 0),
        func.coalesce(func.sum(NutritionDetail.fat), 0),
        func.coalesce(func.sum(NutritionDetail.carbohydrates), 0),
        func.count(func.distinct(FoodRecord.record_date)),
        func.count(FoodRecord.id),
    ).join(NutritionDetail, NutritionDetail.food_record_id == FoodRecord.id).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date >= start,
        FoodRecord.record_date <= end,
    ).first()

    total_cal, total_protein, total_fat, total_carbs, record_days, meal_count = details
    days = max((end - start).days + 1, 1)
    return {
        "total_calories": float(total_cal or 0),
        "total_protein": float(total_protein or 0),
        "total_fat": float(total_fat or 0),
        "total_carbs": float(total_carbs or 0),
        "record_days": int(record_days or 0),
        "meal_count": int(meal_count or 0),
        "total_days": days,
        "avg_daily_cal": float(total_cal or 0) / days,
        "avg_daily_protein": float(total_protein or 0) / days,
    }


def _get_weight_change(db, user_id: int, start: date, end: date) -> dict:
    """获取用户体重变化"""
    first = db.query(WeightRecord).filter(
        WeightRecord.user_id == user_id,
        WeightRecord.measured_at >= start,
    ).order_by(WeightRecord.measured_at).first()

    last = db.query(WeightRecord).filter(
        WeightRecord.user_id == user_id,
        WeightRecord.measured_at <= end + timedelta(days=1),
    ).order_by(WeightRecord.measured_at.desc()).first()

    if first and last and first.id != last.id:
        change = float(last.weight) - float(first.weight)
        return {"start": float(first.weight), "end": float(last.weight), "change": change}
    return {}


def _aggregate_exercise(db, user_id: int, start: date, end: date) -> dict:
    """聚合运动数据"""
    result = db.query(
        func.coalesce(func.sum(ExerciseRecord.calories_burned), 0),
        func.coalesce(func.sum(ExerciseRecord.duration_minutes), 0),
        func.count(func.distinct(ExerciseRecord.record_date)),
    ).filter(
        ExerciseRecord.user_id == user_id,
        ExerciseRecord.record_date >= start,
        ExerciseRecord.record_date <= end,
    ).first()

    return {
        "total_cal": float(result[0] or 0),
        "total_minutes": int(result[1] or 0),
        "exercise_days": int(result[2] or 0),
    }


def _aggregate_water(db, user_id: int, start: date, end: date) -> dict:
    """聚合饮水数据"""
    # 将 datetime 范围转为日期
    start_dt = datetime.combine(start, time.min)
    end_dt = datetime.combine(end + timedelta(days=1), time.min)
    records = db.query(WaterIntakeRecord).filter(
        WaterIntakeRecord.user_id == user_id,
        WaterIntakeRecord.record_time >= start_dt,
        WaterIntakeRecord.record_time < end_dt,
    ).all()

    total_ml = sum(r.amount_ml or 0 for r in records)
    days = max((end - start).days + 1, 1)

    # 达标天数（按用户目标或默认2000ml）
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    goal_ml = (profile.daily_water_goal or 2000) if profile else 2000

    daily_ml = {}
    for r in records:
        d = r.record_time.date()
        daily_ml[d] = daily_ml.get(d, 0) + (r.amount_ml or 0)
    met_days = sum(1 for ml in daily_ml.values() if ml >= goal_ml)

    return {
        "total_ml": total_ml,
        "avg_daily_ml": round(total_ml / days),
        "met_days": met_days,
        "goal_ml": goal_ml,
    }


def _get_fasting_summary(db, user_id: int, start: date, end: date) -> dict:
    """获取断食计划打卡汇总"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.user_id == user_id,
        FastingPlan.status == "active",
    ).first()
    if not plan:
        return {}

    checkins = db.query(FastingCheckin).filter(
        FastingCheckin.plan_id == plan.id,
        FastingCheckin.checkin_date >= start,
        FastingCheckin.checkin_date <= end,
        FastingCheckin.completed == True,
    ).all()

    return {
        "plan_type": plan.plan_type,
        "checkin_count": len(checkins),
    }


def _format_weekly_title():
    today = date.today()
    start = today - timedelta(days=today.weekday())  # this week's Monday
    end = today
    return f"DietAI 周报 | {start.strftime('%m/%d')}-{end.strftime('%m/%d')}"


def _format_monthly_title():
    today = date.today()
    # previous month
    if today.month == 1:
        return f"DietAI 月报 | {today.year - 1}年12月"
    return f"DietAI 月报 | {today.year}年{today.month - 1}月"


def send_weekly_health_report():
    """每周一 08:00 发送周报推送"""
    today = date.today()
    start = today - timedelta(days=7)
    end = today - timedelta(days=1)

    logger.info(f"[周报任务] 开始生成 {start} ~ {end} 周报")

    db = SessionLocal()
    try:
        user_ids = _get_active_user_ids(db, start, end)
        if not user_ids:
            logger.info("[周报任务] 无活跃用户，跳过")
            return

        push_count = 0
        for uid in user_ids:
            try:
                food = _aggregate_food_data(db, uid, start, end)
                if food["meal_count"] == 0:
                    continue  # 无有效数据则跳过

                weight = _get_weight_change(db, uid, start, end)
                exercise = _aggregate_exercise(db, uid, start, end)
                water = _aggregate_water(db, uid, start, end)
                fasting = _get_fasting_summary(db, uid, start, end)

                # 构建推送文案
                lines = []
                lines.append(f"记录 {food['record_days']} 天 · 共 {food['meal_count']} 餐")

                cal_text = f"日均摄入 {food['avg_daily_cal']:.0f} kcal"
                profile = db.query(UserProfile).filter(UserProfile.user_id == uid).first()
                if profile and profile.target_calories:
                    pct = food['avg_daily_cal'] / profile.target_calories * 100
                    if 80 <= pct <= 120:
                        cal_text += " ✓ 达标"
                    elif pct < 80:
                        cal_text += " (偏低)"
                    else:
                        cal_text += " (偏高)"
                lines.append(cal_text)

                lines.append(
                    f"蛋白 {food['avg_daily_protein']:.0f}g · "
                    f"脂肪 {food['total_fat'] / food['total_days']:.0f}g · "
                    f"碳水 {food['total_carbs'] / food['total_days']:.0f}g"
                )

                if weight:
                    change = weight["change"]
                    if change != 0:
                        direction = "↓" if change < 0 else "↑"
                        lines.append(f"体重 {weight['start']:.1f} → {weight['end']:.1f}kg {direction}{abs(change):.1f}")

                if exercise["exercise_days"] > 0:
                    lines.append(
                        f"运动 {exercise['exercise_days']} 天 · "
                        f"{exercise['total_minutes']} 分钟 · "
                        f"消耗 {exercise['total_cal']:.0f} kcal"
                    )

                if water["total_ml"] > 0:
                    lines.append(
                        f"饮水日均 {water['avg_daily_ml']}ml · "
                        f"达标 {water['met_days']}/{food['total_days']} 天"
                    )

                if fasting:
                    lines.append(f"断食打卡 {fasting['checkin_count']} 次")

                body = " | ".join(lines) if lines else "查看完整周报"

                # 拼标题
                title = _format_weekly_title()
                _send_push_sync(uid, title, body, data={"report_type": "weekly"})
                push_count += 1
            except Exception as e:
                logger.error(f"[周报] user {uid} 处理异常: {e}")

        logger.info(f"[周报任务] 完成，共向 {push_count} 位用户发送推送")
    except Exception as e:
        logger.error(f"[周报任务] 异常: {e}", exc_info=True)
    finally:
        db.close()


def send_monthly_health_report():
    """每月1日 08:00 发送月报推送"""
    today = date.today()
    # 上个月范围
    if today.month == 1:
        start = date(today.year - 1, 12, 1)
        end = date(today.year - 1, 12, 31)
    else:
        start = date(today.year, today.month - 1, 1)
        # 当月1号的前一天 = 上月末
        end = today - timedelta(days=1)

    logger.info(f"[月报任务] 开始生成 {start} ~ {end} 月报")

    db = SessionLocal()
    try:
        user_ids = _get_active_user_ids(db, start, end)
        if not user_ids:
            logger.info("[月报任务] 无活跃用户，跳过")
            return

        push_count = 0
        for uid in user_ids:
            try:
                food = _aggregate_food_data(db, uid, start, end)
                if food["meal_count"] == 0:
                    continue

                weight = _get_weight_change(db, uid, start, end)
                exercise = _aggregate_exercise(db, uid, start, end)
                water = _aggregate_water(db, uid, start, end)
                fasting = _get_fasting_summary(db, uid, start, end)

                lines = []
                lines.append(f"记录 {food['record_days']} 天 · 共 {food['meal_count']} 餐")

                cal_text = f"日均摄入 {food['avg_daily_cal']:.0f} kcal"
                profile = db.query(UserProfile).filter(UserProfile.user_id == uid).first()
                if profile and profile.target_calories:
                    pct = food['avg_daily_cal'] / profile.target_calories * 100
                    if 80 <= pct <= 120:
                        cal_text += " ✓"
                    elif pct < 80:
                        cal_text += " ↓"
                    else:
                        cal_text += " ↑"
                lines.append(cal_text)

                if weight:
                    change = weight["change"]
                    if abs(change) > 0.1:
                        direction = "↓" if change < 0 else "↑"
                        lines.append(f"体重变化 {direction}{abs(change):.1f}kg")
                    else:
                        lines.append("体重保持稳定")

                if exercise["exercise_days"] > 0:
                    lines.append(f"运动 {exercise['exercise_days']} 天 · 共 {exercise['total_minutes']} 分钟")

                if water["total_ml"] > 0:
                    lines.append(f"饮水达标 {water['met_days']} 天")

                if fasting:
                    lines.append(f"断食打卡 {fasting['checkin_count']} 天")

                # 月度食物花费
                total_cost = db.query(
                    func.coalesce(func.sum(FoodRecord.cost), 0)
                ).filter(
                    FoodRecord.user_id == uid,
                    FoodRecord.record_date >= start,
                    FoodRecord.record_date <= end,
                ).scalar()
                if total_cost and float(total_cost) > 0:
                    lines.append(f"饮食花费 ¥{float(total_cost):.0f}")

                body = " | ".join(lines) if lines else "查看完整月报"

                title = _format_monthly_title()
                _send_push_sync(uid, title, body, data={"report_type": "monthly"})
                push_count += 1
            except Exception as e:
                logger.error(f"[月报] user {uid} 处理异常: {e}")

        logger.info(f"[月报任务] 完成，共向 {push_count} 位用户发送推送")
    except Exception as e:
        logger.error(f"[月报任务] 异常: {e}", exc_info=True)
    finally:
        db.close()
