"""轻断食/辟谷业务逻辑"""
import logging
from datetime import date, datetime, timedelta
from typing import Optional, Dict, Any, List

from sqlalchemy.orm import Session
from sqlalchemy import func

from shared.models.fasting_models import FastingPlan, FastingCheckin
from shared.models.user_models import UserProfile, User

logger = logging.getLogger(__name__)

# 禁忌条件
CONTRAINDICATIONS = {
    "is_pregnant": "孕妇不建议进行断食",
    "is_breastfeeding": "哺乳期女性不建议进行断食",
    "is_minor": "未成年人（<18岁）不建议进行断食",
    "has_diabetes": "糖尿病患者不建议自行断食，请咨询医生",
    "has_eating_disorder": "进食障碍患者不建议进行断食",
    "bmi_too_low": "BMI 过低（<18.5），不建议启用断食模式",
}

# 复食指导模板
REFEED_GUIDES = {
    "16_8": {
        "refeed_duration": "7 days",
        "phases": [
            {
                "day": "1-2",
                "description": "清淡饮食阶段",
                "foods": ["粥", "蒸蔬菜", "清淡汤品", "鸡蛋羹"],
                "avoid": ["油炸食品", "辛辣食物", "高蛋白大餐"],
            },
            {
                "day": "3-5",
                "description": "渐进恢复阶段",
                "foods": ["全谷物", "瘦肉", "豆制品", "新鲜水果"],
                "avoid": ["暴饮暴食", "过度油腻"],
            },
            {
                "day": "6-7",
                "description": "正常饮食恢复",
                "tips": "逐步恢复到正常饮食结构，保持 16:8 时间窗口的习惯",
            },
        ],
        "disclaimer": "复食期间如出现不适，请立即咨询医生。本建议仅供参考。",
    },
    "5_2": {
        "refeed_duration": "5 days",
        "phases": [
            {
                "day": "1-2",
                "description": "低热量过渡阶段",
                "foods": ["蔬菜汤", "蒸鱼", "燕麦粥", "低脂酸奶"],
                "avoid": ["高糖食物", "加工食品"],
            },
            {
                "day": "3-5",
                "description": "正常饮食恢复",
                "foods": ["均衡三餐", "全谷物", "优质蛋白"],
                "tips": "恢复正常热量摄入，但建议保持健康饮食结构",
            },
        ],
        "disclaimer": "复食期间如出现不适，请立即咨询医生。本建议仅供参考。",
    },
    "basic_fasting": {
        "refeed_duration": "7 days",
        "phases": [
            {
                "day": "1-2",
                "description": "流质/半流质阶段",
                "foods": ["米汤", "蔬菜汁", "清淡汤品", "藕粉"],
                "avoid": ["固体食物", "油腻", "辛辣"],
            },
            {
                "day": "3-5",
                "description": "软食渐进阶段",
                "foods": ["粥", "蒸蔬菜", "豆腐", "烂面条"],
                "avoid": ["油炸", "生冷", "高纤维"],
            },
            {
                "day": "6-7",
                "description": "清淡饮食恢复",
                "foods": ["全谷物", "瘦肉", "豆制品", "清淡炒菜"],
                "tips": "循序渐进，逐步恢复到正常饮食结构",
            },
        ],
        "disclaimer": "辟谷后复食极为重要，请严格遵循渐进原则。如出现不适，请立即咨询医生。本建议仅供参考，不能替代医生诊断。",
    },
}


def health_assessment_check(health_data: Dict[str, Any]) -> List[str]:
    """健康评估禁忌筛查

    Args:
        health_data: 包含 bmi, is_pregnant, is_breastfeeding, is_minor, has_diabetes, has_eating_disorder

    Returns:
        禁忌原因列表，空列表表示通过
    """
    warnings = []

    if health_data.get("is_pregnant"):
        warnings.append(CONTRAINDICATIONS["is_pregnant"])
    if health_data.get("is_breastfeeding"):
        warnings.append(CONTRAINDICATIONS["is_breastfeeding"])
    if health_data.get("is_minor"):
        warnings.append(CONTRAINDICATIONS["is_minor"])
    if health_data.get("has_diabetes"):
        warnings.append(CONTRAINDICATIONS["has_diabetes"])
    if health_data.get("has_eating_disorder"):
        warnings.append(CONTRAINDICATIONS["has_eating_disorder"])

    bmi = health_data.get("bmi")
    if bmi is not None and float(bmi) < 18.5:
        warnings.append(CONTRAINDICATIONS["bmi_too_low"])

    return warnings


def create_fasting_plan(
    db: Session,
    user_id: int,
    plan_type: str,
    start_date: date,
    health_assessment: Optional[Dict[str, Any]],
    disclaimer_accepted: bool = False,
    target_weight: Optional[float] = None,
    eating_window_start: Optional[str] = "08:00",
    eating_window_end: Optional[str] = "16:00",
) -> Dict[str, Any]:
    """创建轻断食计划

    Returns:
        创建结果，包含 plan_id、warnings
    """
    # 检查是否有活跃计划
    active_plan = db.query(FastingPlan).filter(
        FastingPlan.user_id == user_id,
        FastingPlan.status.in_(["active", "paused"])
    ).first()

    if active_plan:
        raise ValueError("已存在进行中的断食计划，请先停止当前计划")

    # 健康评估
    warnings = []
    if health_assessment:
        warnings = health_assessment_check(health_assessment)

    # 禁止禁忌人群创建高风险计划
    if warnings and plan_type == "basic_fasting":
        raise ValueError(f"您属于禁忌人群（{'；'.join(warnings)}），不建议启用辟谷模式，请选择其他减脂方式")

    # 创建计划
    plan = FastingPlan(
        user_id=user_id,
        plan_type=plan_type,
        target_weight=target_weight,
        start_date=start_date,
        status="active",
        eating_window_start=datetime.strptime(eating_window_start, "%H:%M").time(),
        eating_window_end=datetime.strptime(eating_window_end, "%H:%M").time(),
        disclaimer_accepted=disclaimer_accepted,
        disclaimer_accepted_at=datetime.utcnow() if disclaimer_accepted else None,
        health_assessment=health_assessment,
    )

    db.add(plan)
    db.commit()
    db.refresh(plan)

    return {
        "plan_id": plan.id,
        "plan_type": plan.plan_type,
        "status": plan.status,
        "eating_window": f"{eating_window_start}-{eating_window_end}",
        "estimated_duration": "30 days",
        "warnings": warnings,
    }


def get_fasting_plans(
    db: Session,
    user_id: int,
    status_filter: Optional[str] = None
) -> Dict[str, Any]:
    """获取用户断食计划列表"""
    query = db.query(FastingPlan).filter(FastingPlan.user_id == user_id)

    if status_filter:
        query = query.filter(FastingPlan.status == status_filter)

    plans = query.order_by(FastingPlan.created_at.desc()).all()

    result = []
    for p in plans:
        # 获取最新打卡体重
        latest_checkin = db.query(FastingCheckin).filter(
            FastingCheckin.plan_id == p.id,
            FastingCheckin.weight.isnot(None)
        ).order_by(FastingCheckin.checkin_date.desc()).first()

        days_elapsed = (date.today() - p.start_date).days
        days_remaining = None
        if p.end_date:
            days_remaining = max(0, (p.end_date - date.today()).days)

        result.append({
            "plan_id": p.id,
            "plan_type": p.plan_type,
            "status": p.status,
            "start_date": p.start_date.isoformat(),
            "days_elapsed": days_elapsed,
            "days_remaining": days_remaining,
            "target_weight": float(p.target_weight) if p.target_weight else None,
            "current_weight": float(latest_checkin.weight) if latest_checkin else None,
            "eating_window_start": p.eating_window_start.strftime("%H:%M"),
            "eating_window_end": p.eating_window_end.strftime("%H:%M"),
        })

    return {"plans": result}


def update_fasting_plan(
    db: Session,
    plan_id: int,
    user_id: int,
    target_weight: Optional[float] = None,
    eating_window_start: Optional[str] = None,
    eating_window_end: Optional[str] = None,
    end_date: Optional[date] = None,
) -> Dict[str, Any]:
    """更新断食计划"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    if plan.status not in ("active", "paused"):
        raise ValueError("只能修改进行中或暂停的计划")

    if target_weight is not None:
        plan.target_weight = target_weight
    if eating_window_start is not None:
        plan.eating_window_start = datetime.strptime(eating_window_start, "%H:%M").time()
    if eating_window_end is not None:
        plan.eating_window_end = datetime.strptime(eating_window_end, "%H:%M").time()
    if end_date is not None:
        plan.end_date = end_date

    db.commit()
    db.refresh(plan)

    return {
        "plan_id": plan.id,
        "plan_type": plan.plan_type,
        "status": plan.status,
        "message": "计划更新成功",
    }


def stop_fasting_plan(
    db: Session,
    plan_id: int,
    user_id: int,
) -> Dict[str, Any]:
    """停止断食计划"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    if plan.status not in ("active", "paused"):
        raise ValueError("计划已经结束，无需重复停止")

    plan.status = "stopped"
    db.commit()

    return {
        "plan_id": plan.id,
        "status": plan.status,
        "message": "计划已停止，如有需要可查看复食指导",
    }


def create_checkin(
    db: Session,
    plan_id: int,
    user_id: int,
    checkin_date: date,
    weight: Optional[float] = None,
    feeling: str = "normal",
    completed: bool = False,
    discomfort: Optional[Dict[str, bool]] = None,
    notes: Optional[str] = None,
) -> Dict[str, Any]:
    """每日打卡"""
    # 验证计划所有权和状态
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    if plan.status != "active":
        raise ValueError("计划非活跃状态，无法打卡")

    # 检查是否已打卡
    existing = db.query(FastingCheckin).filter(
        FastingCheckin.plan_id == plan_id,
        FastingCheckin.checkin_date == checkin_date
    ).first()

    if existing:
        # 更新已有打卡
        existing.weight = weight
        existing.feeling = feeling
        existing.completed = completed
        existing.discomfort = discomfort
        existing.notes = notes
        db.commit()
        db.refresh(existing)
        checkin = existing
    else:
        checkin = FastingCheckin(
            plan_id=plan_id,
            checkin_date=checkin_date,
            weight=weight,
            feeling=feeling,
            completed=completed,
            discomfort=discomfort,
            notes=notes,
        )
        db.add(checkin)
        db.commit()
        db.refresh(checkin)

    # 获取之前体重，计算变化
    prev_checkin = db.query(FastingCheckin).filter(
        FastingCheckin.plan_id == plan_id,
        FastingCheckin.checkin_date < checkin_date
    ).order_by(FastingCheckin.checkin_date.desc()).first()

    weight_change = None
    if weight is not None and prev_checkin and prev_checkin.weight is not None:
        weight_change = round(float(weight) - float(prev_checkin.weight), 1)

    # 打卡总数
    days_completed = db.query(func.count(FastingCheckin.id)).filter(
        FastingCheckin.plan_id == plan_id
    ).scalar()

    # 不适症状预警
    warning = None
    if discomfort:
        discomfort_list = [k for k, v in discomfort.items() if v]
        if discomfort_list:
            severe = ["dizziness", "low_sugar", "palpitation"]
            has_severe = any(s in discomfort_list for s in severe)
            warning = {
                "level": "high" if has_severe else "medium",
                "symptoms": discomfort_list,
                "advice": (
                    "请立即停止断食并咨询医生，您的身体出现了明显不适反应"
                    if has_severe
                    else "请注意观察身体反应，如症状持续或加重请咨询医生"
                ),
            }

    return {
        "message": "打卡成功，继续保持！" if completed else "打卡已记录",
        "weight_change": weight_change,
        "days_completed": days_completed,
        "warning": warning,
    }


def get_checkins(
    db: Session,
    plan_id: int,
    user_id: int,
) -> Dict[str, Any]:
    """获取打卡记录"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    checkins = db.query(FastingCheckin).filter(
        FastingCheckin.plan_id == plan_id
    ).order_by(FastingCheckin.checkin_date.desc()).all()

    records = []
    for c in checkins:
        records.append({
            "id": c.id,
            "checkin_date": c.checkin_date.isoformat(),
            "weight": float(c.weight) if c.weight else None,
            "feeling": c.feeling,
            "completed": c.completed,
            "discomfort": c.discomfort,
            "notes": c.notes,
            "created_at": c.created_at.isoformat(),
        })

    return {
        "plan_id": plan_id,
        "checkins": records,
        "total": len(records),
    }


def get_progress(
    db: Session,
    plan_id: int,
    user_id: int,
) -> Dict[str, Any]:
    """获取计划进度"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    days_elapsed = (date.today() - plan.start_date).days
    days_total = (plan.end_date - plan.start_date).days if plan.end_date else 30

    checkins = db.query(FastingCheckin).filter(
        FastingCheckin.plan_id == plan_id
    ).order_by(FastingCheckin.checkin_date).all()

    # 体重变化图表
    weight_chart = []
    for c in checkins:
        if c.weight is not None:
            weight_chart.append({
                "date": c.checkin_date.isoformat(),
                "weight": float(c.weight),
            })

    # 体重统计
    weight_start = float(checkins[0].weight) if checkins and checkins[0].weight else None
    weight_current = float(checkins[-1].weight) if checkins and checkins[-1].weight else None
    weight_change = round(weight_current - weight_start, 1) if (weight_start and weight_current) else None

    # 打卡率
    completed_count = sum(1 for c in checkins if c.completed)
    completion_rate = round(completed_count / max(days_elapsed, 1) * 100, 1)

    # 体感统计
    feeling_counts = {}
    for c in checkins:
        feeling_counts[c.feeling] = feeling_counts.get(c.feeling, 0) + 1
    feeling_avg = max(feeling_counts, key=feeling_counts.get) if feeling_counts else "normal"

    # 连续打卡天数
    streak = 0
    for i in range(days_elapsed):
        d = date.today() - timedelta(days=i)
        has_checkin = any(c.checkin_date == d and c.completed for c in checkins)
        if has_checkin:
            streak += 1
        else:
            break

    return {
        "plan_id": plan_id,
        "days_elapsed": days_elapsed,
        "days_total": days_total,
        "completion_rate": completion_rate,
        "weight_start": weight_start,
        "weight_current": weight_current,
        "weight_change": weight_change,
        "feeling_avg": feeling_avg,
        "streak_days": streak,
        "chart": weight_chart,
    }


def get_refeed_guide(
    db: Session,
    plan_id: int,
    user_id: int,
) -> Dict[str, Any]:
    """获取复食指导方案"""
    plan = db.query(FastingPlan).filter(
        FastingPlan.id == plan_id,
        FastingPlan.user_id == user_id
    ).first()

    if not plan:
        raise ValueError("计划不存在")

    guide = REFEED_GUIDES.get(plan.plan_type, REFEED_GUIDES["16_8"])
    guide["plan_type"] = plan.plan_type

    return guide
