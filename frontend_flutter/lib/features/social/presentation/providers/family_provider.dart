import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';

/// 家庭成员健康摘要
class FamilyMemberSummary {
  final int userId;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final String? note;
  final double? totalCalories;
  final double? targetCalories;
  final int? waterIntake;
  final int? waterGoal;
  final String? virtualPetName;
  final String? virtualPetMood;
  final String? virtualPetBodyType;
  final int? hungerHours;
  final List<Map<String, dynamic>>? realPets;
  final Map<String, dynamic>? examSummary;

  FamilyMemberSummary({
    required this.userId,
    required this.username,
    this.realName,
    this.avatarUrl,
    this.note,
    this.totalCalories,
    this.targetCalories,
    this.waterIntake,
    this.waterGoal,
    this.virtualPetName,
    this.virtualPetMood,
    this.virtualPetBodyType,
    this.hungerHours,
    this.realPets,
    this.examSummary,
  });

  factory FamilyMemberSummary.fromJson(Map<String, dynamic> json) {
    return FamilyMemberSummary(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['real_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      note: json['note'] as String?,
      totalCalories: (json['total_calories'] as num?)?.toDouble(),
      targetCalories: (json['target_calories'] as num?)?.toDouble(),
      waterIntake: json['water_intake'] as int?,
      waterGoal: json['water_goal'] as int?,
      virtualPetName: json['virtual_pet_name'] as String?,
      virtualPetMood: json['virtual_pet_mood'] as String?,
      virtualPetBodyType: json['virtual_pet_body_type'] as String?,
      hungerHours: json['hunger_hours'] as int?,
      realPets: (json['real_pets'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      examSummary: json['exam_summary'] is Map<String, dynamic>
          ? json['exam_summary'] as Map<String, dynamic>
          : null,
    );
  }
}

/// 每日健康数据
class DailyHealthData {
  final String date;
  final double calories;
  final double burned;
  final double protein;
  final double fat;
  final double carbs;
  final int water;

  DailyHealthData({
    required this.date,
    this.calories = 0,
    this.burned = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.water = 0,
  });

  factory DailyHealthData.fromJson(Map<String, dynamic> json) {
    return DailyHealthData(
      date: json['date'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      burned: (json['burned'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      water: json['water'] as int? ?? 0,
    );
  }
}

/// 家庭异常提醒
class FamilyAlert {
  final String type;
  final int userId;
  final String userName;
  final String message;
  final String severity;

  FamilyAlert({
    required this.type,
    required this.userId,
    required this.userName,
    required this.message,
    required this.severity,
  });

  factory FamilyAlert.fromJson(Map<String, dynamic> json) {
    return FamilyAlert(
      type: json['type'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      userName: json['user_name'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? 'info',
    );
  }
}

/// 家庭看板状态
class FamilyDashboardState {
  final List<FamilyMemberSummary> members;
  final List<FamilyAlert> alerts;
  final bool isLoading;
  final String? error;

  FamilyDashboardState({
    this.members = const [],
    this.alerts = const [],
    this.isLoading = false,
    this.error,
  });

  FamilyDashboardState copyWith({
    List<FamilyMemberSummary>? members,
    List<FamilyAlert>? alerts,
    bool? isLoading,
    String? error,
  }) {
    return FamilyDashboardState(
      members: members ?? this.members,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 体重记录数据
class WeightHealthData {
  final String date;
  final double weight;
  final double? bodyFatPercentage;
  final double? bmi;

  WeightHealthData({
    required this.date,
    this.weight = 0,
    this.bodyFatPercentage,
    this.bmi,
  });

  factory WeightHealthData.fromJson(Map<String, dynamic> json) {
    return WeightHealthData(
      date: json['date'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      bodyFatPercentage: (json['body_fat_percentage'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
    );
  }
}

/// 运动记录数据
class ExerciseHealthData {
  final String date;
  final String exerciseName;
  final int durationMinutes;
  final double caloriesBurned;

  ExerciseHealthData({
    required this.date,
    this.exerciseName = '',
    this.durationMinutes = 0,
    this.caloriesBurned = 0,
  });

  factory ExerciseHealthData.fromJson(Map<String, dynamic> json) {
    return ExerciseHealthData(
      date: json['date'] as String? ?? '',
      exerciseName: json['exercise_name'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      caloriesBurned: (json['calories_burned'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 健康目标完成情况
class HealthGoalData {
  final int goalType;
  final String goalTypeName;
  final double? targetWeight;
  final String? targetDate;
  final double? startWeight;
  final double? latestWeight;

  HealthGoalData({
    this.goalType = 0,
    this.goalTypeName = '',
    this.targetWeight,
    this.targetDate,
    this.startWeight,
    this.latestWeight,
  });

  factory HealthGoalData.fromJson(Map<String, dynamic> json) {
    return HealthGoalData(
      goalType: json['goal_type'] as int? ?? 0,
      goalTypeName: json['goal_type_name'] as String? ?? '',
      targetWeight: (json['target_weight'] as num?)?.toDouble(),
      targetDate: json['target_date'] as String?,
      startWeight: (json['start_weight'] as num?)?.toDouble(),
      latestWeight: (json['latest_weight'] as num?)?.toDouble(),
    );
  }

  /// 目标完成进度（0~1），基于体重变化
  double? get progress {
    if (startWeight == null || latestWeight == null || targetWeight == null) {
      return null;
    }
    final start = startWeight!;
    final latest = latestWeight!;
    final target = targetWeight!;
    final total = (start - target).abs();
    if (total == 0) return 1.0;
    final done = (start - latest).abs();
    return (done / total).clamp(0.0, 1.0);
  }
}

/// 真实宠物信息
class RealPetData {
  final int petId;
  final String name;
  final String species;
  final String? avatarUrl;
  final int? healthScore;

  RealPetData({
    required this.petId,
    this.name = '',
    this.species = '',
    this.avatarUrl,
    this.healthScore,
  });

  factory RealPetData.fromJson(Map<String, dynamic> json) {
    return RealPetData(
      petId: json['pet_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      healthScore: json['health_score'] as int?,
    );
  }
}

/// 宠物状态（虚拟桌宠 + 真实宠物）
class FamilyPetData {
  final String virtualPetMood;
  final String virtualPetName;
  final List<RealPetData> realPets;

  FamilyPetData({
    this.virtualPetMood = 'normal',
    this.virtualPetName = '桌宠',
    this.realPets = const [],
  });

  factory FamilyPetData.fromJson(Map<String, dynamic> json) {
    return FamilyPetData(
      virtualPetMood: json['virtual_pet_mood'] as String? ?? 'normal',
      virtualPetName: json['virtual_pet_name'] as String? ?? '桌宠',
      realPets: (json['real_pets'] as List<dynamic>?)
              ?.map((e) => RealPetData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 家人健康详情状态
class MemberHealthState {
  final List<DailyHealthData> dailyData;
  final List<WeightHealthData> weightData;
  final List<ExerciseHealthData> exerciseData;
  final HealthGoalData? goal;
  final FamilyPetData? pet;
  final bool isLoading;
  final String? error;

  MemberHealthState({
    this.dailyData = const [],
    this.weightData = const [],
    this.exerciseData = const [],
    this.goal,
    this.pet,
    this.isLoading = false,
    this.error,
  });

  MemberHealthState copyWith({
    List<DailyHealthData>? dailyData,
    List<WeightHealthData>? weightData,
    List<ExerciseHealthData>? exerciseData,
    HealthGoalData? goal,
    FamilyPetData? pet,
    bool? isLoading,
    String? error,
  }) {
    return MemberHealthState(
      dailyData: dailyData ?? this.dailyData,
      weightData: weightData ?? this.weightData,
      exerciseData: exerciseData ?? this.exerciseData,
      goal: goal ?? this.goal,
      pet: pet ?? this.pet,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 家庭看板 Provider
class FamilyDashboardNotifier extends StateNotifier<FamilyDashboardState> {
  final ApiService _api = ApiService();

  FamilyDashboardNotifier() : super(FamilyDashboardState());

  /// 一次性加载看板 + 提醒
  Future<void> load() async {
    await Future.wait([loadDashboard(), loadAlerts()]);
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/family/dashboard');
      if (response.success && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final membersList = (data['family_members'] as List<dynamic>?)
                ?.map((e) =>
                    FamilyMemberSummary.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(members: membersList, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAlerts() async {
    try {
      final response = await _api.get('/family/alerts');
      if (response.success && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final alertsList = (data['alerts'] as List<dynamic>?)
                ?.map((e) => FamilyAlert.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(alerts: alertsList);
      }
    } catch (e) {
      // 静默失败
    }
  }

  /// 向家人发送喝水提醒消息
  Future<bool> remindWater(int userId) async {
    try {
      final response = await _api.post('/family/remind-water/$userId');
      return response.success;
    } catch (e) {
      return false;
    }
  }
}

/// 家人健康详情 Provider
class MemberHealthNotifier extends StateNotifier<MemberHealthState> {
  final ApiService _api = ApiService();

  MemberHealthNotifier() : super(MemberHealthState());

  Future<void> loadMemberHealth(int userId, {int days = 7}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/family/member/$userId/health',
          queryParameters: {'days': days});
      if (response.success && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final dailyDataList = (data['daily_data'] as List<dynamic>?)
                ?.map(
                    (e) => DailyHealthData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final weightDataList = (data['weight_data'] as List<dynamic>?)
                ?.map(
                    (e) => WeightHealthData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final exerciseDataList = (data['exercise_data'] as List<dynamic>?)
                ?.map((e) =>
                    ExerciseHealthData.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final goal = data['goal'] is Map<String, dynamic>
            ? HealthGoalData.fromJson(data['goal'] as Map<String, dynamic>)
            : null;
        final pet = data['pet'] is Map<String, dynamic>
            ? FamilyPetData.fromJson(data['pet'] as Map<String, dynamic>)
            : null;
        state = state.copyWith(
          dailyData: dailyDataList,
          weightData: weightDataList,
          exerciseData: exerciseDataList,
          goal: goal,
          pet: pet,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// 家庭成就
class FamilyAchievement {
  final int id;
  final String achievementType;
  final String title;
  final Map<String, dynamic>? metadata;
  final String? unlockedAt;

  FamilyAchievement({
    required this.id,
    required this.achievementType,
    required this.title,
    this.metadata,
    this.unlockedAt,
  });

  factory FamilyAchievement.fromJson(Map<String, dynamic> json) {
    return FamilyAchievement(
      id: json['id'] as int? ?? 0,
      achievementType: json['achievement_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      unlockedAt: json['unlocked_at'] as String?,
    );
  }
}

/// 家庭成就状态
class FamilyAchievementsState {
  final List<FamilyAchievement> achievements;
  final bool healthFamilyDayUnlocked;
  final bool isLoading;
  final bool isChecking;
  final String? checkResult;
  final String? error;

  FamilyAchievementsState({
    this.achievements = const [],
    this.healthFamilyDayUnlocked = false,
    this.isLoading = false,
    this.isChecking = false,
    this.checkResult,
    this.error,
  });

  FamilyAchievementsState copyWith({
    List<FamilyAchievement>? achievements,
    bool? healthFamilyDayUnlocked,
    bool? isLoading,
    bool? isChecking,
    String? checkResult,
    String? error,
  }) {
    return FamilyAchievementsState(
      achievements: achievements ?? this.achievements,
      healthFamilyDayUnlocked:
          healthFamilyDayUnlocked ?? this.healthFamilyDayUnlocked,
      isLoading: isLoading ?? this.isLoading,
      isChecking: isChecking ?? this.isChecking,
      checkResult: checkResult ?? this.checkResult,
      error: error,
    );
  }
}

/// 家庭成就 Provider
class FamilyAchievementsNotifier
    extends StateNotifier<FamilyAchievementsState> {
  final ApiService _api = ApiService();

  FamilyAchievementsNotifier() : super(FamilyAchievementsState());

  /// 加载已解锁成就
  Future<void> loadAchievements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/family/achievements');
      if (response.success && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['achievements'] as List<dynamic>?)
                ?.map((e) =>
                    FamilyAchievement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(
          achievements: list,
          healthFamilyDayUnlocked:
              data['health_family_day_unlocked'] as bool? ?? false,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 判定"健康家庭"成就是否达成（未解锁时点击触发）
  Future<void> checkHealthFamilyDay() async {
    state = state.copyWith(isChecking: true);
    try {
      final response = await _api.post('/family/check-health-day');
      if (response.success && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final unlocked = data['unlocked'] as bool? ?? false;
        if (unlocked) {
          final ach = data['achievement'];
          final newAch = ach is Map<String, dynamic>
              ? FamilyAchievement.fromJson(ach)
              : FamilyAchievement(
                  id: 0,
                  achievementType: 'health_family_day',
                  title: '健康家庭',
                  unlockedAt: DateTime.now().toIso8601String(),
                );
          state = state.copyWith(
            achievements: [newAch, ...state.achievements],
            healthFamilyDayUnlocked: true,
            isChecking: false,
            checkResult: '🎉 已解锁健康家庭成就',
          );
        } else {
          final reason = data['reason'] as String?;
          state = state.copyWith(
            isChecking: false,
            checkResult: reason != null && reason.isNotEmpty
                ? '未解锁：$reason'
                : '健康家庭成就未解锁',
          );
        }
      } else {
        state = state.copyWith(
          isChecking: false,
          checkResult:
              '判定失败：${response.message.isNotEmpty ? response.message : '请稍后重试'}',
        );
      }
    } catch (e) {
      state = state.copyWith(isChecking: false, checkResult: '判定失败：$e');
    }
  }
}

final familyAchievementsProvider =
    StateNotifierProvider<FamilyAchievementsNotifier, FamilyAchievementsState>(
        (ref) {
  return FamilyAchievementsNotifier();
});

final familyDashboardProvider =
    StateNotifierProvider<FamilyDashboardNotifier, FamilyDashboardState>((ref) {
  return FamilyDashboardNotifier();
});

final memberHealthProvider =
    StateNotifierProvider<MemberHealthNotifier, MemberHealthState>((ref) {
  return MemberHealthNotifier();
});
