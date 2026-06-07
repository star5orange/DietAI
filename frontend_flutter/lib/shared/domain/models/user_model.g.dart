// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: (json['status'] as num).toInt(),
      createdAt: json['created_at'] as String,
      lastLoginAt: json['last_login_at'] as String?,
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'phone': instance.phone,
      'avatar_url': instance.avatarUrl,
      'status': instance.status,
      'created_at': instance.createdAt,
      'last_login_at': instance.lastLoginAt,
    };

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => UserProfile(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      realName: json['real_name'] as String?,
      gender: (json['gender'] as num?)?.toInt(),
      birthDate: json['birth_date'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      activityLevel: (json['activity_level'] as num?)?.toInt(),
      occupation: json['occupation'] as String?,
      region: json['region'] as String?,
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      foodDislikes: (json['food_dislikes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      wakeUpTime: json['wake_up_time'] as String?,
      sleepTime: json['sleep_time'] as String?,
      mealTimes: (json['meal_times'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      healthStatus: (json['health_status'] as num?)?.toInt(),
      onboardingCompleted: json['onboarding_completed'] as bool?,
      onboardingStep: (json['onboarding_step'] as num?)?.toInt(),
      constitutionType: json['constitution_type'] as String?,
      crowdTag: json['crowd_tag'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'real_name': instance.realName,
      'gender': instance.gender,
      'birth_date': instance.birthDate,
      'height': instance.height,
      'weight': instance.weight,
      'bmi': instance.bmi,
      'activity_level': instance.activityLevel,
      'occupation': instance.occupation,
      'region': instance.region,
      'dietary_preferences': instance.dietaryPreferences,
      'food_dislikes': instance.foodDislikes,
      'wake_up_time': instance.wakeUpTime,
      'sleep_time': instance.sleepTime,
      'meal_times': instance.mealTimes,
      'health_status': instance.healthStatus,
      'onboarding_completed': instance.onboardingCompleted,
      'onboarding_step': instance.onboardingStep,
      'constitution_type': instance.constitutionType,
      'crowd_tag': instance.crowdTag,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
      username: json['username'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'password': instance.password,
    };

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      username: json['username'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'password': instance.password,
      'phone': instance.phone,
    };

AuthResponse _$AuthResponseFromJson(Map<String, dynamic> json) => AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
    );

Map<String, dynamic> _$AuthResponseToJson(AuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_type': instance.tokenType,
      'expires_in': instance.expiresIn,
    };

ChangePasswordRequest _$ChangePasswordRequestFromJson(
        Map<String, dynamic> json) =>
    ChangePasswordRequest(
      oldPassword: json['old_password'] as String,
      newPassword: json['new_password'] as String,
    );

Map<String, dynamic> _$ChangePasswordRequestToJson(
        ChangePasswordRequest instance) =>
    <String, dynamic>{
      'old_password': instance.oldPassword,
      'new_password': instance.newPassword,
    };

RefreshTokenRequest _$RefreshTokenRequestFromJson(Map<String, dynamic> json) =>
    RefreshTokenRequest(
      refreshToken: json['refresh_token'] as String,
    );

Map<String, dynamic> _$RefreshTokenRequestToJson(
        RefreshTokenRequest instance) =>
    <String, dynamic>{
      'refresh_token': instance.refreshToken,
    };

UserProfileUpdateRequest _$UserProfileUpdateRequestFromJson(
        Map<String, dynamic> json) =>
    UserProfileUpdateRequest(
      realName: json['real_name'] as String?,
      gender: (json['gender'] as num?)?.toInt(),
      birthDate: json['birth_date'] as String?,
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      activityLevel: (json['activity_level'] as num?)?.toInt(),
      occupation: json['occupation'] as String?,
      region: json['region'] as String?,
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      foodDislikes: (json['food_dislikes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      wakeUpTime: json['wake_up_time'] as String?,
      sleepTime: json['sleep_time'] as String?,
      mealTimes: (json['meal_times'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      healthStatus: (json['health_status'] as num?)?.toInt(),
      constitutionType: json['constitution_type'] as String?,
      crowdTag: json['crowd_tag'] as String?,
    );

Map<String, dynamic> _$UserProfileUpdateRequestToJson(
        UserProfileUpdateRequest instance) =>
    <String, dynamic>{
      'real_name': instance.realName,
      'gender': instance.gender,
      'birth_date': instance.birthDate,
      'height': instance.height,
      'weight': instance.weight,
      'activity_level': instance.activityLevel,
      'occupation': instance.occupation,
      'region': instance.region,
      'dietary_preferences': instance.dietaryPreferences,
      'food_dislikes': instance.foodDislikes,
      'wake_up_time': instance.wakeUpTime,
      'sleep_time': instance.sleepTime,
      'meal_times': instance.mealTimes,
      'health_status': instance.healthStatus,
      'constitution_type': instance.constitutionType,
      'crowd_tag': instance.crowdTag,
    };

HealthGoal _$HealthGoalFromJson(Map<String, dynamic> json) => HealthGoal(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      goalType: (json['goal_type'] as num).toInt(),
      targetWeight: (json['target_weight'] as num?)?.toDouble(),
      targetDate: json['target_date'] as String?,
      currentStatus: (json['current_status'] as num).toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$HealthGoalToJson(HealthGoal instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'goal_type': instance.goalType,
      'target_weight': instance.targetWeight,
      'target_date': instance.targetDate,
      'current_status': instance.currentStatus,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

HealthGoalCreateRequest _$HealthGoalCreateRequestFromJson(
        Map<String, dynamic> json) =>
    HealthGoalCreateRequest(
      goalType: (json['goal_type'] as num).toInt(),
      targetWeight: (json['target_weight'] as num?)?.toDouble(),
      targetDate: json['target_date'] as String?,
    );

Map<String, dynamic> _$HealthGoalCreateRequestToJson(
        HealthGoalCreateRequest instance) =>
    <String, dynamic>{
      'goal_type': instance.goalType,
      'target_weight': instance.targetWeight,
      'target_date': instance.targetDate,
    };

Disease _$DiseaseFromJson(Map<String, dynamic> json) => Disease(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      diseaseCode: json['disease_code'] as String?,
      diseaseName: json['disease_name'] as String,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      diagnosedDate: json['diagnosed_date'] as String?,
      isCurrent: json['is_current'] as bool,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$DiseaseToJson(Disease instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'disease_code': instance.diseaseCode,
      'disease_name': instance.diseaseName,
      'severity_level': instance.severityLevel,
      'diagnosed_date': instance.diagnosedDate,
      'is_current': instance.isCurrent,
      'notes': instance.notes,
      'created_at': instance.createdAt,
    };

DiseaseCreateRequest _$DiseaseCreateRequestFromJson(
        Map<String, dynamic> json) =>
    DiseaseCreateRequest(
      diseaseCode: json['disease_code'] as String?,
      diseaseName: json['disease_name'] as String,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      diagnosedDate: json['diagnosed_date'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$DiseaseCreateRequestToJson(
        DiseaseCreateRequest instance) =>
    <String, dynamic>{
      'disease_code': instance.diseaseCode,
      'disease_name': instance.diseaseName,
      'severity_level': instance.severityLevel,
      'diagnosed_date': instance.diagnosedDate,
      'notes': instance.notes,
    };

DiseaseUpdateRequest _$DiseaseUpdateRequestFromJson(
        Map<String, dynamic> json) =>
    DiseaseUpdateRequest(
      diseaseCode: json['disease_code'] as String?,
      diseaseName: json['disease_name'] as String?,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      diagnosedDate: json['diagnosed_date'] as String?,
      isCurrent: json['is_current'] as bool?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$DiseaseUpdateRequestToJson(
        DiseaseUpdateRequest instance) =>
    <String, dynamic>{
      'disease_code': instance.diseaseCode,
      'disease_name': instance.diseaseName,
      'severity_level': instance.severityLevel,
      'diagnosed_date': instance.diagnosedDate,
      'is_current': instance.isCurrent,
      'notes': instance.notes,
    };

Allergy _$AllergyFromJson(Map<String, dynamic> json) => Allergy(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      allergenType: (json['allergen_type'] as num).toInt(),
      allergenName: json['allergen_name'] as String,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      reactionDescription: json['reaction_description'] as String?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$AllergyToJson(Allergy instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'allergen_type': instance.allergenType,
      'allergen_name': instance.allergenName,
      'severity_level': instance.severityLevel,
      'reaction_description': instance.reactionDescription,
      'created_at': instance.createdAt,
    };

AllergyCreateRequest _$AllergyCreateRequestFromJson(
        Map<String, dynamic> json) =>
    AllergyCreateRequest(
      allergenType: (json['allergen_type'] as num).toInt(),
      allergenName: json['allergen_name'] as String,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      reactionDescription: json['reaction_description'] as String?,
    );

Map<String, dynamic> _$AllergyCreateRequestToJson(
        AllergyCreateRequest instance) =>
    <String, dynamic>{
      'allergen_type': instance.allergenType,
      'allergen_name': instance.allergenName,
      'severity_level': instance.severityLevel,
      'reaction_description': instance.reactionDescription,
    };

AllergyUpdateRequest _$AllergyUpdateRequestFromJson(
        Map<String, dynamic> json) =>
    AllergyUpdateRequest(
      allergenType: (json['allergen_type'] as num?)?.toInt(),
      allergenName: json['allergen_name'] as String?,
      severityLevel: (json['severity_level'] as num?)?.toInt(),
      reactionDescription: json['reaction_description'] as String?,
    );

Map<String, dynamic> _$AllergyUpdateRequestToJson(
        AllergyUpdateRequest instance) =>
    <String, dynamic>{
      'allergen_type': instance.allergenType,
      'allergen_name': instance.allergenName,
      'severity_level': instance.severityLevel,
      'reaction_description': instance.reactionDescription,
    };

WeightRecord _$WeightRecordFromJson(Map<String, dynamic> json) => WeightRecord(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      weight: (json['weight'] as num).toDouble(),
      bodyFatPercentage: (json['body_fat_percentage'] as num?)?.toDouble(),
      muscleMass: (json['muscle_mass'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      measuredAt: json['measured_at'] as String,
      notes: json['notes'] as String?,
      deviceType: json['device_type'] as String?,
      createdAt: json['created_at'] as String,
    );

Map<String, dynamic> _$WeightRecordToJson(WeightRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'weight': instance.weight,
      'body_fat_percentage': instance.bodyFatPercentage,
      'muscle_mass': instance.muscleMass,
      'bmi': instance.bmi,
      'measured_at': instance.measuredAt,
      'notes': instance.notes,
      'device_type': instance.deviceType,
      'created_at': instance.createdAt,
    };

WeightRecordCreateRequest _$WeightRecordCreateRequestFromJson(
        Map<String, dynamic> json) =>
    WeightRecordCreateRequest(
      weight: (json['weight'] as num).toDouble(),
      bodyFatPercentage: (json['body_fat_percentage'] as num?)?.toDouble(),
      muscleMass: (json['muscle_mass'] as num?)?.toDouble(),
      measuredAt: json['measured_at'] as String?,
      notes: json['notes'] as String?,
      deviceType: json['device_type'] as String?,
    );

Map<String, dynamic> _$WeightRecordCreateRequestToJson(
        WeightRecordCreateRequest instance) =>
    <String, dynamic>{
      'weight': instance.weight,
      'body_fat_percentage': instance.bodyFatPercentage,
      'muscle_mass': instance.muscleMass,
      'measured_at': instance.measuredAt,
      'notes': instance.notes,
      'device_type': instance.deviceType,
    };

OnboardingStepUpdateRequest _$OnboardingStepUpdateRequestFromJson(
        Map<String, dynamic> json) =>
    OnboardingStepUpdateRequest(
      step: (json['step'] as num).toInt(),
      data: json['data'] as Map<String, dynamic>?,
      completed: json['completed'] as bool?,
    );

Map<String, dynamic> _$OnboardingStepUpdateRequestToJson(
        OnboardingStepUpdateRequest instance) =>
    <String, dynamic>{
      'step': instance.step,
      'data': instance.data,
      'completed': instance.completed,
    };

OnboardingCompleteRequest _$OnboardingCompleteRequestFromJson(
        Map<String, dynamic> json) =>
    OnboardingCompleteRequest(
      basicInfo: json['basic_info'] as Map<String, dynamic>?,
      physicalData: json['physical_data'] as Map<String, dynamic>?,
      healthGoals: (json['health_goals'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      dietaryPreferences: (json['dietary_preferences'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      medicalConditions: (json['medical_conditions'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      allergies: (json['allergies'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      lifestyleHabits: json['lifestyle_habits'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OnboardingCompleteRequestToJson(
        OnboardingCompleteRequest instance) =>
    <String, dynamic>{
      'basic_info': instance.basicInfo,
      'physical_data': instance.physicalData,
      'health_goals': instance.healthGoals,
      'dietary_preferences': instance.dietaryPreferences,
      'medical_conditions': instance.medicalConditions,
      'allergies': instance.allergies,
      'lifestyle_habits': instance.lifestyleHabits,
    };

OnboardingStatus _$OnboardingStatusFromJson(Map<String, dynamic> json) =>
    OnboardingStatus(
      onboardingCompleted: json['onboarding_completed'] as bool,
      currentStep: (json['current_step'] as num).toInt(),
      totalSteps: (json['total_steps'] as num).toInt(),
      nextStep: (json['next_step'] as num?)?.toInt(),
    );

Map<String, dynamic> _$OnboardingStatusToJson(OnboardingStatus instance) =>
    <String, dynamic>{
      'onboarding_completed': instance.onboardingCompleted,
      'current_step': instance.currentStep,
      'total_steps': instance.totalSteps,
      'next_step': instance.nextStep,
    };
