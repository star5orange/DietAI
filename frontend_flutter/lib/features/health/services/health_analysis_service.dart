import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

// 健康分析结果模型
class BMRResult {
  final double bmr;
  final String formula;
  final Map<String, dynamic> details;

  BMRResult({
    required this.bmr,
    required this.formula,
    required this.details,
  });

  factory BMRResult.fromJson(Map<String, dynamic> json) {
    return BMRResult(
      bmr: (json['bmr'] ?? 0.0).toDouble(),
      formula: json['formula'] ?? '',
      details: json['details'] ?? {},
    );
  }
}

class TDEEResult {
  final double tdee;
  final double activityFactor;
  final Map<String, dynamic> breakdown;

  TDEEResult({
    required this.tdee,
    required this.activityFactor,
    required this.breakdown,
  });

  factory TDEEResult.fromJson(Map<String, dynamic> json) {
    return TDEEResult(
      tdee: (json['tdee'] ?? 0.0).toDouble(),
      activityFactor: (json['activity_factor'] ?? 0.0).toDouble(),
      breakdown: json['breakdown'] ?? {},
    );
  }
}

class HealthScoreResult {
  final double score;
  final String level;
  final List<String> factors;
  final List<String> recommendations;

  HealthScoreResult({
    required this.score,
    required this.level,
    required this.factors,
    required this.recommendations,
  });

  factory HealthScoreResult.fromJson(Map<String, dynamic> json) {
    return HealthScoreResult(
      score: (json['score'] ?? 0.0).toDouble(),
      level: json['level'] ?? '',
      factors: List<String>.from(json['factors'] ?? []),
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}

class NutritionBalanceResult {
  final Map<String, double> balance;
  final List<String> deficiencies;
  final List<String> excesses;
  final Map<String, String> recommendations;

  NutritionBalanceResult({
    required this.balance,
    required this.deficiencies,
    required this.excesses,
    required this.recommendations,
  });

  factory NutritionBalanceResult.fromJson(Map<String, dynamic> json) {
    return NutritionBalanceResult(
      balance: Map<String, double>.from(json['balance'] ?? {}),
      deficiencies: List<String>.from(json['deficiencies'] ?? []),
      excesses: List<String>.from(json['excesses'] ?? []),
      recommendations: Map<String, String>.from(json['recommendations'] ?? {}),
    );
  }
}

class WeightTrendResult {
  final List<Map<String, dynamic>> trend;
  final double changeRate;
  final String prediction;

  WeightTrendResult({
    required this.trend,
    required this.changeRate,
    required this.prediction,
  });

  factory WeightTrendResult.fromJson(Map<String, dynamic> json) {
    return WeightTrendResult(
      trend: List<Map<String, dynamic>>.from(json['trend'] ?? []),
      changeRate: (json['change_rate'] ?? 0.0).toDouble(),
      prediction: json['prediction'] ?? '',
    );
  }
}

class UserData {
  final int id;
  final String username;
  final Map<String, dynamic> profile;

  UserData({
    required this.id,
    required this.username,
    required this.profile,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      profile: json['profile'] ?? {},
    );
  }
}

/// 健康分析服务
class HealthAnalysisService {
  final ApiService _apiService = ApiService();

  /// 计算基础代谢率
  Future<ApiResponse<BMRResult>> calculateBMR() async {
    try {
      final response = await _apiService.get('/health/analysis/bmr');
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          BMRResult.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('计算基础代谢率失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 计算每日总能量消耗
  Future<ApiResponse<TDEEResult>> calculateTDEE() async {
    try {
      final response = await _apiService.get('/health/analysis/tdee');
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          TDEEResult.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('计算TDEE失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取健康评分
  Future<ApiResponse<HealthScoreResult>> getHealthScore() async {
    try {
      final response = await _apiService.get('/health/analysis/health-score');
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          HealthScoreResult.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('获取健康评分失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 分析营养平衡
  Future<ApiResponse<NutritionBalanceResult>> analyzeNutritionBalance({
    String? dateRange,
  }) async {
    try {
      String url = '/health/analysis/nutrition-balance';
      if (dateRange != null) {
        url += '?date_range=$dateRange';
      }
      
      final response = await _apiService.get(url);
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          NutritionBalanceResult.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('营养平衡分析失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取体重趋势
  Future<ApiResponse<WeightTrendResult>> getWeightTrend({
    String? startDate,
    String? endDate,
  }) async {
    try {
      String url = '/health/analysis/weight-trend';
      List<String> params = [];
      
      if (startDate != null) params.add('start_date=$startDate');
      if (endDate != null) params.add('end_date=$endDate');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      final response = await _apiService.get(url);
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          WeightTrendResult.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('获取体重趋势失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }

  /// 获取用户数据
  Future<ApiResponse<UserData>> getUserData() async {
    try {
      final response = await _apiService.get('/users/profile');
      
      if (response.success && response.data != null) {
        return ApiResponse.success(
          UserData.fromJson(response.data),
          response.message,
        );
      }
      
      return ApiResponse.error('获取用户数据失败');
    } catch (e) {
      return ApiResponse.error('网络错误: $e');
    }
  }
}