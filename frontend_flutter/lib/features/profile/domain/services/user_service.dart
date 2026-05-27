import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/user_model.dart';

/// 用户服务类
class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  /// 获取用户资料
  Future<ApiResponse<UserProfile>> getUserProfile() async {
    try {
      final response = await _apiService.get('/users/profile');
      
      if (response.isSuccess && response.data != null) {
        final userProfile = UserProfile.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: userProfile,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取用户资料失败: $e');
    }
  }

  /// 更新用户资料
  Future<ApiResponse<UserProfile>> updateUserProfile(
    UserProfileUpdateRequest request,
  ) async {
    try {
      final response = await _apiService.put(
        '/users/profile',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final userProfile = UserProfile.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: userProfile,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新用户资料失败: $e');
    }
  }

  /// 创建健康目标
  Future<ApiResponse<HealthGoal>> createHealthGoal(
    HealthGoalCreateRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/health-goals',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final healthGoal = HealthGoal.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: healthGoal,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '创建健康目标失败: $e');
    }
  }

  /// 获取健康目标列表
  Future<ApiResponse<List<HealthGoal>>> getHealthGoals({
    int? statusFilter,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (statusFilter != null) {
        params['status_filter'] = statusFilter;
      }
      
      final response = await _apiService.get(
        '/users/health-goals',
        queryParameters: params,
      );
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> dataList = response.data;
        final healthGoals = dataList
            .map((item) => HealthGoal.fromJson(item))
            .toList();
        return ApiResponse.success(
          message: response.message,
          data: healthGoals,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取健康目标列表失败: $e');
    }
  }

  /// 更新健康目标
  Future<ApiResponse<HealthGoal>> updateHealthGoal(
    int goalId,
    HealthGoalCreateRequest request,
  ) async {
    try {
      final response = await _apiService.put(
        '/users/health-goals/$goalId',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final healthGoal = HealthGoal.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: healthGoal,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新健康目标失败: $e');
    }
  }

  /// 添加疾病信息
  Future<ApiResponse<Disease>> addDisease(
    DiseaseCreateRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/diseases',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final disease = Disease.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: disease,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '添加疾病信息失败: $e');
    }
  }

  /// 获取疾病信息列表
  Future<ApiResponse<List<Disease>>> getDiseases({
    bool? isCurrent,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (isCurrent != null) {
        params['is_current'] = isCurrent;
      }
      
      final response = await _apiService.get(
        '/users/diseases',
        queryParameters: params,
      );
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> dataList = response.data;
        final diseases = dataList
            .map((item) => Disease.fromJson(item))
            .toList();
        return ApiResponse.success(
          message: response.message,
          data: diseases,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取疾病信息列表失败: $e');
    }
  }

  /// 添加过敏信息
  Future<ApiResponse<Allergy>> addAllergy(
    AllergyCreateRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/allergies',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final allergy = Allergy.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: allergy,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '添加过敏信息失败: $e');
    }
  }

  /// 获取过敏信息列表
  Future<ApiResponse<List<Allergy>>> getAllergies({
    int? allergenType,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (allergenType != null) {
        params['allergen_type'] = allergenType;
      }
      
      final response = await _apiService.get(
        '/users/allergies',
        queryParameters: params,
      );
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> dataList = response.data;
        final allergies = dataList
            .map((item) => Allergy.fromJson(item))
            .toList();
        return ApiResponse.success(
          message: response.message,
          data: allergies,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取过敏信息列表失败: $e');
    }
  }

  /// 添加体重记录
  Future<ApiResponse<WeightRecord>> addWeightRecord(
    WeightRecordCreateRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/weight-records',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final weightRecord = WeightRecord.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: weightRecord,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '添加体重记录失败: $e');
    }
  }

  /// 获取体重记录列表
  Future<ApiResponse<List<WeightRecord>>> getWeightRecords({
    String? startDate,
    String? endDate,
    int limit = 50,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'limit': limit,
      };
      if (startDate != null) {
        params['start_date'] = startDate;
      }
      if (endDate != null) {
        params['end_date'] = endDate;
      }
      
      final response = await _apiService.get(
        '/users/weight-records',
        queryParameters: params,
      );
      
      if (response.isSuccess && response.data != null) {
        final List<dynamic> dataList = response.data;
        final weightRecords = dataList
            .map((item) => WeightRecord.fromJson(item))
            .toList();
        return ApiResponse.success(
          message: response.message,
          data: weightRecords,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取体重记录列表失败: $e');
    }
  }

  /// 获取引导状态
  Future<ApiResponse<OnboardingStatus>> getOnboardingStatus() async {
    try {
      final response = await _apiService.get('/users/onboarding/status');
      
      if (response.isSuccess && response.data != null) {
        final onboardingStatus = OnboardingStatus.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: onboardingStatus,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取引导状态失败: $e');
    }
  }

  /// 更新引导步骤
  Future<ApiResponse<OnboardingStatus>> updateOnboardingStep(
    OnboardingStepUpdateRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/onboarding/step',
        data: request.toJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final onboardingStatus = OnboardingStatus.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: onboardingStatus,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新引导步骤失败: $e');
    }
  }

  /// 完成引导
  Future<ApiResponse<dynamic>> completeOnboarding(
    OnboardingCompleteRequest request,
  ) async {
    try {
      final response = await _apiService.post(
        '/users/onboarding/complete',
        data: request.toJson(),
      );
      
      if (response.isSuccess) {
        return ApiResponse.success(
          message: response.message,
          data: response.data,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '完成引导失败: $e');
    }
  }

  /// 重置引导状态
  Future<ApiResponse<OnboardingStatus>> resetOnboarding() async {
    try {
      final response = await _apiService.post('/users/onboarding/reset');
      
      if (response.isSuccess && response.data != null) {
        final onboardingStatus = OnboardingStatus.fromJson(response.data);
        return ApiResponse.success(
          message: response.message,
          data: onboardingStatus,
        );
      }
      
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '重置引导状态失败: $e');
    }
  }
}