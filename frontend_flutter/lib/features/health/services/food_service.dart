import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';
import '../../../shared/domain/models/food_model.dart';

/// 健康模块的食物服务
class FoodService {
  final ApiService _apiService = ApiService();

  /// 获取营养趋势数据
  Future<ApiResponse<Map<String, dynamic>>> getNutritionTrends({
    String? startDate,
    String? endDate,
    List<String>? metrics,
  }) async {
    try {
      String url = '/food/nutrition-trends';
      List<String> params = [];
      
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      if (metrics != null && metrics.isNotEmpty) {
        params.add('metrics=${metrics.join(',')}');
      }
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      final response = await _apiService.get(url);
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          response.data as Map<String, dynamic>,
          response.message,
        );
      }
      
      return ApiResponse.error('获取营养趋势失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取每日营养汇总
  Future<ApiResponse<Map<String, dynamic>>> getDailyNutritionSummary({
    String? date,
  }) async {
    try {
      String url = '/food/daily-summary';
      if (date != null) {
        url += '?date=$date';
      }
      
      final response = await _apiService.get(url);
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          response.data as Map<String, dynamic>,
          response.message,
        );
      }
      
      return ApiResponse.error('获取营养汇总失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取食物记录统计
  Future<ApiResponse<Map<String, dynamic>>> getFoodRecordStats({
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '/food/statistics';
      List<String> params = [];
      
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      final response = await _apiService.get(url);
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          response.data as Map<String, dynamic>,
          response.message,
        );
      }
      
      return ApiResponse.error('获取统计数据失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }
}