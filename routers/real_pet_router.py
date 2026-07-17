"""M3 真实宠物管理路由 — 档案/体重/疫苗驱虫/饮食/食品库"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date, datetime
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.models.schemas.real_pet import (
    PetProfileCreate, PetProfileUpdate,
    PetWeightCreate, PetVaccineCreate, PetDewormingCreate,
    PetFeedingCreate, PetWaterCreate, PetAIAdviceRequest,
)
from shared.services.real_pet_service import (
    create_pet, get_pets, get_pet, update_pet, delete_pet,
    add_weight, get_weight_records, get_weight_trend, delete_weight_record,
    add_vaccine, get_vaccine_records,
    add_deworming, get_deworming_records,
    add_feeding, get_feeding_records, get_pet_daily_summary, get_feeding_plan,
    search_food_database, get_ai_advice,
    compare_pet_foods, calculate_health_score,
)

router = APIRouter(prefix="/pets", tags=["真实宠物"])


def _pet_to_dict(p) -> dict:
    return {
        "id": p.id, "user_id": p.user_id, "name": p.name,
        "species": p.species, "breed": p.breed, "gender": p.gender,
        "birth_date": p.birth_date.isoformat() if p.birth_date else None,
        "is_neutered": p.is_neutered, "avatar_url": p.avatar_url,
        "is_active": p.is_active,
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
    }


# ========== 档案 CRUD ==========

@router.post("", response_model=BaseResponse)
async def api_create_pet(data: PetProfileCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """创建宠物档案"""
    try:
        pet = create_pet(db, current_user.id, data.model_dump())
        return BaseResponse(success=True, message="宠物档案创建成功", data=_pet_to_dict(pet))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("", response_model=BaseResponse)
async def api_list_pets(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取当前用户的宠物列表"""
    pets = get_pets(db, current_user.id)
    return BaseResponse(success=True, message="获取宠物列表成功", data={"pets": [_pet_to_dict(p) for p in pets]})


@router.get("/{pet_id}", response_model=BaseResponse)
async def api_get_pet(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取宠物详情"""
    pet = get_pet(db, pet_id, current_user.id)
    if not pet:
        raise HTTPException(status_code=404, detail="宠物不存在")
    return BaseResponse(success=True, message="获取宠物详情成功", data=_pet_to_dict(pet))


@router.put("/{pet_id}", response_model=BaseResponse)
async def api_update_pet(pet_id: int, data: PetProfileUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """更新宠物信息"""
    try:
        pet = update_pet(db, pet_id, current_user.id, data.model_dump(exclude_none=True))
        return BaseResponse(success=True, message="宠物信息更新成功", data=_pet_to_dict(pet))
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{pet_id}", response_model=BaseResponse)
async def api_delete_pet(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """软删除宠物"""
    try:
        delete_pet(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="宠物已删除")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 体重 ==========

@router.post("/{pet_id}/weight-records", response_model=BaseResponse)
async def api_add_weight(pet_id: int, data: PetWeightCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """记录宠物体重"""
    try:
        r = add_weight(db, pet_id, current_user.id, data.model_dump())
        result = {"id": r.id, "weight": float(r.weight), "measured_at": r.measured_at.isoformat(), "notes": r.notes}
        return BaseResponse(success=True, message="体重记录成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{pet_id}/weight-records", response_model=BaseResponse)
async def api_get_weights(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询宠物体重记录"""
    try:
        records = get_weight_records(db, pet_id, current_user.id)
        items = [{"id": r.id, "weight": float(r.weight), "measured_at": r.measured_at.isoformat(), "notes": r.notes} for r in records]
        return BaseResponse(success=True, message="获取体重记录成功", data={"records": items})
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{pet_id}/weight-trend", response_model=BaseResponse)
async def api_weight_trend(pet_id: int, days: int = Query(30), current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """体重趋势图"""
    try:
        data = get_weight_trend(db, pet_id, current_user.id, days)
        return BaseResponse(success=True, message="获取体重趋势成功", data=data)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{pet_id}/weight-records/{record_id}", response_model=BaseResponse)
async def api_delete_weight(pet_id: int, record_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除体重记录"""
    try:
        delete_weight_record(db, record_id, pet_id, current_user.id)
        return BaseResponse(success=True, message="体重记录已删除")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 疫苗 ==========

@router.post("/{pet_id}/vaccine-records", response_model=BaseResponse)
async def api_add_vaccine(pet_id: int, data: PetVaccineCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """添加疫苗记录"""
    try:
        r = add_vaccine(db, pet_id, current_user.id, data.model_dump())
        result = {"id": r.id, "vaccine_name": r.vaccine_name, "vaccinated_at": r.vaccinated_at.isoformat(),
                  "next_vaccination_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else None}
        return BaseResponse(success=True, message="疫苗记录添加成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{pet_id}/vaccine-records", response_model=BaseResponse)
async def api_get_vaccines(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询疫苗记录"""
    try:
        records = get_vaccine_records(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="获取疫苗记录成功", data={"records": records})
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 驱虫 ==========

@router.post("/{pet_id}/deworming-records", response_model=BaseResponse)
async def api_add_deworming(pet_id: int, data: PetDewormingCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """添加驱虫记录"""
    try:
        r = add_deworming(db, pet_id, current_user.id, data.model_dump())
        result = {"id": r.id, "deworming_type": r.deworming_type, "treated_at": r.treated_at.isoformat(),
                  "next_treatment_date": r.next_treatment_date.isoformat() if r.next_treatment_date else None}
        return BaseResponse(success=True, message="驱虫记录添加成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{pet_id}/deworming-records", response_model=BaseResponse)
async def api_get_dewormings(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询驱虫记录"""
    try:
        records = get_deworming_records(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="获取驱虫记录成功", data={"records": records})
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 饮食 ==========

@router.post("/{pet_id}/feeding-records", response_model=BaseResponse)
async def api_add_feeding(pet_id: int, data: PetFeedingCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """手动记录宠物饮食"""
    try:
        record_data = data.model_dump()
        record_data.setdefault("record_time", datetime.utcnow())
        r = add_feeding(db, pet_id, record_data)
        result = {"id": r.id, "food_name": r.food_name, "amount_grams": float(r.amount_grams) if r.amount_grams else None,
                  "calories": float(r.calories) if r.calories else None, "record_time": r.record_time.isoformat()}
        return BaseResponse(success=True, message="饮食记录成功", data=result)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/{pet_id}/feeding-records", response_model=BaseResponse)
async def api_get_feedings(pet_id: int, skip: int = 0, limit: int = 50,
                           current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询宠物饮食记录"""
    records = get_feeding_records(db, pet_id, skip, limit)
    items = [{"id": r.id, "food_name": r.food_name, "amount_grams": float(r.amount_grams) if r.amount_grams else None,
              "calories": float(r.calories) if r.calories else None,
              "protein": float(r.protein) if r.protein else None,
              "record_time": r.record_time.isoformat(), "from_source": r.from_source} for r in records]
    return BaseResponse(success=True, message="获取饮食记录成功", data={"records": items})


@router.get("/{pet_id}/daily-summary/{target_date}", response_model=BaseResponse)
async def api_daily_summary(pet_id: int, target_date: date,
                            current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """宠物每日营养汇总"""
    data = get_pet_daily_summary(db, pet_id, target_date)
    return BaseResponse(success=True, message="获取每日汇总成功", data=data)


@router.get("/{pet_id}/feeding-plan", response_model=BaseResponse)
async def api_feeding_plan(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取推荐喂食计划"""
    try:
        plan = get_feeding_plan(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="获取喂食计划成功", data=plan)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== AI 建议 ==========

@router.post("/{pet_id}/ai-advice", response_model=BaseResponse)
async def api_ai_advice(pet_id: int, _req: PetAIAdviceRequest = PetAIAdviceRequest(),
                        current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取宠物 AI 健康建议（规则兜底）"""
    try:
        advice = get_ai_advice(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="获取健康建议成功", data=advice)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 食品库 ==========

@router.get("/food-database", response_model=BaseResponse)
async def api_food_db(species: Optional[str] = Query(None), category: Optional[str] = Query(None), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """查询宠物食品库"""
    foods = search_food_database(db, species, category)
    return BaseResponse(success=True, message="获取食品库成功", data={"foods": foods})


@router.get("/food-database/search", response_model=BaseResponse)
async def api_food_search(keyword: str = Query(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """搜索宠物食品"""
    foods = search_food_database(db, keyword=keyword)
    return BaseResponse(success=True, message="搜索成功", data={"foods": foods})


# ========== 换粮建议 ==========

class CompareFoodsRequest(BaseModel):
    current_food_id: int = Field(..., description="当前食品ID")
    new_food_id: int = Field(..., description="新食品ID")


@router.post("/{pet_id}/compare-foods", response_model=BaseResponse)
async def api_compare_foods(pet_id: int, req: CompareFoodsRequest,
                            current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """换粮对比与过渡方案

    对比两份食品的营养数据，生成7天渐进过渡方案和注意事项。
    """
    try:
        result = compare_pet_foods(db, pet_id, current_user.id, req.current_food_id, req.new_food_id)
        return BaseResponse(success=True, message="换粮对比完成", data=result)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# ========== 健康评分 ==========

@router.get("/{pet_id}/health-score", response_model=BaseResponse)
async def api_health_score(pet_id: int,
                           current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """宠物健康综合评分（0-100）

    评分维度：
    - 饮食达标率（40分）：近7天热量+蛋白质达标率
    - 体重管理（30分）：体重是否在品种标准范围内
    - 疫苗状态（20分）：疫苗是否在有效期内
    - 活跃度（10分）：近7天饮食记录频次
    """
    try:
        result = calculate_health_score(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="健康评分计算完成", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
