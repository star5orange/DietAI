"""
宠物体重预警 Skill

检测体重异常变化，生成预警文案。
"""

from typing import Any

from langchain_core.tools import tool

VET_DISCLAIMER = "\n\n⚠️ 我是AI助手，建议仅供参考。宠物健康问题请咨询专业兽医。"


@tool
def detect_weight_anomaly(
    weight_records: list[dict],
    threshold_pct: float = 5.0,
) -> dict[str, Any]:
    """检测宠物体重异常变化并生成预警。

    检查最近2周内体重变化是否超过阈值百分比，
    判断连续趋势（持续上升/下降/波动/平稳）。

    Args:
        weight_records: 体重记录列表 [{"date": "2026-01-01", "weight": 5.2}, ...]
        threshold_pct: 异常阈值百分比，默认5%

    Returns:
        预警结果，包含预警等级、趋势描述和建议文案
    """
    if len(weight_records) < 2:
        return {
            "has_alert": False,
            "alert_level": "normal",
            "message": "体重记录不足（需至少2条），无法进行趋势分析。",
            "advice": f"请定期记录宠物体重，至少每2周测量一次。{VET_DISCLAIMER}",
        }

    # 按日期排序
    sorted_records = sorted(weight_records, key=lambda r: str(r.get("date", "")))

    latest = sorted_records[-1]
    earliest = sorted_records[0]
    latest_w = float(latest.get("weight", 0))
    earliest_w = float(earliest.get("weight", 0))

    if earliest_w <= 0:
        return {
            "has_alert": False,
            "alert_level": "normal",
            "message": "体重数据无效。",
        }

    change_pct = ((latest_w - earliest_w) / earliest_w) * 100
    abs_change = abs(change_pct)

    # 判断连续趋势（最近3条记录）
    trend = "stable"
    if len(sorted_records) >= 3:
        last_three = [float(r.get("weight", 0)) for r in sorted_records[-3:]]
        increasing = all(last_three[i] > last_three[i - 1] for i in range(1, 3))
        decreasing = all(last_three[i] < last_three[i - 1] for i in range(1, 3))
        if increasing:
            trend = "rising"
        elif decreasing:
            trend = "falling"

    # 预警等级判断
    if abs_change > threshold_pct * 2:  # >10%
        alert_level = "critical"
    elif abs_change > threshold_pct:  # >5%
        alert_level = "warning"
    else:
        alert_level = "normal"

    # 生成预警文案
    if alert_level == "critical":
        message = (
            f"🚨 严重预警：近两周体重变化 {change_pct:+.1f}%（{earliest_w}kg → {latest_w}kg）。"
            f"\n超出警戒线2倍！强烈建议立即咨询兽医进行检查。"
        )
    elif alert_level == "warning":
        message = (
            f"⚠️ 体重异常：近两周体重变化 {change_pct:+.1f}%（{earliest_w}kg → {latest_w}kg），"
            f"超过 {threshold_pct}% 警戒线。"
            f"\n趋势：{'持续上升' if trend == 'rising' else '持续下降' if trend == 'falling' else '波动中'}。"
        )
    else:
        direction = "上升" if change_pct > 0 else "下降" if change_pct < 0 else "持平"
        message = (
            f"体重趋势正常：近两周变化 {change_pct:+.1f}%（{earliest_w}kg → {latest_w}kg），"
            f"方向：{direction}。继续保持当前喂养方案。"
        )

    return {
        "has_alert": alert_level != "normal",
        "alert_level": alert_level,
        "trend": trend,
        "earliest_weight": earliest_w,
        "latest_weight": latest_w,
        "weight_change_pct": round(change_pct, 1),
        "records_count": len(weight_records),
        "message": message,
        "advice": message + VET_DISCLAIMER,
    }


# 模块导出列表
__all__ = ["detect_weight_anomaly"]
