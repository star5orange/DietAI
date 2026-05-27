import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// 用户模型
@JsonSerializable()
class User {
  final int id;
  final String username;
  final String email;
  final String? phone;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final int status;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'last_login_at')
  final String? lastLoginAt;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 用户资料模型
@JsonSerializable()
class UserProfile {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'real_name')
  final String? realName;
  final int? gender; // 1: 男, 2: 女, 3: 其他
  @JsonKey(name: 'birth_date')
  final String? birthDate;
  final double? height;
  final double? weight;
  final double? bmi;
  @JsonKey(name: 'activity_level')
  final int? activityLevel;
  final String? occupation;
  final String? region;
  @JsonKey(name: 'dietary_preferences')
  final List<String>? dietaryPreferences;
  @JsonKey(name: 'food_dislikes')
  final List<String>? foodDislikes;
  @JsonKey(name: 'wake_up_time')
  final String? wakeUpTime;
  @JsonKey(name: 'sleep_time')
  final String? sleepTime;
  @JsonKey(name: 'meal_times')
  final Map<String, String>? mealTimes;
  @JsonKey(name: 'health_status')
  final int? healthStatus; // 1: 健康, 2: 亚健康, 3: 有疾病
  @JsonKey(name: 'onboarding_completed')
  final bool? onboardingCompleted;
  @JsonKey(name: 'onboarding_step')
  final int? onboardingStep;
  @JsonKey(name: 'constitution_type')
  final String? constitutionType;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const UserProfile({
    required this.id,
    required this.userId,
    this.realName,
    this.gender,
    this.birthDate,
    this.height,
    this.weight,
    this.bmi,
    this.activityLevel,
    this.occupation,
    this.region,
    this.dietaryPreferences,
    this.foodDislikes,
    this.wakeUpTime,
    this.sleepTime,
    this.mealTimes,
    this.healthStatus,
    this.onboardingCompleted,
    this.onboardingStep,
    this.constitutionType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileToJson(this);

  /// 创建用户资料副本，可选择性更新字段
  UserProfile copyWith({
    int? id,
    int? userId,
    String? realName,
    int? gender,
    String? birthDate,
    double? height,
    double? weight,
    double? bmi,
    int? activityLevel,
    String? occupation,
    String? region,
    List<String>? dietaryPreferences,
    List<String>? foodDislikes,
    String? wakeUpTime,
    String? sleepTime,
    Map<String, String>? mealTimes,
    int? healthStatus,
    bool? onboardingCompleted,
    int? onboardingStep,
    String? constitutionType,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      realName: realName ?? this.realName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      activityLevel: activityLevel ?? this.activityLevel,
      occupation: occupation ?? this.occupation,
      region: region ?? this.region,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      foodDislikes: foodDislikes ?? this.foodDislikes,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      sleepTime: sleepTime ?? this.sleepTime,
      mealTimes: mealTimes ?? this.mealTimes,
      healthStatus: healthStatus ?? this.healthStatus,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      constitutionType: constitutionType ?? this.constitutionType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 获取性别描述
  String get genderText {
    switch (gender) {
      case 1:
        return '男';
      case 2:
        return '女';
      case 3:
        return '其他';
      default:
        return '未设置';
    }
  }

  /// 获取活动级别描述
  String get activityLevelText {
    switch (activityLevel) {
      case 1:
        return '久坐不动';
      case 2:
        return '轻度活动';
      case 3:
        return '中度活动';
      case 4:
        return '重度活动';
      case 5:
        return '超重度活动';
      default:
        return '未设置';
    }
  }

  /// 获取健康状态描述
  String get healthStatusText {
    switch (healthStatus) {
      case 1:
        return '健康';
      case 2:
        return '亚健康';
      case 3:
        return '有疾病';
      default:
        return '未评估';
    }
  }

  /// 获取BMI状态
  String get bmiStatus {
    if (bmi == null) return '未计算';

    if (bmi! < 18.5) return '偏瘦';
    if (bmi! < 24) return '正常';
    if (bmi! < 28) return '偏胖';
    return '肥胖';
  }

  /// 检查是否完成引导
  bool get isOnboardingCompleted => onboardingCompleted ?? false;
}

/// 登录请求模型
@JsonSerializable()
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// 注册请求模型
@JsonSerializable()
class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final String? phone;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.phone,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

/// 认证响应模型
@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token')
  final String accessToken;
  @JsonKey(name: 'refresh_token')
  final String refreshToken;
  @JsonKey(name: 'token_type')
  final String tokenType;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

/// 密码修改请求模型
@JsonSerializable()
class ChangePasswordRequest {
  @JsonKey(name: 'old_password')
  final String oldPassword;
  @JsonKey(name: 'new_password')
  final String newPassword;

  const ChangePasswordRequest({
    required this.oldPassword,
    required this.newPassword,
  });

  factory ChangePasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ChangePasswordRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChangePasswordRequestToJson(this);
}

/// 刷新令牌请求模型
@JsonSerializable()
class RefreshTokenRequest {
  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  const RefreshTokenRequest({
    required this.refreshToken,
  });

  factory RefreshTokenRequest.fromJson(Map<String, dynamic> json) =>
      _$RefreshTokenRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RefreshTokenRequestToJson(this);
}

/// 用户资料更新请求模型
@JsonSerializable()
class UserProfileUpdateRequest {
  @JsonKey(name: 'real_name')
  final String? realName;
  final int? gender;
  @JsonKey(name: 'birth_date')
  final String? birthDate;
  final double? height;
  final double? weight;
  @JsonKey(name: 'activity_level')
  final int? activityLevel;
  final String? occupation;
  final String? region;
  @JsonKey(name: 'dietary_preferences')
  final List<String>? dietaryPreferences;
  @JsonKey(name: 'food_dislikes')
  final List<String>? foodDislikes;
  @JsonKey(name: 'wake_up_time')
  final String? wakeUpTime;
  @JsonKey(name: 'sleep_time')
  final String? sleepTime;
  @JsonKey(name: 'meal_times')
  final Map<String, String>? mealTimes;
  @JsonKey(name: 'health_status')
  final int? healthStatus;
  @JsonKey(name: 'constitution_type')
  final String? constitutionType;

  const UserProfileUpdateRequest({
    this.realName,
    this.gender,
    this.birthDate,
    this.height,
    this.weight,
    this.activityLevel,
    this.occupation,
    this.region,
    this.dietaryPreferences,
    this.foodDislikes,
    this.wakeUpTime,
    this.sleepTime,
    this.mealTimes,
    this.healthStatus,
    this.constitutionType,
  });

  factory UserProfileUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$UserProfileUpdateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UserProfileUpdateRequestToJson(this);
}

/// 健康目标模型
@JsonSerializable()
class HealthGoal {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'goal_type')
  final int goalType; // 1:减重 2:增重 3:维持 4:增肌 5:减脂
  @JsonKey(name: 'target_weight')
  final double? targetWeight;
  @JsonKey(name: 'target_date')
  final String? targetDate;
  @JsonKey(name: 'current_status')
  final int currentStatus; // 1:进行中 2:已完成 3:已暂停 4:已取消
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const HealthGoal({
    required this.id,
    required this.userId,
    required this.goalType,
    this.targetWeight,
    this.targetDate,
    required this.currentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthGoal.fromJson(Map<String, dynamic> json) =>
      _$HealthGoalFromJson(json);
  Map<String, dynamic> toJson() => _$HealthGoalToJson(this);

  /// 获取目标类型描述
  String get goalTypeText {
    switch (goalType) {
      case 1:
        return '减重';
      case 2:
        return '增重';
      case 3:
        return '维持';
      case 4:
        return '增肌';
      case 5:
        return '减脂';
      default:
        return '未知';
    }
  }

  /// 获取状态描述
  String get statusText {
    switch (currentStatus) {
      case 1:
        return '进行中';
      case 2:
        return '已完成';
      case 3:
        return '已暂停';
      case 4:
        return '已取消';
      default:
        return '未知';
    }
  }
}

/// 健康目标创建请求模型
@JsonSerializable()
class HealthGoalCreateRequest {
  @JsonKey(name: 'goal_type')
  final int goalType;
  @JsonKey(name: 'target_weight')
  final double? targetWeight;
  @JsonKey(name: 'target_date')
  final String? targetDate;

  const HealthGoalCreateRequest({
    required this.goalType,
    this.targetWeight,
    this.targetDate,
  });

  factory HealthGoalCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$HealthGoalCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$HealthGoalCreateRequestToJson(this);
}

/// 疾病信息模型
@JsonSerializable()
class Disease {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'disease_code')
  final String? diseaseCode;
  @JsonKey(name: 'disease_name')
  final String diseaseName;
  @JsonKey(name: 'severity_level')
  final int? severityLevel; // 1:轻度 2:中度 3:重度
  @JsonKey(name: 'diagnosed_date')
  final String? diagnosedDate;
  @JsonKey(name: 'is_current')
  final bool isCurrent;
  final String? notes;
  @JsonKey(name: 'created_at')
  final String createdAt;

  const Disease({
    required this.id,
    required this.userId,
    this.diseaseCode,
    required this.diseaseName,
    this.severityLevel,
    this.diagnosedDate,
    required this.isCurrent,
    this.notes,
    required this.createdAt,
  });

  factory Disease.fromJson(Map<String, dynamic> json) =>
      _$DiseaseFromJson(json);
  Map<String, dynamic> toJson() => _$DiseaseToJson(this);

  /// 获取严重程度描述
  String get severityText {
    switch (severityLevel) {
      case 1:
        return '轻度';
      case 2:
        return '中度';
      case 3:
        return '重度';
      default:
        return '未评估';
    }
  }
}

/// 疾病信息创建请求模型
@JsonSerializable()
class DiseaseCreateRequest {
  @JsonKey(name: 'disease_code')
  final String? diseaseCode;
  @JsonKey(name: 'disease_name')
  final String diseaseName;
  @JsonKey(name: 'severity_level')
  final int? severityLevel;
  @JsonKey(name: 'diagnosed_date')
  final String? diagnosedDate;
  final String? notes;

  const DiseaseCreateRequest({
    this.diseaseCode,
    required this.diseaseName,
    this.severityLevel,
    this.diagnosedDate,
    this.notes,
  });

  factory DiseaseCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$DiseaseCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$DiseaseCreateRequestToJson(this);
}

/// 过敏信息模型
@JsonSerializable()
class Allergy {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'allergen_type')
  final int allergenType; // 1:食物 2:药物 3:环境 4:其他
  @JsonKey(name: 'allergen_name')
  final String allergenName;
  @JsonKey(name: 'severity_level')
  final int? severityLevel; // 1:轻度 2:中度 3:重度
  @JsonKey(name: 'reaction_description')
  final String? reactionDescription;
  @JsonKey(name: 'created_at')
  final String createdAt;

  const Allergy({
    required this.id,
    required this.userId,
    required this.allergenType,
    required this.allergenName,
    this.severityLevel,
    this.reactionDescription,
    required this.createdAt,
  });

  factory Allergy.fromJson(Map<String, dynamic> json) =>
      _$AllergyFromJson(json);
  Map<String, dynamic> toJson() => _$AllergyToJson(this);

  /// 获取过敏原类型描述
  String get allergenTypeText {
    switch (allergenType) {
      case 1:
        return '食物';
      case 2:
        return '药物';
      case 3:
        return '环境';
      case 4:
        return '其他';
      default:
        return '未知';
    }
  }

  /// 获取严重程度描述
  String get severityText {
    switch (severityLevel) {
      case 1:
        return '轻度';
      case 2:
        return '中度';
      case 3:
        return '重度';
      default:
        return '未评估';
    }
  }
}

/// 过敏信息创建请求模型
@JsonSerializable()
class AllergyCreateRequest {
  @JsonKey(name: 'allergen_type')
  final int allergenType;
  @JsonKey(name: 'allergen_name')
  final String allergenName;
  @JsonKey(name: 'severity_level')
  final int? severityLevel;
  @JsonKey(name: 'reaction_description')
  final String? reactionDescription;

  const AllergyCreateRequest({
    required this.allergenType,
    required this.allergenName,
    this.severityLevel,
    this.reactionDescription,
  });

  factory AllergyCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$AllergyCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AllergyCreateRequestToJson(this);
}

/// 体重记录模型
@JsonSerializable()
class WeightRecord {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  final double weight;
  @JsonKey(name: 'body_fat_percentage')
  final double? bodyFatPercentage;
  @JsonKey(name: 'muscle_mass')
  final double? muscleMass;
  final double? bmi;
  @JsonKey(name: 'measured_at')
  final String measuredAt;
  final String? notes;
  @JsonKey(name: 'device_type')
  final String? deviceType;
  @JsonKey(name: 'created_at')
  final String createdAt;

  const WeightRecord({
    required this.id,
    required this.userId,
    required this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.bmi,
    required this.measuredAt,
    this.notes,
    this.deviceType,
    required this.createdAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) =>
      _$WeightRecordFromJson(json);
  Map<String, dynamic> toJson() => _$WeightRecordToJson(this);
}

/// 体重记录创建请求模型
@JsonSerializable()
class WeightRecordCreateRequest {
  final double weight;
  @JsonKey(name: 'body_fat_percentage')
  final double? bodyFatPercentage;
  @JsonKey(name: 'muscle_mass')
  final double? muscleMass;
  @JsonKey(name: 'measured_at')
  final String? measuredAt;
  final String? notes;
  @JsonKey(name: 'device_type')
  final String? deviceType;

  const WeightRecordCreateRequest({
    required this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.measuredAt,
    this.notes,
    this.deviceType,
  });

  factory WeightRecordCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$WeightRecordCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WeightRecordCreateRequestToJson(this);
}

/// 引导步骤更新请求模型
@JsonSerializable()
class OnboardingStepUpdateRequest {
  final int step;
  final Map<String, dynamic>? data;
  final bool? completed;

  const OnboardingStepUpdateRequest({
    required this.step,
    this.data,
    this.completed,
  });

  factory OnboardingStepUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStepUpdateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$OnboardingStepUpdateRequestToJson(this);
}

/// 引导完成数据请求模型
@JsonSerializable()
class OnboardingCompleteRequest {
  @JsonKey(name: 'basic_info')
  final Map<String, dynamic>? basicInfo;
  @JsonKey(name: 'physical_data')
  final Map<String, dynamic>? physicalData;
  @JsonKey(name: 'health_goals')
  final List<Map<String, dynamic>>? healthGoals;
  @JsonKey(name: 'dietary_preferences')
  final List<String>? dietaryPreferences;
  @JsonKey(name: 'medical_conditions')
  final List<Map<String, dynamic>>? medicalConditions;
  final List<Map<String, dynamic>>? allergies;
  @JsonKey(name: 'lifestyle_habits')
  final Map<String, dynamic>? lifestyleHabits;

  const OnboardingCompleteRequest({
    this.basicInfo,
    this.physicalData,
    this.healthGoals,
    this.dietaryPreferences,
    this.medicalConditions,
    this.allergies,
    this.lifestyleHabits,
  });

  factory OnboardingCompleteRequest.fromJson(Map<String, dynamic> json) =>
      _$OnboardingCompleteRequestFromJson(json);
  Map<String, dynamic> toJson() => _$OnboardingCompleteRequestToJson(this);
}

/// 引导状态响应模型
@JsonSerializable()
class OnboardingStatus {
  @JsonKey(name: 'onboarding_completed')
  final bool onboardingCompleted;
  @JsonKey(name: 'current_step')
  final int currentStep;
  @JsonKey(name: 'total_steps')
  final int totalSteps;
  @JsonKey(name: 'next_step')
  final int? nextStep;

  const OnboardingStatus({
    required this.onboardingCompleted,
    required this.currentStep,
    required this.totalSteps,
    this.nextStep,
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) =>
      _$OnboardingStatusFromJson(json);
  Map<String, dynamic> toJson() => _$OnboardingStatusToJson(this);
}
