"""query_exam：查体检指标（二期查询动作，EXAM_METRIC 卡）。

对应 PRD 二期「体检报告问答」：如「我上次体检血糖是多少」。
隐私红线（PRD 5.4）：体检数据属敏感个人信息，报告 ai_analysis_enabled=False（默认关闭）时
**不得读取/输出任何指标数值**，只提示用户去「体检报告」页面打开 AI 分析开关。

数据源：直接查 exam_reports / exam_metrics（不调用 routers/exam_router.py 的接口）。
历史趋势只统计 ai_analysis_enabled=True 的报告，避免从其它报告绕过隐私开关。
查询类动作不写数据、不需要确认、不可撤销（PRD 4.2）；入参里不出现 user_id（由 ctx 注入）。
"""

import logging
from typing import Any, Optional

from pydantic import BaseModel, Field

from agent.diet_deep_agent.actions.context import ActionContext
from agent.diet_deep_agent.actions.registry import ActionRegistry
from agent.diet_deep_agent.actions.spec import (
    ActionKind,
    ActionResult,
    ActionSpec,
    CardType,
)

logger = logging.getLogger(__name__)

# 跳转映射（PRD 4.8）：体检报告页由健康页承载
JUMP_PAGE = "health"

PRIVACY_MESSAGE = (
    "这份体检报告的 AI 分析是关闭的，出于隐私保护我不能读取其中的指标；"
    "如果要让我解读，请在「体检报告」页面打开 AI 分析开关。"
)

STATUS_LABELS = {
    "normal": "正常",
    "high": "偏高",
    "low": "偏低",
    "abnormal": "异常",
}


class QueryExamArgs(BaseModel):
    """query_exam 入参（不含 user_id）"""

    metric_name: Optional[str] = Field(
        default=None,
        description="要查的指标中文名（如「血糖」「血压」「低密度脂蛋白」）；未提及留空按整份报告异常概要回答",
    )
    report_id: Optional[int] = Field(
        default=None, description="指定体检报告 id；用户没指定则取最新一份"
    )


SPEC = ActionSpec(
    name="query_exam",
    description="查询用户体检报告里的指标（单项指标 + 参考范围，或整份报告异常概要）",
    kind=ActionKind.QUERY,
    args_schema=QueryExamArgs,
    card_type=CardType.EXAM_METRIC,
    requires_confirmation=False,
    undoable=False,
    examples=["我上次体检血糖是多少", "我的低密度脂蛋白正常吗", "看看我最近的体检报告"],
    notes=(
        "查询类动作，不写数据、不需要确认。"
        "体检数据受隐私开关保护：若报告未打开 AI 分析，动作只会返回提示，禁止编造或推测指标数值。"
    ),
)


def _metric_dict(metric: Any) -> dict[str, Any]:
    """ExamMetric → 对外字段（数值统一转 float）"""
    return {
        "metric_name": metric.metric_name,
        "metric_value": float(metric.metric_value) if metric.metric_value is not None else None,
        "unit": metric.unit,
        "reference_range": metric.reference_range,
        "status": metric.status,
        "is_abnormal": bool(metric.is_abnormal),
    }


def _format_value(value: Optional[float]) -> str:
    """数值文案：整数不带小数点"""
    return f"{value:g}" if value is not None else "—"


def _match_metrics(metrics: list[Any], metric_name: str) -> list[Any]:
    """指标名匹配：先精确命中，再双向包含匹配（如「血糖」命中「空腹血糖」）"""
    target = metric_name.strip()
    exact = [m for m in metrics if (m.metric_name or "").strip() == target]
    if exact:
        return exact
    return [
        m
        for m in metrics
        if target in (m.metric_name or "") or (m.metric_name or "") in target
    ]


async def query_exam(params: QueryExamArgs, ctx: ActionContext) -> ActionResult:
    """读取指定/最新一份体检报告的指标，并遵守隐私开关"""
    if ctx.user_id is None:
        return ActionResult.failure(SPEC.name, "缺少用户上下文（user_id），无法查询")

    jump = {"page": JUMP_PAGE}

    from shared.models.database import SessionLocal

    db = SessionLocal()
    try:
        from shared.models.exam_models import ExamMetric, ExamReport

        if params.report_id is not None:
            report = (
                db.query(ExamReport)
                .filter(
                    ExamReport.id == int(params.report_id),
                    ExamReport.user_id == ctx.user_id,
                )
                .first()
            )
            if report is None:
                return ActionResult.failure(
                    SPEC.name, f"没有找到这份体检报告（id={params.report_id}），请确认后再说一次"
                )
        else:
            report = (
                db.query(ExamReport)
                .filter(ExamReport.user_id == ctx.user_id)
                .order_by(ExamReport.exam_date.desc())
                .first()
            )
            if report is None:
                return ActionResult(
                    ok=True,
                    action=SPEC.name,
                    card_type=CardType.TEXT,
                    message="还没有体检报告记录。",
                    data={"report_id": None, "jump": jump},
                )

        exam_date = report.exam_date.isoformat() if report.exam_date else None
        hospital_name = report.hospital_name or ""
        report_id = report.id

        # 隐私红线（PRD 5.4）：未开启 AI 分析时不得读取任何指标数值
        if not report.ai_analysis_enabled:
            return ActionResult(
                ok=True,
                action=SPEC.name,
                card_type=CardType.TEXT,
                message=PRIVACY_MESSAGE,
                data={
                    "report_id": report_id,
                    "exam_date": exam_date,
                    "hospital_name": hospital_name,
                    "ai_analysis_enabled": False,
                    "metrics": [],
                    "jump": {"page": "health", "report_id": report_id},
                },
            )

        metrics = db.query(ExamMetric).filter(ExamMetric.report_id == report_id).all()
        abnormal_count = report.abnormal_count
        if abnormal_count is None:
            abnormal_count = sum(1 for m in metrics if m.is_abnormal)

        if params.metric_name:
            target_name = str(params.metric_name).strip()
            matched = _match_metrics(metrics, target_name)
            if not matched:
                available = "、".join((m.metric_name or "") for m in metrics if m.metric_name)
                return ActionResult(
                    ok=True,
                    action=SPEC.name,
                    card_type=CardType.TEXT,
                    message=(
                        f"这份体检报告里没有「{target_name}」这项指标。"
                        + (f"报告里包含的指标有：{available}。" if available else "这份报告没有识别出指标。")
                    ),
                    data={
                        "report_id": report_id,
                        "exam_date": exam_date,
                        "hospital_name": hospital_name,
                        "ai_analysis_enabled": True,
                        "metrics": [],
                        "available_metrics": [m.metric_name for m in metrics if m.metric_name],
                        "jump": {"page": "health", "report_id": report_id},
                    },
                )

            matched_name = matched[0].metric_name
            # 历史趋势：只统计同样开启 AI 分析的报告，避免绕过隐私开关
            history = (
                db.query(ExamMetric.metric_value, ExamReport.exam_date)
                .join(ExamReport, ExamReport.id == ExamMetric.report_id)
                .filter(
                    ExamReport.user_id == ctx.user_id,
                    ExamReport.ai_analysis_enabled.is_(True),
                    ExamMetric.metric_name == matched_name,
                    ExamMetric.metric_value.isnot(None),
                )
                .order_by(ExamReport.exam_date.asc())
                .all()
            )
            points = [
                {
                    "date": row[1].isoformat() if row[1] else None,
                    "value": float(row[0]),
                }
                for row in history
            ]
            direction = None
            if len(points) >= 2:
                first_val, last_val = points[0]["value"], points[-1]["value"]
                if last_val > first_val * 1.05:
                    direction = "up"
                elif last_val < first_val * 0.95:
                    direction = "down"
                else:
                    direction = "stable"

            first = matched[0]
            status_label = STATUS_LABELS.get(first.status or "", "")
            message = (
                f"{exam_date or '最近一次'} 的{first.metric_name}是 "
                f"{_format_value(float(first.metric_value) if first.metric_value is not None else None)}"
                f"{first.unit or ''}"
            )
            if first.reference_range:
                message += f"（参考范围 {first.reference_range}）"
            message += f"，{status_label}。" if status_label else "。"

            return ActionResult(
                ok=True,
                action=SPEC.name,
                card_type=CardType.EXAM_METRIC,
                message=message,
                data={
                    "report_id": report_id,
                    "exam_date": exam_date,
                    "hospital_name": hospital_name,
                    "ai_analysis_enabled": True,
                    "metrics": [_metric_dict(m) for m in matched],
                    "trend": {"metric_name": matched_name, "points": points, "direction": direction},
                    "jump": {"page": "health", "report_id": report_id},
                },
            )

        # 未指定指标：返回整份报告概要（异常项在前，便于模型复述重点）
        ordered = sorted(metrics, key=lambda m: (not bool(m.is_abnormal), m.id))
        metric_list = [_metric_dict(m) for m in ordered]
        abnormal_names = [d["metric_name"] for d in metric_list if d["is_abnormal"]]
        message = f"{exam_date or '最近一次'} 的体检报告共 {int(abnormal_count)} 项异常"
        if abnormal_names:
            message += "（" + "、".join(abnormal_names[:5]) + "）"
        message += "。"

        return ActionResult(
            ok=True,
            action=SPEC.name,
            card_type=CardType.EXAM_METRIC,
            message=message,
            data={
                "report_id": report_id,
                "exam_date": exam_date,
                "hospital_name": hospital_name,
                "ai_analysis_enabled": True,
                "metrics": metric_list,
                "abnormal_count": int(abnormal_count),
                "jump": {"page": "health", "report_id": report_id},
            },
        )
    except Exception as e:
        logger.exception("query_exam 查询失败")
        return ActionResult.failure(SPEC.name, f"查询失败：{e}")
    finally:
        db.close()


def register(registry: ActionRegistry) -> None:
    """注册 query_exam 动作（二期）"""
    registry.register(SPEC, query_exam)
