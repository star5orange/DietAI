"""家庭健康看板路由 - Milestone 4 家庭健康管理"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from typing import List, Optional
from datetime import datetime, date, timedelta
import logging
import traceback

from shared.models.database import get_db
from shared.models.schemas import BaseResponse
from shared.utils.auth import get_current_user
from shared.models.user_models import User, UserProfile, WeightRecord, HealthGoal
from shared.models.food_models import FoodRecord, DailyNutritionSummary
from shared.models.water_models import WaterIntakeRecord
from shared.models.social_models import UserRelationship
from shared.models.pet_models import VirtualPetState, PetProfile
from shared.models.exercise_models import ExerciseRecord

router = APIRouter(prefix="/family", tags=["家庭健康"])
logger = logging.getLogger(__name__)


# ============================================================
# 家庭健康看板
# ============================================================

@router.get("/dashboard", response_model=BaseResponse)
async def get_family_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取家庭健康看板（聚合所有家人的健康摘要）"""
    try:
        # 查询所有家人关系
        family_relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).all()

        family_members = []
        for rel in family_relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            member_data = await _get_member_health_summary(db, other_id, current_user.id)
            family_members.append(member_data)

        return BaseResponse(
            success=True,
            message="获取家庭健康看板成功",
            data={"family_members": family_members}
        )
    except Exception as e:
        logger.error(f"获取家庭健康看板失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取家庭健康看板失败"
        )


def _pet_body_type(mood: str) -> str:
    """根据桌宠心情派生体型"""
    if mood == "hungry":
        return "干瘪体型"
    if mood == "weak":
        return "虚弱"
    return "标准体型"


def _pet_health_score(db: Session, pet_id: int, user_id: int):
    """获取真实宠物健康分（0-100），失败返回 None"""
    try:
        from shared.services.real_pet_service import calculate_health_score
        return calculate_health_score(db, pet_id, user_id).get("total_score")
    except Exception:
        return None


def _get_family_note(db: Session, member_id: int, current_user_id: int) -> Optional[str]:
    """获取我方对该家人的称谓"""
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


async def _get_member_health_summary(db: Session, member_id: int, current_user_id: int) -> dict:
    """获取单个家人的健康摘要"""
    # 获取用户信息
    user = db.query(User).filter(User.id == member_id).first()
    profile = db.query(UserProfile).filter(UserProfile.user_id == member_id).first()

    note = _get_family_note(db, member_id, current_user_id)

    # 获取今日饮食数据
    today = date.today()
    today_summary = db.query(DailyNutritionSummary).filter(
        DailyNutritionSummary.user_id == member_id,
        DailyNutritionSummary.summary_date == today
    ).first()

    total_calories = float(today_summary.total_calories) if today_summary else 0
    target_calories = profile.target_calories if profile and profile.target_calories else 2000

    # 获取今日饮水数据
    today_water = db.query(func.sum(WaterIntakeRecord.amount_ml)).filter(
        WaterIntakeRecord.user_id == member_id,
        func.date(WaterIntakeRecord.record_time) == today
    ).scalar() or 0

    water_goal = profile.daily_water_goal if profile and profile.daily_water_goal else 2000

    # 获取虚拟桌宠状态
    pet_state = db.query(VirtualPetState).filter(
        VirtualPetState.user_id == member_id
    ).first()

    pet_mood = pet_state.mood if pet_state else "normal"
    pet_name = pet_state.pet_name if pet_state and pet_state.pet_name else "桌宠"

    hunger_hours = 0
    if pet_state and pet_state.last_feed_at:
        hunger_hours = max(0, int((datetime.now() - pet_state.last_feed_at).total_seconds() // 3600))

    # 获取真实宠物状态
    real_pets = db.query(PetProfile).filter(
        PetProfile.user_id == member_id,
        PetProfile.is_active == True
    ).all()

    pet_info = []
    for pet in real_pets:
        pet_info.append({
            "pet_id": pet.id,
            "name": pet.name,
            "species": pet.species,
            "avatar_url": pet.avatar_url,
            "health_score": _pet_health_score(db, pet.id, member_id)
        })

    # 获取体检摘要（最新体检报告 + 异常数）
    exam_summary = None
    try:
        from shared.models.exam_models import ExamReport, ExamMetric
        latest_exam = db.query(ExamReport).filter(
            ExamReport.user_id == member_id
        ).order_by(ExamReport.exam_date.desc()).first()
        if latest_exam:
            exam_abnormal = db.query(func.count(ExamMetric.id)).filter(
                ExamMetric.report_id == latest_exam.id,
                ExamMetric.is_abnormal == True
            ).scalar() or 0
            exam_summary = {
                "latest_exam_date": latest_exam.exam_date.isoformat() if latest_exam.exam_date else None,
                "abnormal_count": exam_abnormal,
            }
    except Exception as e:
        logger.warning(f"获取体检摘要失败: {e}")

    return {
        "user_id": member_id,
        "username": user.username if user else "",
        "real_name": profile.real_name if profile else None,
        "avatar_url": user.avatar_url if user else None,
        "note": note,
        "total_calories": total_calories,
        "target_calories": target_calories,
        "water_intake": int(today_water),
        "water_goal": water_goal,
        "virtual_pet_name": pet_name,
        "virtual_pet_mood": pet_mood,
        "virtual_pet_body_type": _pet_body_type(pet_mood),
        "hunger_hours": hunger_hours,
        "real_pets": pet_info,
        "exam_summary": exam_summary
    }


# ============================================================
# 家人健康详情
# ============================================================

@router.get("/member/{member_id}/health", response_model=BaseResponse)
async def get_member_health_detail(
    member_id: int,
    days: int = Query(7, ge=1, le=30, description="查询天数"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取家人健康详情（7日图表数据）"""
    try:
        # 检查是否是家人关系
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == member_id
                ),
                and_(
                    UserRelationship.user_id == member_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not is_family:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能查看家人的健康详情"
            )

        # 查询最近N天的数据
        end_date = date.today()
        start_date = end_date - timedelta(days=days - 1)

        # 每日热量
        daily_calories = db.query(DailyNutritionSummary).filter(
            DailyNutritionSummary.user_id == member_id,
            DailyNutritionSummary.summary_date >= start_date,
            DailyNutritionSummary.summary_date <= end_date
        ).order_by(DailyNutritionSummary.summary_date).all()

        # 每日饮水
        daily_water = db.query(
            func.date(WaterIntakeRecord.record_time).label('record_date'),
            func.sum(WaterIntakeRecord.amount_ml).label('total_water')
        ).filter(
            WaterIntakeRecord.user_id == member_id,
            WaterIntakeRecord.record_time >= start_date,
            WaterIntakeRecord.record_time < end_date + timedelta(days=1)
        ).group_by(func.date(WaterIntakeRecord.record_time)).order_by(func.date(WaterIntakeRecord.record_time)).all()

        water_dict = {row.record_date: int(row.total_water) for row in daily_water}

        # 每日运动消耗（近N天）
        daily_exercise = db.query(
            ExerciseRecord.record_date,
            func.sum(ExerciseRecord.calories_burned).label('total_burned')
        ).filter(
            ExerciseRecord.user_id == member_id,
            ExerciseRecord.record_date >= start_date,
            ExerciseRecord.record_date <= end_date
        ).group_by(ExerciseRecord.record_date).all()

        exercise_cal_dict = {row.record_date: float(row.total_burned) for row in daily_exercise}

        # 每日体重记录（近N天）
        weight_records = db.query(WeightRecord).filter(
            WeightRecord.user_id == member_id,
            WeightRecord.measured_at >= datetime.combine(start_date, datetime.min.time()),
            WeightRecord.measured_at <= datetime.combine(end_date, datetime.max.time())
        ).order_by(WeightRecord.measured_at).all()

        # 每日运动记录（近N天）
        exercise_records = db.query(ExerciseRecord).filter(
            ExerciseRecord.user_id == member_id,
            ExerciseRecord.record_date >= start_date,
            ExerciseRecord.record_date <= end_date
        ).order_by(ExerciseRecord.record_date).all()

        # 健康目标完成情况（进行中的目标）
        active_goal = db.query(HealthGoal).filter(
            HealthGoal.user_id == member_id,
            HealthGoal.current_status == 1
        ).order_by(HealthGoal.created_at.desc()).first()

        goal_data = None
        if active_goal:
            # 取第一个体重记录作为起始体重
            first_weight = db.query(WeightRecord).filter(
                WeightRecord.user_id == member_id
            ).order_by(WeightRecord.measured_at.asc()).first()
            latest_weight = db.query(WeightRecord).filter(
                WeightRecord.user_id == member_id
            ).order_by(WeightRecord.measured_at.desc()).first()

            goal_type_names = {1: "减重", 2: "增重", 3: "维持体重", 4: "增肌", 5: "减脂"}
            goal_data = {
                "goal_type": active_goal.goal_type,
                "goal_type_name": goal_type_names.get(active_goal.goal_type, "健康目标"),
                "target_weight": float(active_goal.target_weight) if active_goal.target_weight else None,
                "target_date": active_goal.target_date.isoformat() if active_goal.target_date else None,
                "start_weight": float(first_weight.weight) if first_weight else None,
                "latest_weight": float(latest_weight.weight) if latest_weight else None,
            }

        # 组装数据
        daily_data = []
        for i in range(days):
            current_date = start_date + timedelta(days=i)
            summary = next((s for s in daily_calories if s.summary_date == current_date), None)
            daily_data.append({
                "date": current_date.isoformat(),
                "calories": float(summary.total_calories) if summary else 0,
                "burned": exercise_cal_dict.get(current_date, 0),
                "protein": float(summary.total_protein) if summary else 0,
                "fat": float(summary.total_fat) if summary else 0,
                "carbs": float(summary.total_carbohydrates) if summary else 0,
                "water": water_dict.get(current_date, 0)
            })

        weight_data = [
            {
                "date": w.measured_at.date().isoformat(),
                "weight": float(w.weight),
                "body_fat_percentage": float(w.body_fat_percentage) if w.body_fat_percentage else None,
                "bmi": float(w.bmi) if w.bmi else None,
            }
            for w in weight_records
        ]

        exercise_data = [
            {
                "date": e.record_date.isoformat(),
                "exercise_type": e.exercise_type,
                "exercise_name": e.exercise_name or e.exercise_type,
                "duration_minutes": e.duration_minutes,
                "calories_burned": float(e.calories_burned),
            }
            for e in exercise_records
        ]

        # 宠物状态（虚拟桌宠 + 真实宠物）
        pet_state = db.query(VirtualPetState).filter(
            VirtualPetState.user_id == member_id
        ).first()
        real_pets = db.query(PetProfile).filter(
            PetProfile.user_id == member_id,
            PetProfile.is_active == True
        ).all()
        pet_data = {
            "virtual_pet_mood": pet_state.mood if pet_state else "normal",
            "virtual_pet_name": pet_state.pet_name if pet_state and pet_state.pet_name else "桌宠",
            "real_pets": [
                {
                    "pet_id": p.id,
                    "name": p.name,
                    "species": p.species,
                    "avatar_url": p.avatar_url,
                }
                for p in real_pets
            ],
        }

        return BaseResponse(
            success=True,
            message="获取家人健康详情成功",
            data={
                "daily_data": daily_data,
                "weight_data": weight_data,
                "exercise_data": exercise_data,
                "goal": goal_data,
                "pet": pet_data,
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取家人健康详情失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取家人健康详情失败"
        )


# ============================================================
# 家庭异常提醒
# ============================================================

@router.get("/alerts", response_model=BaseResponse)
async def get_family_alerts(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取家庭异常提醒（家人饮水不足/热量超标/宠物异常等）"""
    try:
        # 查询所有家人
        family_relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).all()

        alerts = []
        today = date.today()

        for rel in family_relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            real_name = profile.real_name if profile and profile.real_name else user.username

            # 检查饮水不足
            today_water = db.query(func.sum(WaterIntakeRecord.amount_ml)).filter(
                WaterIntakeRecord.user_id == other_id,
                func.date(WaterIntakeRecord.record_time) == today
            ).scalar() or 0

            water_goal = profile.daily_water_goal if profile and profile.daily_water_goal else 2000
            if today_water < water_goal * 0.5:  # 饮水不足50%
                alerts.append({
                    "type": "water_insufficient",
                    "user_id": other_id,
                    "user_name": real_name,
                    "message": f"{real_name}今日喝水不足（{int(today_water)}ml/{water_goal}ml）",
                    "severity": "warning"
                })

            # 检查热量超标
            today_summary = db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == other_id,
                DailyNutritionSummary.summary_date == today
            ).first()

            if today_summary:
                total_calories = float(today_summary.total_calories)
                target_calories = profile.target_calories if profile and profile.target_calories else 2000
                if total_calories > target_calories * 1.2:  # 热量超标20%
                    alerts.append({
                        "type": "calorie_excess",
                        "user_id": other_id,
                        "user_name": real_name,
                        "message": f"{real_name}今日热量超标（{int(total_calories)}/{target_calories}kcal）",
                        "severity": "warning"
                    })

            # 检查虚拟桌宠饥饿
            pet_state = db.query(VirtualPetState).filter(
                VirtualPetState.user_id == other_id
            ).first()

            if pet_state and pet_state.mood in ["hungry", "weak"]:
                hunger_hours = 0
                if pet_state.last_feed_at:
                    hunger_hours = max(0, int((datetime.now() - pet_state.last_feed_at).total_seconds() // 3600))
                hour_text = f" {hunger_hours} 小时" if hunger_hours else ""
                alerts.append({
                    "type": "pet_hungry",
                    "user_id": other_id,
                    "user_name": real_name,
                    "message": f"{real_name}的桌宠已饥饿{hour_text}",
                    "severity": "info"
                })

        return BaseResponse(
            success=True,
            message="获取家庭异常提醒成功",
            data={"alerts": alerts}
        )
    except Exception as e:
        logger.error(f"获取家庭异常提醒失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取家庭异常提醒失败"
        )


# ============================================================
# 喝水提醒
# ============================================================

@router.post("/remind-water/{target_user_id}", response_model=BaseResponse)
async def remind_family_water(
    target_user_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """向家人发送喝水提醒消息"""
    try:
        # 校验家人关系
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not is_family:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能给家人发送喝水提醒"
            )

        # 发送者信息
        sender_profile = db.query(UserProfile).filter(
            UserProfile.user_id == current_user.id
        ).first()
        sender_name = sender_profile.real_name if sender_profile and sender_profile.real_name else current_user.username

        content = f"💧 {sender_name} 提醒你该喝水啦！记得多喝水，保持健康～"

        # 创建消息记录
        from shared.models.message_models import Message
        msg = Message(
            sender_id=current_user.id,
            receiver_id=target_user_id,
            content=content,
            message_type="text",
            extra_data={"type": "water_remind"}
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)

        # WebSocket 实时推送
        try:
            from routers.message_router import manager
            from datetime import timezone
            created_at = msg.created_at
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
            await manager.send_to_user(target_user_id, {
                "type": "new_message",
                "data": {
                    "id": msg.id,
                    "sender_id": current_user.id,
                    "receiver_id": target_user_id,
                    "content": content,
                    "message_type": "text",
                    "created_at": created_at.isoformat(),
                    "sender_username": current_user.username,
                    "sender_avatar_url": current_user.avatar_url,
                }
            })
        except Exception as ws_error:
            logger.warning(f"喝水提醒 WebSocket 推送失败: {ws_error}")

        # 推送通知
        try:
            from shared.services.push_service import send_push_to_user
            await send_push_to_user(
                db=db,
                user_id=target_user_id,
                title="喝水提醒",
                body=content,
                data={"type": "water_remind", "sender_id": current_user.id},
                reminder_type="water_remind"
            )
        except Exception as notify_error:
            logger.warning(f"喝水提醒推送通知失败: {notify_error}")

        return BaseResponse(
            success=True,
            message="已发送喝水提醒",
            data={"message_id": msg.id}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"发送喝水提醒失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送喝水提醒失败"
        )


# ============================================================
# 代记录饮食
# ============================================================

@router.post("/proxy-record/food", response_model=BaseResponse)
async def proxy_record_food(
    target_user_id: int = Query(..., description="被记录人ID"),
    food_record_id: int = Query(..., description="食物记录ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """代记录饮食（家人为其他家人记录）"""
    try:
        # 检查是否是家人关系
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not is_family:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能为家人代记录"
            )

        # 更新食物记录的代记录人（支持归属转移：记录可属于代记录人或目标用户）
        food_record = db.query(FoodRecord).filter(
            FoodRecord.id == food_record_id,
            or_(
                FoodRecord.user_id == target_user_id,
                FoodRecord.user_id == current_user.id
            )
        ).first()

        if not food_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="食物记录不存在"
            )

        # 记录归属转移给目标用户
        if food_record.user_id == current_user.id:
            food_record.user_id = target_user_id
        food_record.recorded_by_user_id = current_user.id
        db.commit()

        # 创建代记录日志
        from shared.models.proxy_models import ProxyRecord
        proxy_record = ProxyRecord(
            recorded_by_user_id=current_user.id,
            target_user_id=target_user_id,
            record_type="food",
            record_id=food_record_id
        )
        db.add(proxy_record)
        db.commit()

        # 通知被记录人
        try:
            from shared.services.push_service import send_push_to_user
            # 获取代记录人信息
            recorder = db.query(User).filter(User.id == current_user.id).first()
            recorder_name = recorder.real_name or recorder.username if recorder else "家人"
            
            # 构建通知内容
            food_name = food_record.food_name or "食物"
            calories = food_record.calories or 0
            notification_title = f"{recorder_name} 帮你记录了饮食"
            notification_body = f"{food_name} {calories:.0f}卡"
            
            # 发送推送通知
            await send_push_to_user(
                db=db,
                user_id=target_user_id,
                title=notification_title,
                body=notification_body,
                data={
                    "type": "proxy_record",
                    "recorded_by": current_user.id,
                    "food_record_id": food_record_id
                },
                reminder_type="proxy_record"
            )
            logger.info(f"代记录通知已发送: {target_user_id}")
        except Exception as notify_error:
            logger.warning(f"发送代记录通知失败: {notify_error}")

        return BaseResponse(
            success=True,
            message="代记录成功",
            data=None
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"代记录失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="代记录失败"
        )


# ============================================================
# 代记录饮水
# ============================================================

@router.post("/proxy-record/water", response_model=BaseResponse)
async def proxy_record_water(
    target_user_id: int = Query(..., description="被代记录的家人用户ID"),
    amount_ml: int = Query(..., ge=50, le=5000, description="饮水量(ml)"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """代记录饮水（家人为其他家人记录饮水）"""
    try:
        # 校验家人关系
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not is_family:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能为家人代记录饮水"
            )

        # 创建饮水记录
        water_record = WaterIntakeRecord(
            user_id=target_user_id,
            amount_ml=amount_ml,
            record_time=datetime.now()
        )
        db.add(water_record)
        db.flush()  # 先 flush 获取 water_record.id

        # 创建代记录日志
        from shared.models.proxy_models import ProxyRecord
        proxy_record = ProxyRecord(
            recorded_by_user_id=current_user.id,
            target_user_id=target_user_id,
            record_type="water",
            record_id=water_record.id,
        )
        db.add(proxy_record)
        db.commit()
        db.refresh(water_record)

        # 通知被代记录的家人
        try:
            from shared.services.push_service import send_push_to_user
            proxy_user = db.query(User).filter(User.id == current_user.id).first()
            proxy_name = proxy_user.real_name or proxy_user.username if proxy_user else "家人"
            await send_push_to_user(
                db=db,
                user_id=target_user_id,
                title="饮水已记录",
                body=f"{proxy_name} 帮您记录了 {amount_ml}ml 饮水",
                data={
                    "type": "proxy_record",
                    "recorded_by": current_user.id,
                    "amount_ml": amount_ml,
                },
                reminder_type="proxy_record"
            )
            logger.info(f"代记录饮水通知已发送: {target_user_id}")
        except Exception as notify_error:
            logger.warning(f"发送代记录饮水通知失败: {notify_error}")

        return BaseResponse(
            success=True,
            message="代记录饮水成功",
            data={
                "record_id": water_record.id,
                "user_id": target_user_id,
                "amount_ml": amount_ml,
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"代记录饮水失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="代记录饮水失败"
        )


# ============================================================
# 家庭周报
# ============================================================

@router.get("/weekly-report", response_model=BaseResponse)
async def get_family_weekly_report(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取家庭周报（每周生成家庭健康报告）"""
    try:
        # 查询所有家人
        family_relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).all()

        # 计算本周日期范围
        today = date.today()
        week_start = today - timedelta(days=today.weekday())  # 本周一
        week_end = week_start + timedelta(days=6)  # 本周日

        members = []
        total_family_calories = 0
        total_family_water = 0
        member_count = 0

        for rel in family_relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            # 查询本周饮食数据
            weekly_summaries = db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == other_id,
                DailyNutritionSummary.summary_date >= week_start,
                DailyNutritionSummary.summary_date <= week_end
            ).all()

            # 查询本周饮水数据
            weekly_water_records = db.query(WaterIntakeRecord).filter(
                WaterIntakeRecord.user_id == other_id,
                WaterIntakeRecord.record_time >= week_start,
                WaterIntakeRecord.record_time < week_end + timedelta(days=1)
            ).all()

            # 计算周总热量和饮水
            total_calories = sum(float(s.total_calories) for s in weekly_summaries)
            total_water = sum(float(w.amount_ml) for w in weekly_water_records)

            # 计算平均每日热量
            avg_daily_calories = total_calories / 7 if weekly_summaries else 0
            avg_daily_water = total_water / 7

            # 计算达标天数
            target_calories = profile.target_calories if profile and profile.target_calories else 2000
            water_goal = profile.daily_water_goal if profile and profile.daily_water_goal else 2000

            calorie_goal_days = sum(
                1 for s in weekly_summaries
                if float(s.total_calories) >= target_calories * 0.8
                and float(s.total_calories) <= target_calories * 1.2
            )

            water_goal_days = 0
            for day in range(7):
                current_date = week_start + timedelta(days=day)
                day_water = sum(
                    float(w.amount_ml) for w in weekly_water_records
                    if w.record_time.date() == current_date
                )
                if day_water >= water_goal:
                    water_goal_days += 1

            # 健康评分（饮食+饮水达标占比）与成就
            health_score = round(
                ((calorie_goal_days + water_goal_days) / 14) * 100
            )
            achievements = []
            if calorie_goal_days >= 4:
                achievements.append(f"🥗 饮食达标 {calorie_goal_days}/7 天")
            if water_goal_days >= 4:
                achievements.append(f"💧 饮水达标 {water_goal_days}/7 天")

            # 体检异常追踪（最新体检报告 + 距上次体检天数 + 建议复查倒计时）
            exam_summary = None
            try:
                from shared.models.exam_models import ExamReport, ExamMetric
                latest_exam = db.query(ExamReport).filter(
                    ExamReport.user_id == other_id
                ).order_by(ExamReport.exam_date.desc()).first()
                if latest_exam:
                    abnormal_metrics = db.query(ExamMetric).filter(
                        ExamMetric.report_id == latest_exam.id,
                        ExamMetric.is_abnormal == True
                    ).all()
                    days_since_exam = (today - latest_exam.exam_date).days
                    # 复查倒计时：优先用报告的 followup_date，无则按异常默认 90 天
                    next_checkup = None
                    if abnormal_metrics:
                        if latest_exam.followup_date:
                            next_checkup = max(0, (latest_exam.followup_date - today).days)
                        else:
                            next_checkup = max(0, 90 - days_since_exam)
                    exam_summary = {
                        "latest_exam_date": latest_exam.exam_date.isoformat(),
                        "abnormal_count": len(abnormal_metrics),
                        "abnormal_metrics": [m.metric_name for m in abnormal_metrics],
                        "days_since_exam": days_since_exam,
                        "next_checkup_days": next_checkup,
                    }
                    if abnormal_metrics:
                        achievements.append(f"⚠️ 体检异常 {len(abnormal_metrics)} 项")
            except Exception as e:
                logger.warning(f"周报体检追踪失败: {e}")

            members.append({
                "user_id": other_id,
                "username": user.username if user else "",
                "real_name": profile.real_name if profile else None,
                "avatar_url": user.avatar_url if user else None,
                "avg_calories": round(avg_daily_calories, 1),
                "avg_water": round(avg_daily_water, 1),
                "total_calories": round(total_calories, 1),
                "total_water_ml": round(total_water, 1),
                "avg_daily_calories": round(avg_daily_calories, 1),
                "calorie_goal_days": calorie_goal_days,
                "water_goal_days": water_goal_days,
                "target_calories": target_calories,
                "water_goal_ml": water_goal,
                "health_score": health_score,
                "achievements": achievements,
                "exam_summary": exam_summary,
            })

            total_family_calories += total_calories
            total_family_water += total_water
            member_count += 1

        # 计算家庭整体数据
        family_report = {
            "week_start": week_start.isoformat(),
            "week_end": week_end.isoformat(),
            "member_count": member_count,
            "total_family_calories": round(total_family_calories, 1),
            "total_family_water_ml": round(total_family_water, 1),
            "avg_member_calories": round(total_family_calories / member_count, 1) if member_count > 0 else 0,
            "avg_member_water": round(total_family_water / member_count, 1) if member_count > 0 else 0,
            "members": members
        }

        return BaseResponse(
            success=True,
            message="获取家庭周报成功",
            data=family_report
        )
    except Exception as e:
        logger.error(f"获取家庭周报失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取家庭周报失败"
        )


# ============================================================
# 饮食推荐共享
# ============================================================

@router.get("/diet-preferences", response_model=BaseResponse)
async def get_family_diet_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取家庭成员的饮食偏好（用于饮食推荐共享）"""
    try:
        # 查询所有家人
        family_relations = db.query(UserRelationship).filter(
            or_(
                UserRelationship.user_id == current_user.id,
                UserRelationship.related_user_id == current_user.id
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).all()

        member_preferences = []

        for rel in family_relations:
            other_id = rel.related_user_id if rel.user_id == current_user.id else rel.user_id
            user = db.query(User).filter(User.id == other_id).first()
            profile = db.query(UserProfile).filter(UserProfile.user_id == other_id).first()

            if profile:
                # 解析饮食偏好（JSON 字符串）
                dietary_prefs = []
                if profile.dietary_preferences:
                    import json
                    try:
                        dietary_prefs = json.loads(profile.dietary_preferences) if isinstance(profile.dietary_preferences, str) else profile.dietary_preferences
                    except:
                        dietary_prefs = []

                # 解析不喜欢的食物
                food_dislikes = []
                if profile.food_dislikes:
                    try:
                        food_dislikes = json.loads(profile.food_dislikes) if isinstance(profile.food_dislikes, str) else profile.food_dislikes
                    except:
                        food_dislikes = []

                member_preferences.append({
                    "user_id": other_id,
                    "username": user.username if user else "",
                    "real_name": profile.real_name if profile else None,
                    "dietary_preferences": dietary_prefs,
                    "food_dislikes": food_dislikes,
                    "health_status": profile.health_status,
                    "constitution_type": profile.constitution_type
                })

        return BaseResponse(
            success=True,
            message="获取家庭饮食偏好成功",
            data={"member_preferences": member_preferences}
        )
    except Exception as e:
        logger.error(f"获取家庭饮食偏好失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取家庭饮食偏好失败"
        )


@router.post("/diet-recommendation", response_model=BaseResponse)
async def get_family_diet_recommendation(
    target_user_id: int = Query(..., description="目标用户ID"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """基于家庭成员的体检异常和饮食偏好生成饮食推荐"""
    try:
        # 检查是否是家人关系
        is_family = db.query(UserRelationship).filter(
            or_(
                and_(
                    UserRelationship.user_id == current_user.id,
                    UserRelationship.related_user_id == target_user_id
                ),
                and_(
                    UserRelationship.user_id == target_user_id,
                    UserRelationship.related_user_id == current_user.id
                )
            ),
            UserRelationship.relationship_type == "family",
            UserRelationship.status == "accepted"
        ).first()

        if not is_family:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只能为家人生成饮食推荐"
            )

        # 获取目标用户的体检报告异常指标
        from shared.models.exam_models import ExamReport, ExamMetric

        latest_report = db.query(ExamReport).filter(
            ExamReport.user_id == target_user_id
        ).order_by(ExamReport.exam_date.desc()).first()

        abnormal_metrics = []
        if latest_report:
            abnormal_metrics = db.query(ExamMetric).filter(
                ExamMetric.report_id == latest_report.id,
                ExamMetric.is_abnormal == True
            ).all()

        # 获取目标用户的饮食偏好
        profile = db.query(UserProfile).filter(UserProfile.user_id == target_user_id).first()

        dietary_prefs = []
        food_dislikes = []
        if profile:
            import json
            try:
                dietary_prefs = json.loads(profile.dietary_preferences) if isinstance(profile.dietary_preferences, str) else profile.dietary_preferences
                food_dislikes = json.loads(profile.food_dislikes) if isinstance(profile.food_dislikes, str) else profile.food_dislikes
            except:
                pass

        # 生成饮食推荐
        recommendations = []

        # 基于异常指标生成推荐
        for metric in abnormal_metrics:
            metric_name = metric.metric_name

            if "血糖" in metric_name or "glucose" in metric_name.lower():
                recommendations.append({
                    "type": "blood_sugar",
                    "advice": "建议控制精制碳水摄入，增加膳食纤维",
                    "recommended_foods": ["燕麦", "全麦面包", "绿叶蔬菜", "豆类"],
                    "avoid_foods": ["白米饭", "甜食", "含糖饮料"]
                })
            elif "胆固醇" in metric_name or "cholesterol" in metric_name.lower():
                recommendations.append({
                    "type": "cholesterol",
                    "advice": "建议低脂饮食，减少饱和脂肪摄入",
                    "recommended_foods": ["鱼类", "橄榄油", "坚果", "水果"],
                    "avoid_foods": ["油炸食品", "动物内脏", "奶油"]
                })
            elif "血压" in metric_name or "blood_pressure" in metric_name.lower():
                recommendations.append({
                    "type": "blood_pressure",
                    "advice": "建议低盐饮食，增加钾摄入",
                    "recommended_foods": ["香蕉", "土豆", "菠菜", "芹菜"],
                    "avoid_foods": ["咸菜", "腌制品", "高钠调味品"]
                })
            elif "尿酸" in metric_name or "uric_acid" in metric_name.lower():
                recommendations.append({
                    "type": "uric_acid",
                    "advice": "建议低嘌呤饮食，多喝水",
                    "recommended_foods": ["低脂奶制品", "鸡蛋", "大部分蔬菜"],
                    "avoid_foods": ["海鲜", "啤酒", "动物内脏", "浓汤"]
                })

        # 如果没有异常指标，给出通用建议
        if not recommendations:
            recommendations.append({
                "type": "general",
                "advice": "保持均衡饮食，多样化食物摄入",
                "recommended_foods": ["五谷杂粮", "蔬菜水果", "优质蛋白"],
                "avoid_foods": ["过度加工食品", "高糖饮料"]
            })

        # 过滤掉用户不喜欢的食物
        for rec in recommendations:
            rec["recommended_foods"] = [
                food for food in rec["recommended_foods"]
                if food not in food_dislikes
            ]

        return BaseResponse(
            success=True,
            message="获取饮食推荐成功",
            data={
                "user_id": target_user_id,
                "recommendations": recommendations,
                "dietary_preferences": dietary_prefs,
                "food_dislikes": food_dislikes
            }
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取饮食推荐失败: {e}\n{traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取饮食推荐失败"
        )
