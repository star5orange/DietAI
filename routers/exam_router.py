"""体检报告路由 - Milestone 4 体检报告管理"""
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import desc, exists, func
from typing import List, Optional
from datetime import date, datetime, timedelta
from decimal import Decimal
import logging
import traceback

from shared.models.database import get_db
from shared.models.schemas import (
    BaseResponse,
    ExamReportResponse, ExamReportListResponse,
    ExamMetricResponse, ExamMetricUpdate,
    ExamReportFollowupUpdate, ExamReportReassign,
    MetricTrendPoint, MetricTrendResponse,
    ExamSummaryResponse, ExamAdviceResponse,
)
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.models.exam_models import ExamReport, ExamMetric
from shared.models.social_models import UserRelationship
from sqlalchemy import or_, and_
from shared.utils.permission import get_visible_fields, field_hidden

router = APIRouter(prefix="/health/exam", tags=["体检报告"])
logger = logging.getLogger(__name__)


def _check_exam_visible(db: Session, owner_id: int, viewer_id: int) -> None:
    """查看他人体检数据前校验数据权限；对方隐藏体检报告时抛 403"""
    if owner_id == viewer_id:
        return
    visible = get_visible_fields(db, owner_id, viewer_id)
    if field_hidden(visible, "exam_report"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="对方已隐藏体检数据，暂时无法查看"
        )


async def _call_advice_ai(report: ExamReport, metrics: List[ExamMetric]) -> Optional[dict]:
    """调用 DashScope qwen-plus 基于体检指标生成个性化健康建议。失败返回 None。"""
    try:
        from shared.config.settings import get_settings
        import httpx
        import json as _json

        settings = get_settings()
        if not settings.dashscope_api_key:
            return None

        status_map = {"normal": "正常", "high": "偏高", "low": "偏低", "abnormal": "异常"}
        metric_lines = []
        for m in metrics:
            range_str = m.reference_range or (
                f"{m.reference_min}-{m.reference_max}"
                if m.reference_min is not None and m.reference_max is not None
                else "无参考范围"
            )
            flag = "【异常】" if m.is_abnormal else ""
            metric_lines.append(
                f"- {m.metric_name}：{m.metric_value}{m.unit or ''}，参考范围 {range_str}，"
                f"状态 {status_map.get(m.status, '未知')}{flag}"
            )
        metric_text = "\n".join(metric_lines)

        prompt = (
            f"你是一名专业健康管理师。以下是用户 {report.exam_date} 的体检报告"
            f"（{report.hospital_name or '体检机构未知'}）的各项指标：\n{metric_text}\n\n"
            "请根据这些指标给出个性化健康建议，只输出 JSON（不要 markdown 代码块），格式：\n"
            '{"advice": "总体健康建议，1-3句话", "diet_recommendations": ["饮食建议1", "饮食建议2"], '
            '"exercise_recommendations": ["运动建议1", "运动建议2"], "followup_reminder": "复查提醒，没有则为null"}'
        )

        async with httpx.AsyncClient(timeout=120.0, trust_env=False) as client:
            response = await client.post(
                "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation",
                headers={
                    "Authorization": f"Bearer {settings.dashscope_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen-plus",
                    "input": {"messages": [{"role": "user", "content": prompt}]},
                    "parameters": {"result_format": "message"},
                },
            )
            if response.status_code != 200:
                logger.error(f"AI 建议模型调用失败: {response.status_code} - {response.text}")
                return None
            result = response.json()
            content_text = (
                result.get("output", {})
                .get("choices", [{}])[0]
                .get("message", {})
                .get("content", "")
            )
            start, end = content_text.find("{"), content_text.rfind("}") + 1
            if start < 0 or end <= start:
                logger.warning(f"AI 建议返回内容不是 JSON: {content_text[:200]}")
                return None
            parsed = _json.loads(content_text[start:end])
            if not isinstance(parsed.get("advice"), str) or not parsed["advice"].strip():
                return None
            # 字段归一化，保证与 ExamAdviceResponse 契约一致
            parsed["diet_recommendations"] = [
                str(x) for x in (parsed.get("diet_recommendations") or [])
            ]
            parsed["exercise_recommendations"] = [
                str(x) for x in (parsed.get("exercise_recommendations") or [])
            ]
            parsed["followup_reminder"] = parsed.get("followup_reminder")
            logger.info(
                f"AI 体检建议生成成功: {len(parsed['diet_recommendations'])} 条饮食建议"
            )
            return parsed
    except Exception as e:
        logger.warning(f"AI 体检建议调用异常: {e}\n{traceback.format_exc()}")
        return None


# ============================================================
# 辅助函数
# ============================================================

EXAM_EXTRACT_PROMPT = """请分析这张体检报告照片，提取所有检测指标。返回 JSON 格式：
{
  "exam_date": "体检日期 YYYY-MM-DD（如果能识别）",
  "hospital_name": "体检机构名称（如果能识别）",
  "metrics": [
    {
      "category": "指标类别（blood_routine/blood_lipid/blood_sugar/liver/kidney/blood_pressure/physical/other）",
      "metric_name": "指标中文名",
      "metric_value": 数值,
      "unit": "单位",
      "reference_range": "参考范围 如 3.9-6.1",
      "reference_min": 参考下限,
      "reference_max": 参考上限,
      "status": "normal/high/low/abnormal",
      "is_abnormal": true/false
    }
  ],
  "summary": "体检综述（如果有）",
  "doctor_advice": "医生建议（如果有）",
  "followup_days": "建议复查间隔天数（根据异常指标判断，如 90；全部正常或无法判断则为 null）"
}

注意：
1. 只提取能清晰识别的指标，不确定的不要提取
2. 数值必须是数字类型，不是字符串
3. 如果某项指标没有参考范围，reference_min 和 reference_max 设为 null
4. 根据参考范围判断 status 和 is_abnormal"""


async def _call_qwen_vl(image_content: bytes, content_type: str) -> Optional[dict]:
    """调用 qwen-vl-max 视觉模型从体检报告照片提取指标。失败返回 None。"""
    try:
        from shared.config.settings import get_settings
        import base64
        import httpx
        import json

        settings = get_settings()
        if not settings.dashscope_api_key:
            logger.warning("未配置 dashscope_api_key，跳过 AI 指标提取")
            return None

        # 将图片转为 base64
        image_base64 = base64.b64encode(image_content).decode('utf-8')
        image_data_url = f"data:{content_type};base64,{image_base64}"

        # 调用 qwen-vl-max 视觉模型（禁用代理，避免走系统代理导致连接断开；超时120s适应大图）
        async with httpx.AsyncClient(timeout=120.0, trust_env=False) as client:
            response = await client.post(
                "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation",
                headers={
                    "Authorization": f"Bearer {settings.dashscope_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "qwen-vl-max",
                    "input": {
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {"image": image_data_url},
                                    {"text": EXAM_EXTRACT_PROMPT}
                                ]
                            }
                        ]
                    },
                    "parameters": {
                        "result_format": "message"
                    }
                }
            )

            if response.status_code != 200:
                logger.error(f"AI 视觉模型调用失败: {response.status_code} - {response.text}")
                return None

            result = response.json()
            raw_content = result.get("output", {}).get("choices", [{}])[0].get("message", {}).get("content", "")
            # qwen-vl-max 返回的 content 可能是列表 [{"text": "..."}]
            if isinstance(raw_content, list):
                raw_content = "".join(
                    item.get("text", "") for item in raw_content if isinstance(item, dict)
                )
            content_text = raw_content if isinstance(raw_content, str) else str(raw_content)

            # 提取 JSON 部分（可能被 markdown 代码块包裹）
            json_start = content_text.find("{")
            json_end = content_text.rfind("}") + 1
            if json_start < 0 or json_end <= json_start:
                logger.warning(f"AI 返回内容无法解析为 JSON: {content_text[:200]}")
                return None
            return json.loads(content_text[json_start:json_end])
    except Exception as e:
        logger.error(f"AI 视觉识别异常: {e}\n{traceback.format_exc()}")
        return None


def _is_family(db: Session, user_id: int, target_user_id: int) -> bool:
    """判断两个用户是否为已接受的家人关系"""
    rel = db.query(UserRelationship).filter(
        or_(
            and_(
                UserRelationship.user_id == user_id,
                UserRelationship.related_user_id == target_user_id
            ),
            and_(
                UserRelationship.user_id == target_user_id,
                UserRelationship.related_user_id == user_id
            )
        ),
        UserRelationship.relationship_type == "family",
        UserRelationship.status == "accepted"
    ).first()
    return rel is not None


def _get_family_note(db: Session, member_id: int, current_user_id: int) -> Optional[str]:
    """获取当前用户对该成员的关系称谓（如：妈妈），无则为 None"""
    rel = db.query(UserRelationship).filter(
        or_(
            and_(
                UserRelationship.user_id == current_user_id,
                UserRelationship.related_user_id == member_id
            ),
            and_(
                UserRelationship.user_id == member_id,
                UserRelationship.related_user_id == current_user_id
            )
        ),
        UserRelationship.relationship_type == "family",
        UserRelationship.status == "accepted"
    ).first()
    if not rel:
        return None
    return rel.note_from_user if rel.user_id == current_user_id else rel.note_from_related


def _extract_object_name(photo_url: str) -> Optional[str]:
    """从 MinIO 预签名 URL 中提取对象名（用于删除文件）"""
    try:
        from urllib.parse import urlparse, unquote
        from shared.config.settings import get_settings
        parsed = urlparse(photo_url)
        path = parsed.path.lstrip("/")
        bucket = get_settings().minio_bucket
        if path.startswith(bucket + "/"):
            return unquote(path[len(bucket) + 1:])
        return unquote(path)
    except Exception:
        return None


# ============================================================
# 上传体检报告
# ============================================================

@router.post("/upload", response_model=BaseResponse)
async def upload_exam_report(
    photo: UploadFile = File(None, description="体检报告照片（单张，与 photos 二选一）"),
    photos: List[UploadFile] = File(None, description="体检报告照片（多页，与 photo 二选一）"),
    user_id: int = Form(..., description="体检用户ID"),
    exam_date: Optional[str] = Form(None, description="体检日期 YYYY-MM-DD"),
    hospital_name: Optional[str] = Form(None, description="体检机构"),
    report_type: Optional[str] = Form("full", description="报告类型"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """上传体检报告照片，AI提取指标"""
    try:
        # 权限检查：本人或家人
        if user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == user_id
                    ),
                    and_(
                        UserRelationship.user_id == user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能为自己或家人上传体检报告"
                )

        # 收集待处理照片：photos 优先（多页），兼容单张 photo
        file_list = []
        if photos:
            file_list = list(photos)
        elif photo is not None:
            file_list = [photo]
        if not file_list:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="请上传体检报告照片（photo 或 photos）"
            )

        # 解析体检日期
        parsed_exam_date = None
        if exam_date:
            try:
                parsed_exam_date = datetime.strptime(exam_date, "%Y-%m-%d").date()
            except ValueError:
                pass

        if not parsed_exam_date:
            parsed_exam_date = date.today()

        # 上传到 MinIO 并逐张调用 AI 视觉模型提取
        from shared.config.minio_config import get_minio_client
        minio_client = get_minio_client()

        merged_metrics = {}
        ai_result = None  # 第一张照片的解析结果（exam_date/hospital_name/summary/followup_days 取它）
        photo_url = None

        for idx, f in enumerate(file_list):
            # 验证文件类型
            if f.content_type not in ["image/jpeg", "image/png", "image/jpg"]:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="仅支持 JPEG/PNG 格式"
                )

            content = await f.read()
            file_ext = f.content_type.split("/")[-1]
            object_name = f"exam_reports/{user_id}/{datetime.now().strftime('%Y%m%d_%H%M%S')}_{idx}.{file_ext}"

            upload_ok = minio_client.upload_file(object_name, content, f.content_type)
            if not upload_ok:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="图片上传失败"
                )

            # 第一张照片的 URL 作为报告主图
            if idx == 0:
                photo_url = minio_client.get_file_url(object_name)

            result = await _call_qwen_vl(content, f.content_type)
            if not result:
                continue
            if ai_result is None:
                ai_result = result

            # 合并指标：同名指标后者覆盖前者，指标集合去重
            for m in result.get("metrics", []):
                merged_metrics[m.get("metric_name", "")] = {
                    "category": m.get("category", "other"),
                    "metric_name": m.get("metric_name", ""),
                    "metric_value": m.get("metric_value"),
                    "unit": m.get("unit"),
                    "reference_range": m.get("reference_range"),
                    "reference_min": m.get("reference_min"),
                    "reference_max": m.get("reference_max"),
                    "status": m.get("status", "normal"),
                    "is_abnormal": m.get("is_abnormal", False)
                }

        extracted_metrics = list(merged_metrics.values())
        abnormal_count = sum(1 for m in extracted_metrics if m.get("is_abnormal"))

        # exam_date / hospital_name 取第一张结果（用户未手动指定时）
        if ai_result:
            if ai_result.get("exam_date") and not exam_date:
                try:
                    parsed_exam_date = datetime.strptime(ai_result["exam_date"], "%Y-%m-%d").date()
                except Exception:
                    pass

            if ai_result.get("hospital_name") and not hospital_name:
                hospital_name = ai_result["hospital_name"]

        logger.info(f"AI 成功提取 {len(extracted_metrics)} 项指标，{abnormal_count} 项异常")

        # 创建报告记录
        # 复查日期：优先用 AI 解析的复查周期；异常但未解析到时默认 3 个月
        followup_date = None
        if abnormal_count > 0:
            followup_days = None
            if ai_result is not None:
                followup_days = ai_result.get("followup_days")
            if isinstance(followup_days, (int, float)) and followup_days > 0:
                followup_date = parsed_exam_date + timedelta(days=int(followup_days))
            else:
                followup_date = parsed_exam_date + timedelta(days=90)

        report = ExamReport(
            user_id=user_id,
            exam_date=parsed_exam_date,
            hospital_name=hospital_name,
            report_type=report_type,
            photo_url=photo_url,
            followup_date=followup_date,
            abnormal_count=abnormal_count,
            summary=ai_result.get("summary") if ai_result else None,
            doctor_advice=ai_result.get("doctor_advice") if ai_result else None,
            created_by=current_user.id if user_id != current_user.id else None
        )
        db.add(report)
        db.commit()
        db.refresh(report)

        # 保存提取的指标
        for m in extracted_metrics:
            metric = ExamMetric(
                report_id=report.id,
                category=m["category"],
                metric_name=m["metric_name"],
                metric_value=m["metric_value"],
                unit=m["unit"],
                reference_range=m.get("reference_range"),
                reference_min=m.get("reference_min"),
                reference_max=m.get("reference_max"),
                status=m["status"],
                is_abnormal=m["is_abnormal"]
            )
            db.add(metric)

        db.commit()

        # 与上次体检数据对比，生成趋势分析
        last_report = db.query(ExamReport).filter(
            ExamReport.user_id == user_id,
            ExamReport.id != report.id
        ).order_by(desc(ExamReport.exam_date)).first()

        compared_to_last = None
        trend_summary = []
        if last_report:
            # 获取上次所有指标
            last_metrics = {m.metric_name: m for m in db.query(ExamMetric).filter(
                ExamMetric.report_id == last_report.id
            ).all() if m.metric_value is not None}

            # 对比本次指标
            for m in extracted_metrics:
                name = m["metric_name"]
                current_val = m.get("metric_value")
                if name in last_metrics and current_val is not None:
                    last_val = last_metrics[name].metric_value
                    if last_val and current_val != last_val:
                        change = current_val - last_val
                        pct = (change / last_val * 100) if last_val != 0 else 0
                        direction = "↑" if change > 0 else "↓"
                        trend_summary.append({
                            "metric": name,
                            "last_value": last_val,
                            "current_value": current_val,
                            "change": round(change, 2),
                            "change_pct": round(pct, 1),
                            "direction": direction
                        })

            # 获取上次异常指标
            last_abnormal = db.query(ExamMetric).filter(
                ExamMetric.report_id == last_report.id,
                ExamMetric.is_abnormal == True
            ).all()
            if last_abnormal or trend_summary:
                compared_to_last = {
                    "last_exam_date": last_report.exam_date.isoformat() if last_report.exam_date else None,
                    "abnormal_metrics": {m.metric_name: m.metric_value for m in last_abnormal if m.metric_value},
                    "trends": trend_summary[:10]  # 最多10项趋势
                }

        # 更新报告的对比数据
        report.compared_to_last = compared_to_last
        db.commit()
        db.refresh(report)

        return BaseResponse(
            success=True,
            message="体检报告上传成功，AI正在分析",
            data=ExamReportResponse.model_validate(report).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"上传体检报告失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="上传体检报告失败"
        )


# ============================================================
# 获取体检报告列表
# ============================================================

@router.get("/reports/{user_id}", response_model=BaseResponse)
async def get_exam_reports(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户的体检报告列表"""
    try:
        # 权限检查：本人或家人
        if user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == user_id
                    ),
                    and_(
                        UserRelationship.user_id == user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能查看自己或家人的体检报告"
                )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, user_id, current_user.id)

        # 仅返回包含体检指标的记录（过滤掉识别失败的空报告）
        reports = db.query(ExamReport).filter(
            ExamReport.user_id == user_id,
            exists().where(ExamMetric.report_id == ExamReport.id)
        ).order_by(desc(ExamReport.exam_date)).all()

        return BaseResponse(
            success=True,
            message="获取体检报告列表成功",
            data=ExamReportListResponse(
                reports=[ExamReportResponse.model_validate(r).model_dump() for r in reports],
                total=len(reports)
            ).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取体检报告列表失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取体检报告列表失败"
        )


# ============================================================
# 获取最新体检报告摘要
# ============================================================

@router.get("/reports/{user_id}/latest", response_model=BaseResponse)
async def get_latest_exam_report(
    user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取最新体检报告摘要（家庭看板用）"""
    try:
        # 权限检查
        if user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == user_id
                    ),
                    and_(
                        UserRelationship.user_id == user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能查看自己或家人的体检报告"
                )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, user_id, current_user.id)

        # 仅取包含指标的最新报告（跳过识别失败的空报告）
        latest_report = db.query(ExamReport).filter(
            ExamReport.user_id == user_id,
            exists().where(ExamMetric.report_id == ExamReport.id)
        ).order_by(desc(ExamReport.exam_date)).first()

        if not latest_report:
            return BaseResponse(
                success=True,
                message="暂无体检报告",
                data=None
            )

        # 获取异常指标
        abnormal_metrics = db.query(ExamMetric).filter(
            ExamMetric.report_id == latest_report.id,
            ExamMetric.is_abnormal == True
        ).all()

        return BaseResponse(
            success=True,
            message="获取最新体检报告摘要成功",
            data=ExamSummaryResponse(
                user_id=user_id,
                latest_exam_date=latest_report.exam_date,
                abnormal_count=latest_report.abnormal_count,
                abnormal_metrics=[m.metric_name for m in abnormal_metrics],
                followup_date=latest_report.followup_date
            ).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取最新体检报告摘要失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取最新体检报告摘要失败"
        )


# ============================================================
# 报告详情 / 归属修正 / 复查提醒 / 删除
# ============================================================

@router.get("/reports/{user_id}/{report_id}", response_model=BaseResponse)
async def get_exam_report_detail(
    user_id: int,
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取体检报告基本信息详情"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 校验报告属于该 user_id
        if report.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 权限检查：本人或家人
        if report.user_id != current_user.id and not _is_family(db, current_user.id, report.user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能查看自己或家人的体检报告"
            )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, report.user_id, current_user.id)

        # owner_name：报告所属用户的可展示名称（家人称谓优先，否则用户名）
        owner = db.query(User).filter(User.id == report.user_id).first()
        note = _get_family_note(db, report.user_id, current_user.id)
        owner_name = note or (owner.username if owner else "")

        data = ExamReportResponse.model_validate(report).model_dump()
        data["owner_name"] = owner_name
        return BaseResponse(
            success=True,
            message="获取体检报告详情成功",
            data=data
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取体检报告详情失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取体检报告详情失败"
        )


@router.post("/reports/{report_id}/reassign", response_model=BaseResponse)
async def reassign_exam_report(
    report_id: int,
    body: ExamReportReassign,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """事后修正体检报告归属"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        target_user_id = body.target_user_id

        # 校验当前用户：报告创建者 或 报告所属用户本人/家人
        is_creator = report.created_by is not None and report.created_by == current_user.id
        is_owner = report.user_id == current_user.id
        if not (is_creator or is_owner or _is_family(db, current_user.id, report.user_id)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权修正该报告的归属"
            )

        # 校验目标用户：必须是本人或当前用户的家人
        if target_user_id != current_user.id and not _is_family(db, current_user.id, target_user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能将报告归属给本人或家人"
            )

        report.user_id = target_user_id
        report.created_by = current_user.id
        db.commit()
        db.refresh(report)

        return BaseResponse(
            success=True,
            message="报告归属修正成功",
            data=ExamReportResponse.model_validate(report).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修正报告归属失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="修正报告归属失败"
        )


@router.put("/reports/{report_id}/followup", response_model=BaseResponse)
async def set_exam_report_followup(
    report_id: int,
    body: ExamReportFollowupUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """设置/清除体检报告复查提醒"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 权限检查：本人或家人
        if report.user_id != current_user.id and not _is_family(db, current_user.id, report.user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能为自己或家人设置复查提醒"
            )

        report.followup_date = body.followup_date
        db.commit()
        db.refresh(report)

        return BaseResponse(
            success=True,
            message="复查提醒设置成功",
            data=ExamReportResponse.model_validate(report).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"设置复查提醒失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="设置复查提醒失败"
        )


@router.delete("/reports/{report_id}", response_model=BaseResponse)
async def delete_exam_report(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除体检报告（含指标明细与 MinIO 照片）"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 权限检查：本人或家人
        if report.user_id != current_user.id and not _is_family(db, current_user.id, report.user_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能删除自己或家人的体检报告"
            )

        # 删除指标明细（显式删除，外键级联兜底）
        db.query(ExamMetric).filter(ExamMetric.report_id == report.id).delete()
        db.flush()

        # 删除 MinIO 照片（失败不阻断报告删除）
        if report.photo_url:
            try:
                from shared.config.minio_config import get_minio_client
                object_name = _extract_object_name(report.photo_url)
                if object_name:
                    get_minio_client().delete_file(object_name)
            except Exception as e:
                logger.warning(f"删除体检照片失败（不影响报告删除）: {e}")

        db.delete(report)
        db.commit()

        return BaseResponse(
            success=True,
            message="体检报告删除成功",
            data={"success": True}
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"删除体检报告失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="删除体检报告失败"
        )


# ============================================================
# 获取指标详情
# ============================================================

@router.get("/metrics/{report_id}", response_model=BaseResponse)
async def get_exam_metrics(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取某次报告的所有指标详情"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 权限检查
        if report.user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == report.user_id
                    ),
                    and_(
                        UserRelationship.user_id == report.user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能查看自己或家人的体检指标"
                )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, report.user_id, current_user.id)

        metrics = db.query(ExamMetric).filter(
            ExamMetric.report_id == report_id
        ).order_by(ExamMetric.category, ExamMetric.metric_name).all()

        return BaseResponse(
            success=True,
            message="获取指标详情成功",
            data=[ExamMetricResponse.model_validate(m).model_dump() for m in metrics]
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取指标详情失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取指标详情失败"
        )


# ============================================================
# 修正指标值
# ============================================================

@router.put("/metrics/{metric_id}", response_model=BaseResponse)
async def update_exam_metric(
    metric_id: int,
    update: ExamMetricUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """人工修正AI提取的指标值"""
    try:
        metric = db.query(ExamMetric).filter(ExamMetric.id == metric_id).first()
        if not metric:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="指标不存在"
            )

        # 权限检查
        report = db.query(ExamReport).filter(ExamReport.id == metric.report_id).first()
        if report.user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == report.user_id
                    ),
                    and_(
                        UserRelationship.user_id == report.user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能修正自己或家人的指标"
                )

        if update.metric_value is not None:
            metric.metric_value = update.metric_value
        if update.status is not None:
            metric.status = update.status.value
        if update.is_abnormal is not None:
            metric.is_abnormal = update.is_abnormal

        db.commit()

        # 修正后联动：重算该报告所有异常指标数
        abnormal_count = db.query(func.count(ExamMetric.id)).filter(
            ExamMetric.report_id == report.id,
            ExamMetric.is_abnormal == True
        ).scalar() or 0
        report.abnormal_count = abnormal_count

        # 有异常但无复查日期 → 默认 exam_date + 90 天；无异常则保留已有 followup_date
        if abnormal_count > 0 and not report.followup_date:
            report.followup_date = report.exam_date + timedelta(days=90)

        db.commit()

        return BaseResponse(
            success=True,
            message="指标修正成功",
            data=ExamMetricResponse.model_validate(metric).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"修正指标失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="修正指标失败"
        )


# ============================================================
# 指标趋势
# ============================================================

@router.get("/trend/{user_id}/{metric_name}", response_model=BaseResponse)
async def get_metric_trend(
    user_id: int,
    metric_name: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """某项指标的历史趋势数据"""
    try:
        # 权限检查
        if user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == user_id
                    ),
                    and_(
                        UserRelationship.user_id == user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能查看自己或家人的指标趋势"
                )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, user_id, current_user.id)

        # 查询该指标的历史数据
        metrics = db.query(ExamMetric).join(ExamReport).filter(
            ExamReport.user_id == user_id,
            ExamMetric.metric_name == metric_name,
            ExamMetric.metric_value.isnot(None)
        ).order_by(ExamReport.exam_date).all()

        if not metrics:
            return BaseResponse(
                success=True,
                message="暂无该指标的历史数据",
                data=None
            )

        # 组装趋势数据
        trend_points = []
        for m in metrics:
            report = db.query(ExamReport).filter(ExamReport.id == m.report_id).first()
            trend_points.append(MetricTrendPoint(
                exam_date=report.exam_date,
                metric_value=m.metric_value,
                unit=m.unit,
                report_id=m.report_id
            ))

        # 计算趋势方向
        if len(trend_points) >= 2:
            first_val = float(trend_points[0].metric_value)
            last_val = float(trend_points[-1].metric_value)
            if last_val > first_val * 1.05:
                direction = "up"
            elif last_val < first_val * 0.95:
                direction = "down"
            else:
                direction = "stable"

            change = last_val - first_val
            change_summary = f"累计{'上升' if change > 0 else '下降'} {abs(change):.1f} {trend_points[0].unit or ''}"
        else:
            direction = None
            change_summary = None

        first_metric = metrics[0]
        return BaseResponse(
            success=True,
            message="获取指标趋势成功",
            data=MetricTrendResponse(
                metric_name=metric_name,
                category=first_metric.category,
                unit=first_metric.unit,
                reference_min=first_metric.reference_min,
                reference_max=first_metric.reference_max,
                trend=trend_points,
                trend_direction=direction,
                change_summary=change_summary
            ).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取指标趋势失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取指标趋势失败"
        )


# ============================================================
# AI 健康建议
# ============================================================

@router.get("/advice/{report_id}", response_model=BaseResponse)
async def get_exam_advice(
    report_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """基于异常指标生成AI饮食/运动建议"""
    try:
        report = db.query(ExamReport).filter(ExamReport.id == report_id).first()
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="体检报告不存在"
            )

        # 权限检查
        if report.user_id != current_user.id:
            is_family = db.query(UserRelationship).filter(
                or_(
                    and_(
                        UserRelationship.user_id == current_user.id,
                        UserRelationship.related_user_id == report.user_id
                    ),
                    and_(
                        UserRelationship.user_id == report.user_id,
                        UserRelationship.related_user_id == current_user.id
                    )
                ),
                UserRelationship.relationship_type == "family",
                UserRelationship.status == "accepted"
            ).first()
            if not is_family:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只能查看自己或家人的健康建议"
                )

        # 数据权限：owner 对 viewer 隐藏了体检数据时拒绝
        _check_exam_visible(db, report.user_id, current_user.id)

        # 获取异常指标
        abnormal_metrics = db.query(ExamMetric).filter(
            ExamMetric.report_id == report_id,
            ExamMetric.is_abnormal == True
        ).all()

        # ---------- 方案A：AI 生成个性化建议（失败时回退规则模板） ----------
        advice_parts = []
        diet_recs = []
        exercise_recs = []
        followup = None

        ai_advice = None
        if abnormal_metrics:
            ai_advice = await _call_advice_ai(report, abnormal_metrics)

        if ai_advice:
            advice_parts = [ai_advice["advice"]]
            diet_recs = ai_advice["diet_recommendations"]
            exercise_recs = ai_advice["exercise_recommendations"]
            followup = ai_advice["followup_reminder"]
        else:
            # ---------- 方案B：规则模板（AI 不可用/失败时降级） ----------
            for m in abnormal_metrics:
                name = m.metric_name
                if "血糖" in name:
                    advice_parts.append(f"您的{name}偏高，建议控制碳水摄入")
                    diet_recs.append("减少精制碳水和含糖饮料")
                    exercise_recs.append("每天至少30分钟快走")
                    followup = "建议3个月后复查糖化血红蛋白"
                elif "胆固醇" in name or "血脂" in name:
                    advice_parts.append(f"您的{name}偏高，建议低脂饮食")
                    diet_recs.append("减少油炸食品和高脂肪食物")
                    exercise_recs.append("每周至少150分钟有氧运动")
                elif "血压" in name or "收缩压" in name:
                    advice_parts.append(f"您的{name}偏高，建议低盐饮食")
                    diet_recs.append("每日盐摄入不超过5克")
                    exercise_recs.append("适度运动，避免剧烈运动")
                elif "尿酸" in name:
                    advice_parts.append(f"您的{name}偏高，建议低嘌呤饮食")
                    diet_recs.append("减少海鲜、啤酒等高嘌呤食物")
                elif "BMI" in name:
                    advice_parts.append(f"您的BMI偏高，建议控制体重")
                    diet_recs.append("控制总热量摄入")
                    exercise_recs.append("每周至少150分钟中等强度运动")

        if not advice_parts:
            advice_parts.append("您的体检指标均在正常范围内，请继续保持健康的生活方式")

        # 计算是否需要引导设置减重目标：
        # 出现 BMI 且值 > 24，或出现"超重/肥胖"异常指标时为 true
        suggest_weight_loss_goal = False
        all_metrics = db.query(ExamMetric).filter(
            ExamMetric.report_id == report_id
        ).all()
        for m in all_metrics:
            name = (m.metric_name or "").lower()
            if "bmi" in name or "体质指数" in name:
                if m.metric_value is not None and float(m.metric_value) > 24:
                    suggest_weight_loss_goal = True
                    break
            elif "超重" in name or "肥胖" in name:
                if m.is_abnormal or (m.status and m.status in ("high", "abnormal")):
                    suggest_weight_loss_goal = True
                    break

        return BaseResponse(
            success=True,
            message="获取健康建议成功",
            data=ExamAdviceResponse(
                report_id=report_id,
                advice="。".join(advice_parts),
                diet_recommendations=diet_recs,
                exercise_recommendations=exercise_recs,
                followup_reminder=followup,
                suggest_weight_loss_goal=suggest_weight_loss_goal
            ).model_dump()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取健康建议失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取健康建议失败"
        )
