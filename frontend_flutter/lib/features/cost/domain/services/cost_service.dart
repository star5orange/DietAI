import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/services/api_service.dart';

/// 消费统计服务
/// 用于管理消费数据和统计分析
class CostService {
  final ApiService _apiService = ApiService();

  /// 获取消费统计数据（本周/本月）
  /// [period]: week 或 month
  Future<ApiResponse<Map<String, dynamic>>> getCostStats({
    String period = 'week',
  }) async {
    try {
      final result = await _apiService.get(
        '/foods/cost-stats',
        queryParameters: {'period': period},
      );
      if (!result.isSuccess) {
        return ApiResponse.failure(message: result.message);
      }
      return ApiResponse.success(
        message: result.message,
        data: result.data as Map<String, dynamic>?,
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取消费统计失败', error: e.toString());
    }
  }

  /// 获取消费汇总数据（兼容旧接口）
  Future<ApiResponse<Map<String, dynamic>>> getCostSummary({
    String? startDate,
    String? endDate,
  }) async {
    return getCostStats(period: 'week');
  }

  /// 获取消费分类数据
  /// 从 cost-stats 数据中提取分类信息
  Future<ApiResponse<List<Map<String, dynamic>>>> getCategoryData({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final result = await getCostStats(period: 'week');
      if (result.isSuccess && result.data != null) {
        final categories = result.data!['categories'] as List? ??
            result.data!['by_source'] as List? ??
            [];
        return ApiResponse.success(
          message: '获取分类数据成功',
          data: categories.map((e) => e as Map<String, dynamic>).toList(),
        );
      }
      return ApiResponse.success(message: '无分类数据', data: []);
    } catch (e) {
      return ApiResponse.failure(message: '获取分类数据失败', error: e.toString());
    }
  }

  /// 获取消费趋势数据
  Future<ApiResponse<Map<String, dynamic>>> getTrendData({
    int days = 7,
    String? sourceTag,
  }) async {
    try {
      final result = await _apiService.get(
        '/foods/cost-trend',
        queryParameters: {
          'days': days,
          if (sourceTag != null) 'source_tag': sourceTag,
        },
      );
      if (!result.isSuccess) {
        return ApiResponse.failure(message: result.message);
      }
      return ApiResponse.success(
        message: result.message,
        data: result.data as Map<String, dynamic>?,
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取趋势数据失败', error: e.toString());
    }
  }

  /// 设置预算
  Future<ApiResponse<bool>> setBudget(double budget) async {
    try {
      await _apiService.post(
        '/foods/cost-budget',
        data: {'budget': budget},
      );
      return ApiResponse.success(message: '设置预算成功', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '设置预算失败', error: e.toString());
    }
  }
}
