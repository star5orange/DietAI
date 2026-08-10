import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/domain/models/api_response.dart';
import '../domain/exam_models.dart';

/// 体检报告 API 服务
class ExamApiService {
  final ApiService _api = ApiService();

  /// 上传体检报告（多张照片，字段名 photos）
  Future<ApiResponse<ExamReport>> uploadExamReports({
    required List<File> photos,
    required int userId,
    String? examDate,
    String? hospitalName,
    String reportType = 'full',
  }) async {
    try {
      final formData = FormData();
      for (final photo in photos) {
        formData.files.add(MapEntry(
          'photos',
          await MultipartFile.fromFile(photo.path),
        ));
      }
      formData.fields.add(MapEntry('user_id', '$userId'));
      if (examDate != null)
        formData.fields.add(MapEntry('exam_date', examDate));
      if (hospitalName != null) {
        formData.fields.add(MapEntry('hospital_name', hospitalName));
      }
      formData.fields.add(MapEntry('report_type', reportType));

      final res = await _api.post(
        '/health/exam/upload',
        data: formData,
      );

      if (res.success && res.data is Map<String, dynamic>) {
        final report = ExamReport.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: report);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '上传体检报告失败', error: e.toString());
    }
  }

  /// 上传单张体检报告（兼容原有调用）
  Future<ApiResponse<ExamReport>> uploadExamReport({
    required File photo,
    required int userId,
    String? examDate,
    String? hospitalName,
    String reportType = 'full',
  }) {
    return uploadExamReports(
      photos: [photo],
      userId: userId,
      examDate: examDate,
      hospitalName: hospitalName,
      reportType: reportType,
    );
  }

  /// 获取报告详情元数据
  Future<ApiResponse<ExamReportDetail>> getExamReportDetail(
    int userId,
    int reportId,
  ) async {
    try {
      final res = await _api.get('/health/exam/reports/$userId/$reportId');
      if (res.success && res.data is Map<String, dynamic>) {
        final detail =
            ExamReportDetail.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: detail);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取报告详情失败', error: e.toString());
    }
  }

  /// 重新归属报告（修改为谁拍的）
  Future<ApiResponse<dynamic>> reassignExamReport(
    int reportId,
    int targetUserId,
  ) async {
    try {
      final res = await _api.post(
        '/health/exam/reports/$reportId/reassign',
        data: {'target_user_id': targetUserId},
      );
      if (res.success) {
        return ApiResponse.success(message: res.message, data: res.data);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '修改归属失败', error: e.toString());
    }
  }

  /// 设置/取消复查提醒（date 传 null 表示取消）
  Future<ApiResponse<dynamic>> setFollowupDate(
    int reportId,
    String? followupDate,
  ) async {
    try {
      final res = await _api.put(
        '/health/exam/reports/$reportId/followup',
        data: {'followup_date': followupDate},
      );
      if (res.success) {
        return ApiResponse.success(message: res.message, data: res.data);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '设置复查提醒失败', error: e.toString());
    }
  }

  /// 删除体检报告
  Future<ApiResponse<dynamic>> deleteExamReport(int reportId) async {
    try {
      final res = await _api.delete('/health/exam/reports/$reportId');
      if (res.success) {
        return ApiResponse.success(message: res.message, data: res.data);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '删除体检报告失败', error: e.toString());
    }
  }

  /// 获取体检报告列表
  Future<ApiResponse<ExamReportList>> getExamReports(int userId) async {
    try {
      final res = await _api.get('/health/exam/reports/$userId');
      if (res.success && res.data is Map<String, dynamic>) {
        final reportList =
            ExamReportList.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: reportList);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取体检报告列表失败', error: e.toString());
    }
  }

  /// 获取最新体检报告摘要
  Future<ApiResponse<ExamSummary>> getLatestExamReport(int userId) async {
    try {
      final res = await _api.get('/health/exam/reports/$userId/latest');
      if (res.success && res.data is Map<String, dynamic>) {
        final summary = ExamSummary.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: summary);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取最新体检报告失败', error: e.toString());
    }
  }

  /// 获取指标详情
  Future<ApiResponse<List<ExamMetric>>> getExamMetrics(int reportId) async {
    try {
      final res = await _api.get('/health/exam/metrics/$reportId');
      if (res.success && res.data is List) {
        final metrics = (res.data as List)
            .map((e) => ExamMetric.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(message: res.message, data: metrics);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取指标详情失败', error: e.toString());
    }
  }

  /// 修正指标值
  Future<ApiResponse<ExamMetric>> updateExamMetric(
    int metricId, {
    double? metricValue,
    String? status,
    bool? isAbnormal,
    String? unit,
  }) async {
    try {
      final res = await _api.put(
        '/health/exam/metrics/$metricId',
        data: {
          if (metricValue != null) 'metric_value': metricValue,
          if (status != null) 'status': status,
          if (isAbnormal != null) 'is_abnormal': isAbnormal,
          if (unit != null) 'unit': unit,
        },
      );
      if (res.success && res.data is Map<String, dynamic>) {
        final metric = ExamMetric.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: metric);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '修正指标失败', error: e.toString());
    }
  }

  /// 获取指标趋势
  Future<ApiResponse<MetricTrendResponse>> getMetricTrend(
    int userId,
    String metricName,
  ) async {
    try {
      final res = await _api.get('/health/exam/trend/$userId/$metricName');
      if (res.success && res.data is Map<String, dynamic>) {
        final trend =
            MetricTrendResponse.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: trend);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取指标趋势失败', error: e.toString());
    }
  }

  /// 获取健康建议
  Future<ApiResponse<ExamAdvice>> getExamAdvice(int reportId) async {
    try {
      final res = await _api.get('/health/exam/advice/$reportId');
      if (res.success && res.data is Map<String, dynamic>) {
        final advice = ExamAdvice.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: advice);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取健康建议失败', error: e.toString());
    }
  }
}
