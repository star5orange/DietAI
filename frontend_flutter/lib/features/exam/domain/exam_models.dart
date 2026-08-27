/// 安全解析数字：兼容后端返回的 num 或数字字符串（如 "24.10"）
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// 体检报告模型
class ExamReport {
  final int id;
  final int userId;
  final DateTime examDate;
  final String? hospitalName;
  final String reportType;
  final String? photoUrl;
  final int abnormalCount;
  final DateTime createdAt;
  final Map<String, dynamic>? comparedToLast;
  final String? followupDate; // 复查提醒日期 YYYY-MM-DD

  ExamReport({
    required this.id,
    required this.userId,
    required this.examDate,
    this.hospitalName,
    this.reportType = 'full',
    this.photoUrl,
    this.abnormalCount = 0,
    required this.createdAt,
    this.comparedToLast,
    this.followupDate,
  });

  factory ExamReport.fromJson(Map<String, dynamic> json) {
    return ExamReport(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      examDate: DateTime.parse(json['exam_date'] as String),
      hospitalName: json['hospital_name'] as String?,
      reportType: json['report_type'] as String? ?? 'full',
      photoUrl: json['photo_url'] as String?,
      abnormalCount: json['abnormal_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      comparedToLast: json['compared_to_last'] as Map<String, dynamic>?,
      followupDate: json['followup_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'exam_date': examDate.toIso8601String(),
      'hospital_name': hospitalName,
      'report_type': reportType,
      'photo_url': photoUrl,
      'abnormal_count': abnormalCount,
      'created_at': createdAt.toIso8601String(),
      'compared_to_last': comparedToLast,
      'followup_date': followupDate,
    };
  }
}

/// 体检上传结果（报告 + 模糊页提示）
class ExamUploadResult {
  final ExamReport report;

  /// 判定为模糊的照片页码（从 1 起），非空时提示重拍
  final List<int> blurPages;

  ExamUploadResult({required this.report, this.blurPages = const []});

  factory ExamUploadResult.fromJson(Map<String, dynamic> json) {
    return ExamUploadResult(
      report: ExamReport.fromJson(json),
      blurPages: (json['blur_warning'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

/// 体检报告详情（元数据，来自 GET /health/exam/reports/{userId}/{reportId}）
class ExamReportDetail {
  final int id;
  final int userId;
  final DateTime examDate;
  final DateTime? reportDate;
  final String? hospitalName;
  final String reportType;
  final String? photoUrl;
  final List<String>? photoUrls; // 多页报告全部照片 URL
  final int abnormalCount;
  final String? summary;
  final String? doctorAdvice;
  final Map<String, dynamic>? comparedToLast;
  final String? followupDate; // 复查提醒日期 YYYY-MM-DD
  final int? createdBy;
  final String? ownerName;

  ExamReportDetail({
    required this.id,
    required this.userId,
    required this.examDate,
    this.reportDate,
    this.hospitalName,
    this.reportType = 'full',
    this.photoUrl,
    this.photoUrls,
    this.abnormalCount = 0,
    this.summary,
    this.doctorAdvice,
    this.comparedToLast,
    this.followupDate,
    this.createdBy,
    this.ownerName,
  });

  factory ExamReportDetail.fromJson(Map<String, dynamic> json) {
    return ExamReportDetail(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      examDate: DateTime.parse(json['exam_date'] as String),
      reportDate: json['report_date'] != null
          ? DateTime.tryParse(json['report_date'] as String)
          : null,
      hospitalName: json['hospital_name'] as String?,
      reportType: json['report_type'] as String? ?? 'full',
      photoUrl: json['photo_url'] as String?,
      photoUrls:
          (json['photo_urls'] as List<dynamic>?)?.whereType<String>().toList(),
      abnormalCount: json['abnormal_count'] as int? ?? 0,
      summary: json['summary'] as String?,
      doctorAdvice: json['doctor_advice'] as String?,
      comparedToLast: json['compared_to_last'] as Map<String, dynamic>?,
      followupDate: json['followup_date'] as String?,
      createdBy: json['created_by'] as int?,
      ownerName: json['owner_name'] as String?,
    );
  }
}

/// 体检报告列表
class ExamReportList {
  final List<ExamReport> reports;
  final int total;

  ExamReportList({
    this.reports = const [],
    this.total = 0,
  });

  factory ExamReportList.fromJson(Map<String, dynamic> json) {
    return ExamReportList(
      reports: (json['reports'] as List<dynamic>?)
              ?.map((e) => ExamReport.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
    );
  }
}

/// 体检指标模型
class ExamMetric {
  final int id;
  final int reportId;
  final String category;
  final String metricName;
  final double? metricValue;
  final String? unit;
  final String status;
  final double? referenceMin;
  final double? referenceMax;
  final bool isAbnormal;

  ExamMetric({
    required this.id,
    required this.reportId,
    required this.category,
    required this.metricName,
    this.metricValue,
    this.unit,
    this.status = 'normal',
    this.referenceMin,
    this.referenceMax,
    this.isAbnormal = false,
  });

  factory ExamMetric.fromJson(Map<String, dynamic> json) {
    return ExamMetric(
      id: json['id'] as int,
      reportId: json['report_id'] as int,
      category: json['category'] as String? ?? '',
      metricName: json['metric_name'] as String? ?? '',
      metricValue: _toDouble(json['metric_value']),
      unit: json['unit'] as String?,
      status: json['status'] as String? ?? 'normal',
      referenceMin: _toDouble(json['reference_min']),
      referenceMax: _toDouble(json['reference_max']),
      isAbnormal: json['is_abnormal'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'category': category,
      'metric_name': metricName,
      'metric_value': metricValue,
      'unit': unit,
      'status': status,
      'reference_min': referenceMin,
      'reference_max': referenceMax,
      'is_abnormal': isAbnormal,
    };
  }
}

/// 指标趋势点
class MetricTrendPoint {
  final DateTime examDate;
  final double metricValue;
  final String? unit;
  final int reportId;

  MetricTrendPoint({
    required this.examDate,
    required this.metricValue,
    this.unit,
    required this.reportId,
  });

  factory MetricTrendPoint.fromJson(Map<String, dynamic> json) {
    return MetricTrendPoint(
      examDate: DateTime.parse(json['exam_date'] as String),
      metricValue: _toDouble(json['metric_value']) ?? 0,
      unit: json['unit'] as String?,
      reportId: json['report_id'] as int,
    );
  }
}

/// 指标趋势响应
class MetricTrendResponse {
  final String metricName;
  final String? category;
  final String? unit;
  final double? referenceMin;
  final double? referenceMax;
  final List<MetricTrendPoint> trend;
  final String? trendDirection;
  final String? changeSummary;

  MetricTrendResponse({
    required this.metricName,
    this.category,
    this.unit,
    this.referenceMin,
    this.referenceMax,
    this.trend = const [],
    this.trendDirection,
    this.changeSummary,
  });

  factory MetricTrendResponse.fromJson(Map<String, dynamic> json) {
    return MetricTrendResponse(
      metricName: json['metric_name'] as String? ?? '',
      category: json['category'] as String?,
      unit: json['unit'] as String?,
      referenceMin: _toDouble(json['reference_min']),
      referenceMax: _toDouble(json['reference_max']),
      trend: (json['trend'] as List<dynamic>?)
              ?.map((e) => MetricTrendPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      trendDirection: json['trend_direction'] as String?,
      changeSummary: json['change_summary'] as String?,
    );
  }
}

/// 体检摘要
class ExamSummary {
  final int userId;
  final DateTime? latestExamDate;
  final int abnormalCount;
  final List<String> abnormalMetrics;

  ExamSummary({
    required this.userId,
    this.latestExamDate,
    this.abnormalCount = 0,
    this.abnormalMetrics = const [],
  });

  factory ExamSummary.fromJson(Map<String, dynamic> json) {
    return ExamSummary(
      userId: json['user_id'] as int,
      latestExamDate: json['latest_exam_date'] != null
          ? DateTime.tryParse(json['latest_exam_date'] as String)
          : null,
      abnormalCount: json['abnormal_count'] as int? ?? 0,
      abnormalMetrics: (json['abnormal_metrics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// 体检建议
class ExamAdvice {
  final int reportId;
  final String advice;
  final List<String> dietRecommendations;
  final List<String> exerciseRecommendations;
  final String? followupReminder;
  final bool suggestWeightLossGoal; // 是否建议设置减重目标

  ExamAdvice({
    required this.reportId,
    required this.advice,
    this.dietRecommendations = const [],
    this.exerciseRecommendations = const [],
    this.followupReminder,
    this.suggestWeightLossGoal = false,
  });

  factory ExamAdvice.fromJson(Map<String, dynamic> json) {
    return ExamAdvice(
      reportId: json['report_id'] as int,
      advice: json['advice'] as String? ?? '',
      dietRecommendations: (json['diet_recommendations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      exerciseRecommendations:
          (json['exercise_recommendations'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
      followupReminder: json['followup_reminder'] as String?,
      suggestWeightLossGoal: json['suggest_weight_loss_goal'] as bool? ?? false,
    );
  }
}
