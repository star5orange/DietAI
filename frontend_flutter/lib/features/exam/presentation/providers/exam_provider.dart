import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/exam_api_service.dart';
import '../../domain/exam_models.dart';

/// 体检报告 API 服务 Provider
final examApiServiceProvider = Provider<ExamApiService>((ref) {
  return ExamApiService();
});

/// 体检报告列表状态
class ExamReportListState {
  final List<ExamReport> reports;
  final bool isLoading;
  final String? error;

  ExamReportListState({
    this.reports = const [],
    this.isLoading = false,
    this.error,
  });

  ExamReportListState copyWith({
    List<ExamReport>? reports,
    bool? isLoading,
    String? error,
  }) {
    return ExamReportListState(
      reports: reports ?? this.reports,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 体检报告列表 Provider
class ExamReportListNotifier extends StateNotifier<ExamReportListState> {
  final ExamApiService _apiService;

  ExamReportListNotifier(this._apiService) : super(ExamReportListState());

  Future<void> loadReports(int userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getExamReports(userId);
      if (response.success && response.data != null) {
        state = state.copyWith(
          reports: response.data!.reports,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 上传体检报告，成功返回报告对象（含 reportId），失败返回 null
  Future<ExamReport?> uploadReport({
    required File photo,
    required int userId,
    String? examDate,
    String? hospitalName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.uploadExamReport(
        photo: photo,
        userId: userId,
        examDate: examDate,
        hospitalName: hospitalName,
      );
      if (response.success && response.data != null) {
        // 重新加载列表
        await loadReports(userId);
        return response.data;
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
        return null;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

final examReportListProvider =
    StateNotifierProvider<ExamReportListNotifier, ExamReportListState>((ref) {
  return ExamReportListNotifier(ref.watch(examApiServiceProvider));
});

/// 体检指标状态
class ExamMetricsState {
  final List<ExamMetric> metrics;
  final bool isLoading;
  final String? error;

  ExamMetricsState({
    this.metrics = const [],
    this.isLoading = false,
    this.error,
  });

  ExamMetricsState copyWith({
    List<ExamMetric>? metrics,
    bool? isLoading,
    String? error,
  }) {
    return ExamMetricsState(
      metrics: metrics ?? this.metrics,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 体检指标 Provider
class ExamMetricsNotifier extends StateNotifier<ExamMetricsState> {
  final ExamApiService _apiService;

  ExamMetricsNotifier(this._apiService) : super(ExamMetricsState());

  Future<void> loadMetrics(int reportId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getExamMetrics(reportId);
      if (response.success && response.data != null) {
        state = state.copyWith(
          metrics: response.data!,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateMetric(
    int metricId, {
    double? metricValue,
    String? status,
    bool? isAbnormal,
    String? unit,
  }) async {
    try {
      final response = await _apiService.updateExamMetric(
        metricId,
        metricValue: metricValue,
        status: status,
        isAbnormal: isAbnormal,
        unit: unit,
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }
}

final examMetricsProvider =
    StateNotifierProvider<ExamMetricsNotifier, ExamMetricsState>((ref) {
  return ExamMetricsNotifier(ref.watch(examApiServiceProvider));
});

/// 指标趋势状态
class MetricTrendState {
  final MetricTrendResponse? trend;
  final bool isLoading;
  final String? error;

  MetricTrendState({
    this.trend,
    this.isLoading = false,
    this.error,
  });

  MetricTrendState copyWith({
    MetricTrendResponse? trend,
    bool? isLoading,
    String? error,
  }) {
    return MetricTrendState(
      trend: trend ?? this.trend,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 指标趋势 Provider
class MetricTrendNotifier extends StateNotifier<MetricTrendState> {
  final ExamApiService _apiService;

  MetricTrendNotifier(this._apiService) : super(MetricTrendState());

  Future<void> loadTrend(int userId, String metricName) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getMetricTrend(userId, metricName);
      if (response.success && response.data != null) {
        state = state.copyWith(
          trend: response.data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final metricTrendProvider =
    StateNotifierProvider<MetricTrendNotifier, MetricTrendState>((ref) {
  return MetricTrendNotifier(ref.watch(examApiServiceProvider));
});

/// 体检建议状态
class ExamAdviceState {
  final ExamAdvice? advice;
  final bool isLoading;
  final String? error;

  ExamAdviceState({
    this.advice,
    this.isLoading = false,
    this.error,
  });

  ExamAdviceState copyWith({
    ExamAdvice? advice,
    bool? isLoading,
    String? error,
  }) {
    return ExamAdviceState(
      advice: advice ?? this.advice,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 体检建议 Provider
class ExamAdviceNotifier extends StateNotifier<ExamAdviceState> {
  final ExamApiService _apiService;

  ExamAdviceNotifier(this._apiService) : super(ExamAdviceState());

  Future<void> loadAdvice(int reportId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getExamAdvice(reportId);
      if (response.success && response.data != null) {
        state = state.copyWith(
          advice: response.data,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final examAdviceProvider =
    StateNotifierProvider<ExamAdviceNotifier, ExamAdviceState>((ref) {
  return ExamAdviceNotifier(ref.watch(examApiServiceProvider));
});
