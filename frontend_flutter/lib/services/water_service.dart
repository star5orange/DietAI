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
}
