from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, date, timedelta
import json
import logging
import traceback
from decimal import Decimal

from shared.models.database import get_db
from shared.models.schemas import (
    BaseResponse, UserProfileUpdate, UserProfileResponse,
    HealthGoalCreate, HealthGoalResponse, DiseaseCreate, DiseaseResponse,
    AllergyCreate, AllergyResponse, WeightRecordCreate, WeightRecordResponse,
    OnboardingStepUpdate, OnboardingDataRequest
)
from shared.models.schemas.user import DiseaseUpdate, AllergyUpdate
from shared.models.schemas.constitution import (
    ConstitutionQuizRequest, QuizAnswer,
    QUIZ_QUESTIONS, CONSTITUTION_TYPES, CONSTITUTION_DIET_ADVICE,
    ConstitutionTypeInfo
)
from shared.utils.auth import get_current_user
from shared.models.user_models import User, UserProfile, HealthGoal, Disease, Allergy, WeightRecord
from shared.config.redis_config import cache_service

router = APIRouter(prefix="/users", tags=["用户", "用户管理"])
logger = logging.getLogger(__name__)

# 错误消息常量
class ErrorMessages:
    """错误消息常量"""
    PROFILE_NOT_FOUND = "用户资料不存在"
    PROFILE_LOAD_FAILED = "获取用户资料失败"
    PROFILE_UPDATE_FAILED = "更新用户资料失败"
    HEALTH_GOAL_NOT_FOUND = "健康目标不存在"
    HEALTH_GOAL_CREATE_FAILED = "创建健康目标失败"
    HEALTH_GOAL_UPDATE_FAILED = "更新健康目标失败"
    DISEASE_CREATE_FAILED = "添加疾病信息失败"
    ALLERGY_CREATE_FAILED = "添加过敏信息失败"
    WEIGHT_RECORD_CREATE_FAILED = "添加体重记录失败"
    ONBOARDING_UPDATE_FAILED = "更新引导步骤失败"
    ONBOARDING_COMPLETE_FAILED = "完成用户引导失败"
    DATABASE_ERROR = "数据库操作失败"
    UNKNOWN_ERROR = "未知错误"

def handle_database_error(e: Exception, operation: str = "数据库操作") -> HTTPException:
    """统一处理数据库错误"""
    logger.error(f"{operation}失败: {str(e)}")
    logger.error(f"错误类型: {type(e).__name__}")
    logger.error(f"详细堆栈: {traceback.format_exc()}")
    
    if isinstance(e, SQLAlchemyError):
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"{operation}失败，请稍后重试"
        )
    else:
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"{operation}失败: {str(e)}"
        )

def calculate_bmi(height: Optional[float], weight: Optional[float]) -> Optional[float]:
    """计算BMI"""
    if height and weight and height > 0:
        height_m = height / 100
        return round(weight / (height_m ** 2), 2)
    return None

def format_profile_data(profile: UserProfile) -> dict:
    """格式化用户资料数据 - 只使用数据库中存在的字段"""
    return {
        # 数据库中存在的字段
        "id": profile.id,
        "user_id": profile.user_id,
        "real_name": profile.real_name,
        "gender": profile.gender,
        "birth_date": profile.birth_date.isoformat() if profile.birth_date else None,
        "height": float(profile.height) if profile.height else None,
        "weight": float(profile.weight) if profile.weight else None,
        "bmi": float(profile.bmi) if profile.bmi else None,
        "activity_level": profile.activity_level,
        "occupation": profile.occupation,
        "region": profile.region,
        "created_at": profile.created_at.isoformat(),
        "updated_at": profile.updated_at.isoformat(),
        
        # 以下字段在当前数据库中不存在，返回默认值以保持API兼容性
        "dietary_preferences": None,
        "food_dislikes": None,
        "wake_up_time": None,
        "sleep_time": None,
        "meal_times": None,
        "health_status": 1,  # 默认健康状态
        "onboarding_completed": profile.onboarding_completed if profile.onboarding_completed is not None else False,
        "onboarding_step": profile.onboarding_step if profile.onboarding_step is not None else 0,
        "constitution_type": profile.constitution_type,
        "crowd_tag": profile.crowd_tag,
        "daily_water_goal": profile.daily_water_goal,
    }


@router.get("/stats", response_model=BaseResponse)
async def get_user_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户统计数据：连续打卡天数、总记录次数、平均卡路里"""
    try:
        from shared.models.food_models import FoodRecord, DailyNutritionSummary

        total_records = db.query(func.count(FoodRecord.id)).filter(
            FoodRecord.user_id == current_user.id
        ).scalar() or 0

        avg_calories_result = db.query(func.avg(DailyNutritionSummary.total_calories)).filter(
            DailyNutritionSummary.user_id == current_user.id,
            DailyNutritionSummary.total_calories > 0
        ).scalar()
        avg_calories = round(float(avg_calories_result), 0) if avg_calories_result else 0

        streak = 0
        check_date = date.today()
        for i in range(365):
            has_record = db.query(FoodRecord).filter(
                FoodRecord.user_id == current_user.id,
                FoodRecord.record_date == check_date
            ).first()
            if has_record:
                streak += 1
                check_date -= timedelta(days=1)
            else:
                break

        return BaseResponse(
            success=True,
            message="获取用户统计成功",
            data={
                "streak_days": streak,
                "total_records": total_records,
                "avg_calories": int(avg_calories),
            }
        )
    except Exception as e:
        raise handle_database_error(e, "获取用户统计")


@router.get("/profile", response_model=BaseResponse)
async def get_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户资料"""
    try:
        # 先尝试从缓存获取
        cached_profile = cache_service.get_user_profile(current_user.id)
        if cached_profile:
            return BaseResponse(
                success=True,
                message="获取用户资料成功",
                data=cached_profile
            )
        
        # 从数据库获取
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if not profile:
            # 如果没有资料，创建默认资料
            profile = UserProfile(
                user_id=current_user.id,
                activity_level=2  # 默认轻度活动
            )
            db.add(profile)
            db.commit()
            db.refresh(profile)
        
        # 计算BMI
        bmi = calculate_bmi(profile.height, profile.weight)
        if bmi and profile.bmi != bmi:
            profile.bmi = bmi
            db.commit()
        
        profile_data = format_profile_data(profile)
        
        # 缓存用户资料
        cache_service.cache_user_profile(current_user.id, profile_data)
        
        return BaseResponse(
            success=True,
            message="获取用户资料成功",
            data=profile_data
        )
    except Exception as e:
        raise handle_database_error(e, "获取用户资料")


@router.put("/profile", response_model=BaseResponse)
async def update_user_profile(
    profile_data: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新用户资料"""
    try:
        # 获取现有资料
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if not profile:
            # 如果没有资料，创建新的
            profile = UserProfile(user_id=current_user.id)
            db.add(profile)
        
        # 更新字段
        update_data = profile_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            if hasattr(profile, field):
                setattr(profile, field, value)
        
        # 重新计算BMI
        bmi = calculate_bmi(profile.height, profile.weight)
        if bmi:
            profile.bmi = bmi
        
        profile.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(profile)
        
        # 清除缓存
        cache_service.clear_user_cache(current_user.id)
        
        return BaseResponse(
            success=True,
            message="用户资料更新成功",
            data=format_profile_data(profile)
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新用户资料")


@router.post("/health-goals", response_model=BaseResponse)
async def create_health_goal(
    goal_data: HealthGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建健康目标"""
    try:
        # 暂停其他进行中的目标
        db.query(HealthGoal).filter(
            HealthGoal.user_id == current_user.id,
            HealthGoal.current_status == 1
        ).update({"current_status": 3})  # 暂停
        
        # 创建新目标
        health_goal = HealthGoal(
            user_id=current_user.id,
            goal_type=goal_data.goal_type,
            target_weight=goal_data.target_weight,
            target_date=goal_data.target_date,
            current_status=1  # 进行中
        )
        
        db.add(health_goal)
        db.commit()
        db.refresh(health_goal)
        
        return BaseResponse(
            success=True,
            message="健康目标创建成功",
            data={
                "id": health_goal.id,
                "user_id": health_goal.user_id,
                "goal_type": health_goal.goal_type,
                "target_weight": float(health_goal.target_weight) if health_goal.target_weight else None,
                "target_date": health_goal.target_date.isoformat() if health_goal.target_date else None,
                "current_status": health_goal.current_status,
                "created_at": health_goal.created_at.isoformat(),
                "updated_at": health_goal.updated_at.isoformat() if health_goal.updated_at else None,
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "创建健康目标")


@router.get("/health-goals", response_model=BaseResponse)
async def get_health_goals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    status_filter: Optional[int] = Query(None, description="状态筛选")
):
    """获取健康目标列表"""
    try:
        query = db.query(HealthGoal).filter(HealthGoal.user_id == current_user.id)
        
        if status_filter is not None:
            query = query.filter(HealthGoal.current_status == status_filter)
        
        goals = query.order_by(HealthGoal.created_at.desc()).all()
        
        goals_data = []
        for goal in goals:
            goals_data.append({
                "id": goal.id,
                "user_id": goal.user_id,
                "goal_type": goal.goal_type,
                "target_weight": float(goal.target_weight) if goal.target_weight else None,
                "target_date": goal.target_date.isoformat() if goal.target_date else None,
                "current_status": goal.current_status,
                "created_at": goal.created_at.isoformat(),
                "updated_at": goal.updated_at.isoformat()
            })
        
        return BaseResponse(
            success=True,
            message="获取健康目标列表成功",
            data=goals_data
        )
    except Exception as e:
        raise handle_database_error(e, "获取健康目标列表")


@router.put("/health-goals/{goal_id}", response_model=BaseResponse)
async def update_health_goal(
    goal_id: int,
    goal_data: HealthGoalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新健康目标"""
    try:
        goal = db.query(HealthGoal).filter(
            HealthGoal.id == goal_id,
            HealthGoal.user_id == current_user.id
        ).first()
        
        if not goal:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=ErrorMessages.HEALTH_GOAL_NOT_FOUND
            )
        
        # 更新字段
        goal.goal_type = goal_data.goal_type
        goal.target_weight = goal_data.target_weight
        goal.target_date = goal_data.target_date
        goal.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(goal)
        
        return BaseResponse(
            success=True,
            message="健康目标更新成功",
            data={
                "id": goal.id,
                "user_id": goal.user_id,
                "goal_type": goal.goal_type,
                "target_weight": float(goal.target_weight) if goal.target_weight else None,
                "target_date": goal.target_date.isoformat() if goal.target_date else None,
                "current_status": goal.current_status,
                "created_at": goal.created_at.isoformat(),
                "updated_at": goal.updated_at.isoformat()
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新健康目标")


@router.delete("/health-goals/{goal_id}", response_model=BaseResponse)
async def delete_health_goal(
    goal_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除健康目标"""
    try:
        goal = db.query(HealthGoal).filter(
            HealthGoal.id == goal_id,
            HealthGoal.user_id == current_user.id
        ).first()

        if not goal:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=ErrorMessages.HEALTH_GOAL_NOT_FOUND
            )

        db.delete(goal)
        db.commit()

        return BaseResponse(
            success=True,
            message="健康目标已删除",
            data={"deleted_id": goal_id}
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "删除健康目标")


@router.post("/diseases", response_model=BaseResponse)
async def add_disease(
    disease_data: DiseaseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """添加疾病信息"""
    try:
        disease = Disease(
            user_id=current_user.id,
            disease_code=disease_data.disease_code,
            disease_name=disease_data.disease_name,
            severity_level=disease_data.severity_level,
            diagnosed_date=disease_data.diagnosed_date,
            notes=disease_data.notes
        )
        
        db.add(disease)
        db.commit()
        db.refresh(disease)
        
        return BaseResponse(
            success=True,
            message="疾病信息添加成功",
            data={
                "id": disease.id,
                "user_id": disease.user_id,
                "disease_code": disease.disease_code,
                "disease_name": disease.disease_name,
                "severity_level": disease.severity_level,
                "diagnosed_date": disease.diagnosed_date.isoformat() if disease.diagnosed_date else None,
                "is_current": disease.is_current,
                "notes": disease.notes,
                "created_at": disease.created_at.isoformat()
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "添加疾病信息")


@router.get("/diseases", response_model=BaseResponse)
async def get_diseases(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    is_current: Optional[bool] = Query(None, description="是否当前病症")
):
    """获取疾病信息列表"""
    try:
        query = db.query(Disease).filter(Disease.user_id == current_user.id)
        
        if is_current is not None:
            query = query.filter(Disease.is_current == is_current)
        
        diseases = query.order_by(Disease.created_at.desc()).all()
        
        diseases_data = []
        for disease in diseases:
            diseases_data.append({
                "id": disease.id,
                "user_id": disease.user_id,
                "disease_code": disease.disease_code,
                "disease_name": disease.disease_name,
                "severity_level": disease.severity_level,
                "diagnosed_date": disease.diagnosed_date.isoformat() if disease.diagnosed_date else None,
                "is_current": disease.is_current,
                "notes": disease.notes,
                "created_at": disease.created_at.isoformat()
            })
        
        return BaseResponse(
            success=True,
            message="获取疾病信息列表成功",
            data=diseases_data
        )
    except Exception as e:
        raise handle_database_error(e, "获取疾病信息列表")


@router.put("/diseases/{disease_id}", response_model=BaseResponse)
async def update_disease(
    disease_id: int,
    disease_data: DiseaseUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新疾病信息"""
    try:
        disease = db.query(Disease).filter(
            Disease.id == disease_id,
            Disease.user_id == current_user.id
        ).first()
        
        if not disease:
            raise HTTPException(status_code=404, detail="疾病记录不存在")
        
        update_data = disease_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(disease, field, value)
        
        db.commit()
        db.refresh(disease)
        
        return BaseResponse(
            success=True,
            message="疾病信息更新成功",
            data={
                "id": disease.id,
                "user_id": disease.user_id,
                "disease_code": disease.disease_code,
                "disease_name": disease.disease_name,
                "severity_level": disease.severity_level,
                "diagnosed_date": disease.diagnosed_date.isoformat() if disease.diagnosed_date else None,
                "is_current": disease.is_current,
                "notes": disease.notes,
                "created_at": disease.created_at.isoformat()
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新疾病信息")


@router.delete("/diseases/{disease_id}", response_model=BaseResponse)
async def delete_disease(
    disease_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除疾病信息"""
    try:
        disease = db.query(Disease).filter(
            Disease.id == disease_id,
            Disease.user_id == current_user.id
        ).first()
        
        if not disease:
            raise HTTPException(status_code=404, detail="疾病记录不存在")
        
        db.delete(disease)
        db.commit()
        
        return BaseResponse(
            success=True,
            message="疾病信息删除成功"
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "删除疾病信息")


@router.post("/allergies", response_model=BaseResponse)
async def add_allergy(
    allergy_data: AllergyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """添加过敏信息"""
    try:
        allergy = Allergy(
            user_id=current_user.id,
            allergen_type=allergy_data.allergen_type,
            allergen_name=allergy_data.allergen_name,
            severity_level=allergy_data.severity_level,
            reaction_description=allergy_data.reaction_description
        )
        
        db.add(allergy)
        db.commit()
        db.refresh(allergy)
        
        return BaseResponse(
            success=True,
            message="过敏信息添加成功",
            data={
                "id": allergy.id,
                "user_id": allergy.user_id,
                "allergen_type": allergy.allergen_type,
                "allergen_name": allergy.allergen_name,
                "severity_level": allergy.severity_level,
                "reaction_description": allergy.reaction_description,
                "created_at": allergy.created_at.isoformat()
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "添加过敏信息")


@router.get("/allergies", response_model=BaseResponse)
async def get_allergies(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    allergen_type: Optional[int] = Query(None, description="过敏原类型")
):
    """获取过敏信息列表"""
    try:
        query = db.query(Allergy).filter(Allergy.user_id == current_user.id)
        
        if allergen_type is not None:
            query = query.filter(Allergy.allergen_type == allergen_type)
        
        allergies = query.order_by(Allergy.created_at.desc()).all()
        
        allergies_data = []
        for allergy in allergies:
            allergies_data.append({
                "id": allergy.id,
                "user_id": allergy.user_id,
                "allergen_type": allergy.allergen_type,
                "allergen_name": allergy.allergen_name,
                "severity_level": allergy.severity_level,
                "reaction_description": allergy.reaction_description,
                "created_at": allergy.created_at.isoformat()
            })
        
        return BaseResponse(
            success=True,
            message="获取过敏信息列表成功",
            data=allergies_data
        )
    except Exception as e:
        raise handle_database_error(e, "获取过敏信息列表")


@router.put("/allergies/{allergy_id}", response_model=BaseResponse)
async def update_allergy(
    allergy_id: int,
    allergy_data: AllergyUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新过敏信息"""
    try:
        allergy = db.query(Allergy).filter(
            Allergy.id == allergy_id,
            Allergy.user_id == current_user.id
        ).first()
        
        if not allergy:
            raise HTTPException(status_code=404, detail="过敏记录不存在")
        
        update_data = allergy_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(allergy, field, value)
        
        db.commit()
        db.refresh(allergy)
        
        return BaseResponse(
            success=True,
            message="过敏信息更新成功",
            data={
                "id": allergy.id,
                "user_id": allergy.user_id,
                "allergen_type": allergy.allergen_type,
                "allergen_name": allergy.allergen_name,
                "severity_level": allergy.severity_level,
                "reaction_description": allergy.reaction_description,
                "created_at": allergy.created_at.isoformat()
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新过敏信息")


@router.delete("/allergies/{allergy_id}", response_model=BaseResponse)
async def delete_allergy(
    allergy_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除过敏信息"""
    try:
        allergy = db.query(Allergy).filter(
            Allergy.id == allergy_id,
            Allergy.user_id == current_user.id
        ).first()
        
        if not allergy:
            raise HTTPException(status_code=404, detail="过敏记录不存在")
        
        db.delete(allergy)
        db.commit()
        
        return BaseResponse(
            success=True,
            message="过敏信息删除成功"
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "删除过敏信息")


@router.post("/weight-records", response_model=BaseResponse)
async def add_weight_record(
    weight_data: WeightRecordCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """添加体重记录"""
    try:
        # 获取用户资料并计算BMI
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        bmi = calculate_bmi(user_profile.height if user_profile else None, weight_data.weight)
        
        weight_record = WeightRecord(
            user_id=current_user.id,
            weight=weight_data.weight,
            body_fat_percentage=weight_data.body_fat_percentage,
            muscle_mass=weight_data.muscle_mass,
            bmi=bmi,
            measured_at=weight_data.measured_at or datetime.utcnow(),
            notes=weight_data.notes,
            device_type=weight_data.device_type
        )
        
        db.add(weight_record)
        db.commit()
        db.refresh(weight_record)
        
        # 更新用户资料中的体重
        if user_profile:
            user_profile.weight = weight_data.weight
            user_profile.bmi = bmi
            user_profile.updated_at = datetime.utcnow()
            db.commit()
            
            # 清除缓存
            cache_service.clear_user_cache(current_user.id)
        
        return BaseResponse(
            success=True,
            message="体重记录添加成功",
            data={
                "id": weight_record.id,
                "user_id": weight_record.user_id,
                "weight": float(weight_record.weight),
                "body_fat_percentage": float(weight_record.body_fat_percentage) if weight_record.body_fat_percentage else None,
                "muscle_mass": float(weight_record.muscle_mass) if weight_record.muscle_mass else None,
                "bmi": float(weight_record.bmi) if weight_record.bmi else None,
                "measured_at": weight_record.measured_at.isoformat(),
                "notes": weight_record.notes,
                "device_type": weight_record.device_type,
                "created_at": weight_record.created_at.isoformat()
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "添加体重记录")


@router.get("/weight-records", response_model=BaseResponse)
async def get_weight_records(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    start_date: Optional[date] = Query(None, description="开始日期"),
    end_date: Optional[date] = Query(None, description="结束日期"),
    limit: int = Query(50, description="记录数量限制")
):
    """获取体重记录列表"""
    try:
        query = db.query(WeightRecord).filter(WeightRecord.user_id == current_user.id)
        
        if start_date:
            query = query.filter(WeightRecord.measured_at >= start_date)
        if end_date:
            query = query.filter(WeightRecord.measured_at <= end_date)
        
        records = query.order_by(WeightRecord.measured_at.desc()).limit(limit).all()
        
        records_data = []
        for record in records:
            records_data.append({
                "id": record.id,
                "user_id": record.user_id,
                "weight": float(record.weight),
                "body_fat_percentage": float(record.body_fat_percentage) if record.body_fat_percentage else None,
                "muscle_mass": float(record.muscle_mass) if record.muscle_mass else None,
                "bmi": float(record.bmi) if record.bmi else None,
                "measured_at": record.measured_at.isoformat(),
                "notes": record.notes,
                "device_type": record.device_type,
                "created_at": record.created_at.isoformat()
            })
        
        return BaseResponse(
            success=True,
            message="获取体重记录列表成功",
            data=records_data
        )
    except Exception as e:
        raise handle_database_error(e, "获取体重记录列表")


@router.put("/weight-records/{record_id}", response_model=BaseResponse)
async def update_weight_record(
    record_id: int,
    weight_data: WeightRecordCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新体重记录"""
    try:
        record = db.query(WeightRecord).filter(
            WeightRecord.id == record_id,
            WeightRecord.user_id == current_user.id
        ).first()
        
        if not record:
            raise HTTPException(status_code=404, detail="体重记录不存在")
        
        # 更新字段
        record.weight = weight_data.weight
        if weight_data.body_fat_percentage is not None:
            record.body_fat_percentage = weight_data.body_fat_percentage
        if weight_data.muscle_mass is not None:
            record.muscle_mass = weight_data.muscle_mass
        if weight_data.measured_at is not None:
            record.measured_at = weight_data.measured_at
        if weight_data.notes is not None:
            record.notes = weight_data.notes
        if weight_data.device_type is not None:
            record.device_type = weight_data.device_type
        
        # 重新计算BMI
        user_profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        bmi = calculate_bmi(user_profile.height if user_profile else None, weight_data.weight)
        record.bmi = bmi
        
        db.commit()
        db.refresh(record)
        
        # 更新用户资料中的体重
        if user_profile:
            user_profile.weight = weight_data.weight
            user_profile.bmi = bmi
            user_profile.updated_at = datetime.utcnow()
            db.commit()
            cache_service.clear_user_cache(current_user.id)
        
        return BaseResponse(
            success=True,
            message="体重记录更新成功",
            data={
                "id": record.id,
                "user_id": record.user_id,
                "weight": float(record.weight),
                "body_fat_percentage": float(record.body_fat_percentage) if record.body_fat_percentage else None,
                "muscle_mass": float(record.muscle_mass) if record.muscle_mass else None,
                "bmi": float(record.bmi) if record.bmi else None,
                "measured_at": record.measured_at.isoformat(),
                "notes": record.notes,
                "device_type": record.device_type,
                "created_at": record.created_at.isoformat()
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新体重记录")


@router.delete("/weight-records/{record_id}", response_model=BaseResponse)
async def delete_weight_record(
    record_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除体重记录"""
    try:
        record = db.query(WeightRecord).filter(
            WeightRecord.id == record_id,
            WeightRecord.user_id == current_user.id
        ).first()
        
        if not record:
            raise HTTPException(status_code=404, detail="体重记录不存在")
        
        db.delete(record)
        db.commit()
        
        return BaseResponse(
            success=True,
            message="体重记录删除成功"
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "删除体重记录")


# 用户引导相关端点
@router.get("/onboarding/status", response_model=BaseResponse)
async def get_onboarding_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户引导状态"""
    try:
        logger.info(f"开始获取用户 {current_user.id} 的引导状态")
        
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if not profile:
            logger.info(f"用户 {current_user.id} 没有资料，创建新的资料")
            profile = UserProfile(
                user_id=current_user.id,
                activity_level=2
            )
            db.add(profile)
            db.commit()
            db.refresh(profile)
            logger.info(f"用户 {current_user.id} 的资料创建成功")
        
        data = {
            "onboarding_completed": profile.onboarding_completed or False,
            "current_step": profile.onboarding_step or 0,
            "total_steps": 6,
            "next_step": (profile.onboarding_step or 0) + 1 if not profile.onboarding_completed else 6,
        }
        
        logger.info(f"用户 {current_user.id} 的引导状态: {data}")
        
        return BaseResponse(
            success=True,
            message="获取引导状态成功",
            data=data
        )
    except Exception as e:
        raise handle_database_error(e, "获取引导状态")


@router.post("/onboarding/step", response_model=BaseResponse)
async def update_onboarding_step(
    step_data: OnboardingStepUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """更新用户引导步骤"""
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if not profile:
            profile = UserProfile(
                user_id=current_user.id,
                activity_level=2
            )
            db.add(profile)
        
        # 更新引导步骤
        profile.onboarding_step = step_data.step
    
        # 如果标记为完成，设置 onboarding_completed
        if step_data.completed:
            profile.onboarding_completed = True
        
        # 处理步骤数据，只更新存在的字段
        if step_data.data:
            for key, value in step_data.data.items():
                if hasattr(profile, key):
                    # 跳过引导元数据字段（已单独处理）
                    if key in ('onboarding_step', 'onboarding_completed'):
                        continue
                    else:
                        setattr(profile, key, value)
        
        profile.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(profile)
        
        # 清除缓存
        cache_service.clear_user_cache(current_user.id)
        
        return BaseResponse(
            success=True,
            message="引导步骤更新成功",
            data={
                "current_step": step_data.step,
                "completed": step_data.completed,
                "next_step": step_data.step + 1 if not step_data.completed else None
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "更新引导步骤")


@router.post("/onboarding/complete", response_model=BaseResponse)
async def complete_onboarding(
    onboarding_data: OnboardingDataRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """完成用户引导并批量保存数据 - 简化版本"""
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if not profile:
            profile = UserProfile(
                user_id=current_user.id,
                activity_level=2
            )
            db.add(profile)
        
        # 更新基本信息
        if onboarding_data.basic_info:
            for key, value in onboarding_data.basic_info.items():
                if hasattr(profile, key):
                    if key == 'birth_date' and isinstance(value, str):
                        profile.birth_date = datetime.strptime(value, "%Y-%m-%d").date()
                    else:
                        setattr(profile, key, value)
        
        # 更新身体数据
        if onboarding_data.physical_data:
            for key, value in onboarding_data.physical_data.items():
                if hasattr(profile, key):
                    setattr(profile, key, value)
        
        # 跳过不存在的字段
        if onboarding_data.dietary_preferences:
            logger.warning("跳过dietary_preferences字段，数据库中不存在")
        
        if onboarding_data.lifestyle_habits:
            for key, value in onboarding_data.lifestyle_habits.items():
                if hasattr(profile, key):
                    if key in ['meal_times', 'wake_up_time', 'sleep_time']:
                        logger.warning(f"跳过不存在的字段: {key}")
                        continue
                    else:
                        setattr(profile, key, value)
        
        # 计算BMI
        bmi = calculate_bmi(profile.height, profile.weight)
        if bmi:
            profile.bmi = bmi
        
        # 标记引导已完成
        profile.onboarding_completed = True
        profile.onboarding_step = 6
        
        profile.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(profile)
        
        # 创建健康目标
        health_goals_created = 0
        if onboarding_data.health_goals:
            for goal_data in onboarding_data.health_goals:
                health_goal = HealthGoal(
                    user_id=current_user.id,
                    goal_type=goal_data.get('goal_type', 1),
                    target_weight=goal_data.get('target_weight'),
                    target_date=datetime.strptime(goal_data['target_date'], "%Y-%m-%d").date() if goal_data.get('target_date') else None,
                    current_status=1
                )
                db.add(health_goal)
                health_goals_created += 1
        
        # 添加疾病信息
        diseases_added = 0
        if onboarding_data.medical_conditions:
            for condition in onboarding_data.medical_conditions:
                disease = Disease(
                    user_id=current_user.id,
                    disease_name=condition['disease_name'],
                    disease_code=condition.get('disease_code'),
                    severity_level=condition.get('severity_level', 1),
                    diagnosed_date=datetime.strptime(condition['diagnosed_date'], "%Y-%m-%d").date() if condition.get('diagnosed_date') else None,
                    notes=condition.get('notes')
                )
                db.add(disease)
                diseases_added += 1
        
        # 添加过敏信息
        allergies_added = 0
        if onboarding_data.allergies:
            for allergy_data in onboarding_data.allergies:
                allergy = Allergy(
                    user_id=current_user.id,
                    allergen_type=allergy_data.get('allergen_type', 1),
                    allergen_name=allergy_data['allergen_name'],
                    severity_level=allergy_data.get('severity_level', 1),
                    reaction_description=allergy_data.get('reaction_description')
                )
                db.add(allergy)
                allergies_added += 1
        
        db.commit()

        # 自动创建默认提醒模板（仅当用户尚无提醒时）
        reminders_created = 0
        try:
            from shared.services.reminder_service import create_default_reminders
            result = create_default_reminders(db, current_user.id)
            reminders_created = result["water"] + result["meal"]
            db.commit()
            logger.info(f"用户 {current_user.id} 引导完成后默认提醒模板创建: {result}")
        except Exception as e:
            logger.warning(f"用户 {current_user.id} 默认提醒模板创建失败 (非致命): {e}")

        # 清除缓存
        cache_service.clear_user_cache(current_user.id)

        return BaseResponse(
            success=True,
            message="用户引导完成成功",
            data={
                "profile_id": profile.id,
                "onboarding_completed": True,  # 返回默认值
                "bmi": float(profile.bmi) if profile.bmi else None,
                "health_goals_created": health_goals_created,
                "medical_conditions_added": diseases_added,
                "allergies_added": allergies_added,
                "reminders_created": reminders_created
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "完成用户引导")


@router.post("/constitution-quiz", response_model=BaseResponse)
async def submit_constitution_quiz(
    quiz_data: ConstitutionQuizRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """体质自测接口：接收9题问卷答案，返回推荐体质标签及饮食建议"""
    try:
        # 为每种体质累计得分
        scores: dict = {name: 0.0 for name in CONSTITUTION_TYPES}
        question_count_answered = {name: 0 for name in CONSTITUTION_TYPES}

        # 建立题目索引
        question_map = {q["id"]: q for q in QUIZ_QUESTIONS}

        for answer in quiz_data.answers:
            q = question_map.get(answer.question_id)
            if not q:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"无效的题目编号: {answer.question_id}"
                )

            # 将 1-5 分映射为 agree/neutral/disagree
            if answer.score >= 4:
                level = "agree"
            elif answer.score == 3:
                level = "neutral"
            else:
                level = "disagree"

            for ctype, score_map in q["constitution_scores"].items():
                if level in score_map:
                    scores[ctype] += score_map[level]
                    question_count_answered[ctype] += 1

        # 归一化：将每个体质的分数除以其相关题目数，得到平均分
        normalized = {}
        for ctype in CONSTITUTION_TYPES:
            count = question_count_answered[ctype]
            if count > 0:
                normalized[ctype] = scores[ctype] / count
            else:
                normalized[ctype] = 0.0

        # 找出最高分的体质
        max_score = max(normalized.values()) if normalized else 0
        recommended = max(normalized, key=normalized.get)

        # 计算置信度 (最高分与第二高分的差距)
        sorted_scores = sorted(normalized.items(), key=lambda x: x[1], reverse=True)
        if len(sorted_scores) >= 2 and sorted_scores[0][1] > 0:
            confidence = min(1.0, (sorted_scores[0][1] - sorted_scores[1][1]) / sorted_scores[0][1])
        else:
            confidence = 0.5

        # 如果最高分和最低分很接近，可能是平和质
        if max_score < 1.5:
            recommended = "平和质"
            confidence = 0.3

        # 构建所有体质得分详情
        all_scores_info = [
            {
                "name": ctype,
                "score": round(normalized[ctype], 1),
                "description": CONSTITUTION_TYPES[ctype],
            }
            for ctype, _ in sorted(normalized.items(), key=lambda x: x[1], reverse=True)
        ]

        # 自动更新用户体质标签
        try:
            profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
            if profile:
                profile.constitution_type = recommended
                profile.updated_at = datetime.utcnow()
                db.commit()
                cache_service.clear_user_cache(current_user.id)
                logger.info(f"用户 {current_user.id} 体质已更新为: {recommended}")
        except Exception as e:
            logger.warning(f"自动更新体质标签失败 (非致命): {e}")

        return BaseResponse(
            success=True,
            message=f"体质自测完成，推荐体质: {recommended}",
            data={
                "recommended_type": recommended,
                "confidence": round(confidence, 2),
                "all_scores": all_scores_info,
                "diet_advice": CONSTITUTION_DIET_ADVICE.get(recommended, CONSTITUTION_DIET_ADVICE["平和质"]),
                "characteristics": CONSTITUTION_TYPES.get(recommended, ""),
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "体质自测")


@router.post("/onboarding/reset", response_model=BaseResponse)
async def reset_onboarding(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """重置用户引导状态"""
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        
        if profile:
            profile.onboarding_completed = False
            profile.onboarding_step = 0
            profile.updated_at = datetime.utcnow()
            db.commit()
            
            # 清除缓存
            cache_service.clear_user_cache(current_user.id)
        
        return BaseResponse(
            success=True,
            message="引导状态重置成功",
            data={
                "onboarding_completed": False,
                "current_step": 0
            }
        )
    except Exception as e:
        db.rollback()
        raise handle_database_error(e, "重置引导状态") 