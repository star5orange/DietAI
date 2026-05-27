import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';
import '../shared/domain/models/health_goals_model.dart';

class HealthGoalsService {
  final ApiService _apiService = ApiService();

  /// 获取用户的健康目标列表
  Future<ApiResponse<List<HealthGoal>>> getHealthGoals() async {
    try {
      final response = await _apiService.get('/users/health-goals');
      
      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data is List 
          ? response.data 
          : (response.data['items'] ?? []);
        final goals = dataList.map((json) => HealthGoal.fromJson(json)).toList();
        
        return ApiResponse<List<HealthGoal>>.success(
          message: response.message.isNotEmpty ? response.message : '获取健康目标成功',
          data: goals,
        );
      } else {
        return ApiResponse<List<HealthGoal>>.failure(
          message: response.message.isNotEmpty ? response.message : '获取健康目标失败',
        );
      }
    } catch (e) {
      return ApiResponse<List<HealthGoal>>.failure(
        message: '获取健康目标失败: $e',
      );
    }
  }

  /// 创建新的健康目标
  Future<ApiResponse<HealthGoal>> createHealthGoal(CreateHealthGoalRequest request) async {
    try {
      final response = await _apiService.post(
        '/users/health-goals',
        data: request.toJson(),
      );
      
      if (response.success && response.data != null) {
        final goal = HealthGoal.fromJson(response.data);
        
        return ApiResponse<HealthGoal>.success(
          message: response.message.isNotEmpty ? response.message : '创建健康目标成功',
          data: goal,
        );
      } else {
        return ApiResponse<HealthGoal>.failure(
          message: response.message.isNotEmpty ? response.message : '创建健康目标失败',
        );
      }
    } catch (e) {
      return ApiResponse<HealthGoal>.failure(
        message: '创建健康目标失败: $e',
      );
    }
  }

  /// 更新健康目标
  Future<ApiResponse<HealthGoal>> updateHealthGoal(int goalId, UpdateHealthGoalRequest request) async {
    try {
      final response = await _apiService.put(
        '/users/health-goals/$goalId',
        data: request.toJson(),
      );
      
      if (response.success && response.data != null) {
        final goal = HealthGoal.fromJson(response.data);
        
        return ApiResponse<HealthGoal>.success(
          message: response.message.isNotEmpty ? response.message : '更新健康目标成功',
          data: goal,
        );
      } else {
        return ApiResponse<HealthGoal>.failure(
          message: response.message.isNotEmpty ? response.message : '更新健康目标失败',
        );
      }
    } catch (e) {
      return ApiResponse<HealthGoal>.failure(
        message: '更新健康目标失败: $e',
      );
    }
  }

  /// 删除健康目标
  Future<ApiResponse<void>> deleteHealthGoal(int goalId) async {
    try {
      final response = await _apiService.delete('/users/health-goals/$goalId');
      
      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '删除健康目标成功',
        );
      } else {
        return ApiResponse<void>.failure(
          message: response.message.isNotEmpty ? response.message : '删除健康目标失败',
        );
      }
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除健康目标失败: $e',
      );
    }
  }

  /// 获取健康目标进度
  Future<ApiResponse<HealthGoalProgress>> getHealthGoalProgress(int goalId) async {
    try {
      final response = await _apiService.get('/users/health-goals/$goalId/progress');
      
      if (response.success && response.data != null) {
        final progress = HealthGoalProgress.fromJson(response.data);
        
        return ApiResponse<HealthGoalProgress>.success(
          message: response.message.isNotEmpty ? response.message : '获取目标进度成功',
          data: progress,
        );
      } else {
        return ApiResponse<HealthGoalProgress>.failure(
          message: response.message.isNotEmpty ? response.message : '获取目标进度失败',
        );
      }
    } catch (e) {
      return ApiResponse<HealthGoalProgress>.failure(
        message: '获取目标进度失败: $e',
      );
    }
  }
}