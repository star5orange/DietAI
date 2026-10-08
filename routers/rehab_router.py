"""康复建议路由。

用户记录了疾病（如骨折）后，健康页展示 AI 生成的康复饮食指导；
把该疾病标记为「已痊愈」（is_current=False）后不再返回，卡片随之消失。

生成策略：首次访问时懒生成并缓存到 diseases.rehab_advice，
之后直接读缓存；输入签名变化（疾病信息/过敏原/并发疾病变化）才重建。
"""
import asyncio
import json
import logging
from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.models.user_models import Disease, User
from shared.services.rehab_advice_service import (
    compute_advice_sig,
    elapsed_days,
    generate_rehab_advice,
    needs_regeneration,
    parse_stored_advice,
)
from shared.services.user_health_context import (
    build_user_health_context,
    get_allergen_names,
)
from shared.utils.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/health/rehab-advice", tags=["康复建议"])

# 同一疾病的并发生成保护：健康页与「我的」页可能同时首访，
# 不加锁会重复调用模型（重复计费）。单进程部署，用进程内锁即可。
_generation_locks: dict[int, asyncio.Lock] = {}


def _get_lock(disease_id: int) -> asyncio.Lock:
    lock = _generation_locks.get(disease_id)
    if lock is None:
        lock = asyncio.Lock()
        _generation_locks[disease_id] = lock
    return lock


def _to_item(disease: Disease, advice: Optional[dict], failed: bool) -> dict:
    """组装单条响应，字段与 RehabAdviceItem 契约一致。"""
    advice = advice or {}
    return {
        "disease_id": disease.id,
        "disease_name": disease.disease_name,
        "severity_level": disease.severity_level,
        "diagnosed_date": (
            disease.diagnosed_date.isoformat() if disease.diagnosed_date else None
        ),
        "days_elapsed": elapsed_days(disease),
        "summary": advice.get("summary"),
        "diet_recommendations": advice.get("diet_recommendations") or [],
        "avoid_recommendations": advice.get("avoid_recommendations") or [],
        "nutrient_focus": advice.get("nutrient_focus") or [],
        "recovery_notes": advice.get("recovery_notes") or [],
        "followup_reminder": advice.get("followup_reminder"),
        "disclaimer": advice.get("disclaimer"),
        "generated_at": (
            disease.rehab_advice_generated_at.isoformat()
            if disease.rehab_advice_generated_at
            else None
        ),
        "failed": failed,
    }


@router.get("", response_model=BaseResponse)
async def get_rehab_advices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """获取当前患病的康复建议列表（缺失时懒生成并落库缓存）。"""
    try:
        diseases = (
            db.query(Disease)
            .filter(
                Disease.user_id == current_user.id,
                Disease.is_current.is_(True),
            )
            .order_by(Disease.created_at.desc())
            .all()
        )

        if not diseases:
            return BaseResponse(
                success=True,
                message="当前无患病记录",
                data={"items": []},
            )

        allergen_names = get_allergen_names(current_user.id)
        all_names = [d.disease_name for d in diseases if d.disease_name]
        health_context: Optional[str] = None
        items: list[dict[str, Any]] = []

        for disease in diseases:
            # 并发疾病参与签名：多病共存时建议需要一起考虑
            comorbidities = [n for n in all_names if n != disease.disease_name]
            sig = compute_advice_sig(disease, allergen_names, comorbidities)
            advice = None
            failed = False

            if needs_regeneration(disease, sig):
                if health_context is None:
                    health_context = build_user_health_context(current_user.id)

                async with _get_lock(disease.id):
                    # 等锁期间可能已被并发请求生成，刷新后再判断一次
                    db.refresh(disease)
                    if needs_regeneration(disease, sig):
                        advice = await generate_rehab_advice(disease, health_context)
                        if advice is not None:
                            disease.rehab_advice = json.dumps(
                                advice, ensure_ascii=False
                            )
                            disease.rehab_advice_sig = sig
                            disease.rehab_advice_generated_at = datetime.now()
                            db.commit()
                        else:
                            logger.warning(
                                f"康复建议生成失败，本次不返回内容: disease_id={disease.id}"
                            )
                            failed = True

            if advice is None:
                advice = parse_stored_advice(disease)
            if advice is None and not failed:
                # 缓存损坏（非法 JSON）且重建失败
                failed = True

            items.append(_to_item(disease, advice, failed))

        return BaseResponse(
            success=True,
            message="获取康复建议成功",
            data={"items": items},
        )
    except Exception as e:
        logger.error(f"获取康复建议失败: {e}", exc_info=True)
        return BaseResponse(
            success=False,
            message="获取康复建议失败，请稍后重试",
            data={"items": []},
        )