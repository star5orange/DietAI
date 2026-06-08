import '../../core/services/api_service.dart';
import '../../shared/domain/models/api_response.dart';
import '../../shared/domain/models/water_intake_model.dart';

class WaterService {
  final ApiService _apiService = ApiService();

  Future<ApiResponse<List<WaterIntakeRecord>>> getWaterRecords() async {
    try {
      final records = await WaterIntakeStorage.loadAll();
      return ApiResponse<List<WaterIntakeRecord>>.success(
        message: '获取饮水记录成功',
        data: records,
      );
    } catch (e) {
      return ApiResponse<List<WaterIntakeRecord>>.failure(
        message: '获取饮水记录失败: $e',
      );
    }
  }

  Future<ApiResponse<WaterIntakeRecord>> addWaterIntake({
    required int amountMl,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final record = WaterIntakeRecord(
        id: now.millisecondsSinceEpoch.toString(),
        amountMl: amountMl,
        notes: notes,
        recordedAt: now.toIso8601String(),
        createdAt: now.toIso8601String(),
      );

      await WaterIntakeStorage.add(record);

      return ApiResponse<WaterIntakeRecord>.success(
        message: '添加饮水记录成功',
        data: record,
      );
    } catch (e) {
      return ApiResponse<WaterIntakeRecord>.failure(
        message: '添加饮水记录失败: $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteWaterRecord(String id) async {
    try {
      await WaterIntakeStorage.delete(id);
      return ApiResponse<void>.success(
        message: '删除饮水记录成功',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除饮水记录失败: $e',
      );
    }
  }

  Future<ApiResponse<DailyWaterSummary>> getDailySummary(String dateStr) async {
    try {
      final summary = await WaterIntakeStorage.getDailySummary(dateStr);
      return ApiResponse<DailyWaterSummary>.success(
        message: '获取每日饮水汇总成功',
        data: summary,
      );
    } catch (e) {
      return ApiResponse<DailyWaterSummary>.failure(
        message: '获取每日饮水汇总失败: $e',
      );
    }
  }

  Future<ApiResponse<double>> getBackendWaterIntake(String dateStr) async {
    try {
      final response = await _apiService.get('/foods/daily-summary/$dateStr');
      if (response.success && response.data != null) {
        final waterIntake =
            (response.data['water_intake'] as num?)?.toDouble() ?? 0.0;
        return ApiResponse<double>.success(
          message: '获取后端饮水数据成功',
          data: waterIntake,
        );
      }
      return ApiResponse<double>.success(
        message: '暂无后端饮水数据',
        data: 0.0,
      );
    } catch (e) {
      return ApiResponse<double>.failure(
        message: '获取后端饮水数据失败: $e',
      );
    }
  }

  Future<ApiResponse<int>> getGoal() async {
    try {
      final goal = await WaterIntakeStorage.getGoal();
      return ApiResponse<int>.success(
        message: '获取饮水目标成功',
        data: goal,
      );
    } catch (e) {
      return ApiResponse<int>.failure(
        message: '获取饮水目标失败: $e',
      );
    }
  }

  Future<ApiResponse<void>> setGoal(int goalMl) async {
    try {
      await WaterIntakeStorage.setGoal(goalMl);
      return ApiResponse<void>.success(
        message: '设置饮水目标成功',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '设置饮水目标失败: $e',
      );
    }
  }

  // ==================== 后端 API 方法 ====================

  /// 向后端创建饮水记录
  Future<ApiResponse<Map<String, dynamic>>> createRemoteWaterRecord({
    required double amountMl,
    String? recordedAt,
    String? notes,
  }) async {
    try {
      final data = {
        'amount_ml': amountMl,
        if (recordedAt != null) 'recorded_at': recordedAt,
        if (notes != null) 'notes': notes,
      };

      final response = await _apiService.post('/water/records', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '创建饮水记录成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '创建饮水记录失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '创建饮水记录失败: $e',
      );
    }
  }

  /// 从后端获取饮水记录列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getRemoteWaterRecords({
    String? startDate,
    String? endDate,
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'skip': skip,
        'limit': limit,
      };
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/water/records',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data as List;
        final records = dataList.map((e) => e as Map<String, dynamic>).toList();
        return ApiResponse<List<Map<String, dynamic>>>.success(
          message: response.message.isNotEmpty ? response.message : '获取饮水记录成功',
          data: records,
        );
      }
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取饮水记录失败',
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: '获取饮水记录失败: $e',
      );
    }
  }

  /// 从后端获取每日饮水汇总
  Future<ApiResponse<Map<String, dynamic>>> getRemoteDailySummary(String targetDate) async {
    try {
      final response = await _apiService.get('/water/daily-summary/$targetDate');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取每日饮水汇总成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取每日饮水汇总失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取每日饮水汇总失败: $e',
      );
    }
  }

  /// 从后端获取饮水统计
  Future<ApiResponse<Map<String, dynamic>>> getWaterStatistics({
    String period = '7d',
  }) async {
    try {
      final response = await _apiService.get(
        '/water/statistics',
        queryParameters: {'period': period},
      );

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取饮水统计成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取饮水统计失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取饮水统计失败: $e',
      );
    }
  }
}
