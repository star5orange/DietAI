import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';

/// 消费统计模型
class CostStats {
  final String period;
  final double totalCost;
  final double dailyAvg;
  final double maxSingle;
  final int recordCount;
  final Map<String, double> byMealTime;
  final Map<String, double> bySource;
  final double caloriePerYuan;
  final double? budgetRemaining;
  final double? budget;
  final Map<String, dynamic>? budgetWarning;

  const CostStats({
    required this.period,
    required this.totalCost,
    required this.dailyAvg,
    required this.maxSingle,
    required this.recordCount,
    required this.byMealTime,
    required this.bySource,
    required this.caloriePerYuan,
    this.budgetRemaining,
    this.budget,
    this.budgetWarning,
  });

  factory CostStats.fromJson(Map<String, dynamic> json) {
    return CostStats(
      period: json['period'] ?? 'week',
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      dailyAvg: (json['daily_avg'] ?? 0).toDouble(),
      maxSingle: (json['max_single'] ?? 0).toDouble(),
      recordCount: json['record_count'] ?? 0,
      byMealTime: Map<String, double>.from(
        (json['by_meal_time'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {},
      ),
      bySource: Map<String, double>.from(
        (json['by_source'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {},
      ),
      caloriePerYuan: (json['calorie_per_yuan'] ?? 0).toDouble(),
      budgetRemaining: json['budget_remaining']?.toDouble(),
      budget: json['budget']?.toDouble(),
      budgetWarning: json['budget_warning'],
    );
  }
}

/// 消费趋势项
class CostTrendItem {
  final String date;
  final double cost;
  final int records;

  const CostTrendItem({
    required this.date,
    required this.cost,
    required this.records,
  });

  factory CostTrendItem.fromJson(Map<String, dynamic> json) {
    return CostTrendItem(
      date: json['date'] ?? '',
      cost: (json['cost'] ?? 0).toDouble(),
      records: json['records'] ?? 0,
    );
  }
}

/// 消费趋势模型
class CostTrend {
  final List<CostTrendItem> trend;
  final double total;
  final double avg;
  final String? sourceTag;

  const CostTrend({
    required this.trend,
    required this.total,
    required this.avg,
    this.sourceTag,
  });

  factory CostTrend.fromJson(Map<String, dynamic> json) {
    return CostTrend(
      trend: (json['trend'] as List<dynamic>?)
              ?.map((e) => CostTrendItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] ?? 0).toDouble(),
      avg: (json['avg'] ?? 0).toDouble(),
      sourceTag: json['source_tag'],
    );
  }
}

/// 消费统计服务
class CostService {
  final ApiService _apiService;

  CostService(this._apiService);

  /// 获取消费统计
  Future<CostStats> getCostStats({String period = 'week'}) async {
    final response = await _apiService.dio.get(
      '/foods/cost-stats',
      queryParameters: {'period': period},
    );

    final responseData = response.data as Map<String, dynamic>;
    if (responseData['success'] == true && responseData['data'] != null) {
      return CostStats.fromJson(responseData['data'] as Map<String, dynamic>);
    }

    throw Exception(responseData['message'] ?? '获取消费统计失败');
  }

  /// 获取消费趋势
  Future<CostTrend> getCostTrend({
    int days = 7,
    String? sourceTag,
  }) async {
    final params = <String, dynamic>{'days': days};
    if (sourceTag != null) {
      params['source_tag'] = sourceTag;
    }

    final response = await _apiService.dio.get(
      '/foods/cost-trend',
      queryParameters: params,
    );

    final responseData = response.data as Map<String, dynamic>;
    if (responseData['success'] == true && responseData['data'] != null) {
      return CostTrend.fromJson(responseData['data'] as Map<String, dynamic>);
    }

    throw Exception(responseData['message'] ?? '获取消费趋势失败');
  }

  /// 设置月度预算
  Future<void> setMonthlyBudget(double budget) async {
    final response = await _apiService.dio.post(
      '/foods/cost-budget',
      data: {'budget': budget},
    );

    final responseData = response.data as Map<String, dynamic>;
    if (responseData['success'] != true) {
      throw Exception(responseData['message'] ?? '设置预算失败');
    }
  }
}

/// Provider 定义
final costServiceProvider = Provider<CostService>((ref) {
  return CostService(ApiService());
});

final costStatsProvider =
    FutureProvider.family<CostStats, String>((ref, period) async {
  final service = ref.watch(costServiceProvider);
  return service.getCostStats(period: period);
});

final costTrendProvider =
    FutureProvider.family<CostTrend, int>((ref, days) async {
  final service = ref.watch(costServiceProvider);
  return service.getCostTrend(days: days);
});
