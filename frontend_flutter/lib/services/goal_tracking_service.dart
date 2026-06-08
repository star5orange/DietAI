import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

/// 目标追踪服务 - 对应后端 /api/goals/* 接口
class GoalTrackingService {
  final ApiService _apiService = ApiService();

  /// 获取今日目标追踪状态
  /// 返回: daily_targets, today_consumed, remaining_budget, goal_progress, suggestions, bmr, tdee
  Future<ApiResponse<Map<String, dynamic>>> getDailyStatus() async {
    try {
      final response = await _apiService.get('/goals/daily-status');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取每日目标状态成功',
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>.failure(
          message: response.message.isNotEmpty ? response.message : '获取每日目标状态失败',
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取每日目标状态失败: $e',
      );
    }
  }

  /// 获取目标总体进度
  /// 返回: has_active_goal, active_goal, weight_progress, weight_records_count
  Future<ApiResponse<Map<String, dynamic>>> getProgress() async {
    try {
      final response = await _apiService.get('/goals/progress');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取目标进度成功',
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>.failure(
          message: response.message.isNotEmpty ? response.message : '获取目标进度失败',
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取目标进度失败: $e',
      );
    }
  }

  /// 强制重新计算每日营养配额
  /// 在体重更新、目标变更、活动水平变更后调用
  /// 返回: daily_targets, bmr, tdee, recalculated_at
  Future<ApiResponse<Map<String, dynamic>>> recalculateTargets() async {
    try {
      final response = await _apiService.post('/goals/recalculate');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '每日配额已重新计算',
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>.failure(
          message: response.message.isNotEmpty ? response.message : '重算目标失败',
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '重算目标失败: $e',
      );
    }
  }
}
