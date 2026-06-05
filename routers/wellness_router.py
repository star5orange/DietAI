from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional, List

from shared.models.database import get_db
from shared.utils.auth import get_current_user
from shared.models.schemas.wellness import DailyWellnessRecommendation, SolarTermOut
from shared.services.wellness_service import (
    get_daily_wellness_recommendation,
    generate_ai_wellness_recommendation,
    get_solar_terms,
    get_wellness_tips,
)

router = APIRouter(prefix="/api/wellness", tags=["wellness"])


@router.get("/daily-recommendation", response_model=DailyWellnessRecommendation)
async def daily_recommendation(
    solar_term: Optional[str] = Query(None, description="节气名称"),
    season: Optional[str] = Query(None, description="季节"),
    constitution_type: Optional[str] = Query(None, description="体质类型"),
    use_ai: bool = Query(True, description="是否使用AI生成推荐"),
    db: Session = Depends(get_db),
    user=Depends(get_current_user)
):
    """每日养生推荐：结合节气、季节、体质生成个性化养生建议。

    默认调用 AI Agent 生成个性化推荐，use_ai=false 时使用知识库查询。
    """
    if use_ai:
        return await generate_ai_wellness_recommendation(
            user_id=user.id,
            db=db,
            solar_term=solar_term,
            season=season,
            constitution_type=constitution_type,
        )
    return get_daily_wellness_recommendation(db, solar_term, season, constitution_type)


@router.get("/solar-terms", response_model=List[SolarTermOut])
async def solar_terms(
    year: int = Query(2026, description="年份"),
    db: Session = Depends(get_db),
):
    """获取该年所有节气日期及描述"""
    return get_solar_terms(db, year)


@router.get("/tips")
async def wellness_tips_endpoint(
    constitution_type: Optional[str] = Query(None, description="用户体质类型"),
    limit: int = Query(5, ge=1, le=20, description="返回条数"),
    db: Session = Depends(get_db),
):
    """随机获取养生知识卡片。匹配用户体质优先返回。"""
    tips = get_wellness_tips(db, constitution_type, limit)
    from shared.models.schemas.base import BaseResponse
    return BaseResponse(
        success=True,
        message=f"获取到 {len(tips)} 条养生知识",
        data=tips,
    )
