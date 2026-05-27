# 原有模块
from .base import BaseResponse, PaginatedResponse, PaginationParams, DateRangeParams, FileUploadResponse
from .user import (
    UserCreate, UserLogin, UserResponse, TokenResponse, RefreshTokenRequest,
    PasswordChangeRequest, UserProfileUpdate, OnboardingStepUpdate, OnboardingDataRequest,
    UserProfileResponse, HealthGoalCreate, HealthGoalResponse, DiseaseCreate, DiseaseResponse,
    AllergyCreate, AllergyResponse, WeightRecordCreate, WeightRecordResponse,
)
from .food import (
    FoodRecordCreate, FoodRecordResponse, NutritionDetailCreate, NutritionDetailResponse,
    DailyNutritionSummaryResponse, NutritionTrendParams,
)
from .chat import (
    ConversationSessionCreate, ConversationCreate, ConversationResponse,
    ConversationMessageCreate, MessageCreate, MessageResponse,
)
from .health import HealthAnalysisRequest, HealthAnalysisResponse
from .agent import (
    Macronutrients, VitaminsMinerals, HealthLevelEnum, NutritionFacts,
    Recommendations, AgentAnalysisData, AdviceDependencies,
)
from .enums import GenderEnum, ActivityLevelEnum, MealTypeEnum, GoalTypeEnum

# Milestone 1 新增模块
from .exercise import ExerciseRecordCreate, ExerciseRecordOut, ExerciseStatistics
from .water import WaterIntakeCreate, WaterIntakeOut, DailyWaterSummary, WaterStatistics
from .reminder import ReminderCreate, ReminderUpdate, ReminderOut
from .notification import NotificationResponseCreate, NotificationResponseOut
from .wellness import WellnessKnowledgeOut, DailyWellnessRecommendation, SolarTermOut