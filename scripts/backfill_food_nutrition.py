#!/usr/bin/env python3
"""历史记录营养回溯重算

背景：`analysis_status=1`（待分析）的记录表示写入时没在食物库匹配到营养数据，
因此不写 NutritionDetail、也不计入当日汇总。食物库后续补齐后，这些旧记录
不会自动重算，会永久停留在「0 kcal / 待分析」。

本脚本对这些记录重新跑一次食物库匹配（复用对话记录链路的同一套匹配与换算逻辑，
保证口径一致），命中则回填营养明细、置为已分析，并重算受影响的当日汇总。

用法：
    python scripts/backfill_food_nutrition.py                # 试运行，只报告不写库
    python scripts/backfill_food_nutrition.py --apply        # 实际写入
    python scripts/backfill_food_nutrition.py --user-id 10   # 只处理指定用户

重要限制：FoodRecord 表不存份量，脚本无法得知用户当初说了多少克，
统一按 DEFAULT_PORTION_G（100g）估算。若某条记录有明确份量，请先在
记录页手动补充营养，或先跳过该条，避免汇总偏差。
"""
import argparse
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from agent.diet_deep_agent.actions.definitions.record_food import (
    DEFAULT_PORTION_G,
    _lookup_food,
    _scale_nutrition,
    refresh_daily_summary,
)
from shared.models.database import SessionLocal
from shared.models.food_models import FoodRecord, NutritionDetail


def collect(db, user_id: int | None) -> tuple[list[dict], list[dict]]:
    """返回 (可回填的计划列表, 仍未命中的跳过列表)"""
    query = db.query(FoodRecord).filter(FoodRecord.analysis_status == 1)
    if user_id is not None:
        query = query.filter(FoodRecord.user_id == user_id)

    planned: list[dict] = []
    unmatched: list[dict] = []
    for record in query.order_by(FoodRecord.id).all():
        # 已有营养明细的记录不该被覆盖（unique 约束也会拒绝）
        exists = (
            db.query(NutritionDetail)
            .filter(NutritionDetail.food_record_id == record.id)
            .first()
        )
        if exists is not None:
            continue

        matched = _lookup_food(db, record.food_name or "")
        if matched is None:
            unmatched.append(
                {"id": record.id, "user_id": record.user_id, "food_name": record.food_name}
            )
            continue

        planned.append(
            {
                "id": record.id,
                "user_id": record.user_id,
                "record_date": record.record_date,
                "food_name": record.food_name,
                "matched_name": matched["matched_name"],
                "nutrition": _scale_nutrition(matched["per_100g"], DEFAULT_PORTION_G),
            }
        )
    return planned, unmatched


def main() -> None:
    parser = argparse.ArgumentParser(description="历史记录营养回溯重算")
    parser.add_argument("--apply", action="store_true", help="实际写入（默认仅试运行）")
    parser.add_argument("--user-id", type=int, default=None, help="只处理指定用户")
    args = parser.parse_args()

    db = SessionLocal()
    try:
        planned, unmatched = collect(db, args.user_id)
        mode = "写入" if args.apply else "试运行"
        print(
            f"[{mode}] 待分析记录中可回填 {len(planned)} 条，"
            f"仍未命中食物库 {len(unmatched)} 条（份量按 {DEFAULT_PORTION_G:g}g 估算）\n"
        )

        for item in planned:
            n = item["nutrition"]
            print(
                f"  记录 {item['id']} [{item['food_name']}] → 命中「{item['matched_name']}」: "
                f"{n['calories']:.1f} kcal / 蛋白 {n['protein']:.1f}g"
            )
        for item in unmatched:
            print(f"  记录 {item['id']} [{item['food_name']}] → 食物库仍无匹配，跳过")

        if not args.apply:
            print("\n（试运行未写库；确认无误后加 --apply 执行）")
            return

        touched: dict[tuple[int, object], int] = defaultdict(int)
        for item in planned:
            db.add(
                NutritionDetail(
                    food_record_id=item["id"],
                    analysis_method="food_database_backfill",
                    confidence_score=None,
                    **item["nutrition"],
                )
            )
            record = db.query(FoodRecord).filter(FoodRecord.id == item["id"]).first()
            record.analysis_status = 3
            touched[(item["user_id"], item["record_date"])] += 1
        db.commit()

        # 重算受影响的当日汇总（refresh_daily_summary 内部会一并失效 Redis 缓存）
        for (user_id, record_date), count in touched.items():
            totals = refresh_daily_summary(db, user_id, record_date)
            print(
                f"\n重算汇总 user={user_id} date={record_date}（回填 {count} 条）→ "
                f"{totals['total_calories']:.1f} kcal / 蛋白 {totals['total_protein']:.1f}g"
            )

        print(f"\n完成：回填 {len(planned)} 条，涉及 {len(touched)} 个日期")
    except Exception as e:
        db.rollback()
        print(f"错误: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
