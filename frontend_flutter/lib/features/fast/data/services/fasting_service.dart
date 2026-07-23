import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/api_service.dart';

/// 断食计划模型
class FastingPlan {
  final int planId;
  final String planType;
  final String status;
  final String startDate;
  final int? daysElapsed;
  final int? daysRemaining;
  final double? targetWeight;
  final double? currentWeight;
  final String? eatingWindowStart;
  final String? eatingWindowEnd;
  final List<int>? fastingDays; // 断食日(1-7表示周一到周日)

  const FastingPlan({
    required this.planId,
    required this.planType,
    required this.status,
    required this.startDate,
    this.daysElapsed,
    this.daysRemaining,
    this.targetWeight,
    this.currentWeight,
    this.eatingWindowStart,
    this.eatingWindowEnd,
    this.fastingDays,
  });

  factory FastingPlan.fromJson(Map<String, dynamic> json) {
    return FastingPlan(
      planId: json['plan_id'] ?? 0,
      planType: json['plan_type'] ?? '',
      status: json['status'] ?? '',
      startDate: json['start_date'] ?? '',
      daysElapsed: json['days_elapsed'],
      daysRemaining: json['days_remaining'],
      targetWeight: json['target_weight']?.toDouble(),
      currentWeight: json['current_weight']?.toDouble(),
      eatingWindowStart: json['eating_window_start'],
      eatingWindowEnd: json['eating_window_end'],
      fastingDays: (json['fasting_days'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  /// 判断今天是否是断食日
  bool isFastingDayToday() {
    // 16:8 每天都是断食日
    if (planType == '16_8') return true;

    // 5:2 和 basic_fasting 需要检查 fastingDays
    // 没有配置时默认不允许打卡（需要先配置断食日）
    if (fastingDays == null || fastingDays!.isEmpty) return false;

    // 获取今天是周几（1=周一，7=周日）
    final today = DateTime.now().weekday;
    return fastingDays!.contains(today);
  }
}

/// 断食打卡记录模型
class FastingCheckin {
  final int id;
  final String checkinDate;
  final double? weight;
  final String feeling;
  final bool completed;
  final Map<String, dynamic>? discomfort;
  final String? notes;

  const FastingCheckin({
    required this.id,
    required this.checkinDate,
    this.weight,
    required this.feeling,
    required this.completed,
    this.discomfort,
    this.notes,
  });

  factory FastingCheckin.fromJson(Map<String, dynamic> json) {
    return FastingCheckin(
      id: json['id'] ?? 0,
      checkinDate: json['checkin_date'] ?? '',
      weight: json['weight']?.toDouble(),
      feeling: json['feeling'] ?? 'normal',
      completed: json['completed'] ?? false,
      discomfort: json['discomfort'],
      notes: json['notes'],
    );
  }
}

/// 断食进度模型
class FastingProgress {
  final int planId;
  final String? planType;
  final int daysElapsed;
  final int daysTotal;
  final double completionRate;
  final double? weightStart;
  final double? weightCurrent;
  final double? weightChange;
  final String feelingAvg;
  final int streakDays; // 16:8 使用
  final int weeklyCheckins; // 5:2/基础断食使用
  final int weeklyTarget; // 5:2/基础断食使用
  final List<Map<String, dynamic>> chart;

  const FastingProgress({
    required this.planId,
    this.planType,
    required this.daysElapsed,
    required this.daysTotal,
    required this.completionRate,
    this.weightStart,
    this.weightCurrent,
    this.weightChange,
    required this.feelingAvg,
    required this.streakDays,
    this.weeklyCheckins = 0,
    this.weeklyTarget = 0,
    required this.chart,
  });

  factory FastingProgress.fromJson(Map<String, dynamic> json) {
    return FastingProgress(
      planId: json['plan_id'] ?? 0,
      planType: json['plan_type'],
      daysElapsed: json['days_elapsed'] ?? 0,
      daysTotal: json['days_total'] ?? 30,
      completionRate: (json['completion_rate'] ?? 0).toDouble(),
      weightStart: json['weight_start']?.toDouble(),
      weightCurrent: json['weight_current']?.toDouble(),
      weightChange: json['weight_change']?.toDouble(),
      feelingAvg: json['feeling_avg'] ?? 'normal',
      streakDays: json['streak_days'] ?? 0,
      weeklyCheckins: json['weekly_checkins'] ?? 0,
      weeklyTarget: json['weekly_target'] ?? 0,
      chart: List<Map<String, dynamic>>.from(
        (json['chart'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>) ??
            [],
      ),
    );
  }
}

/// 复食指导模型
class RefeedGuide {
  final String planType;
  final String refeedDuration;
  final List<Map<String, dynamic>> phases;
  final String disclaimer;

  const RefeedGuide({
    required this.planType,
    required this.refeedDuration,
    required this.phases,
    required this.disclaimer,
  });

  factory RefeedGuide.fromJson(Map<String, dynamic> json) {
    return RefeedGuide(
      planType: json['plan_type'] ?? '',
      refeedDuration: json['refeed_duration'] ?? '',
      phases: List<Map<String, dynamic>>.from(
        (json['phases'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>) ??
            [],
      ),
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

/// 断食服务
class FastingService {
  final ApiService _apiService;

  FastingService(this._apiService);

  /// 获取计划列表
  Future<List<FastingPlan>> getPlans({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final response = await _apiService.dio.get(
      '/fasting/plans',
      queryParameters: params.isEmpty ? null : params,
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      final plans = data['data']['plans'] as List<dynamic>? ?? [];
      return plans
          .map((e) => FastingPlan.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 创建断食计划
  Future<Map<String, dynamic>> createPlan({
    required String planType,
    required String startDate,
    String eatingWindowStart = '08:00',
    String eatingWindowEnd = '16:00',
    double? targetWeight,
    Map<String, dynamic>? healthAssessment,
    bool disclaimerAccepted = false,
    List<int>? fastingDays,
  }) async {
    try {
      final response = await _apiService.dio.post(
        '/fasting/plans',
        data: {
          'plan_type': planType,
          'start_date': startDate,
          'eating_window_start': eatingWindowStart,
          'eating_window_end': eatingWindowEnd,
          if (targetWeight != null) 'target_weight': targetWeight,
          if (healthAssessment != null) 'health_assessment': healthAssessment,
          'disclaimer_accepted': disclaimerAccepted,
          if (fastingDays != null) 'fasting_days': fastingDays,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['data'] as Map<String, dynamic>;
      }
      throw Exception(data['message'] ?? '创建计划失败');
    } on DioException catch (e) {
      final detail = _extractErrorDetail(e);
      throw Exception(detail);
    }
  }

  /// 更新计划
  Future<void> updatePlan(
    int planId, {
    double? targetWeight,
    String? eatingWindowStart,
    String? eatingWindowEnd,
    String? endDate,
  }) async {
    final response = await _apiService.dio.put(
      '/fasting/plans/$planId',
      data: {
        if (targetWeight != null) 'target_weight': targetWeight,
        if (eatingWindowStart != null) 'eating_window_start': eatingWindowStart,
        if (eatingWindowEnd != null) 'eating_window_end': eatingWindowEnd,
        if (endDate != null) 'end_date': endDate,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '更新计划失败');
    }
  }

  /// 停止计划
  Future<void> stopPlan(int planId) async {
    final response = await _apiService.dio.put('/fasting/plans/$planId/stop');
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '停止计划失败');
    }
  }

  /// 每日打卡
  Future<Map<String, dynamic>> createCheckin({
    required int planId,
    required String checkinDate,
    double? weight,
    String feeling = 'normal',
    bool completed = false,
    Map<String, bool>? discomfort,
    String? notes,
  }) async {
    final response = await _apiService.dio.post(
      '/fasting/checkins',
      data: {
        'plan_id': planId,
        'checkin_date': checkinDate,
        if (weight != null) 'weight': weight,
        'feeling': feeling,
        'completed': completed,
        if (discomfort != null) 'discomfort': discomfort,
        if (notes != null) 'notes': notes,
      },
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception(data['message'] ?? '打卡失败');
  }

  /// 获取打卡记录
  Future<List<FastingCheckin>> getCheckins(int planId) async {
    final response = await _apiService.dio.get(
      '/fasting/checkins',
      queryParameters: {'plan_id': planId},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      final checkins = data['data']['checkins'] as List<dynamic>? ?? [];
      return checkins
          .map((e) => FastingCheckin.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取进度
  Future<FastingProgress> getProgress(int planId) async {
    final response = await _apiService.dio.get(
      '/fasting/progress',
      queryParameters: {'plan_id': planId},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      return FastingProgress.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? '获取进度失败');
  }

  /// 获取复食指导
  Future<RefeedGuide> getRefeedGuide(int planId) async {
    final response = await _apiService.dio.get(
      '/fasting/refeed-guide',
      queryParameters: {'plan_id': planId},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      return RefeedGuide.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? '获取复食指导失败');
  }

  /// 从 DioException 提取后端返回的具体错误信息
  String _extractErrorDetail(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final body = e.response!.data as Map<String, dynamic>;
      // FastAPI HTTPException detail
      if (body.containsKey('detail')) {
        return body['detail'].toString();
      }
      // 自定义 message
      if (body.containsKey('message')) {
        return body['message'].toString();
      }
    }
    // 网络错误
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return '网络连接超时，请检查网络后重试';
    }
    if (e.type == DioExceptionType.connectionError) {
      return '无法连接服务器，请检查网络';
    }
    return e.message ?? '未知错误';
  }
}

/// Provider 定义
final fastingServiceProvider = Provider<FastingService>((ref) {
  return FastingService(ApiService());
});

final fastingPlansProvider = FutureProvider<List<FastingPlan>>((ref) async {
  final service = ref.watch(fastingServiceProvider);
  return service.getPlans();
});
