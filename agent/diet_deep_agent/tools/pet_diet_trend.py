"""
宠物饮食趋势与预警工具

体重异常预警（连续变化>5%）、7天饮食趋势分析。
"""

from datetime import date, timedelta
from typing import Any

from langchain_core.tools import tool

VET_DISCLAIMER = "\n\n⚠️ 我是AI助手，建议仅供参考。宠物健康问题请咨询专业兽医。"


@tool
def analyze_weight_trend_alert(
    pet_id: int,
    weight_records: list[dict],
) -> dict[str, Any]:
    """分析宠物体重趋势，检测异常变化并预警。

    检查最近2周体重变化是否超过5%，
    检测连续趋势（持续上升/下降）。

    Args:
        pet_id: 宠物 ID
        weight_records: 体重记录列表 [{date, weight}]

    Returns:
        体重趋势分析结果和预警信息
    """
    if len(weight_records) < 2:
        return {
            "pet_id": pet_id,
            "has_alert": False,
            "message": "体重记录不足，无法分析趋势。",
            "trend": "insufficient_data",
        }

    # 按日期排序
    sorted_records = sorted(weight_records, key=lambda r: r.get("date", ""))

    # 最近2周变化
    latest = sorted_records[-1]
    earliest = sorted_records[0]
    latest_weight = float(latest.get("weight", 0))
    earliest_weight = float(earliest.get("weight", 0))

    if earliest_weight == 0:
        return {"pet_id": pet_id, "has_alert": False, "message": "无效体重数据。"}

    weight_change_pct = ((latest_weight - earliest_weight) / earliest_weight) * 100

    # 判断趋势
    if weight_change_pct > 5:
        trend = "rising"
        alert_level = "warning"
        message = (
            f"⚠️ 体重持续上升：近两周体重从 {earliest_weight}kg 升至 {latest_weight}kg，"
            f"增幅 {weight_change_pct:.1f}%（超过5%警戒线）。"
            f"\n建议控制饮食量，增加运动。如持续上升，请咨询兽医。"
        )
    elif weight_change_pct < -5:
        trend = "falling"
        alert_level = "warning"
        message = (
            f"⚠️ 体重持续下降：近两周体重从 {earliest_weight}kg 降至 {latest_weight}kg，"
            f"降幅 {abs(weight_change_pct):.1f}%（超过5%警戒线）。"
            f"\n建议检查是否有健康问题，及时咨询兽医。"
        )
    else:
        trend = "stable"
        alert_level = "normal"
        direction = "上升" if weight_change_pct > 0 else "下降" if weight_change_pct < 0 else "不变"
        message = (
            f"体重趋势正常：近两周变化 {abs(weight_change_pct):.1f}%，"
            f"方向：{direction}。继续保持。"
        )

    return {
        "pet_id": pet_id,
        "has_alert": alert_level != "normal",
        "alert_level": alert_level,
        "trend": trend,
        "earliest_weight": earliest_weight,
        "latest_weight": latest_weight,
        "weight_change_pct": round(weight_change_pct, 1),
        "records_count": len(weight_records),
        "advice": message + VET_DISCLAIMER,
    }


@tool
def analyze_weekly_diet_trend(
    pet_id: int,
    daily_summaries: list[dict],
    target_calories: int,
    target_protein: float,
) -> dict[str, Any]:
    """分析近7天宠物饮食趋势。

    Args:
        pet_id: 宠物 ID
        daily_summaries: 每日营养汇总 [{date, calories, protein, fat}]
        target_calories: 每日目标热量
        target_protein: 每日目标蛋白质

    Returns:
        7天饮食趋势报告
    """
    if not daily_summaries:
        return {
            "pet_id": pet_id,
            "status": "no_data",
            "message": "暂无饮食数据，无法分析趋势。",
        }

    # 计算7天统计
    calories_list = [s.get("total_calories", 0) for s in daily_summaries]
    protein_list = [s.get("total_protein", 0) for s in daily_summaries]

    total_calories = sum(calories_list)
    avg_calories = total_calories / len(calories_list) if calories_list else 0
    total_protein = sum(protein_list)
    avg_protein = total_protein / len(protein_list) if protein_list else 0

    # 达标天数
    on_target_days = sum(
        1 for c in calories_list if target_calories > 0 and 0.85 <= c / target_calories <= 1.15
    )
    under_days = sum(
        1 for c in calories_list if target_calories > 0 and c / target_calories < 0.85
    )
    over_days = sum(
        1 for c in calories_list if target_calories > 0 and c / target_calories > 1.15
    )

    avg_ratio = (avg_calories / target_calories * 100) if target_calories > 0 else 0

    # 蛋白质缺口检测
    protein_ratio = (avg_protein / target_protein * 100) if target_protein > 0 else 0
    protein_deficit = target_protein > 0 and protein_ratio < 80

    # 生成建议
    advice = f"近{len(daily_summaries)}天饮食趋势：\n"
    advice += f"- 平均每日热量：{avg_calories:.0f} kcal（目标的{avg_ratio:.0f}%）\n"
    advice += f"- 达标天数：{on_target_days}/{len(daily_summaries)}天\n"

    if under_days > len(daily_summaries) // 2:
        advice += "⚠️ 超过半数天数摄入不足，建议增加喂食量或提高食物营养密度。"
    elif over_days > len(daily_summaries) // 2:
        advice += "⚠️ 超过半数天数摄入超标，建议控制喂食量，减少零食。"
    else:
        advice += "整体饮食均衡，继续保持。"

    if protein_deficit:
        advice += f"\n⚠️ 蛋白质摄入持续偏低（平均仅达目标{protein_ratio:.0f}%），建议增加鲜食或高蛋白粮。"

    return {
        "pet_id": pet_id,
        "days_analyzed": len(daily_summaries),
        "avg_calories": round(avg_calories),
        "target_calories": target_calories,
        "avg_ratio_pct": round(avg_ratio),
        "avg_protein": round(avg_protein, 1),
        "target_protein": target_protein,
        "protein_ratio_pct": round(protein_ratio),
        "on_target_days": on_target_days,
        "under_days": under_days,
        "over_days": over_days,
        "has_protein_deficit": protein_deficit,
        "advice": advice + VET_DISCLAIMER,
    }