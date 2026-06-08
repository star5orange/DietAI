import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

/// 提醒响应服务 - 对应后端 /api/notifications/* 接口
class NotificationResponseService {
  final ApiService _apiService = ApiService();

  /// 记录提醒响应
  /// actionType: drank, ate, snooze, skipped
  /// - drank: 自动创建喝水记录(250ml)，更新当日饮水汇总
  /// - ate: 记录吃饭响应
  /// - snooze: 记录延迟
  /// - skipped: 记录跳过
  Future<ApiResponse<Map<String, dynamic>>> createResponse({
    required int reminderId,
    required String actionType,
  }) async {
    try {
      final data = {
        'reminder_id': reminderId,
        'action_type': actionType,
      };

      final response = await _apiService.post('/notifications/responses', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '提醒响应记录成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '记录提醒响应失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '记录提醒响应失败: $e',
      );
    }
  }

  /// 获取提醒响应统计
  /// 返回各类型的响应率、连续响应天数等
  Future<ApiResponse<Map<String, dynamic>>> getResponseStats({
    int days = 7,
  }) async {
    try {
      final response = await _apiService.get(
        '/notifications/responses/stats',
        queryParameters: {'days': days},
      );

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取提醒统计成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取提醒统计失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取提醒统计失败: $e',
      );
    }
  }
}
