# 原有模块
from .base import BaseResponse, PaginatedResponse, PaginationParams, DateRangeParams, FileUploadResponse
from .user import (
    UserCreate, UserLogin, UserResponse, TokenResponse, RefreshTokenRequest,
    PasswordChangeRequest, UserProfileUpdate, OnboardingStepUpdate, OnboardingDataRequest,
    UserProfileResponse, HealthGoalCreate, HealthGoalResponse, DiseaseCreate, DiseaseResponse,
    AllergyCreate, AllergyResponse, WeightRecordCreate, WeightRecordResponse,
    # 密码重置相关
    ForgotPasswordRequest, VerifyResetCodeRequest, ResetPasswordRequest,
)
from .food import (
    FoodRecordCreate, FoodRecordConfirmCreate, FoodRecordResponse, NutritionDetailCreate, NutritionDetailResponse,
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
from .constitution import (
    ConstitutionQuizRequest, QuizAnswer, ConstitutionQuizResponse,
    ConstitutionTypeInfo, CONSTITUTION_TYPES, CONSTITUTION_DIET_ADVICE, QUIZ_QUESTIONS
)

# Milestone 4 新增模块
from .social import (
    RelationshipType, RelationshipStatus,
    FriendRequestCreate, FriendRequestResponse,
    UserRelationResponse, UserRelationWithProfile,
    FamilyAddRequest, UserSearchResult, FriendListResponse,
    DataPermissionUpdate, DataPermissionResponse,
    RelationNoteUpdate,
)
from .message import (
    MessageType, MessageSend, MessageResponse, MessageWithSender,
    ChatRoomResponse, MessageHistoryRequest, MessageHistoryResponse,
    PokeRequest, WSMessage,
)
from .exam import (
    ReportType, MetricStatus,
    ExamReportUpload, ExamReportUploadResponse,
    ExamReportResponse, ExamReportListResponse,
    ExamMetricResponse, ExamMetricUpdate,
    ExamReportFollowupUpdate, ExamReportReassign,
    MetricTrendPoint, MetricTrendResponse,
    ExamSummaryResponse, ExamAdviceResponse,
)