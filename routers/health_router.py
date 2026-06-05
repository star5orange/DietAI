from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import Optional, Dict, Any, List
from datetime import datetime, date, timedelta
import math
import logging

from shared.models.database import get_db
from shared.models.schemas import (
    BaseResponse, HealthAnalysisRequest, HealthAnalysisResponse,
    DateRangeParams
)
from shared.utils.auth import get_current_user
from shared.models.user_models import User, UserProfile, HealthGoal, WeightRecord
from shared.models.food_models import FoodRecord, DailyNutritionSummary
from shared.models.exercise_models import ExerciseRecord
from shared.models.water_models import WaterIntakeRecord
from shared.config.redis_config import cache_service

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/health", tags=["健康分析"])


@router.post("/analysis", response_model=BaseResponse)
async def health_analysis(
    analysis_request: HealthAnalysisRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """健康分析"""
    try:
        analysis_type = analysis_request.analysis_type
        
        if analysis_type == "bmr":
            result = await calculate_bmr(current_user.id, db)
        elif analysis_type == "tdee":
            result = await calculate_tdee(current_user.id, db)
        elif analysis_type == "nutrition_balance":
            result = await analyze_nutrition_balance(
                current_user.id, 
                analysis_request.date_range,
                db
            )
        elif analysis_type == "health_level":
            result = await calculate_health_score(
                current_user.id,
                analysis_request.date_range,
                db
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="不支持的分析类型"
            )
        
        return BaseResponse(
            success=True,
            message="健康分析完成",
            data={
                "analysis_type": analysis_type,
                "result": result,
                "timestamp": datetime.utcnow().isoformat()
            }
        )
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"健康分析失败: {str(e)}"
        )


@router.get("/bmr", response_model=BaseResponse)
async def get_bmr(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """计算基础代谢率(BMR)"""
    try:
        # 先尝试从缓存获取
        cached_bmr = cache_service.get_health_score(current_user.id)
        if cached_bmr and "bmr" in cached_bmr:
            return BaseResponse(
                success=True,
                message="获取BMR成功",
                data=cached_bmr["bmr"]
            )
        
        result = await calculate_bmr(current_user.id, db)
        
        return BaseResponse(
            success=True,
            message="BMR计算完成",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"BMR计算失败: {str(e)}"
        )


@router.get("/tdee", response_model=BaseResponse)
async def get_tdee(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """计算每日总能量消耗(TDEE)"""
    try:
        result = await calculate_tdee(current_user.id, db)
        
        return BaseResponse(
            success=True,
            message="TDEE计算完成",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"TDEE计算失败: {str(e)}"
        )


@router.get("/nutrition-balance", response_model=BaseResponse)
async def get_nutrition_balance(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    start_date: Optional[date] = Query(None, description="开始日期"),
    end_date: Optional[date] = Query(None, description="结束日期")
):
    """营养平衡分析"""
    try:
        date_range = {}
        if start_date:
            date_range["start_date"] = start_date.isoformat()
        if end_date:
            date_range["end_date"] = end_date.isoformat()
        
        result = await analyze_nutrition_balance(current_user.id, date_range, db)
        
        return BaseResponse(
            success=True,
            message="营养平衡分析完成",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"营养平衡分析失败: {str(e)}"
        )


@router.get("/health-score", response_model=BaseResponse)
async def get_health_score(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    start_date: Optional[date] = Query(None, description="开始日期"),
    end_date: Optional[date] = Query(None, description="结束日期")
):
    """健康评分"""
    try:
        date_range = {}
        if start_date:
            date_range["start_date"] = start_date.isoformat()
        if end_date:
            date_range["end_date"] = end_date.isoformat()
        
        result = await calculate_health_score(current_user.id, date_range, db)
        
        return BaseResponse(
            success=True,
            message="健康评分完成",
            data=result
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"健康评分失败: {str(e)}"
        )


@router.get("/weight-trend", response_model=BaseResponse)
async def get_weight_trend(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    days: int = Query(30, description="天数", ge=7, le=365)
):
    """体重趋势分析"""
    try:
        end_date = datetime.combine(date.today(), datetime.max.time())
        start_date = datetime.combine(date.today() - timedelta(days=days), datetime.min.time())
        
        weight_records = db.query(WeightRecord).filter(
            WeightRecord.user_id == current_user.id,
            WeightRecord.measured_at >= start_date,
            WeightRecord.measured_at <= end_date
        ).order_by(WeightRecord.measured_at).all()
        
        if not weight_records:
            return BaseResponse(
                success=True,
                message="暂无体重数据",
                data={
                    "current_weight": 0,
                    "previous_weight": None,
                    "weight_change": 0,
                    "change_percentage": 0,
                    "trend_direction": "stable",
                    "days_tracked": 0,
                    "average_weekly_change": 0
                }
            )
        
        first_weight = float(weight_records[0].weight)
        last_weight = float(weight_records[-1].weight)
        previous_weight = float(weight_records[-2].weight) if len(weight_records) > 1 else None
        weight_change = last_weight - first_weight
        change_percentage = (weight_change / first_weight) * 100 if first_weight != 0 else 0
        
        if abs(change_percentage) < 2:
            trend_direction = "stable"
        elif change_percentage > 0:
            trend_direction = "up"
        else:
            trend_direction = "down"
        
        days_tracked = (weight_records[-1].measured_at.date() - weight_records[0].measured_at.date()).days
        weeks = max(days_tracked / 7, 1)
        average_weekly_change = weight_change / weeks
        
        return BaseResponse(
            success=True,
            message="体重趋势分析完成",
            data={
                "current_weight": round(last_weight, 2),
                "previous_weight": round(previous_weight, 2) if previous_weight is not None else None,
                "weight_change": round(weight_change, 2),
                "change_percentage": round(change_percentage, 2),
                "trend_direction": trend_direction,
                "days_tracked": days_tracked,
                "average_weekly_change": round(average_weekly_change, 2)
            }
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"体重趋势分析失败: {str(e)}"
        )


# 辅助函数
async def calculate_bmr(user_id: int, db: Session) -> Dict[str, Any]:
    """计算基础代谢率"""
    # 获取用户资料
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile or not profile.weight or not profile.height or not profile.gender or not profile.birth_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="缺少必要的用户资料信息（体重、身高、性别、出生日期）"
        )
    
    # 计算年龄
    today = date.today()
    age = today.year - profile.birth_date.year - ((today.month, today.day) < (profile.birth_date.month, profile.birth_date.day))
    
    weight = float(profile.weight)
    height = float(profile.height)
    
    # 使用Mifflin-St Jeor方程计算BMR
    if profile.gender == 1:  # 男性
        bmr = 10 * weight + 6.25 * height - 5 * age + 5
    else:  # 女性
        bmr = 10 * weight + 6.25 * height - 5 * age - 161
    
    return {
        "bmr": round(bmr, 1),
        "unit": "kcal/day",
        "method": "Mifflin-St Jeor方程",
        "user_data": {
            "weight": weight,
            "height": height,
            "age": age,
            "gender": "男" if profile.gender == 1 else "女"
        },
        "description": "基础代谢率是维持基本生理功能所需的最少能量"
    }


async def calculate_tdee(user_id: int, db: Session) -> Dict[str, Any]:
    """计算每日总能量消耗"""
    # 先计算BMR
    bmr_result = await calculate_bmr(user_id, db)
    bmr = bmr_result["bmr"]
    
    # 获取活动水平
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    activity_level = profile.activity_level if profile else 2
    
    # 活动系数
    activity_factors = {
        1: 1.2,   # 久坐
        2: 1.375, # 轻度活动
        3: 1.55,  # 中度活动
        4: 1.725, # 重度活动
        5: 1.9    # 超重度活动
    }
    
    activity_descriptions = {
        1: "久坐（很少或无运动）",
        2: "轻度活动（轻松运动/每周1-3天）",
        3: "中度活动（中等运动/每周3-5天）",
        4: "重度活动（剧烈运动/每周6-7天）",
        5: "超重度活动（极剧烈运动/体力劳动）"
    }
    
    factor = activity_factors.get(activity_level, 1.375)
    tdee = bmr * factor
    
    return {
        "tdee": round(tdee, 1),
        "bmr": bmr,
        "activity_level": activity_level,
        "activity_factor": factor,
        "activity_description": activity_descriptions.get(activity_level, "轻度活动"),
        "unit": "kcal/day",
        "description": "每日总能量消耗包括基础代谢和活动消耗"
    }


async def analyze_nutrition_balance(user_id: int, date_range: Dict[str, str], db: Session) -> Dict[str, Any]:
    """营养平衡分析"""
    # 设置日期范围
    if date_range.get("end_date"):
        end_date = datetime.fromisoformat(date_range["end_date"]).date()
    else:
        end_date = date.today()
    
    if date_range.get("start_date"):
        start_date = datetime.fromisoformat(date_range["start_date"]).date()
    else:
        start_date = end_date - timedelta(days=7)
    
    # 获取营养汇总数据
    summaries = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date >= start_date,
        DailyNutritionSummary.summary_date <= end_date
    ).all()
    
    if not summaries:
        return {
            "period": {
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat()
            },
            "analysis": "暂无营养数据",
            "recommendations": ["请记录饮食以获得营养分析"]
        }
    
    # 计算平均值
    total_days = len(summaries)
    avg_calories = sum(float(s.total_calories) for s in summaries) / total_days
    avg_protein = sum(float(s.total_protein) for s in summaries) / total_days
    avg_fat = sum(float(s.total_fat) for s in summaries) / total_days
    avg_carbs = sum(float(s.total_carbohydrates) for s in summaries) / total_days
    avg_fiber = sum(float(s.total_fiber) for s in summaries) / total_days
    avg_sodium = sum(float(s.total_sodium) for s in summaries) / total_days
    
    # 计算TDEE作为参考
    tdee_result = await calculate_tdee(user_id, db)
    recommended_calories = tdee_result["tdee"]
    
    # 营养素比例分析
    protein_calories = avg_protein * 4
    fat_calories = avg_fat * 9
    carb_calories = avg_carbs * 4
    total_macro_calories = protein_calories + fat_calories + carb_calories
    
    if total_macro_calories > 0:
        protein_percentage = (protein_calories / total_macro_calories) * 100
        fat_percentage = (fat_calories / total_macro_calories) * 100
        carb_percentage = (carb_calories / total_macro_calories) * 100
    else:
        protein_percentage = fat_percentage = carb_percentage = 0
    
    # 生成建议
    recommendations = []
    
    # 热量分析
    calorie_ratio = avg_calories / recommended_calories
    if calorie_ratio < 0.8:
        recommendations.append("热量摄入偏低，建议适量增加")
    elif calorie_ratio > 1.2:
        recommendations.append("热量摄入偏高，建议适量减少")
    
    # 蛋白质分析
    if protein_percentage < 10:
        recommendations.append("蛋白质摄入不足，建议增加优质蛋白质")
    elif protein_percentage > 35:
        recommendations.append("蛋白质摄入过多，建议适量减少")
    
    # 脂肪分析
    if fat_percentage < 20:
        recommendations.append("脂肪摄入偏低，建议适量增加健康脂肪")
    elif fat_percentage > 35:
        recommendations.append("脂肪摄入过多，建议减少饱和脂肪")
    
    # 碳水化合物分析
    if carb_percentage < 45:
        recommendations.append("碳水化合物摄入偏低，建议增加复合碳水")
    elif carb_percentage > 65:
        recommendations.append("碳水化合物摄入过多，建议适量减少")
    
    # 膳食纤维分析
    if avg_fiber < 25:
        recommendations.append("膳食纤维摄入不足，建议多吃蔬菜水果")
    
    # 钠摄入分析
    if avg_sodium > 2300:
        recommendations.append("钠摄入过多，建议减少盐分摄入")
    
    if not recommendations:
        recommendations.append("营养平衡良好，请继续保持")
    
    return {
        "period": {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "days": total_days
        },
        "averages": {
            "calories": round(avg_calories, 1),
            "protein": round(avg_protein, 1),
            "fat": round(avg_fat, 1),
            "carbohydrates": round(avg_carbs, 1),
            "fiber": round(avg_fiber, 1),
            "sodium": round(avg_sodium, 1)
        },
        "percentages": {
            "protein": round(protein_percentage, 1),
            "fat": round(fat_percentage, 1),
            "carbohydrates": round(carb_percentage, 1)
        },
        "reference": {
            "recommended_calories": round(recommended_calories, 1),
            "calorie_ratio": round(calorie_ratio, 2)
        },
        "recommendations": recommendations
    }


async def calculate_health_score(user_id: int, date_range: Dict[str, str], db: Session) -> Dict[str, Any]:
    """计算健康评分"""
    # 设置日期范围
    if date_range.get("end_date"):
        end_date = datetime.fromisoformat(date_range["end_date"]).date()
    else:
        end_date = date.today()
    
    if date_range.get("start_date"):
        start_date = datetime.fromisoformat(date_range["start_date"]).date()
    else:
        start_date = end_date - timedelta(days=7)
    
    score_components = {}
    total_score = 0
    max_score = 0
    
    # 营养平衡评分 (40分)
    nutrition_analysis = await analyze_nutrition_balance(user_id, date_range, db)
    if "averages" in nutrition_analysis:
        nutrition_score = calculate_nutrition_score(nutrition_analysis)
        score_components["nutrition"] = {
            "score": nutrition_score,
            "max_score": 40,
            "description": "营养平衡"
        }
        total_score += nutrition_score
    max_score += 40
    
    # BMI评分 (20分)
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if profile and profile.bmi:
        bmi_score = calculate_bmi_score(float(profile.bmi))
        score_components["bmi"] = {
            "score": bmi_score,
            "max_score": 20,
            "description": "体重指数"
        }
        total_score += bmi_score
    max_score += 20
    
    # 饮食规律性评分 (20分)
    summaries = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == user_id,
        DailyNutritionSummary.summary_date >= start_date,
        DailyNutritionSummary.summary_date <= end_date
    ).all()
    
    if summaries:
        regularity_score = calculate_diet_regularity_score(summaries)
        score_components["regularity"] = {
            "score": regularity_score,
            "max_score": 20,
            "description": "饮食规律性"
        }
        total_score += regularity_score
    max_score += 20
    
    # 水分摄入评分 (10分)
    if summaries:
        avg_water = sum(float(s.water_intake) for s in summaries) / len(summaries)
        water_score = calculate_water_score(avg_water)
        score_components["water"] = {
            "score": water_score,
            "max_score": 10,
            "description": "水分摄入"
        }
        total_score += water_score
    max_score += 10
    
    # 运动评分 (10分)
    if summaries:
        avg_exercise = sum(float(s.exercise_calories) for s in summaries) / len(summaries)
        exercise_score = calculate_exercise_score(avg_exercise)
        score_components["exercise"] = {
            "score": exercise_score,
            "max_score": 10,
            "description": "运动消耗"
        }
        total_score += exercise_score
    max_score += 10
    
    # 计算总分百分比
    final_score = (total_score / max_score * 100) if max_score > 0 else 0
    
    # 生成等级和建议
    if final_score >= 90:
        grade = "优秀"
        suggestions = ["继续保持良好的饮食习惯"]
    elif final_score >= 80:
        grade = "良好"
        suggestions = ["整体表现不错，可以在薄弱环节进一步改善"]
    elif final_score >= 70:
        grade = "一般"
        suggestions = ["需要关注营养平衡和饮食规律"]
    elif final_score >= 60:
        grade = "较差"
        suggestions = ["建议调整饮食结构，增加运动"]
    else:
        grade = "很差"
        suggestions = ["强烈建议咨询营养师，制定健康饮食计划"]
    
    return {
        "total_score": round(final_score, 1),
        "grade": grade,
        "components": score_components,
        "suggestions": suggestions,
        "period": {
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat()
        }
    }


def calculate_nutrition_score(nutrition_analysis: Dict[str, Any]) -> float:
    """计算营养评分"""
    score = 0
    
    # 热量平衡 (15分)
    calorie_ratio = nutrition_analysis["reference"]["calorie_ratio"]
    if 0.9 <= calorie_ratio <= 1.1:
        score += 15
    elif 0.8 <= calorie_ratio <= 1.2:
        score += 10
    elif 0.7 <= calorie_ratio <= 1.3:
        score += 5
    
    # 蛋白质比例 (10分)
    protein_pct = nutrition_analysis["percentages"]["protein"]
    if 15 <= protein_pct <= 25:
        score += 10
    elif 10 <= protein_pct <= 30:
        score += 7
    elif 8 <= protein_pct <= 35:
        score += 4
    
    # 脂肪比例 (10分)
    fat_pct = nutrition_analysis["percentages"]["fat"]
    if 25 <= fat_pct <= 30:
        score += 10
    elif 20 <= fat_pct <= 35:
        score += 7
    elif 15 <= fat_pct <= 40:
        score += 4
    
    # 膳食纤维 (5分)
    fiber = nutrition_analysis["averages"]["fiber"]
    if fiber >= 25:
        score += 5
    elif fiber >= 20:
        score += 3
    elif fiber >= 15:
        score += 1
    
    return score


def calculate_bmi_score(bmi: float) -> float:
    """计算BMI评分"""
    if 18.5 <= bmi <= 24.9:
        return 20
    elif 17.0 <= bmi <= 27.9:
        return 15
    elif 16.0 <= bmi <= 29.9:
        return 10
    elif 15.0 <= bmi <= 34.9:
        return 5
    else:
        return 0


def calculate_diet_regularity_score(summaries) -> float:
    """计算饮食规律性评分"""
    if not summaries:
        return 0
    
    # 计算每日餐次的标准差
    meal_counts = [s.meal_count for s in summaries]
    avg_meals = sum(meal_counts) / len(meal_counts)
    
    if avg_meals >= 3:
        base_score = 15
    elif avg_meals >= 2:
        base_score = 10
    else:
        base_score = 5
    
    # 规律性加分
    if len(set(meal_counts)) <= 2:  # 餐次变化不大
        base_score += 5
    
    return min(base_score, 20)


def calculate_water_score(water_intake: float) -> float:
    """计算水分摄入评分"""
    if water_intake >= 2.0:
        return 10
    elif water_intake >= 1.5:
        return 7
    elif water_intake >= 1.0:
        return 4
    elif water_intake >= 0.5:
        return 2
    else:
        return 0


def calculate_exercise_score(exercise_calories: float) -> float:
    """计算运动评分"""
    if exercise_calories >= 300:
        return 10
    elif exercise_calories >= 200:
        return 7
    elif exercise_calories >= 100:
        return 4
    elif exercise_calories >= 50:
        return 2
    else:
        return 0


# ==================== B2-6: 人群维度统计接口 ====================


@router.get("/statistics", response_model=BaseResponse)
async def crowd_statistics(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    crowd_tag: Optional[str] = Query(None, description="人群标签筛选 (减脂/健身/普通日常)"),
    days: int = Query(30, ge=7, le=365, description="统计天数"),
):
    """人群维度统计接口：按人群标签返回差异化统计数据。

    如不指定 crowd_tag，使用当前用户的人群标签。
    返回该人群的平均营养摄入、达标率、运动消耗、水分摄入等统计。
    """
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        tag = crowd_tag or (profile.crowd_tag if profile else None) or "普通日常"

        end_date = date.today()
        start_date = end_date - timedelta(days=days)

        # 查询该人群标签的所有用户
        tagged_user_ids = [
            r[0] for r in db.query(UserProfile.user_id).filter(
                UserProfile.crowd_tag == tag
            ).all()
        ]

        if not tagged_user_ids:
            return BaseResponse(
                success=True,
                message=f"暂无【{tag}】人群的统计数据",
                data={"crowd_tag": tag, "user_count": 0, "days": days}
            )

        # 汇总该人群的营养数据
        summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id.in_(tagged_user_ids),
            DailyNutritionSummary.summary_date >= start_date,
            DailyNutritionSummary.summary_date <= end_date
        ).all()

        user_count = len(set(s.user_id for s in summaries))

        if not summaries:
            return BaseResponse(
                success=True,
                message=f"【{tag}】人群暂无营养数据",
                data={"crowd_tag": tag, "user_count": user_count, "days": days}
            )

        # 计算人均日平均值
        total_days = len(set(s.summary_date for s in summaries))
        actual_days = max(total_days, 1)

        avg_calories = sum(float(s.total_calories or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_protein = sum(float(s.total_protein or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_fat = sum(float(s.total_fat or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_carbs = sum(float(s.total_carbohydrates or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_fiber = sum(float(s.total_fiber or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_water = sum(float(s.water_intake or 0) for s in summaries) / len(summaries) if summaries else 0
        avg_exercise = sum(float(s.exercise_calories or 0) for s in summaries) / len(summaries) if summaries else 0

        # 计算达标率（基于人群标签的目标）
        from shared.utils.nutrition_calc import calculate_daily_targets, CrowdTag

        # 达标率估算：取代表性TDEE 2200
        targets = calculate_daily_targets(2200, 3, tag)  # 维持目标+人群标签
        calorie_target = targets["calories"]
        protein_target = targets["protein"]

        calorie_compliance = len([
            s for s in summaries if s.total_calories and abs(float(s.total_calories) - calorie_target) / calorie_target <= 0.15
        ]) / len(summaries) * 100 if summaries else 0

        protein_compliance = len([
            s for s in summaries if s.total_protein and float(s.total_protein) >= protein_target * 0.8
        ]) / len(summaries) * 100 if summaries else 0

        return BaseResponse(
            success=True,
            message=f"【{tag}】人群统计（近{days}天）",
            data={
                "crowd_tag": tag,
                "crowd_description": targets.get("crowd_description", ""),
                "crowd_recommendations": targets.get("crowd_recommendations", []),
                "user_count": user_count,
                "days": actual_days,
                "daily_targets": targets,
                "averages": {
                    "calories": round(avg_calories, 1),
                    "protein": round(avg_protein, 1),
                    "fat": round(avg_fat, 1),
                    "carbohydrates": round(avg_carbs, 1),
                    "fiber": round(avg_fiber, 1),
                    "water_intake_l": round(avg_water, 1),
                    "exercise_calories": round(avg_exercise, 1),
                },
                "compliance": {
                    "calorie_compliance_pct": round(calorie_compliance, 1),
                    "protein_compliance_pct": round(protein_compliance, 1),
                },
            }
        )
    except Exception as e:
        logger.error(f"人群统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"人群统计失败: {str(e)}"
        )


@router.get("/meal-regularity", response_model=BaseResponse)
async def meal_regularity(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    days: int = Query(14, ge=7, le=90, description="分析天数"),
):
    """三餐规律度分析：分析用户在一定时间内各餐的规律性。

    对早餐/午餐/晚餐分别计算：
    - 记录天数和缺餐天数
    - 用餐时间的标准差
    - 规律度评分 (0-100)
    """
    try:
        end_date = date.today()
        start_date = end_date - timedelta(days=days)

        records = db.query(FoodRecord).filter(
            FoodRecord.user_id == current_user.id,
            FoodRecord.record_date >= start_date,
            FoodRecord.record_date <= end_date
        ).all()

        # 按餐次分组
        meal_groups = {1: [], 2: [], 3: []}  # breakfast, lunch, dinner
        meal_names = {1: "早餐", 2: "午餐", 3: "晚餐"}

        for r in records:
            if r.meal_type in meal_groups:
                meal_groups[r.meal_type].append(r)

        total_days = (end_date - start_date).days + 1

        meal_details = {}
        overall_scores = []

        for meal_type, meal_records in meal_groups.items():
            # 记录天数
            recorded_dates = set(r.record_date for r in meal_records)
            recorded_days = len(recorded_dates)
            missed_days = total_days - recorded_days

            # 用餐频率评分
            freq_rate = recorded_days / total_days
            freq_score = min(100, freq_rate * 100)

            # 时间规律性：提取记录的小时和分钟，计算时间方差
            time_variance = 0
            if len(meal_records) >= 3:
                times = [r.created_at.hour * 60 + r.created_at.minute for r in meal_records]
                avg_time = sum(times) / len(times)
                variance = sum((t - avg_time) ** 2 for t in times) / len(times)
                time_variance = round(variance, 0)
                # 方差越小越规律，方差>3600(约1小时标准差)为不规律
                if variance <= 900:  # 30min std
                    time_score = 100
                elif variance <= 3600:  # 1h std
                    time_score = 80
                elif variance <= 8100:  # 1.5h std
                    time_score = 60
                elif variance <= 14400:  # 2h std
                    time_score = 40
                else:
                    time_score = 20
            else:
                time_score = 50 if len(meal_records) > 0 else 0

            # 综合评分：频率60% + 时间规律40%
            combined_score = round(freq_score * 0.6 + time_score * 0.4)

            # 判断评级
            if combined_score >= 90:
                grade = "非常规律"
            elif combined_score >= 75:
                grade = "较规律"
            elif combined_score >= 60:
                grade = "一般"
            elif combined_score >= 40:
                grade = "不够规律"
            else:
                grade = "不规律"

            meal_details[meal_type] = {
                "meal_type": meal_type,
                "meal_name": meal_names[meal_type],
                "recorded_days": recorded_days,
                "missed_days": missed_days,
                "completion_rate": round(freq_rate * 100, 1),
                "time_variance_minutes_sq": time_variance,
                "regularity_score": combined_score,
                "grade": grade,
            }
            overall_scores.append(combined_score)

        # 整体规律度
        overall_score = round(sum(overall_scores) / len(overall_scores)) if overall_scores else 0
        if overall_score >= 90:
            overall_grade = "非常规律"
        elif overall_score >= 75:
            overall_grade = "较规律"
        elif overall_score >= 60:
            overall_grade = "一般"
        elif overall_score >= 40:
            overall_grade = "不够规律"
        else:
            overall_grade = "不规律"

        return BaseResponse(
            success=True,
            message=f"三餐规律度分析完成，整体评级: {overall_grade}",
            data={
                "overall_score": overall_score,
                "overall_grade": overall_grade,
                "days_analyzed": total_days,
                "meals": meal_details,
                "suggestions": _get_regularity_suggestions(overall_score, meal_details),
            }
        )
    except Exception as e:
        logger.error(f"三餐规律度分析失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"三餐规律度分析失败: {str(e)}"
        )


def _get_regularity_suggestions(overall_score: float, meal_details: dict) -> list:
    """根据规律度评分生成建议"""
    suggestions = []
    if overall_score < 60:
        suggestions.append("建议设定固定的用餐时间，逐步养成规律饮食的习惯")
        suggestions.append("可以使用 APP 的提醒功能，设置每餐提醒")
    for detail in meal_details.values():
        if detail["completion_rate"] < 60:
            suggestions.append(f"{detail['meal_name']}缺餐较多，建议按时进食")
    if not suggestions:
        suggestions.append("三餐规律度良好，请继续保持")
    return suggestions


@router.get("/habit-streak", response_model=BaseResponse)
async def habit_streak(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """习惯连续天数统计：返回饮食记录、喝水、运动的连续打卡天数。

    统计：
    - 饮食记录连续天数（有食物记录的天数）
    - 喝水达标连续天数（饮水量>=目标量的天数）
    - 运动连续天数（有运动记录的天数）
    - 综合连续天数（三项都达标的天数）
    """
    try:
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        water_goal_ml = profile.daily_water_goal if profile else 2000
        water_goal_l = water_goal_ml / 1000.0

        today = date.today()

        def calc_streak(check_func, max_days=365):
            """计算从今天往前数的连续天数"""
            streak = 0
            check_date = today
            for _ in range(max_days):
                if check_func(check_date):
                    streak += 1
                    check_date -= timedelta(days=1)
                else:
                    # 今天还没结束，跳过今天
                    if streak == 0 and check_date == today:
                        check_date -= timedelta(days=1)
                        continue
                    break
            return streak

        # 饮食记录连续天数
        def has_food_record(d):
            return db.query(FoodRecord).filter(
                FoodRecord.user_id == current_user.id,
                FoodRecord.record_date == d
            ).first() is not None

        # 喝水达标连续天数
        def has_water_goal(d):
            summary = db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == current_user.id,
                DailyNutritionSummary.summary_date == d
            ).first()
            if summary and summary.water_intake:
                return float(summary.water_intake) >= water_goal_l
            # 也检查直接的水记录
            water_records = db.query(WaterIntakeRecord).filter(
                WaterIntakeRecord.user_id == current_user.id,
                func.date(WaterIntakeRecord.record_time) == d
            ).all()
            total_ml = sum(float(r.amount_ml) for r in water_records)
            return total_ml >= water_goal_ml

        # 运动连续天数
        def has_exercise_record(d):
            return db.query(ExerciseRecord).filter(
                ExerciseRecord.user_id == current_user.id,
                ExerciseRecord.record_date == d
            ).first() is not None

        food_streak = calc_streak(has_food_record)
        water_streak = calc_streak(has_water_goal)
        exercise_streak = calc_streak(has_exercise_record)

        # 综合连续天数（三项都达标）
        def all_three(d):
            return has_food_record(d) and has_water_goal(d) and has_exercise_record(d)

        combined_streak = calc_streak(all_three)

        # 计算最长连续纪录（近365天）
        def calc_longest_streak(check_func, max_days=365):
            longest = 0
            current = 0
            check_date = today - timedelta(days=max_days - 1)
            for _ in range(max_days):
                if check_func(check_date):
                    current += 1
                    longest = max(longest, current)
                else:
                    current = 0
                check_date += timedelta(days=1)
            return longest

        longest_food = calc_longest_streak(has_food_record)
        longest_water = calc_longest_streak(has_water_goal)
        longest_exercise = calc_longest_streak(has_exercise_record)

        # 评级
        def streak_grade(s):
            if s >= 30: return "金牌习惯"
            if s >= 14: return "银牌习惯"
            if s >= 7: return "铜牌习惯"
            if s >= 3: return "养成中"
            return "刚开始"

        return BaseResponse(
            success=True,
            message="习惯连续天数统计完成",
            data={
                "current_streaks": {
                    "food_record": {"days": food_streak, "grade": streak_grade(food_streak)},
                    "water_goal": {"days": water_streak, "grade": streak_grade(water_streak)},
                    "exercise": {"days": exercise_streak, "grade": streak_grade(exercise_streak)},
                    "combined": {"days": combined_streak, "grade": streak_grade(combined_streak)},
                },
                "longest_streaks": {
                    "food_record": longest_food,
                    "water_goal": longest_water,
                    "exercise": longest_exercise,
                },
                "water_goal_ml": water_goal_ml,
            }
        )
    except Exception as e:
        logger.error(f"习惯连续天数统计失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"习惯连续天数统计失败: {str(e)}"
        )


# ==================== B3-4: 周度摘要接口 ====================


@router.get("/weekly-summary", response_model=BaseResponse)
async def get_weekly_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    target_date: Optional[date] = Query(None, description="目标日期，默认当天"),
):
    """周度摘要接口：获取最近 7 天的完整营养健康报告。

    返回数据包括：
    - 每日营养摄入明细（热量/蛋白/脂肪/碳水/纤维/运动/饮水）
    - 7 天平均值
    - 与上周的趋势对比（上升/下降/持平 + 百分比变化）
    - 目标完成率（基于用户健康目标或人群标签目标）
    - 体重变化
    - AI 风格文字摘要
    """
    try:
        target = target_date or date.today()
        # 本周：包含 target_date 的最近 7 天
        week_end = target
        week_start = target - timedelta(days=6)
        # 上周：前面 7 天
        prev_week_end = week_start - timedelta(days=1)
        prev_week_start = prev_week_end - timedelta(days=6)

        # --- 1. 查询本周每日营养汇总 ---
        summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == current_user.id,
            DailyNutritionSummary.summary_date >= week_start,
            DailyNutritionSummary.summary_date <= week_end
        ).order_by(DailyNutritionSummary.summary_date).all()

        # 构建按日期索引
        summary_map = {s.summary_date: s for s in summaries}

        # --- 2. 查询上周汇总 ---
        prev_summaries = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == current_user.id,
            DailyNutritionSummary.summary_date >= prev_week_start,
            DailyNutritionSummary.summary_date <= prev_week_end
        ).all()

        # --- 3. 查询体重记录（本周每天取最新一条） ---
        weight_records = db.query(WeightRecord).filter(
            WeightRecord.user_id == current_user.id,
            func.date(WeightRecord.measured_at) >= week_start,
            func.date(WeightRecord.measured_at) <= week_end
        ).order_by(WeightRecord.measured_at.desc()).all()

        # 按日期分组取最新
        weight_map = {}
        for wr in weight_records:
            d = wr.measured_at.date() if isinstance(wr.measured_at, datetime) else (
                wr.measured_at if isinstance(wr.measured_at, date) else wr.measured_at
            )
            if d not in weight_map:
                weight_map[d] = float(wr.weight)

        # --- 4. 构建每日明细 ---
        daily_details = []
        fields = ["total_calories", "total_protein", "total_fat", "total_carbohydrates",
                   "total_fiber", "exercise_calories", "water_intake"]
        field_labels = {
            "total_calories": "热量(kcal)", "total_protein": "蛋白质(g)",
            "total_fat": "脂肪(g)", "total_carbohydrates": "碳水化合物(g)",
            "total_fiber": "纤维(g)", "exercise_calories": "运动消耗(kcal)",
            "water_intake": "饮水量(L)",
        }

        all_null = True
        week_totals = {f: 0.0 for f in fields}
        days_with_data = 0

        current = week_start
        while current <= week_end:
            s = summary_map.get(current)
            day_data = {"date": current.isoformat()}
            for f in fields:
                if s and getattr(s, f) is not None:
                    val = float(getattr(s, f))
                    day_data[f] = round(val, 2)
                    week_totals[f] += val
                    all_null = False
                else:
                    day_data[f] = 0.0

            day_data["weight"] = round(weight_map.get(current, 0), 2) if current in weight_map else None

            if s:
                days_with_data += 1

            daily_details.append(day_data)
            current += timedelta(days=1)

        # --- 5. 计算本周平均值 ---
        divisor = max(days_with_data, 1)
        week_averages = {
            f: round(week_totals[f] / divisor, 1) for f in fields
        }

        # --- 6. 计算上周平均值 ---
        prev_week_avgs = {}
        if prev_summaries:
            prev_count = len(prev_summaries)
            for f in fields:
                total = sum(float(getattr(s, f) or 0) for s in prev_summaries)
                prev_week_avgs[f] = round(total / prev_count, 1)
        else:
            prev_week_avgs = {f: 0.0 for f in fields}

        # --- 7. 趋势对比 ---
        trends = {}
        for f in fields:
            curr = week_averages[f]
            prev = prev_week_avgs[f]
            if prev > 0:
                change_pct = round((curr - prev) / prev * 100, 1)
            elif curr > 0:
                change_pct = 100.0
            else:
                change_pct = 0.0

            if abs(change_pct) < 3:
                direction = "持平"
            elif change_pct > 0:
                direction = "上升"
            else:
                direction = "下降"

            trends[f] = {
                "current_avg": curr,
                "previous_avg": prev,
                "change_pct": change_pct,
                "direction": direction,
                "label": field_labels.get(f, f),
            }

        # --- 8. 目标完成率 ---
        profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.id).first()
        crowd_tag = profile.crowd_tag if profile else None

        active_goal = db.query(HealthGoal).filter(
            HealthGoal.user_id == current_user.id,
            HealthGoal.current_status == 1
        ).first()
        goal_type = active_goal.goal_type if active_goal else 3

        from shared.utils.nutrition_calc import calculate_daily_targets
        tdEE = 2200  # 默认估值
        try:
            tdee_result = await calculate_tdee(current_user.id, db)
            tdEE = tdee_result["tdee"]
        except Exception:
            pass
        targets = calculate_daily_targets(tdEE, goal_type, crowd_tag)

        goal_completion = {
            "calories": {
                "target": targets["calories"],
                "actual": week_averages["total_calories"],
                "completion_pct": round(week_averages["total_calories"] / max(targets["calories"], 1) * 100, 1),
            },
            "protein": {
                "target": targets["protein"],
                "actual": week_averages["total_protein"],
                "completion_pct": round(week_averages["total_protein"] / max(targets["protein"], 1) * 100, 1),
            },
            "fat": {
                "target": targets["fat"],
                "actual": week_averages["total_fat"],
                "completion_pct": round(week_averages["total_fat"] / max(targets["fat"], 1) * 100, 1),
            },
            "carbohydrates": {
                "target": targets["carbs"],
                "actual": week_averages["total_carbohydrates"],
                "completion_pct": round(week_averages["total_carbohydrates"] / max(targets["carbs"], 1) * 100, 1),
            },
        }

        # --- 9. 体重变化 ---
        weight_dates = sorted(weight_map.keys())
        weight_change = None
        if len(weight_dates) >= 2:
            first_w = weight_map[weight_dates[0]]
            last_w = weight_map[weight_dates[-1]]
            weight_change = {
                "earliest_date": weight_dates[0].isoformat(),
                "earliest_weight": first_w,
                "latest_date": weight_dates[-1].isoformat(),
                "latest_weight": last_w,
                "change_kg": round(last_w - first_w, 2),
            }
        elif len(weight_dates) == 1:
            wd = weight_dates[0]
            weight_change = {
                "earliest_date": wd.isoformat(),
                "earliest_weight": weight_map[wd],
                "latest_date": wd.isoformat(),
                "latest_weight": weight_map[wd],
                "change_kg": 0,
            }

        # --- 10. 生成文字摘要 ---
        summary_text = _generate_weekly_summary_text(
            week_averages, trends, goal_completion, weight_change,
            crowd_tag, week_start, week_end
        )

        return BaseResponse(
            success=True,
            message="周度摘要生成成功",
            data={
                "period": {
                    "start_date": week_start.isoformat(),
                    "end_date": week_end.isoformat(),
                    "days_with_data": days_with_data,
                },
                "daily_details": daily_details,
                "averages": week_averages,
                "trends": trends,
                "goal_completion": goal_completion,
                "weight_change": weight_change,
                "summary_text": summary_text,
                "crowd_tag": crowd_tag or "未设置",
                "targets": targets,
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"周度摘要生成失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"周度摘要生成失败: {str(e)}"
        )


def _generate_weekly_summary_text(
    avgs: dict,
    trends: dict,
    goals: dict,
    weight_change: Optional[dict],
    crowd_tag: Optional[str],
    week_start: date,
    week_end: date,
) -> str:
    """生成 AI 风格的中文周度摘要文字"""
    parts = []
    period_str = f"{week_start.strftime('%m/%d')}-{week_end.strftime('%m/%d')}"

    # 热量
    cal_trend = trends.get("total_calories", {})
    cal_dir = cal_trend.get("direction", "持平")
    cal_pct = abs(cal_trend.get("change_pct", 0))
    if cal_dir == "上升":
        parts.append(f"本周日均热量摄入较上周上升 {cal_pct}%")
    elif cal_dir == "下降":
        parts.append(f"本周日均热量摄入较上周下降 {cal_pct}%")
    else:
        parts.append("本周日均热量摄入与上周基本持平")

    # 蛋白质
    protein_goal = goals.get("protein", {})
    protein_pct = protein_goal.get("completion_pct", 0)
    parts.append(f"蛋白质摄入达标率 {protein_pct}%")

    # 脂肪
    fat_goal = goals.get("fat", {})
    fat_pct = fat_goal.get("completion_pct", 0)
    if fat_pct > 120:
        parts.append("脂肪摄入偏高，建议控制油脂")
    elif fat_pct < 60:
        parts.append("脂肪摄入偏低，建议适量增加健康脂肪")

    # 饮水
    water_trend = trends.get("water_intake", {})
    water_avg = water_trend.get("current_avg", 0)
    if water_avg < 1.5:
        parts.append("饮水量不足，建议每日至少饮用 1.5L 水")
    elif water_avg < 2.0:
        parts.append("饮水量一般，建议增加至每日 2L")
    else:
        parts.append("饮水量充足，继续保持")

    # 运动
    ex_trend = trends.get("exercise_calories", {})
    ex_avg = ex_trend.get("current_avg", 0)
    if ex_avg < 100:
        parts.append("运动消耗偏低，建议每周增加运动量")
    elif ex_avg > 300:
        parts.append("运动表现优秀")

    # 体重
    if weight_change and weight_change.get("change_kg") is not None:
        change_kg = weight_change["change_kg"]
        if abs(change_kg) > 0.5:
            direction = "下降" if change_kg < 0 else "上升"
            parts.append(f"体重较上周{direction} {abs(change_kg):.1f}kg")

    # 人群标签总结
    if crowd_tag == "减脂":
        parts.append("减脂期间建议继续保持热量缺口，优先选择高蛋白低碳水食物")
    elif crowd_tag == "健身":
        parts.append("健身期间注意训练前后营养补充，保证蛋白质摄入充足")

    return f"【{period_str} 周报】" + "；".join(parts) + "。"