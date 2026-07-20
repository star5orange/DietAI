import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../shared/domain/models/api_response.dart';
import '../../shared/domain/models/water_intake_model.dart';
import '../../shared/domain/models/user_model.dart';
import '../features/profile/domain/services/user_service.dart';

class WaterService {
  final ApiService _apiService = ApiService();
  final UserService _userService = UserService(ApiService());

  /// 获取指定日期范围的饮水记录
  Future<ApiResponse<List<WaterIntakeRecord>>> getWaterRecords({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': 50,
      };
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/water/records',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data as List;
        final records = dataList
            .map((e) => WaterIntakeRecord(
                  id: ((e['id'] as num?)?.toInt() ?? 0).toString(),
                  amountMl: (e['amount_ml'] as num?)?.toInt() ?? 0,
                  notes: e['drink_type'] as String?,
                  recordedAt: e['record_time'] as String? ?? '',
                  createdAt: e['created_at'] as String? ?? '',
                ))
            .toList();
        return ApiResponse<List<WaterIntakeRecord>>.success(
          message: '获取饮水记录成功',
          data: records,
        );
      }
      return ApiResponse<List<WaterIntakeRecord>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取饮水记录失败',
      );
    } catch (e) {
      return ApiResponse<List<WaterIntakeRecord>>.failure(
        message: '获取饮水记录失败: $e',
      );
    }
  }

  /// 添加饮水记录（持久化到后端数据库）
  Future<ApiResponse<WaterIntakeRecord>> addWaterIntake({
    required int amountMl,
    String? notes,
    String? drinkType,
    DateTime? recordedAt,
  }) async {
    try {
      final recordTime = recordedAt ?? DateTime.now();
      final data = <String, dynamic>{
        'amount_ml': amountMl,
        'record_time': recordTime.toIso8601String(),
        'drink_type': drinkType ?? notes ?? '水',
      };

      debugPrint('[WaterService] POST /water/records data=$data');
      final response = await _apiService.post('/water/records', data: data);
      debugPrint(
          '[WaterService] POST result: success=${response.success}, message=${response.message}');

      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final record = WaterIntakeRecord(
          id: ((d['id'] as num?)?.toInt() ?? 0).toString(),
          amountMl: (d['amount_ml'] as num?)?.toInt() ?? 0,
          notes: d['drink_type'] as String?,
          recordedAt: d['record_time'] as String? ?? '',
          createdAt: d['created_at'] as String? ?? '',
        );
        return ApiResponse<WaterIntakeRecord>.success(
          message: '添加饮水记录成功',
          data: record,
        );
      }
      return ApiResponse<WaterIntakeRecord>.failure(
        message: response.message.isNotEmpty ? response.message : '添加饮水记录失败',
      );
    } catch (e) {
      return ApiResponse<WaterIntakeRecord>.failure(
        message: '添加饮水记录失败: $e',
      );
    }
  }

  /// 删除饮水记录
  Future<ApiResponse<void>> deleteWaterRecord(String id) async {
    try {
      final response = await _apiService.delete('/water/records/$id');
      if (response.success) {
        return ApiResponse<void>.success(message: '饮水记录已删除');
      }
      return ApiResponse<void>.failure(
        message: response.message.isNotEmpty ? response.message : '删除失败',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除饮水记录失败: $e',
      );
    }
  }

  /// 获取每日饮水汇总
  Future<ApiResponse<DailyWaterSummary>> getDailySummary(String dateStr) async {
    try {
      final response = await _apiService.get('/water/daily-summary/$dateStr');

      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        final summary = DailyWaterSummary(
          date: d['date'] as String? ?? '',
          totalMl: (d['total_intake_ml'] as num?)?.toInt() ?? 0,
          goalMl: (d['daily_goal_ml'] as num?)?.toInt() ?? 0,
          recordCount: (d['records_count'] as num?)?.toInt() ?? 0,
        );
        return ApiResponse<DailyWaterSummary>.success(
          message: '获取每日饮水汇总成功',
          data: summary,
        );
      }
      return ApiResponse<DailyWaterSummary>.failure(
        message: response.message.isNotEmpty ? response.message : '获取每日饮水汇总失败',
      );
    } catch (e) {
      return ApiResponse<DailyWaterSummary>.failure(
        message: '获取每日饮水汇总失败: $e',
      );
    }
  }

  /// 获取饮水目标（优先从后端 summary 读取，兜底 2000）
  Future<ApiResponse<int>> getGoal() async {
    try {
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final response = await _apiService.get('/water/daily-summary/$dateStr');
      if (response.success && response.data != null) {
        final d = response.data as Map<String, dynamic>;
        return ApiResponse<int>.success(
          message: '获取饮水目标成功',
          data: (d['daily_goal_ml'] as num?)?.toInt() ?? 2000,
        );
      }
      return ApiResponse<int>.success(
        message: '使用默认目标',
        data: 2000,
      );
    } catch (e) {
      return ApiResponse<int>.success(
        message: '使用默认目标',
        data: 2000,
      );
    }
  }

  /// 设置饮水目标（同步到后端数据库）
  Future<ApiResponse<void>> setGoal(int goalMl) async {
    try {
      // 1. 保存到本地存储（作为缓存）
      await WaterIntakeStorage.setGoal(goalMl);

      // 2. 同步到后端数据库
      final updateResponse = await _userService.updateUserProfile(
        UserProfileUpdateRequest(dailyWaterGoal: goalMl),
      );

      if (!updateResponse.isSuccess) {
        debugPrint('[WaterService] 更新后端目标失败: ${updateResponse.message}');
        return ApiResponse<void>.failure(
          message: '更新饮水目标失败: ${updateResponse.message}',
        );
      }

      debugPrint('[WaterService] 饮水目标已同步到后端: ${goalMl}ml');
      return ApiResponse<void>.success(message: '设置饮水目标成功');
    } catch (e) {
      debugPrint('[WaterService] 设置饮水目标异常: $e');
      return ApiResponse<void>.failure(message: '设置饮水目标失败: $e');
    }
  }

  /// 获取饮水统计
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
          message: '获取饮水统计成功',
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
