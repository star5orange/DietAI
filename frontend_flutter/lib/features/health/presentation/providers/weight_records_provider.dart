import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/weight_records_service.dart';
import '../../../../shared/domain/models/weight_record_model.dart';
import '../../../../shared/domain/models/api_response.dart';

/// Weight Records Service Provider
final weightRecordsServiceProvider = Provider<WeightRecordsService>((ref) {
  return WeightRecordsService();
});

/// Weight Records State Provider
final weightRecordsProvider = StateNotifierProvider<WeightRecordsNotifier,
    AsyncValue<List<WeightRecord>>>((ref) {
  final service = ref.watch(weightRecordsServiceProvider);
  return WeightRecordsNotifier(service);
});

/// Weight Records Notifier
class WeightRecordsNotifier
    extends StateNotifier<AsyncValue<List<WeightRecord>>> {
  final WeightRecordsService _service;

  WeightRecordsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadWeightRecords();
  }

  /// 加载体重记录列表
  Future<void> loadWeightRecords({
    int? limit,
    String? startDate,
    String? endDate,
  }) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.getWeightRecords(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );

      if (result.success) {
        // 按时间倒序排列（最新的在前）
        final sortedRecords = result.data ?? [];
        sortedRecords.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
        state = AsyncValue.data(sortedRecords);
      } else {
        state = AsyncValue.error(result.message, StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 创建体重记录
  Future<ApiResponse<WeightRecord>> createWeightRecord(
      CreateWeightRecordRequest request) async {
    try {
      final result = await _service.createWeightRecord(request);

      if (result.success && result.data != null) {
        // 安全更新本地状态
        state.mapOrNull(
          data: (dataState) {
            final updatedRecords = [result.data!, ...dataState.value];
            state = AsyncValue.data(updatedRecords);
          },
        );
      }

      return result;
    } catch (e) {
      return ApiResponse<WeightRecord>.failure(
        message: '添加体重记录失败: $e',
      );
    }
  }

  /// 更新体重记录
  Future<ApiResponse<WeightRecord>> updateWeightRecord(
      int recordId, UpdateWeightRecordRequest request) async {
    try {
      final result = await _service.updateWeightRecord(recordId, request);

      if (result.success && result.data != null) {
        // 安全更新本地状态
        state.mapOrNull(
          data: (dataState) {
            final updatedRecords = dataState.value.map((record) {
              return record.id == recordId ? result.data! : record;
            }).toList();
            state = AsyncValue.data(updatedRecords);
          },
        );
      }

      return result;
    } catch (e) {
      return ApiResponse<WeightRecord>.failure(
        message: '更新体重记录失败: $e',
      );
    }
  }

  /// 删除体重记录
  Future<ApiResponse<void>> deleteWeightRecord(int recordId) async {
    try {
      final result = await _service.deleteWeightRecord(recordId);

      if (result.success) {
        // 安全更新本地状态
        state.mapOrNull(
          data: (dataState) {
            final updatedRecords = dataState.value
                .where((record) => record.id != recordId)
                .toList();
            state = AsyncValue.data(updatedRecords);
          },
        );
      }

      return result;
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除体重记录失败: $e',
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadWeightRecords();
  }
}

/// 最新体重记录Provider
final latestWeightRecordProvider = FutureProvider<WeightRecord?>((ref) async {
  final service = ref.watch(weightRecordsServiceProvider);
  final result = await service.getLatestWeightRecord();

  return result.success ? result.data : null;
});

/// 体重趋势Provider
final weightTrendProvider =
    FutureProvider.family<WeightTrend?, int>((ref, days) async {
  final service = ref.watch(weightRecordsServiceProvider);
  final result = await service.getWeightTrend(days: days);

  return result.success ? result.data : null;
});

/// 近期体重记录Provider（用于图表显示）
final recentWeightRecordsProvider =
    Provider<AsyncValue<List<WeightRecord>>>((ref) {
  final allRecordsAsync = ref.watch(weightRecordsProvider);

  return allRecordsAsync.when(
    data: (records) {
      // 获取最近30条记录用于图表显示
      final recentRecords = records.take(30).toList();
      return AsyncValue.data(recentRecords);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});
