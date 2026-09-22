"""M3 真实宠物管理路由 — 档案/体重/疫苗驱虫/饮食/食品库/AI形象"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import Optional
from datetime import date, datetime
from pydantic import BaseModel, Field

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User
from shared.models.pet_models import PetWeightRecord, PetAvatar  # 用于查询最新体重和AI形象
from shared.models.schemas.real_pet import (
    PetProfileCreate, PetProfileUpdate,
    PetWeightCreate, PetVaccineCreate, PetVaccineUpdate,
    PetDewormingCreate, PetDewormingUpdate,
    PetFeedingCreate, PetWaterCreate, PetAIAdviceRequest,
    PetFoodOCRRequest, PetFoodSaveRequest, GenerateAvatarRequest, RegenerateEmotionRequest,
)
from shared.services.real_pet_service import (
    create_pet, get_pets, get_pet, update_pet, delete_pet,
    add_weight, get_weight_records, get_weight_trend, delete_weight_record, update_weight_record,
    add_vaccine, update_vaccine, delete_vaccine, get_vaccine_records, get_due_vaccines,
    add_deworming, update_deworming, delete_deworming, get_deworming_records,
    add_feeding, get_feeding_records, get_pet_daily_summary, get_feeding_plan,
    add_water, get_water_records, delete_water_record,
    search_food_database, save_food_to_database, _food_to_dict, get_ai_advice,
    compare_pet_foods, calculate_health_score,
    generate_avatar, get_generation_task, regenerate_emotion, upgrade_to_gif,
)
from shared.config.minio_config import minio_client

router = APIRouter(prefix="/pets", tags=["真实宠物"])


def _refresh_avatar_url(url: Optional[str]) -> Optional[str]:
    """刷新宠物形象 URL。

    生成形象时存库的是 MinIO 预签名 URL（7 天有效），过期后前端无法加载。
    这里对 MinIO URL 重新签名；非 MinIO URL（如 DashScope 临时 URL/本地路径）原样返回。
    """
    if not url or "X-Amz" not in url:
        return url
    try:
        from urllib.parse import urlparse
        parsed = urlparse(url)
        # 形如 /<bucket>/pet_avatars/pet_1_happy_123.png，去掉桶名得到 object_name
        parts = parsed.path.lstrip("/").split("/", 1)
        if len(parts) != 2:
            return url
        object_name = parts[1]
        refreshed = minio_client.get_file_url(object_name)
        return refreshed or url
    except Exception:
        return url


def _pet_to_dict(p, db: Session = None) -> dict:
    """将 PetProfile 对象转为字典，包含年龄和体重

    Args:
        p: PetProfile 对象
        db: 数据库会话，提供后自动填充 age 和 weight 字段
    """
    result = {
        "id": p.id, "user_id": p.user_id, "name": p.name,
        "species": p.species, "breed": p.breed, "gender": p.gender,
        "birth_date": p.birth_date.isoformat() if p.birth_date else None,
        "is_neutered": p.is_neutered, "avatar_url": _refresh_avatar_url(p.avatar_url),
        "is_active": p.is_active,
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
        "age": None,
        "weight": None,
    }

    # 计算年龄
    if p.birth_date:
        today = date.today()
        years = today.year - p.birth_date.year
        months = today.month - p.birth_date.month
        if months < 0:
            years -= 1
            months += 12
        if years > 0:
            result["age"] = f"{years}岁{months}个月" if months > 0 else f"{years}岁"
        else:
            result["age"] = f"{months}个月" if months > 0 else "不足1个月"

    # 获取最新体重
    if db is not None:
        try:
            latest = db.query(PetWeightRecord).filter(
                PetWeightRecord.pet_id == p.id
            ).order_by(PetWeightRecord.measured_at.desc()).first()
            if latest:
                result["weight"] = round(float(latest.weight), 2)
        except Exception:
            pass

        # 获取 AI 形象情绪变体 URL
        try:
            avatar = db.query(PetAvatar).filter(
                PetAvatar.pet_id == p.id
            ).first()
            if avatar:
                result["avatar_emotions"] = {
                    "happy": _refresh_avatar_url(avatar.emotion_happy_url),
                    "normal": _refresh_avatar_url(avatar.emotion_normal_url),
                    "hungry": _refresh_avatar_url(avatar.emotion_hungry_url),
                    "weak": _refresh_avatar_url(avatar.emotion_weak_url),
                }
                result["avatar_base_url"] = _refresh_avatar_url(avatar.base_image_url)
        except Exception:
            pass

    return result


# ========== 品种列表 ==========

# 猫/狗品种数据
_BREEDS = {
    "cat": [
        "英国短毛猫", "布偶猫", "暹罗猫", "中华田园猫", "美国短毛猫",
        "异国短毛猫", "波斯猫", "缅因猫", "苏格兰折耳猫", "无毛猫",
        "德文卷毛猫", "孟加拉豹猫", "俄罗斯蓝猫", "挪威森林猫",
    ],
    "dog": [
        "泰迪/贵宾", "柯基", "金毛", "拉布拉多", "哈士奇",
        "柴犬", "博美", "比熊", "萨摩耶", "阿拉斯加",
        "边境牧羊犬", "德国牧羊犬", "吉娃娃", "法斗",
        "巴哥", "约克夏",
    ],
}


@router.get("/breeds", response_model=BaseResponse)
async def api_get_breeds(species: Optional[str] = Query(None, description="cat 或 dog，不传返回全部"),
                         current_user: User = Depends(get_current_user)):
    """获取宠物品种列表"""
    if species and species in _BREEDS:
        return BaseResponse(success=True, message="获取品种列表成功", data={"breeds": _BREEDS[species]})
    all_breeds = {}
    for s, breeds in _BREEDS.items():
        all_breeds[s] = breeds
    return BaseResponse(success=True, message="获取品种列表成功", data={"breeds": all_breeds})


# ========== 食品库（必须在 /{pet_id} 之前注册，避免 food-database 被当作 pet_id 解析） ==========

@router.get("/food-database", response_model=BaseResponse)
async def api_food_db(species: Optional[str] = Query(None), category: Optional[str] = Query(None), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """查询用户宠物食品库"""
    foods = search_food_database(db, current_user.id, species, category)
    return BaseResponse(success=True, message="获取食品库成功", data={"foods": foods})


@router.get("/food-database/search", response_model=BaseResponse)
async def api_food_search(keyword: str = Query(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """搜索用户宠物食品"""
    foods = search_food_database(db, current_user.id, keyword=keyword)
    return BaseResponse(success=True, message="搜索成功", data={"foods": foods})


@router.post("/food-database/save", response_model=BaseResponse)
async def api_save_food(data: PetFoodSaveRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """保存OCR识别的食品到用户食品库"""
    try:
        food = save_food_to_database(db, current_user.id, {
            "food_name": data.food_name,
            "brand": data.brand or "",
            "category": data.category or "",
            "suitable_species": data.suitable_species or "",
            "calories_per_100g": data.calories_per_100g,
            "protein_per_100g": data.protein_per_100g,
            "fat_per_100g": data.fat_per_100g,
            "carbs_per_100g": data.carbs_per_100g,
        })
        return BaseResponse(success=True, message="保存成功", data=_food_to_dict(food))
    except Exception as e:
        logger.error(f"Save pet food failed: {e}")
        raise HTTPException(status_code=500, detail=f"保存失败: {str(e)}")


@router.post("/food-database/ocr", response_model=BaseResponse)
async def api_ocr_pet_food(data: PetFoodOCRRequest,
                            current_user: User = Depends(get_current_user)):
    """拍照识别宠物食品包装营养成分表

    使用 DashScope qwen-vl 模型进行 OCR + 结构化解析。
    返回品牌、产品名、每100g营养成分供用户确认后录入食品库。
    """
    from shared.services.real_pet_service import parse_pet_food_label
    try:
        result = parse_pet_food_label(data.image_base64)
        return BaseResponse(success=True, message="识别成功", data=result)
    except Exception as e:
        logger.error(f"Pet food OCR failed: {e}")
        raise HTTPException(status_code=500, detail=f"识别失败: {str(e)}")


@router.get("/vaccines/due", response_model=BaseResponse)
async def api_get_due_vaccines(days: int = Query(30, description="提前多少天提醒"),
                                current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取所有宠物即将到期/已过期的疫苗（用于首页提醒）"""
    records = get_due_vaccines(db, current_user.id, days)
    return BaseResponse(success=True, message="获取到期提醒成功", data={"records": records, "total": len(records)})


# ========== 档案 CRUD ==========

@router.post("", response_model=BaseResponse)
async def api_create_pet(data: PetProfileCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """创建宠物档案"""
    try:
        pet = create_pet(db, current_user.id, data.model_dump())
        return BaseResponse(success=True, message="宠物档案创建成功", data=_pet_to_dict(pet, db))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("", response_model=BaseResponse)
async def api_list_pets(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取当前用户的宠物列表"""
    pets = get_pets(db, current_user.id)
    return BaseResponse(success=True, message="获取宠物列表成功", data={"pets": [_pet_to_dict(p, db) for p in pets]})


@router.get("/{pet_id}", response_model=BaseResponse)
async def api_get_pet(pet_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """获取宠物详情"""
    pet = get_pet(db, pet_id, current_user.id)
    if not pet:
        raise HTTPException(status_code=404, detail="宠物不存在")
    return BaseResponse(success=True, message="获取宠物详情成功", data=_pet_to_dict(pet, db))


@router.put("/{pet_id}", response_model=BaseResponse)
async def api_update_pet(pet_id: int, data: PetProfileUpdate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """更新宠物信息"""
    try:
        pet = update_pet(db, pet_id, current_user.id, data.model_dump(exclude_none=True))
        return BaseResponse(success=True, message="宠物信息更新成功", data=_pet_to_dict(pet, db))
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


@router.put("/{pet_id}/weight-records/{record_id}", response_model=BaseResponse)
async def api_update_weight(pet_id: int, record_id: int, data: dict, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """更新体重记录"""
    try:
        r = update_weight_record(db, record_id, pet_id, current_user.id, data)
        return BaseResponse(success=True, message="体重记录已更新", data={
            "id": r.id, "weight": float(r.weight), "measured_at": r.measured_at.isoformat() if r.measured_at else None,
            "notes": r.notes,
        })
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 疫苗 ==========

@router.post("/{pet_id}/vaccine-records", response_model=BaseResponse)
async def api_add_vaccine(pet_id: int, data: PetVaccineCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """添加疫苗记录"""
    try:
        r = add_vaccine(db, pet_id, current_user.id, data.model_dump())
        result = {
            "id": r.id,
            "vaccine_name": r.vaccine_name,
            "vaccinated_at": r.vaccinated_at.isoformat() if r.vaccinated_at else None,
            "expiry_date": r.expiry_date.isoformat() if r.expiry_date else None,
            "next_vaccination_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else None,
            "notes": r.notes
        }
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


@router.put("/{pet_id}/vaccine-records/{record_id}", response_model=BaseResponse)
async def api_update_vaccine(pet_id: int, record_id: int, data: PetVaccineUpdate,
                              current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """更新疫苗记录"""
    try:
        r = update_vaccine(db, record_id, pet_id, current_user.id, data.model_dump(exclude_none=True))
        result = {
            "id": r.id,
            "vaccine_name": r.vaccine_name,
            "vaccinated_at": r.vaccinated_at.isoformat() if r.vaccinated_at else None,
            "expiry_date": r.expiry_date.isoformat() if r.expiry_date else None,
            "next_vaccination_date": r.next_vaccination_date.isoformat() if r.next_vaccination_date else None,
            "notes": r.notes
        }
        return BaseResponse(success=True, message="疫苗记录更新成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{pet_id}/vaccine-records/{record_id}", response_model=BaseResponse)
async def api_delete_vaccine(pet_id: int, record_id: int,
                              current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除疫苗记录"""
    try:
        delete_vaccine(db, record_id, pet_id, current_user.id)
        return BaseResponse(success=True, message="疫苗记录已删除")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ========== 驱虫 ==========

@router.post("/{pet_id}/deworming-records", response_model=BaseResponse)
async def api_add_deworming(pet_id: int, data: PetDewormingCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """添加驱虫记录"""
    try:
        r = add_deworming(db, pet_id, current_user.id, data.model_dump())
        result = {
            "id": r.id,
            "deworming_type": r.deworming_type,
            "treated_at": r.treated_at.isoformat() if r.treated_at else None,
            "next_treatment_date": r.next_treatment_date.isoformat() if r.next_treatment_date else None,
            "notes": r.notes
        }
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


@router.put("/{pet_id}/deworming-records/{record_id}", response_model=BaseResponse)
async def api_update_deworming(pet_id: int, record_id: int, data: PetDewormingUpdate,
                                current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """更新驱虫记录"""
    try:
        r = update_deworming(db, record_id, pet_id, current_user.id, data.model_dump(exclude_none=True))
        result = {
            "id": r.id,
            "deworming_type": r.deworming_type,
            "treated_at": r.treated_at.isoformat() if r.treated_at else None,
            "next_treatment_date": r.next_treatment_date.isoformat() if r.next_treatment_date else None,
            "notes": r.notes
        }
        return BaseResponse(success=True, message="驱虫记录更新成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{pet_id}/deworming-records/{record_id}", response_model=BaseResponse)
async def api_delete_deworming(pet_id: int, record_id: int,
                                current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除驱虫记录"""
    try:
        delete_deworming(db, record_id, pet_id, current_user.id)
        return BaseResponse(success=True, message="驱虫记录已删除")
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
        result = {"id": r.id, "food_name": r.food_name, "amount_grams": float(r.amount_grams) if r.amount_grams else 0,
                  "calories": float(r.calories) if r.calories else 0, "record_time": r.record_time.isoformat()}
        return BaseResponse(success=True, message="饮食记录成功", data=result)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/{pet_id}/feeding-records", response_model=BaseResponse)
async def api_get_feedings(pet_id: int, skip: int = 0, limit: int = 50,
                           current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询宠物饮食记录"""
    records = get_feeding_records(db, pet_id, skip, limit)
    items = [{"id": r.id, "food_name": r.food_name,
              "amount_grams": float(r.amount_grams) if r.amount_grams else 0,
              "calories": float(r.calories) if r.calories else 0,
              "protein": float(r.protein) if r.protein else 0,
              "fat": float(r.fat) if r.fat else 0,
              "carbs": float(r.carbs) if r.carbs else 0,
              "record_time": r.record_time.isoformat(), "from_source": r.from_source} for r in records]
    return BaseResponse(success=True, message="获取饮食记录成功", data={"records": items})


@router.delete("/{pet_id}/feeding-records/{record_id}", response_model=BaseResponse)
async def api_delete_feeding(pet_id: int, record_id: int,
                              current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除宠物饮食记录"""
    from shared.services.real_pet_service import delete_feeding
    ok = delete_feeding(db, pet_id, record_id)
    if not ok:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="饮食记录不存在")
    return BaseResponse(success=True, message="删除成功")


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


# ========== 饮水 ==========

@router.post("/{pet_id}/water-records", response_model=BaseResponse)
async def api_add_water(pet_id: int, data: PetWaterCreate,
                        current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """手动记录宠物饮水"""
    try:
        record_data = data.model_dump()
        record_data.setdefault("record_time", datetime.utcnow())
        r = add_water(db, pet_id, record_data)
        result = {"id": r.id, "amount_ml": r.amount_ml,
                  "record_time": r.record_time.isoformat(), "from_source": r.from_source}
        return BaseResponse(success=True, message="饮水记录成功", data=result)
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/{pet_id}/water-records", response_model=BaseResponse)
async def api_get_waters(pet_id: int, skip: int = 0, limit: int = 50,
                         current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """查询宠物饮水记录"""
    records = get_water_records(db, pet_id, skip, limit)
    items = [{"id": r.id, "amount_ml": r.amount_ml,
              "record_time": r.record_time.isoformat(), "from_source": r.from_source} for r in records]
    return BaseResponse(success=True, message="获取饮水记录成功", data={"records": items})


@router.delete("/{pet_id}/water-records/{record_id}", response_model=BaseResponse)
async def api_delete_water(pet_id: int, record_id: int,
                           current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """删除饮水记录"""
    try:
        delete_water_record(db, record_id, pet_id, current_user.id)
        return BaseResponse(success=True, message="饮水记录已删除")
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


# ========== AI 形象生成 ==========

@router.post("/{pet_id}/generate-avatar", response_model=BaseResponse)
async def api_generate_avatar(pet_id: int, data: GenerateAvatarRequest,
                               current_user: User = Depends(get_current_user),
                               db: Session = Depends(get_db)):
    """触发 AI 生成宠物卡通形象

    mode: photo（拍照上传）或 description（文字描述）
    """
    try:
        task_id = generate_avatar(
            db, pet_id, current_user.id,
            mode=data.mode,
            photo=data.photo,
            description=data.description,
            style=data.style,
        )
        return BaseResponse(success=True, message="生成任务已提交", data={"task_id": task_id})
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/generation-tasks/{task_id}", response_model=BaseResponse)
async def api_get_generation_task(task_id: str, db: Session = Depends(get_db)):
    """查询形象生成任务状态"""
    data = get_generation_task(db, task_id)
    return BaseResponse(success=True, message="查询成功", data=data)


@router.post("/{pet_id}/regenerate-emotion", response_model=BaseResponse)
async def api_regenerate_emotion(pet_id: int, data: RegenerateEmotionRequest,
                                  current_user: User = Depends(get_current_user),
                                  db: Session = Depends(get_db)):
    """重新生成单个情绪变体"""
    try:
        result = regenerate_emotion(db, pet_id, current_user.id, data.emotion)
        return BaseResponse(success=True, message="重生成成功", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{pet_id}/upgrade-to-gif", response_model=BaseResponse)
async def api_upgrade_to_gif(pet_id: int,
                              current_user: User = Depends(get_current_user),
                              db: Session = Depends(get_db)):
    """触发 GIF 动图生成"""
    try:
        result = upgrade_to_gif(db, pet_id, current_user.id)
        return BaseResponse(success=True, message="GIF生成完成", data=result)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
