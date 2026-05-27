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

  Future<ApiResponse<DailyExerciseSummary>> getDailySummary(String dateStr) async {
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
        final calories = (response.data['exercise_calories'] as num?)?.toDouble() ?? 0.0;
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

  double estimateCalories(String exerciseType, int durationMinutes, {double? userWeight}) {
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
}
