"""
家人线演示数据种子脚本 —— 为老人夹具账号造近两天的饮食/饮水/体重数据。

用途：家人健康页 / 家人状态卡（query_family）/ 父母日报 / 成本卡等用例
（TC-001~002、TC-005~006、TC-015、TC-034~038 等）需要有真实数据才可观察。
此前夹具账号（79/41/32）档案全空，导致"没有老人信息"。

用法:
    uv run python tests/seed_family_demo.py              # 造今天+昨天的饮食/体重（不动饮水）
    uv run python tests/seed_family_demo.py --with-water # 连饮水一起造（会稀释 B3 喝水不足告警）
    uv run python tests/seed_family_demo.py --days 3     # 造近三天

设计：
- 默认**不造饮水**：B3 异常告警（喝水不足）依赖老人饮水偏低，造满水会让
  TC-003/TC-004 的告警链路失去触发条件。需要饮水演示时显式加 --with-water。
- 幂等：某老人某天已有饮食记录则跳过该老人该天，不重复造。
- 营养汇总按 food_router._update_daily_summary 同口径内联重算。
"""

import argparse
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from shared.models.database import SessionLocal
from shared.models.exam_models import ExamMetric, ExamReport
from shared.models.food_models import DailyNutritionSummary, FoodRecord, NutritionDetail
from shared.models.user_models import WeightRecord
from shared.models.water_models import WaterIntakeRecord

# 老人夹具账号（与 tests/intent_eval.py / care_tasks 家人夹具一致）
ELDERS = [79, 41, 32]
# 主测账号（流程二二期动作需要：成本周数据 / 体重趋势 / 昨天 / 体检报告）
MAIN_ACCOUNT = 10
MAIN_DAYS = 7

# 每天三餐的演示数据：(meal_type, 餐名, food_name, 热量, 蛋白g, 脂肪g, 碳水g, 消费元, 来源)
MEALS = [
    (1, "早餐", "燕麦粥 + 水煮蛋", 380, 18, 10, 55, 8.0, "home"),
    (2, "午餐", "番茄炒蛋 + 米饭", 620, 25, 18, 82, 22.5, "canteen"),
    (3, "晚餐", "清蒸鱼 + 时蔬", 520, 35, 15, 45, 28.0, "delivery"),
]

MEAL_TIME_HOUR = {1: 8, 2: 12, 3: 18}


def seed_day(db, elder_id: int, day: date, with_water: bool) -> bool:
    """给单个老人造某天的数据；已有饮食记录则跳过。返回是否新造。"""
    exists = db.query(FoodRecord).filter(
        FoodRecord.user_id == elder_id, FoodRecord.record_date == day
    ).first()
    if exists:
        return False

    for meal_type, meal_name, food_name, cal, pro, fat, carb, cost, tag in MEALS:
        record = FoodRecord(
            user_id=elder_id,
            record_date=day,
            record_time=datetime(day.year, day.month, day.day, MEAL_TIME_HOUR[meal_type], 0),
            meal_type=meal_type,
            food_name=f"{food_name}（演示）",
            description=f"家人线演示数据 · {meal_name}",
            recording_method=1,
            analysis_status=3,
            from_source="manual",
            cost=cost,
            source_tag=tag,
        )
        db.add(record)
        db.flush()
        db.add(NutritionDetail(
            food_record_id=record.id,
            calories=cal, protein=pro, fat=fat, carbohydrates=carb,
            confidence_score=1.0,
        ))
    # SessionLocal 为 autoflush=False：循环内 pending 的营养明细必须显式 flush，
    # 否则下面的汇总重算查不到最后一条（会出现"少一餐热量"的静默错账）
    db.flush()

    # 体重：当天一条
    db.add(WeightRecord(
        user_id=elder_id,
        weight=65.5,
        measured_at=datetime(day.year, day.month, day.day, 7, 30),
        notes="家人线演示数据",
    ))

    # 饮水：默认不造（保住 B3 喝水不足告警的触发条件）
    if with_water:
        for hour, ml in ((9, 300), (11, 250), (15, 400), (19, 300)):
            db.add(WaterIntakeRecord(
                user_id=elder_id,
                amount_ml=ml,
                record_time=datetime(day.year, day.month, day.day, hour, 0),
                drink_type="水",
            ))

    _rebuild_daily_summary(db, elder_id, day)
    return True


def _add_demo_metrics(db, report_id: int) -> None:
    metrics = [
        # (category, 名称, 值, 单位, 参考范围文本, 下限, 上限, status, 异常)
        ("glucose", "空腹血糖", 6.3, "mmol/L", "3.9-6.1", 3.9, 6.1, "high", True),
        ("blood_routine", "血红蛋白", 145, "g/L", "130-175", 130, 175, "normal", False),
        ("lipids", "总胆固醇", 4.8, "mmol/L", "2.8-5.7", 2.8, 5.7, "normal", False),
    ]
    for category, name, value, unit, ref, lo, hi, status, abnormal in metrics:
        db.add(ExamMetric(
            report_id=report_id,
            category=category,
            metric_name=name,
            metric_value=value,
            unit=unit,
            reference_range=ref,
            reference_min=lo,
            reference_max=hi,
            status=status,
            is_abnormal=abnormal,
        ))
    db.flush()


def seed_exam_report(db, user_id: int) -> bool:
    """给账号造一份演示体检报告（0 指标的空报告会补指标）。返回是否新造/补齐。"""
    exists = db.query(ExamReport).filter(ExamReport.user_id == user_id).first()
    if exists:
        # 0 指标空报告会被 query_exam 跳过（§35）——补上演示指标
        has_metrics = db.query(ExamMetric).filter(ExamMetric.report_id == exists.id).first()
        if has_metrics:
            return False
        _add_demo_metrics(db, exists.id)
        return True
    exam_day = date.today() - timedelta(days=30)
    report = ExamReport(
        user_id=user_id,
        exam_date=exam_day,
        report_date=exam_day,
        hospital_name="演示体检中心",
        report_type="full",
        abnormal_count=1,
        summary="演示体检报告：空腹血糖偏高，其余指标正常。",
        doctor_advice="少糖饮食，一个月后复查空腹血糖。",
        ai_analysis_enabled=False,
    )
    db.add(report)
    db.flush()
    _add_demo_metrics(db, report.id)
    return True


def _rebuild_daily_summary(db, user_id: int, day: date) -> None:
    """与 routers/food_router._update_daily_summary 同口径：聚合 analysis_status=3 的营养明细"""
    records = db.query(FoodRecord).filter(
        FoodRecord.user_id == user_id,
        FoodRecord.record_date == day,
        FoodRecord.analysis_status == 3,
    ).all()
    total_cal = total_pro = total_fat = total_carb = 0.0
    for r in records:
        nd = db.query(NutritionDetail).filter(NutritionDetail.food_record_id == r.id).first()
        if nd:
            total_cal += float(nd.calories or 0)
            total_pro += float(nd.protein or 0)
            total_fat += float(nd.fat or 0)
            total_carb += float(nd.carbohydrates or 0)
    meal_count = db.query(FoodRecord).filter(
        FoodRecord.user_id == user_id, FoodRecord.record_date == day
    ).count()

    summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date == day,
    ).first()
    if not summary:
        summary = DailyNutritionSummary(user_id=user_id, summary_date=day)
        db.add(summary)
    summary.total_calories = round(total_cal, 2)
    summary.total_protein = round(total_pro, 2)
    summary.total_fat = round(total_fat, 2)
    summary.total_carbohydrates = round(total_carb, 2)
    summary.meal_count = meal_count
    db.commit()


def main():
    parser = argparse.ArgumentParser(description="家人线演示数据种子")
    parser.add_argument("--days", type=int, default=2, help="造最近 N 天（含今天，默认 2）")
    parser.add_argument("--with-water", action="store_true", help="连饮水一起造（会稀释 B3 喝水不足告警）")
    parser.add_argument("--fix-summaries", action="store_true", help="跳过造数，仅按现有明细重算每日汇总（修历史错账）")
    args = parser.parse_args()

    db = SessionLocal()
    created, skipped = 0, 0
    try:
        if args.fix_summaries:
            for offset in range(args.days):
                day = date.today() - timedelta(days=offset)
                for elder_id in ELDERS:
                    _rebuild_daily_summary(db, elder_id, day)
                    print(f"  √ user {elder_id} @ {day} 汇总已重算")
            db.commit()
            print("\n汇总修复完成。")
            return
        for offset in range(args.days):
            day = date.today() - timedelta(days=offset)
            for elder_id in ELDERS:
                if seed_day(db, elder_id, day, args.with_water):
                    created += 1
                    print(f"  + user {elder_id} @ {day} 已造（三餐/体重{'/饮水' if args.with_water else ''}）")
                else:
                    skipped += 1
                    print(f"  · user {elder_id} @ {day} 已有数据，跳过")
        # 主测账号：至少 7 天（成本周数据 / 体重趋势 / 二期动作依赖）
        for offset in range(max(args.days, MAIN_DAYS)):
            day = date.today() - timedelta(days=offset)
            if seed_day(db, MAIN_ACCOUNT, day, args.with_water):
                created += 1
                print(f"  + user {MAIN_ACCOUNT} @ {day} 已造（三餐含消费/体重{'/饮水' if args.with_water else ''}）")
            else:
                skipped += 1
                print(f"  · user {MAIN_ACCOUNT} @ {day} 已有数据，跳过")
        if seed_exam_report(db, MAIN_ACCOUNT):
            created += 1
            print(f"  + user {MAIN_ACCOUNT} 体检报告已造（含 3 项指标，血糖偏高）")
        else:
            skipped += 1
            print(f"  · user {MAIN_ACCOUNT} 已有体检报告，跳过")
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

    print(f"\n完成：新造 {created} 组，跳过 {skipped} 组。")
    print("提示：默认未造饮水 → 老人当日喝水不足，B3 告警（TC-003/TC-004）仍可触发。")


if __name__ == "__main__":
    main()
