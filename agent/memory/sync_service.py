"""
Sync Service - Database to Markdown synchronization.

Provides:
- Full regeneration of workspace files from database
- Incremental updates for specific sections
- Data extraction from various database tables

Data Sources:
- UserProfile, HealthGoal, Disease, Allergy -> shared/user_memory.md
- HealthGoal, WeightRecord, DailyNutritionSummary -> goal_tracking/user_goals.md
- FoodRecord, NutritionDetail -> nutrition/user_nutrition.md
- ConversationSession, ConversationMessage -> chat/user_chat.md
"""

import logging
from datetime import datetime, date, timedelta
from typing import Optional, Dict, Any, List
from sqlalchemy.orm import Session
from sqlalchemy import func

from agent.memory.memory_manager import MemoryManager
from agent.memory.schemas import (
    SharedMemoryData,
    GoalTrackingData,
    NutritionWorkspaceData,
    ChatWorkspaceData,
    AllergyInfo,
    DiseaseInfo,
    MedicationInfo,
    FoodPreferences,
    BehaviorPatterns,
    ActiveGoal,
    BMRTDEEData,
    DailyTargets,
    WeightProgress,
    TodayStatus,
    Milestone,
    DietSummary,
    FrequentFood,
    NutritionTrend,
    RecentAnalysis,
    ConversationPreferences,
    FrequentTopic,
    InteractionSummary,
    SeverityLevel,
    GoalType,
    ActivityLevel
)
from agent.memory.markdown_renderer import (
    render_shared_memory,
    render_goal_tracking,
    render_nutrition_workspace,
    render_chat_workspace
)
from shared.utils.nutrition_calc import (
    calculate_bmr,
    calculate_tdee,
    calculate_daily_targets,
    calculate_age,
    calculate_goal_progress
)

logger = logging.getLogger(__name__)


class SyncService:
    """
    Database to Markdown synchronization service.

    Syncs user data from PostgreSQL to MD workspace files for agent consumption.
    """

    def __init__(self, db: Session):
        """
        Initialize SyncService.

        Args:
            db: SQLAlchemy database session
        """
        self.db = db

    async def sync_shared_memory(self, user_id: int) -> bool:
        """
        Sync shared memory workspace from database.

        Reads: UserProfile, Disease, Allergy

        Args:
            user_id: User ID

        Returns:
            True if successful
        """
        try:
            # Import models here to avoid circular imports
            from shared.models.user_models import User, UserProfile, Disease, Allergy

            # Get user and profile
            user = self.db.query(User).filter(User.id == user_id).first()
            if not user:
                logger.warning(f"User {user_id} not found")
                return False

            profile = self.db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not profile:
                logger.warning(f"UserProfile for user {user_id} not found")
                return False

            # Calculate age from birth_date
            age = calculate_age(profile.birth_date) if profile.birth_date else 30

            # Get allergies
            allergies_db = self.db.query(Allergy).filter(Allergy.user_id == user_id).all()
            allergies = [
                AllergyInfo(
                    name=a.allergen_name,
                    severity=SeverityLevel(a.severity_level) if a.severity_level else SeverityLevel.MODERATE,
                    reaction=a.reaction_description
                )
                for a in allergies_db
            ]

            # Get diseases
            diseases_db = self.db.query(Disease).filter(
                Disease.user_id == user_id,
                Disease.is_current == True
            ).all()
            diseases = [
                DiseaseInfo(
                    name=d.disease_name,
                    icd_code=d.disease_code,
                    status="控制中" if d.severity_level == 1 else "活跃",
                    notes=d.notes
                )
                for d in diseases_db
            ]

            # Build food preferences from any stored data
            # Note: These may need to be populated from user input or learned behavior
            food_prefs = FoodPreferences(
                liked_foods=[],
                disliked_foods=[],
                dietary_restrictions=self._extract_dietary_restrictions(diseases, allergies)
            )

            # Build behavior patterns (defaults, can be updated from user input)
            behavior = BehaviorPatterns()

            # Create shared memory data
            shared_data = SharedMemoryData(
                user_id=user_id,
                last_updated=datetime.now(),
                gender=profile.gender or 1,
                age=age,
                height=float(profile.height) if profile.height else 170.0,
                weight=float(profile.weight) if profile.weight else 70.0,
                activity_level=ActivityLevel(profile.activity_level) if profile.activity_level else ActivityLevel.LIGHT,
                allergies=allergies,
                diseases=diseases,
                medications=[],  # Would need medication table
                food_preferences=food_prefs,
                behavior_patterns=behavior
            )

            # Render and save
            content = render_shared_memory(shared_data)
            manager = MemoryManager(user_id)
            return await manager.write_workspace("shared", content)

        except Exception as e:
            logger.error(f"Error syncing shared memory for user {user_id}: {e}")
            return False

    async def sync_goal_tracking(self, user_id: int) -> bool:
        """
        Sync goal tracking workspace from database.

        Reads: HealthGoal, WeightRecord, UserProfile, DailyNutritionSummary

        Args:
            user_id: User ID

        Returns:
            True if successful
        """
        try:
            from shared.models.user_models import UserProfile, HealthGoal, WeightRecord
            from shared.models.food_models import DailyNutritionSummary

            # Get profile for BMR/TDEE calculation
            profile = self.db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
            if not profile:
                logger.warning(f"UserProfile for user {user_id} not found")
                return False

            # Get active health goal
            active_goal_db = self.db.query(HealthGoal).filter(
                HealthGoal.user_id == user_id,
                HealthGoal.current_status == 1  # In progress
            ).first()

            active_goal = None
            if active_goal_db:
                active_goal = ActiveGoal(
                    goal_id=active_goal_db.id,
                    goal_type=GoalType(active_goal_db.goal_type),
                    target_weight=float(active_goal_db.target_weight) if active_goal_db.target_weight else None,
                    target_date=active_goal_db.target_date,
                    status="进行中"
                )

            # Calculate BMR/TDEE
            age = calculate_age(profile.birth_date) if profile.birth_date else 30
            bmr = calculate_bmr(
                weight=float(profile.weight) if profile.weight else 70,
                height=float(profile.height) if profile.height else 170,
                age=age,
                gender=profile.gender or 1
            )
            tdee = calculate_tdee(bmr, profile.activity_level or 2)

            bmr_tdee_data = BMRTDEEData(
                bmr=bmr,
                tdee=tdee,
                activity_factor={1: 1.2, 2: 1.375, 3: 1.55, 4: 1.725, 5: 1.9}.get(profile.activity_level or 2, 1.375),
                calculated_at=datetime.now()
            )

            # Calculate daily targets
            goal_type = active_goal.goal_type if active_goal else GoalType.MAINTAIN
            targets_dict = calculate_daily_targets(tdee, goal_type)
            daily_targets = DailyTargets(
                calories=targets_dict["calories"],
                protein=targets_dict["protein"],
                carbs=targets_dict["carbs"],
                fat=targets_dict["fat"],
                calorie_adjustment=targets_dict["calorie_adjustment"]
            )

            # Get weight progress
            weight_records = self.db.query(WeightRecord).filter(
                WeightRecord.user_id == user_id
            ).order_by(WeightRecord.measured_at.asc()).all()

            weight_progress = None
            if weight_records and active_goal and active_goal.target_weight:
                first_record = weight_records[0]
                last_record = weight_records[-1]
                progress = calculate_goal_progress(
                    starting_weight=float(first_record.weight),
                    current_weight=float(last_record.weight),
                    target_weight=active_goal.target_weight,
                    goal_type=active_goal.goal_type
                )
                weight_progress = WeightProgress(
                    starting_weight=progress["starting_weight"],
                    starting_date=first_record.measured_at.date() if isinstance(first_record.measured_at, datetime) else first_record.measured_at,
                    current_weight=progress["current_weight"],
                    current_date=last_record.measured_at.date() if isinstance(last_record.measured_at, datetime) else last_record.measured_at,
                    weight_change=progress["weight_change"],
                    target_remaining=progress["remaining"],
                    progress_percentage=progress["progress_percentage"]
                )

            # Get today's consumption
            today = date.today()
            today_summary = self.db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == user_id,
                DailyNutritionSummary.summary_date == today
            ).first()

            today_status = TodayStatus()
            if today_summary:
                today_status = TodayStatus(
                    consumed_calories=float(today_summary.total_calories) if today_summary.total_calories else 0,
                    consumed_protein=float(today_summary.total_protein) if today_summary.total_protein else 0,
                    consumed_carbs=float(today_summary.total_carbohydrates) if today_summary.total_carbohydrates else 0,
                    consumed_fat=float(today_summary.total_fat) if today_summary.total_fat else 0,
                    remaining_calories=daily_targets.calories - (float(today_summary.total_calories) if today_summary.total_calories else 0),
                    remaining_protein=daily_targets.protein - (float(today_summary.total_protein) if today_summary.total_protein else 0),
                    remaining_carbs=daily_targets.carbs - (float(today_summary.total_carbohydrates) if today_summary.total_carbohydrates else 0),
                    remaining_fat=daily_targets.fat - (float(today_summary.total_fat) if today_summary.total_fat else 0),
                    last_updated=datetime.now()
                )
            else:
                today_status = TodayStatus(
                    remaining_calories=daily_targets.calories,
                    remaining_protein=daily_targets.protein,
                    remaining_carbs=daily_targets.carbs,
                    remaining_fat=daily_targets.fat,
                    last_updated=datetime.now()
                )

            # Build goal tracking data
            goal_data = GoalTrackingData(
                user_id=user_id,
                last_updated=datetime.now(),
                active_goal=active_goal,
                bmr_tdee=bmr_tdee_data,
                daily_targets=daily_targets,
                weight_progress=weight_progress,
                today_status=today_status,
                milestones=[],  # Can be generated based on progress
                suggestions=[],  # Will be filled by Goal Agent
                warnings=[]
            )

            # Render and save
            content = render_goal_tracking(goal_data)
            manager = MemoryManager(user_id)
            return await manager.write_workspace("goal_tracking", content)

        except Exception as e:
            logger.error(f"Error syncing goal tracking for user {user_id}: {e}")
            return False

    async def sync_nutrition_workspace(self, user_id: int) -> bool:
        """
        Sync nutrition workspace from database.

        Reads: FoodRecord, NutritionDetail, DailyNutritionSummary

        Args:
            user_id: User ID

        Returns:
            True if successful
        """
        try:
            from shared.models.food_models import FoodRecord, NutritionDetail, DailyNutritionSummary

            # Get diet summary for last 7 days
            seven_days_ago = date.today() - timedelta(days=7)
            summaries = self.db.query(DailyNutritionSummary).filter(
                DailyNutritionSummary.user_id == user_id,
                DailyNutritionSummary.summary_date >= seven_days_ago
            ).all()

            diet_summary = DietSummary()
            if summaries:
                diet_summary = DietSummary(
                    period_days=7,
                    avg_calories=round(sum(float(s.total_calories or 0) for s in summaries) / len(summaries), 1),
                    avg_protein=round(sum(float(s.total_protein or 0) for s in summaries) / len(summaries), 1),
                    avg_carbs=round(sum(float(s.total_carbohydrates or 0) for s in summaries) / len(summaries), 1),
                    avg_fat=round(sum(float(s.total_fat or 0) for s in summaries) / len(summaries), 1),
                    meal_regularity="良好" if len(summaries) >= 5 else "需改善"
                )

            # Get frequent foods (last 30 days)
            thirty_days_ago = date.today() - timedelta(days=30)
            food_records = self.db.query(FoodRecord).filter(
                FoodRecord.user_id == user_id,
                FoodRecord.record_date >= thirty_days_ago,
                FoodRecord.analysis_status == 3  # Completed
            ).all()

            # Count food frequencies
            food_counts: Dict[str, Dict[str, Any]] = {}
            for record in food_records:
                # Get nutrition details
                detail = self.db.query(NutritionDetail).filter(
                    NutritionDetail.food_record_id == record.id
                ).first()

                if record.food_name:
                    name = record.food_name
                    if name not in food_counts:
                        food_counts[name] = {
                            "count": 0,
                            "total_calories": 0,
                            "health_levels": []
                        }
                    food_counts[name]["count"] += 1
                    if detail:
                        food_counts[name]["total_calories"] += float(detail.calories or 0)
                        if detail.confidence_score:
                            # Map confidence to health level
                            level = "A" if detail.confidence_score >= 0.8 else "B" if detail.confidence_score >= 0.6 else "C"
                            food_counts[name]["health_levels"].append(level)

            # Build frequent foods list
            frequent_foods = []
            for name, data in sorted(food_counts.items(), key=lambda x: x[1]["count"], reverse=True)[:10]:
                avg_calories = data["total_calories"] / data["count"] if data["count"] > 0 else 0
                # Get most common health level
                health_level = max(set(data["health_levels"]), key=data["health_levels"].count) if data["health_levels"] else "B"
                frequent_foods.append(FrequentFood(
                    name=name,
                    frequency=data["count"],
                    avg_calories=round(avg_calories, 0),
                    health_level=health_level
                ))

            # Get recent analyses (last 5)
            recent_records = self.db.query(FoodRecord).filter(
                FoodRecord.user_id == user_id,
                FoodRecord.analysis_status == 3
            ).order_by(FoodRecord.record_date.desc()).limit(5).all()

            recent_analyses = []
            meal_type_map = {1: "早餐", 2: "午餐", 3: "晚餐", 4: "加餐", 5: "夜宵"}
            for record in recent_records:
                detail = self.db.query(NutritionDetail).filter(
                    NutritionDetail.food_record_id == record.id
                ).first()

                if detail:
                    recent_analyses.append(RecentAnalysis(
                        date=record.record_date,
                        meal_type=meal_type_map.get(record.meal_type, "未知"),
                        foods=[record.food_name] if record.food_name else ["未识别"],
                        calories=float(detail.calories) if detail.calories else 0,
                        health_level="A"  # Would need health level field
                    ))

            # Build nutrition workspace data
            nutrition_data = NutritionWorkspaceData(
                user_id=user_id,
                last_updated=datetime.now(),
                diet_summary=diet_summary,
                frequent_foods=frequent_foods,
                nutrition_trends=[],  # Would need more complex calculation
                recent_analyses=recent_analyses
            )

            # Render and save
            content = render_nutrition_workspace(nutrition_data)
            manager = MemoryManager(user_id)
            return await manager.write_workspace("nutrition", content)

        except Exception as e:
            logger.error(f"Error syncing nutrition workspace for user {user_id}: {e}")
            return False

    async def sync_chat_workspace(self, user_id: int) -> bool:
        """
        Sync chat workspace from database.

        Reads: ConversationSession, ConversationMessage

        Args:
            user_id: User ID

        Returns:
            True if successful
        """
        try:
            from shared.models.conversation_models import ConversationSession, ConversationMessage

            # Get conversation sessions
            sessions = self.db.query(ConversationSession).filter(
                ConversationSession.user_id == user_id
            ).order_by(ConversationSession.created_at.desc()).limit(10).all()

            # Analyze conversation topics
            topic_counts: Dict[str, int] = {}
            recent_interactions: List[InteractionSummary] = []

            for session in sessions:
                # Get messages for this session
                messages = self.db.query(ConversationMessage).filter(
                    ConversationMessage.session_id == session.id,
                    ConversationMessage.message_type == 1  # User messages
                ).order_by(ConversationMessage.created_at.desc()).limit(3).all()

                if messages:
                    # Use session title or first message as topic
                    topic = session.title or "一般咨询"
                    topic_counts[topic] = topic_counts.get(topic, 0) + 1

                    # Add to recent interactions
                    if len(recent_interactions) < 5:
                        first_msg = messages[-1] if messages else None
                        if first_msg:
                            recent_interactions.append(InteractionSummary(
                                date=session.created_at.date() if isinstance(session.created_at, datetime) else date.today(),
                                topic=topic,
                                user_question=first_msg.content[:100] if first_msg.content else "未记录",
                                key_points=[]
                            ))

            # Build frequent topics
            frequent_topics = [
                FrequentTopic(topic=topic, count=count)
                for topic, count in sorted(topic_counts.items(), key=lambda x: x[1], reverse=True)[:5]
            ]

            # Build chat workspace data
            chat_data = ChatWorkspaceData(
                user_id=user_id,
                last_updated=datetime.now(),
                preferences=ConversationPreferences(),  # Defaults
                frequent_topics=frequent_topics,
                recent_interactions=recent_interactions,
                user_feedback=[]
            )

            # Render and save
            content = render_chat_workspace(chat_data)
            manager = MemoryManager(user_id)
            return await manager.write_workspace("chat", content)

        except Exception as e:
            logger.error(f"Error syncing chat workspace for user {user_id}: {e}")
            return False

    async def full_sync(self, user_id: int) -> bool:
        """
        Perform full synchronization of all workspaces for a user.

        Args:
            user_id: User ID

        Returns:
            True if all syncs successful
        """
        results = []

        results.append(await self.sync_shared_memory(user_id))
        results.append(await self.sync_goal_tracking(user_id))
        results.append(await self.sync_nutrition_workspace(user_id))
        results.append(await self.sync_chat_workspace(user_id))

        success = all(results)
        if success:
            logger.info(f"Full sync completed for user {user_id}")
        else:
            logger.warning(f"Partial sync failure for user {user_id}: {results}")

        return success

    def _extract_dietary_restrictions(
        self,
        diseases: List[DiseaseInfo],
        allergies: List[AllergyInfo]
    ) -> List[str]:
        """Extract dietary restrictions from diseases and allergies."""
        restrictions = []

        # Add restrictions based on diseases
        disease_restrictions = {
            "糖尿病": "低糖饮食",
            "高血压": "低钠饮食",
            "高血脂": "低脂饮食",
            "痛风": "低嘌呤饮食",
            "肾病": "低蛋白饮食"
        }

        for disease in diseases:
            for keyword, restriction in disease_restrictions.items():
                if keyword in disease.name:
                    restrictions.append(f"{restriction} ({disease.name})")

        # Add allergen avoidance
        for allergy in allergies:
            restrictions.append(f"避免{allergy.name}")

        return restrictions
