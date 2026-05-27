"""
Pydantic schemas for memory workspace data structures.

Each workspace has its own data model:
- SharedMemoryData: User profile, health status, preferences, behavior patterns
- GoalTrackingData: Goals, BMR/TDEE, daily targets, progress
- NutritionWorkspaceData: Diet summary, frequent foods, nutrition trends
- ChatWorkspaceData: Conversation preferences, frequent topics, interaction history
"""

from datetime import datetime, date
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from enum import IntEnum


class GoalType(IntEnum):
    """健康目标类型"""
    LOSE_WEIGHT = 1      # 减重
    GAIN_WEIGHT = 2      # 增重
    MAINTAIN = 3         # 维持
    BUILD_MUSCLE = 4     # 增肌
    LOSE_FAT = 5         # 减脂


class SeverityLevel(IntEnum):
    """严重程度等级"""
    MILD = 1
    MODERATE = 2
    SEVERE = 3


class ActivityLevel(IntEnum):
    """活动水平"""
    SEDENTARY = 1        # 久坐
    LIGHT = 2            # 轻度活动
    MODERATE = 3         # 中度活动
    ACTIVE = 4           # 重度活动
    VERY_ACTIVE = 5      # 超重度活动


# ============== Shared Memory Workspace ==============

class AllergyInfo(BaseModel):
    """过敏原信息"""
    name: str
    severity: SeverityLevel
    reaction: Optional[str] = None


class DiseaseInfo(BaseModel):
    """疾病信息"""
    name: str
    icd_code: Optional[str] = None
    status: str = "控制中"  # 控制中/活跃/已痊愈
    notes: Optional[str] = None


class MedicationInfo(BaseModel):
    """用药信息"""
    name: str
    dosage: str
    frequency: str


class FoodPreferences(BaseModel):
    """食物偏好"""
    liked_foods: List[str] = Field(default_factory=list)
    disliked_foods: List[str] = Field(default_factory=list)
    dietary_restrictions: List[str] = Field(default_factory=list)


class BehaviorPatterns(BaseModel):
    """行为模式"""
    meal_times: Dict[str, str] = Field(default_factory=lambda: {
        "breakfast": "07:30",
        "lunch": "12:30",
        "dinner": "19:00"
    })
    sleep_schedule: Dict[str, str] = Field(default_factory=lambda: {
        "bedtime": "23:00",
        "wake_time": "06:30"
    })
    exercise_routine: Optional[Dict[str, Any]] = None
    budget_level: str = "中等"


class SharedMemoryData(BaseModel):
    """共享工作区数据模型 - 所有 Agent 只读"""
    user_id: int
    last_updated: datetime = Field(default_factory=datetime.now)
    schema_version: str = "1.0"

    # 基础信息
    gender: int  # 1=男, 2=女, 3=其他
    age: int
    height: float  # cm
    weight: float  # kg
    activity_level: ActivityLevel = ActivityLevel.LIGHT

    # 健康状况
    allergies: List[AllergyInfo] = Field(default_factory=list)
    diseases: List[DiseaseInfo] = Field(default_factory=list)
    medications: List[MedicationInfo] = Field(default_factory=list)

    # 长期偏好
    food_preferences: FoodPreferences = Field(default_factory=FoodPreferences)

    # 行为模式
    behavior_patterns: BehaviorPatterns = Field(default_factory=BehaviorPatterns)


# ============== Goal Tracking Workspace ==============

class ActiveGoal(BaseModel):
    """活跃目标"""
    goal_id: int
    goal_type: GoalType
    target_weight: Optional[float] = None
    target_date: Optional[date] = None
    status: str = "进行中"  # 进行中/已完成/已暂停/已取消


class BMRTDEEData(BaseModel):
    """BMR/TDEE 计算数据"""
    bmr: float
    tdee: float
    activity_factor: float
    calculated_at: datetime = Field(default_factory=datetime.now)


class DailyTargets(BaseModel):
    """每日营养配额"""
    calories: float
    protein: float  # g
    carbs: float    # g
    fat: float      # g
    calorie_adjustment: float = 0  # 赤字/盈余


class WeightProgress(BaseModel):
    """体重进度"""
    starting_weight: float
    starting_date: date
    current_weight: float
    current_date: date
    weight_change: float
    target_remaining: Optional[float] = None
    progress_percentage: float = 0


class TodayStatus(BaseModel):
    """今日状态"""
    consumed_calories: float = 0
    consumed_protein: float = 0
    consumed_carbs: float = 0
    consumed_fat: float = 0
    remaining_calories: float = 0
    remaining_protein: float = 0
    remaining_carbs: float = 0
    remaining_fat: float = 0
    last_updated: datetime = Field(default_factory=datetime.now)


class Milestone(BaseModel):
    """里程碑"""
    description: str
    target_date: Optional[date] = None
    achieved_date: Optional[date] = None
    completed: bool = False


class GoalTrackingData(BaseModel):
    """目标追踪工作区数据模型 - Goal Agent 专属读写"""
    user_id: int
    last_updated: datetime = Field(default_factory=datetime.now)

    # 当前活跃目标
    active_goal: Optional[ActiveGoal] = None

    # 计算基准
    bmr_tdee: Optional[BMRTDEEData] = None
    daily_targets: Optional[DailyTargets] = None

    # 进度追踪
    weight_progress: Optional[WeightProgress] = None
    today_status: TodayStatus = Field(default_factory=TodayStatus)

    # 里程碑
    milestones: List[Milestone] = Field(default_factory=list)

    # Agent 生成的建议
    suggestions: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)


# ============== Nutrition Workspace ==============

class DietSummary(BaseModel):
    """饮食摘要"""
    period_days: int = 7
    avg_calories: float = 0
    avg_protein: float = 0
    avg_carbs: float = 0
    avg_fat: float = 0
    meal_regularity: str = "良好"


class FrequentFood(BaseModel):
    """高频食物"""
    name: str
    frequency: int
    avg_calories: float
    health_level: str = "B"


class NutritionTrend(BaseModel):
    """营养趋势"""
    metric: str  # 如 "蛋白质达标率"
    current_week: float
    last_week: float
    trend: str = "→"  # ↑ ↓ →


class RecentAnalysis(BaseModel):
    """近期分析记录"""
    date: date
    meal_type: str  # 早餐/午餐/晚餐/加餐
    foods: List[str]
    calories: float
    health_level: str


class NutritionWorkspaceData(BaseModel):
    """营养分析工作区数据模型 - Nutrition Agent 专属读写"""
    user_id: int
    last_updated: datetime = Field(default_factory=datetime.now)

    # 近期饮食摘要
    diet_summary: DietSummary = Field(default_factory=DietSummary)

    # 高频食物
    frequent_foods: List[FrequentFood] = Field(default_factory=list)

    # 营养趋势
    nutrition_trends: List[NutritionTrend] = Field(default_factory=list)

    # 近期分析记录
    recent_analyses: List[RecentAnalysis] = Field(default_factory=list)


# ============== Chat Workspace ==============

class ConversationPreferences(BaseModel):
    """对话偏好"""
    prefers_detailed_explanation: bool = True
    likes_data_driven_advice: bool = True
    response_style: str = "专业友善"
    topics_of_interest: List[str] = Field(default_factory=list)


class FrequentTopic(BaseModel):
    """常见问题主题"""
    topic: str
    count: int
    last_asked: Optional[date] = None


class InteractionSummary(BaseModel):
    """交互摘要"""
    date: date
    topic: str
    user_question: str
    key_points: List[str] = Field(default_factory=list)


class UserFeedback(BaseModel):
    """用户反馈记录"""
    date: date
    feedback: str
    sentiment: str = "中性"  # 正面/中性/负面


class ChatWorkspaceData(BaseModel):
    """对话工作区数据模型 - Chat Agent 专属读写"""
    user_id: int
    last_updated: datetime = Field(default_factory=datetime.now)

    # 对话偏好
    preferences: ConversationPreferences = Field(default_factory=ConversationPreferences)

    # 常见问题主题
    frequent_topics: List[FrequentTopic] = Field(default_factory=list)

    # 近期交互摘要
    recent_interactions: List[InteractionSummary] = Field(default_factory=list)

    # 用户反馈记录
    user_feedback: List[UserFeedback] = Field(default_factory=list)


# ============== Combined User Memory ==============

class UserMemoryData(BaseModel):
    """用户完整记忆数据 - 包含所有工作区"""
    shared: Optional[SharedMemoryData] = None
    goal_tracking: Optional[GoalTrackingData] = None
    nutrition: Optional[NutritionWorkspaceData] = None
    chat: Optional[ChatWorkspaceData] = None
