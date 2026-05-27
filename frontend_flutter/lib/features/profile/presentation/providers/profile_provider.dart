import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../domain/services/user_service.dart';

/// 用户服务提供者
final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ApiService());
});

/// 用户资料状态管理
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final UserService _userService;

  UserProfileNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载用户资料
  Future<void> loadUserProfile() async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getUserProfile();
      if (response.isSuccess) {
        state = AsyncValue.data(response.data);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 更新用户资料
  Future<bool> updateUserProfile(UserProfileUpdateRequest request) async {
    try {
      final response = await _userService.updateUserProfile(request);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data);
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 获取当前用户资料
  UserProfile? get currentProfile => state.value;
}

/// 用户资料提供者
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return UserProfileNotifier(userService);
});

/// 健康目标状态管理
class HealthGoalsNotifier extends StateNotifier<AsyncValue<List<HealthGoal>>> {
  final UserService _userService;

  HealthGoalsNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载健康目标
  Future<void> loadHealthGoals({int? statusFilter}) async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getHealthGoals(statusFilter: statusFilter);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data ?? []);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 创建健康目标
  Future<bool> createHealthGoal(HealthGoalCreateRequest request) async {
    try {
      final response = await _userService.createHealthGoal(request);
      if (response.isSuccess) {
        // 重新加载列表
        await loadHealthGoals();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 更新健康目标
  Future<bool> updateHealthGoal(int goalId, HealthGoalCreateRequest request) async {
    try {
      final response = await _userService.updateHealthGoal(goalId, request);
      if (response.isSuccess) {
        // 重新加载列表
        await loadHealthGoals();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 获取进行中的健康目标
  List<HealthGoal> get activeGoals {
    return state.value?.where((goal) => goal.currentStatus == 1).toList() ?? [];
  }

  /// 获取已完成的健康目标
  List<HealthGoal> get completedGoals {
    return state.value?.where((goal) => goal.currentStatus == 2).toList() ?? [];
  }
}

/// 健康目标提供者
final healthGoalsProvider = StateNotifierProvider<HealthGoalsNotifier, AsyncValue<List<HealthGoal>>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return HealthGoalsNotifier(userService);
});

/// 疾病信息状态管理
class DiseasesNotifier extends StateNotifier<AsyncValue<List<Disease>>> {
  final UserService _userService;

  DiseasesNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载疾病信息
  Future<void> loadDiseases({bool? isCurrent}) async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getDiseases(isCurrent: isCurrent);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data ?? []);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 添加疾病信息
  Future<bool> addDisease(DiseaseCreateRequest request) async {
    try {
      final response = await _userService.addDisease(request);
      if (response.isSuccess) {
        // 重新加载列表
        await loadDiseases();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 获取当前疾病
  List<Disease> get currentDiseases {
    return state.value?.where((disease) => disease.isCurrent).toList() ?? [];
  }

  /// 获取历史疾病
  List<Disease> get historicalDiseases {
    return state.value?.where((disease) => !disease.isCurrent).toList() ?? [];
  }
}

/// 疾病信息提供者
final diseasesProvider = StateNotifierProvider<DiseasesNotifier, AsyncValue<List<Disease>>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return DiseasesNotifier(userService);
});

/// 过敏信息状态管理
class AllergiesNotifier extends StateNotifier<AsyncValue<List<Allergy>>> {
  final UserService _userService;

  AllergiesNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载过敏信息
  Future<void> loadAllergies({int? allergenType}) async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getAllergies(allergenType: allergenType);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data ?? []);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 添加过敏信息
  Future<bool> addAllergy(AllergyCreateRequest request) async {
    try {
      final response = await _userService.addAllergy(request);
      if (response.isSuccess) {
        // 重新加载列表
        await loadAllergies();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 获取食物过敏
  List<Allergy> get foodAllergies {
    return state.value?.where((allergy) => allergy.allergenType == 1).toList() ?? [];
  }

  /// 获取药物过敏
  List<Allergy> get medicineAllergies {
    return state.value?.where((allergy) => allergy.allergenType == 2).toList() ?? [];
  }

  /// 获取环境过敏
  List<Allergy> get environmentAllergies {
    return state.value?.where((allergy) => allergy.allergenType == 3).toList() ?? [];
  }
}

/// 过敏信息提供者
final allergiesProvider = StateNotifierProvider<AllergiesNotifier, AsyncValue<List<Allergy>>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return AllergiesNotifier(userService);
});

/// 体重记录状态管理
class WeightRecordsNotifier extends StateNotifier<AsyncValue<List<WeightRecord>>> {
  final UserService _userService;

  WeightRecordsNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载体重记录
  Future<void> loadWeightRecords({
    String? startDate,
    String? endDate,
    int limit = 50,
  }) async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getWeightRecords(
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      if (response.isSuccess) {
        state = AsyncValue.data(response.data ?? []);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 添加体重记录
  Future<bool> addWeightRecord(WeightRecordCreateRequest request) async {
    try {
      final response = await _userService.addWeightRecord(request);
      if (response.isSuccess) {
        // 重新加载列表
        await loadWeightRecords();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 获取最新的体重记录
  WeightRecord? get latestRecord {
    final records = state.value;
    if (records == null || records.isEmpty) return null;
    
    // 按时间排序，获取最新的记录
    final sortedRecords = List<WeightRecord>.from(records)
      ..sort((a, b) => DateTime.parse(b.measuredAt).compareTo(DateTime.parse(a.measuredAt)));
    
    return sortedRecords.first;
  }

  /// 获取体重趋势数据（最近30天）
  List<WeightRecord> get recentRecords {
    final records = state.value;
    if (records == null || records.isEmpty) return [];
    
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return records.where((record) {
      final recordDate = DateTime.parse(record.measuredAt);
      return recordDate.isAfter(thirtyDaysAgo);
    }).toList();
  }
}

/// 体重记录提供者
final weightRecordsProvider = StateNotifierProvider<WeightRecordsNotifier, AsyncValue<List<WeightRecord>>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return WeightRecordsNotifier(userService);
});

/// 引导状态管理
class OnboardingNotifier extends StateNotifier<AsyncValue<OnboardingStatus>> {
  final UserService _userService;

  OnboardingNotifier(this._userService) : super(const AsyncValue.loading());

  /// 加载引导状态
  Future<void> loadOnboardingStatus() async {
    state = const AsyncValue.loading();
    try {
      final response = await _userService.getOnboardingStatus();
      if (response.isSuccess) {
        state = AsyncValue.data(response.data!);
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 更新引导步骤
  Future<bool> updateOnboardingStep(OnboardingStepUpdateRequest request) async {
    try {
      final response = await _userService.updateOnboardingStep(request);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data!);
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 完成引导
  Future<bool> completeOnboarding(OnboardingCompleteRequest request) async {
    try {
      final response = await _userService.completeOnboarding(request);
      if (response.isSuccess) {
        // 重新加载状态
        await loadOnboardingStatus();
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 重置引导状态
  Future<bool> resetOnboarding() async {
    try {
      final response = await _userService.resetOnboarding();
      if (response.isSuccess) {
        state = AsyncValue.data(response.data!);
        return true;
      } else {
        state = AsyncValue.error(response.message, StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  /// 检查是否完成引导
  bool get isOnboardingCompleted {
    return state.value?.onboardingCompleted ?? false;
  }

  /// 获取当前步骤
  int get currentStep {
    return state.value?.currentStep ?? 0;
  }

  /// 获取下一步
  int? get nextStep {
    return state.value?.nextStep;
  }
}

/// 引导状态提供者
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, AsyncValue<OnboardingStatus>>((ref) {
  final userService = ref.watch(userServiceProvider);
  return OnboardingNotifier(userService);
});