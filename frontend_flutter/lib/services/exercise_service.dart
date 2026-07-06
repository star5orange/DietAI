import '../../core/services/api_service.dart';
import '../../shared/domain/models/api_response.dart';
import '../../shared/domain/models/exercise_model.dart';

class ExerciseService {
  final ApiService _apiService = ApiService();

  Future<ApiResponse<List<ExerciseRecord>>> getExerciseRecords() async {
    try {
      final records = await ExerciseRecordStorage.loadAll();
      return ApiResponse<List<ExerciseRecord>>.success(
        message: '获取运动记录成功',
        data: records,
      );
    } catch (e) {
      return ApiResponse<List<ExerciseRecord>>.failure(
        message: '获取运动记录失败: $e',
      );
    }
  }

  Future<ApiResponse<ExerciseRecord>> createExerciseRecord(
    CreateExerciseRecordRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final record = ExerciseRecord(
        id: now.millisecondsSinceEpoch.toString(),
        exerciseName: request.exerciseName,
        exerciseType: request.exerciseType,
        durationMinutes: request.durationMinutes,
        caloriesBurned: request.caloriesBurned,
        notes: request.notes,
        recordedAt: request.recordedAt ?? now.toIso8601String(),
        createdAt: now.toIso8601String(),
      );

      await ExerciseRecordStorage.add(record);

      return ApiResponse<ExerciseRecord>.success(
        message: '创建运动记录成功',
        data: record,
      );
    } catch (e) {
      return ApiResponse<ExerciseRecord>.failure(
        message: '创建运动记录失败: $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteExerciseRecord(String id) async {
    try {
      await ExerciseRecordStorage.delete(id);
      return ApiResponse<void>.success(
        message: '删除运动记录成功',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除运动记录失败: $e',
      );
    }
  }

  Future<ApiResponse<DailyExerciseSummary>> getDailySummary(
      String dateStr) async {
    try {
      final summary = await ExerciseRecordStorage.getDailySummary(dateStr);
      return ApiResponse<DailyExerciseSummary>.success(
        message: '获取每日运动汇总成功',
        data: summary,
      );
    } catch (e) {
      return ApiResponse<DailyExerciseSummary>.failure(
        message: '获取每日运动汇总失败: $e',
      );
    }
  }

  Future<ApiResponse<double>> getBackendExerciseCalories(String dateStr) async {
    try {
      final response = await _apiService.get('/foods/daily-summary/$dateStr');
      if (response.success && response.data != null) {
        final calories =
            (response.data['exercise_calories'] as num?)?.toDouble() ?? 0.0;
        return ApiResponse<double>.success(
          message: '获取后端运动消耗成功',
          data: calories,
        );
      }
      return ApiResponse<double>.success(
        message: '暂无后端运动数据',
        data: 0.0,
      );
    } catch (e) {
      return ApiResponse<double>.failure(
        message: '获取后端运动消耗失败: $e',
      );
    }
  }

  double estimateCalories(String exerciseType, int durationMinutes,
      {double? userWeight}) {
    final weight = userWeight ?? 70.0;
    final metValues = {
      'running': 9.8,
      'walking': 3.8,
      'cycling': 7.5,
      'swimming': 8.0,
      'yoga': 3.0,
      'strength': 6.0,
      'hiit': 10.0,
      'dance': 5.5,
      'basketball': 8.0,
      'football': 7.0,
      'badminton': 5.5,
      'tennis': 7.3,
      'other': 5.0,
    };

    final met = metValues[exerciseType] ?? 5.0;
    return met * weight * (durationMinutes / 60.0);
  }

  // ==================== 后端 API 方法 ====================

  /// 从后端获取运动记录列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getRemoteExerciseRecords({
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
        '/exercises/records',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data as List;
        final records = dataList.map((e) => e as Map<String, dynamic>).toList();
        return ApiResponse<List<Map<String, dynamic>>>.success(
          message: response.message.isNotEmpty ? response.message : '获取运动记录成功',
          data: records,
        );
      }
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取运动记录失败',
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: '获取运动记录失败: $e',
      );
    }
  }

  /// 向后端创建运动记录
  Future<ApiResponse<Map<String, dynamic>>> createRemoteExerciseRecord({
    required String exerciseName,
    required String exerciseType,
    required int durationMinutes,
    required double caloriesBurned,
    String? notes,
    String? recordDate,
    Map<String, dynamic>? strengthDetail,
  }) async {
    try {
      final data = {
        'exercise_name': exerciseName,
        'exercise_type': exerciseType,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'record_date':
            recordDate ?? DateTime.now().toIso8601String().substring(0, 10),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (strengthDetail != null) 'strength_detail': strengthDetail,
      };

      final response = await _apiService.post('/exercises/records', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '创建运动记录成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '创建运动记录失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '创建运动记录失败: $e',
      );
    }
  }

  /// 更新后端运动记录
  Future<ApiResponse<Map<String, dynamic>>> updateRemoteExerciseRecord({
    required int recordId,
    required String exerciseName,
    required String exerciseType,
    required int durationMinutes,
    required double caloriesBurned,
    String? notes,
    String? recordDate,
  }) async {
    try {
      final data = {
        'exercise_name': exerciseName,
        'exercise_type': exerciseType,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'record_date':
            recordDate ?? DateTime.now().toIso8601String().substring(0, 10),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response =
          await _apiService.put('/exercises/records/$recordId', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '更新运动记录成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '更新运动记录失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '更新运动记录失败: $e',
      );
    }
  }

  /// 删除后端运动记录
  Future<ApiResponse<void>> deleteRemoteExerciseRecord(int recordId) async {
    try {
      final response = await _apiService.delete('/exercises/records/$recordId');

      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '删除运动记录成功',
        );
      }
      return ApiResponse<void>.failure(
        message: response.message.isNotEmpty ? response.message : '删除运动记录失败',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除运动记录失败: $e',
      );
    }
  }

  /// 获取运动统计
  Future<ApiResponse<Map<String, dynamic>>> getExerciseStatistics({
    String period = '7d',
  }) async {
    try {
      final response = await _apiService.get(
        '/exercises/statistics',
        queryParameters: {'period': period},
      );

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取运动统计成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取运动统计失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取运动统计失败: $e',
      );
    }
  }
}
