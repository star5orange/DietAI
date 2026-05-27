"""
Markdown Renderer - Converts structured data to Markdown format.

Provides rendering functions for each workspace type:
- render_shared_memory: User profile, health status, preferences
- render_goal_tracking: Goals, targets, progress
- render_nutrition_workspace: Diet summary, frequent foods
- render_chat_workspace: Conversation preferences, topics
"""

from datetime import datetime, date
from typing import Optional, List, Dict, Any
import yaml

from agent.memory.schemas import (
    SharedMemoryData,
    GoalTrackingData,
    NutritionWorkspaceData,
    ChatWorkspaceData,
    AllergyInfo,
    DiseaseInfo,
    MedicationInfo,
    ActiveGoal,
    DailyTargets,
    WeightProgress,
    TodayStatus,
    Milestone,
    DietSummary,
    FrequentFood,
    NutritionTrend,
    RecentAnalysis,
    ConversationPreferences,
    FrequentTopic,
    InteractionSummary,
    UserFeedback
)


def _render_frontmatter(data: Dict[str, Any]) -> str:
    """Render YAML frontmatter."""
    return f"---\n{yaml.dump(data, allow_unicode=True, default_flow_style=False)}---\n\n"


def _format_date(d: Optional[date]) -> str:
    """Format date for display."""
    if d is None:
        return "未设定"
    return d.isoformat() if isinstance(d, date) else str(d)


def _format_datetime(dt: Optional[datetime]) -> str:
    """Format datetime for display."""
    if dt is None:
        return "未知"
    return dt.strftime("%Y-%m-%d %H:%M") if isinstance(dt, datetime) else str(dt)


# ============== Shared Memory Renderer ==============

def render_shared_memory(data: SharedMemoryData) -> str:
    """
    Render SharedMemoryData to Markdown format.

    Args:
        data: Shared memory data

    Returns:
        Formatted Markdown string
    """
    lines = []

    # Frontmatter
    frontmatter = {
        "user_id": data.user_id,
        "last_updated": data.last_updated.isoformat(),
        "schema_version": data.schema_version
    }
    lines.append(_render_frontmatter(frontmatter))

    # Title
    lines.append("# 用户长期画像\n")

    # 基础信息
    lines.append("## 基础信息")
    gender_map = {1: "男", 2: "女", 3: "其他"}
    lines.append(f"- 性别: {gender_map.get(data.gender, '未知')} | 年龄: {data.age} | 身高: {data.height}cm | 体重: {data.weight}kg")
    activity_map = {1: "久坐", 2: "轻度活动", 3: "中度活动", 4: "重度活动", 5: "超重度活动"}
    lines.append(f"- 活动水平: {activity_map.get(data.activity_level, '轻度活动')} ({data.activity_level})\n")

    # 健康状况
    lines.append("## 健康状况")

    # 过敏原
    lines.append("### 过敏原")
    if data.allergies:
        severity_map = {1: "轻度", 2: "中度", 3: "重度"}
        for allergy in data.allergies:
            severity = severity_map.get(allergy.severity, "未知")
            lines.append(f"- {allergy.name} (严重度: {allergy.severity}-{severity})")
    else:
        lines.append("- 无已知过敏原")
    lines.append("")

    # 疾病
    lines.append("### 疾病/医疗状况")
    if data.diseases:
        for disease in data.diseases:
            icd = f" (ICD-10: {disease.icd_code})" if disease.icd_code else ""
            lines.append(f"- {disease.name}{icd}, {disease.status}")
    else:
        lines.append("- 无已知疾病")
    lines.append("")

    # 用药情况
    lines.append("### 用药情况")
    if data.medications:
        for med in data.medications:
            lines.append(f"- {med.name} {med.dosage} ({med.frequency})")
    else:
        lines.append("- 无正在服用的药物")
    lines.append("")

    # 长期偏好
    lines.append("## 长期偏好")
    prefs = data.food_preferences

    lines.append("### 喜欢的食物")
    if prefs.liked_foods:
        lines.append(f"- {', '.join(prefs.liked_foods)}")
    else:
        lines.append("- 暂无记录")
    lines.append("")

    lines.append("### 不喜欢的食物")
    if prefs.disliked_foods:
        lines.append(f"- {', '.join(prefs.disliked_foods)}")
    else:
        lines.append("- 暂无记录")
    lines.append("")

    lines.append("### 饮食限制")
    if prefs.dietary_restrictions:
        for restriction in prefs.dietary_restrictions:
            lines.append(f"- {restriction}")
    else:
        lines.append("- 无特殊饮食限制")
    lines.append("")

    # 行为模式
    lines.append("## 行为模式")
    patterns = data.behavior_patterns

    lines.append("### 用餐时间习惯")
    meal_times = patterns.meal_times
    lines.append(f"- 早餐: {meal_times.get('breakfast', '未设定')} | 午餐: {meal_times.get('lunch', '未设定')} | 晚餐: {meal_times.get('dinner', '未设定')}")
    lines.append("")

    lines.append("### 作息规律")
    sleep = patterns.sleep_schedule
    lines.append(f"- 入睡: {sleep.get('bedtime', '未设定')} | 起床: {sleep.get('wake_time', '未设定')}")
    lines.append("")

    lines.append("### 运动习惯")
    if patterns.exercise_routine:
        routine = patterns.exercise_routine
        lines.append(f"- 类型: {routine.get('type', '未知')}")
        lines.append(f"- 频率: {routine.get('frequency', '未知')}")
        lines.append(f"- 时长: {routine.get('duration', '未知')}")
    else:
        lines.append("- 暂无运动计划")
    lines.append("")

    lines.append("### 消费水平")
    lines.append(f"- {patterns.budget_level}")

    return "\n".join(lines)


# ============== Goal Tracking Renderer ==============

def render_goal_tracking(data: GoalTrackingData) -> str:
    """
    Render GoalTrackingData to Markdown format.

    Args:
        data: Goal tracking data

    Returns:
        Formatted Markdown string
    """
    lines = []

    # Frontmatter
    frontmatter = {
        "user_id": data.user_id,
        "last_updated": data.last_updated.isoformat()
    }
    lines.append(_render_frontmatter(frontmatter))

    # Title
    lines.append("# 目标追踪工作区\n")

    # 当前活跃目标
    lines.append("## 当前活跃目标")
    if data.active_goal:
        goal = data.active_goal
        goal_type_map = {1: "减重", 2: "增重", 3: "维持", 4: "增肌", 5: "减脂"}
        lines.append(f"- 目标ID: {goal.goal_id}")
        lines.append(f"- 目标类型: {goal_type_map.get(goal.goal_type, '未知')} ({goal.goal_type})")
        if goal.target_weight:
            lines.append(f"- 目标体重: {goal.target_weight} kg")
        if goal.target_date:
            lines.append(f"- 目标日期: {_format_date(goal.target_date)}")
        lines.append(f"- 状态: {goal.status}")
    else:
        lines.append("- 暂无活跃目标")
    lines.append("")

    # 计算基准
    lines.append("## 计算基准")

    lines.append("### BMR/TDEE")
    if data.bmr_tdee:
        bmr = data.bmr_tdee
        lines.append(f"- BMR: {bmr.bmr} kcal (Mifflin-St Jeor)")
        lines.append(f"- TDEE: {bmr.tdee} kcal (活动因子: {bmr.activity_factor})")
        lines.append(f"- 计算日期: {_format_date(bmr.calculated_at.date() if isinstance(bmr.calculated_at, datetime) else bmr.calculated_at)}")
    else:
        lines.append("- 尚未计算")
    lines.append("")

    lines.append("### 每日营养配额")
    if data.daily_targets:
        targets = data.daily_targets
        adj_str = f"赤字 {abs(targets.calorie_adjustment)}" if targets.calorie_adjustment < 0 else f"盈余 {targets.calorie_adjustment}" if targets.calorie_adjustment > 0 else "无调整"
        lines.append(f"- 卡路里预算: {targets.calories} kcal ({adj_str})")
        lines.append(f"- 蛋白质: {targets.protein}g")
        lines.append(f"- 碳水: {targets.carbs}g")
        lines.append(f"- 脂肪: {targets.fat}g")
    else:
        lines.append("- 尚未设定")
    lines.append("")

    # 进度追踪
    lines.append("## 进度追踪")

    lines.append("### 体重变化")
    if data.weight_progress:
        wp = data.weight_progress
        lines.append(f"- 起始体重: {wp.starting_weight} kg ({_format_date(wp.starting_date)})")
        lines.append(f"- 当前体重: {wp.current_weight} kg ({_format_date(wp.current_date)})")
        change_str = f"减重 {abs(wp.weight_change)}" if wp.weight_change < 0 else f"增重 {wp.weight_change}" if wp.weight_change > 0 else "无变化"
        lines.append(f"- 已{change_str} kg")
        if wp.target_remaining is not None:
            lines.append(f"- 目标剩余: {wp.target_remaining} kg")
        lines.append(f"- 完成进度: {wp.progress_percentage}%")
    else:
        lines.append("- 暂无体重记录")
    lines.append("")

    lines.append("### 今日状态")
    status = data.today_status
    lines.append(f"- 已摄入卡路里: {status.consumed_calories} kcal")
    lines.append(f"- 剩余配额: {status.remaining_calories} kcal")
    if data.daily_targets:
        lines.append(f"- 蛋白质: {status.consumed_protein}g / {data.daily_targets.protein}g")
        lines.append(f"- 碳水: {status.consumed_carbs}g / {data.daily_targets.carbs}g")
        lines.append(f"- 脂肪: {status.consumed_fat}g / {data.daily_targets.fat}g")
    lines.append("")

    # 里程碑
    lines.append("## 里程碑")
    if data.milestones:
        for milestone in data.milestones:
            check = "x" if milestone.completed else " "
            date_str = f" ({_format_date(milestone.achieved_date)})" if milestone.achieved_date else ""
            status_str = " ✓" if milestone.completed else " (进行中)" if not milestone.completed else ""
            lines.append(f"- [{check}] {milestone.description}{date_str}{status_str}")
    else:
        lines.append("- 暂无里程碑")
    lines.append("")

    # Agent 生成的建议
    lines.append("## Agent 生成的建议")
    if data.suggestions:
        for suggestion in data.suggestions:
            lines.append(f"- {suggestion}")
    else:
        lines.append("- 暂无建议")

    if data.warnings:
        lines.append("\n### 警告")
        for warning in data.warnings:
            lines.append(f"- ⚠️ {warning}")

    return "\n".join(lines)


# ============== Nutrition Workspace Renderer ==============

def render_nutrition_workspace(data: NutritionWorkspaceData) -> str:
    """
    Render NutritionWorkspaceData to Markdown format.

    Args:
        data: Nutrition workspace data

    Returns:
        Formatted Markdown string
    """
    lines = []

    # Frontmatter
    frontmatter = {
        "user_id": data.user_id,
        "last_updated": data.last_updated.isoformat()
    }
    lines.append(_render_frontmatter(frontmatter))

    # Title
    lines.append("# 营养分析工作区\n")

    # 近期饮食摘要
    lines.append("## 近期饮食摘要")
    summary = data.diet_summary
    lines.append(f"(近{summary.period_days}天)")
    lines.append(f"- 日均卡路里: {summary.avg_calories} kcal")
    lines.append(f"- 日均蛋白质: {summary.avg_protein}g")
    lines.append(f"- 日均碳水: {summary.avg_carbs}g")
    lines.append(f"- 日均脂肪: {summary.avg_fat}g")
    lines.append(f"- 餐次规律性: {summary.meal_regularity}")
    lines.append("")

    # 高频食物
    lines.append("## 高频食物 (近30天)")
    if data.frequent_foods:
        lines.append("| 食物 | 频次 | 平均热量 | 健康等级 |")
        lines.append("|------|------|----------|----------|")
        for food in data.frequent_foods:
            lines.append(f"| {food.name} | {food.frequency}次 | {food.avg_calories} kcal | {food.health_level} |")
    else:
        lines.append("暂无记录")
    lines.append("")

    # 营养趋势
    lines.append("## 营养趋势")
    if data.nutrition_trends:
        for trend in data.nutrition_trends:
            lines.append(f"### {trend.metric}")
            lines.append(f"- 本周: {trend.current_week}% | 上周: {trend.last_week}% | 趋势: {trend.trend}")
    else:
        lines.append("暂无趋势数据")
    lines.append("")

    # 近期分析记录
    lines.append("## 近期分析记录")
    if data.recent_analyses:
        for analysis in data.recent_analyses[:5]:  # Show last 5
            lines.append(f"### {_format_date(analysis.date)} {analysis.meal_type}")
            lines.append(f"- 食物: {', '.join(analysis.foods)}")
            lines.append(f"- 热量: {analysis.calories} kcal")
            lines.append(f"- 健康等级: {analysis.health_level}")
    else:
        lines.append("暂无分析记录")

    return "\n".join(lines)


# ============== Chat Workspace Renderer ==============

def render_chat_workspace(data: ChatWorkspaceData) -> str:
    """
    Render ChatWorkspaceData to Markdown format.

    Args:
        data: Chat workspace data

    Returns:
        Formatted Markdown string
    """
    lines = []

    # Frontmatter
    frontmatter = {
        "user_id": data.user_id,
        "last_updated": data.last_updated.isoformat()
    }
    lines.append(_render_frontmatter(frontmatter))

    # Title
    lines.append("# 对话工作区\n")

    # 对话偏好
    lines.append("## 对话偏好")
    prefs = data.preferences
    lines.append(f"- {'偏好详细解释' if prefs.prefers_detailed_explanation else '偏好简洁回答'}")
    lines.append(f"- {'喜欢数据驱动的建议' if prefs.likes_data_driven_advice else '偏好感性建议'}")
    lines.append(f"- 回答风格: {prefs.response_style}")
    if prefs.topics_of_interest:
        lines.append(f"- 感兴趣的话题: {', '.join(prefs.topics_of_interest)}")
    lines.append("")

    # 常见问题主题
    lines.append("## 常见问题主题")
    if data.frequent_topics:
        for i, topic in enumerate(data.frequent_topics, 1):
            lines.append(f"{i}. {topic.topic} (问过{topic.count}次)")
    else:
        lines.append("暂无记录")
    lines.append("")

    # 近期交互摘要
    lines.append("## 近期交互摘要")
    if data.recent_interactions:
        for interaction in data.recent_interactions[:5]:  # Show last 5
            lines.append(f"### {_format_date(interaction.date)}")
            lines.append(f"- 话题: {interaction.topic}")
            lines.append(f"- 用户问: \"{interaction.user_question}\"")
            if interaction.key_points:
                lines.append(f"- 关注点: {', '.join(interaction.key_points)}")
    else:
        lines.append("暂无交互记录")
    lines.append("")

    # 用户反馈记录
    lines.append("## 用户反馈记录")
    if data.user_feedback:
        for feedback in data.user_feedback[:5]:  # Show last 5
            lines.append(f"- {_format_date(feedback.date)}: {feedback.feedback} ({feedback.sentiment})")
    else:
        lines.append("暂无反馈记录")

    return "\n".join(lines)


# ============== Convenience Functions ==============

def render_workspace(workspace: str, data: Any) -> str:
    """
    Render any workspace data to Markdown.

    Args:
        workspace: Workspace name
        data: Workspace data object

    Returns:
        Formatted Markdown string
    """
    renderers = {
        "shared": render_shared_memory,
        "goal_tracking": render_goal_tracking,
        "nutrition": render_nutrition_workspace,
        "chat": render_chat_workspace
    }

    renderer = renderers.get(workspace)
    if not renderer:
        raise ValueError(f"Unknown workspace: {workspace}")

    return renderer(data)
