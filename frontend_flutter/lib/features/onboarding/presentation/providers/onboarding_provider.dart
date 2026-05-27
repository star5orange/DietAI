import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/onboarding_service.dart';

// 引导状态数据模型
class OnboardingState {
  final int currentStep;
  final bool isCompleted;
  final Map<String, dynamic> basicInfo;
  final Map<String, dynamic> physicalData;
  final List<Map<String, dynamic>> healthGoals;
  final List<String> dietaryPreferences;
  final List<Map<String, dynamic>> medicalConditions;
  final List<Map<String, dynamic>> allergies;
  final Map<String, dynamic> lifestyleHabits;
  final bool isLoading;
  final String? error;

  OnboardingState({
    this.currentStep = 0,
    this.isCompleted = false,
    this.basicInfo = const {},
    this.physicalData = const {},
    this.healthGoals = const [],
    this.dietaryPreferences = const [],
    this.medicalConditions = const [],
    this.allergies = const [],
    this.lifestyleHabits = const {},
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    int? currentStep,
    bool? isCompleted,
    Map<String, dynamic>? basicInfo,
    Map<String, dynamic>? physicalData,
    List<Map<String, dynamic>>? healthGoals,
    List<String>? dietaryPreferences,
    List<Map<String, dynamic>>? medicalConditions,
    List<Map<String, dynamic>>? allergies,
    Map<String, dynamic>? lifestyleHabits,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      isCompleted: isCompleted ?? this.isCompleted,
      basicInfo: basicInfo ?? this.basicInfo,
      physicalData: physicalData ?? this.physicalData,
      healthGoals: healthGoals ?? this.healthGoals,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      allergies: allergies ?? this.allergies,
      lifestyleHabits: lifestyleHabits ?? this.lifestyleHabits,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// 引导状态管理
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final OnboardingService _service;

  OnboardingNotifier(this._service) : super(OnboardingState());

  /// 检查引导状态
  Future<void> checkOnboardingStatus() async {
    print('🔍 开始检查引导状态...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _service.checkOnboardingStatus();

      print(
          '📡 API响应: success=${response.isSuccess}, message=${response.message}');

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        print('📊 引导数据: $data');

        final isCompleted = data['onboarding_completed'] ?? false;
        final currentStep = data['current_step'] ?? 0;

        print('✅ 解析结果: isCompleted=$isCompleted, currentStep=$currentStep');

        state = state.copyWith(
          isCompleted: isCompleted,
          currentStep: currentStep,
          isLoading: false,
        );
      } else {
        print('❌ API调用失败: ${response.message}');
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      print('❌ 检查引导状态异常: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void updateStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void updateBasicInfo(Map<String, dynamic> info) {
    state = state.copyWith(basicInfo: {...state.basicInfo, ...info});
  }

  void updatePhysicalData(Map<String, dynamic> data) {
    state = state.copyWith(physicalData: {...state.physicalData, ...data});
  }

  void updateHealthGoals(List<Map<String, dynamic>> goals) {
    state = state.copyWith(healthGoals: goals);
  }

  void updateDietaryPreferences(List<String> preferences) {
    state = state.copyWith(dietaryPreferences: preferences);
  }

  void updateMedicalConditions(List<Map<String, dynamic>> conditions) {
    state = state.copyWith(medicalConditions: conditions);
  }

  void updateAllergies(List<Map<String, dynamic>> allergies) {
    state = state.copyWith(allergies: allergies);
  }

  void updateLifestyleHabits(Map<String, dynamic> habits) {
    state =
        state.copyWith(lifestyleHabits: {...state.lifestyleHabits, ...habits});
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final onboardingData = {
        'basic_info': state.basicInfo,
        'physical_data': state.physicalData,
        'health_goals': state.healthGoals,
        'dietary_preferences': state.dietaryPreferences,
        'medical_conditions': state.medicalConditions,
        'allergies': state.allergies,
        'lifestyle_habits': state.lifestyleHabits,
      };

      final response = await _service.completeOnboarding(
        onboardingData: onboardingData,
      );

      if (response.isSuccess) {
        state = state.copyWith(
          isCompleted: true,
          currentStep: 6,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = OnboardingState();
  }
}

// Provider
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref.read(onboardingServiceProvider));
});
