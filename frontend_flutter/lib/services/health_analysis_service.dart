import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

class HealthAnalysisService {
  final ApiService _apiService = ApiService();

  /// 获取每周摘要报告
  Future<ApiResponse<Map<String, dynamic>>> getWeeklySummary({
    String? targetDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (targetDate != null) queryParams['target_date'] = targetDate;

      final response = await _apiService.get(
        '/health/weekly-summary',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取周报成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取周报失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取周报失败: $e',
      );
    }
  }

  /// 获取基础代谢率(BMR)
  Future<ApiResponse<BMRResult>> getBMR() async {
    try {
      final response = await _apiService.get('/health/bmr');
      
      if (response.success && response.data != null) {
        final bmr = BMRResult.fromJson(response.data);
        
        return ApiResponse<BMRResult>.success(
          message: response.message.isNotEmpty ? response.message : '获取BMR成功',
          data: bmr,
        );
      } else {
        return ApiResponse<BMRResult>.failure(
          message: response.message.isNotEmpty ? response.message : '获取BMR失败',
        );
      }
    } catch (e) {
      return ApiResponse<BMRResult>.failure(
        message: '获取BMR失败: $e',
      );
    }
  }

  /// 获取每日总能量消耗(TDEE)
  Future<ApiResponse<TDEEResult>> getTDEE() async {
    try {
      final response = await _apiService.get('/health/tdee');
      
      if (response.success && response.data != null) {
        final tdee = TDEEResult.fromJson(response.data);
        
        return ApiResponse<TDEEResult>.success(
          message: response.message.isNotEmpty ? response.message : '获取TDEE成功',
          data: tdee,
        );
      } else {
        return ApiResponse<TDEEResult>.failure(
          message: response.message.isNotEmpty ? response.message : '获取TDEE失败',
        );
      }
    } catch (e) {
      return ApiResponse<TDEEResult>.failure(
        message: '获取TDEE失败: $e',
      );
    }
  }

  /// 获取营养平衡分析
  Future<ApiResponse<NutritionBalanceResult>> getNutritionBalance({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/health/nutrition-balance',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final nutrition = NutritionBalanceResult.fromJson(response.data);
        
        return ApiResponse<NutritionBalanceResult>.success(
          message: response.message.isNotEmpty ? response.message : '获取营养分析成功',
          data: nutrition,
        );
      } else {
        return ApiResponse<NutritionBalanceResult>.failure(
          message: response.message.isNotEmpty ? response.message : '获取营养分析失败',
        );
      }
    } catch (e) {
      return ApiResponse<NutritionBalanceResult>.failure(
        message: '获取营养分析失败: $e',
      );
    }
  }

  /// 获取健康评分
  Future<ApiResponse<HealthScoreResult>> getHealthScore({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/health/health-score',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final healthScore = HealthScoreResult.fromJson(response.data);
        
        return ApiResponse<HealthScoreResult>.success(
          message: response.message.isNotEmpty ? response.message : '获取健康评分成功',
          data: healthScore,
        );
      } else {
        return ApiResponse<HealthScoreResult>.failure(
          message: response.message.isNotEmpty ? response.message : '获取健康评分失败',
        );
      }
    } catch (e) {
      return ApiResponse<HealthScoreResult>.failure(
        message: '获取健康评分失败: $e',
      );
    }
  }

  /// 获取体重趋势分析
  Future<ApiResponse<WeightTrendResult>> getWeightTrend({
    int? days,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (days != null) queryParams['days'] = days;

      final response = await _apiService.get(
        '/health/weight-trend',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final weightTrend = WeightTrendResult.fromJson(response.data);
        
        return ApiResponse<WeightTrendResult>.success(
          message: response.message.isNotEmpty ? response.message : '获取体重趋势成功',
          data: weightTrend,
        );
      } else {
        return ApiResponse<WeightTrendResult>.failure(
          message: response.message.isNotEmpty ? response.message : '获取体重趋势失败',
        );
      }
    } catch (e) {
      return ApiResponse<WeightTrendResult>.failure(
        message: '获取体重趋势失败: $e',
      );
    }
  }

  /// 执行健康分析（通用接口）
  Future<ApiResponse<Map<String, dynamic>>> performHealthAnalysis({
    required String analysisType,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final requestData = {
        'analysis_type': analysisType,
        if (startDate != null || endDate != null) 'date_range': {
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        }
      };

      final response = await _apiService.post(
        '/health/analysis',
        data: requestData,
      );
      
      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '健康分析完成',
          data: response.data,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>.failure(
          message: response.message.isNotEmpty ? response.message : '健康分析失败',
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '健康分析失败: $e',
      );
    }
  }
}

// 数据模型类
class BMRResult {
  final double bmr;
  final String unit;
  final String method;
  final UserData userData;
  final String description;

  BMRResult({
    required this.bmr,
    required this.unit,
    required this.method,
    required this.userData,
    required this.description,
  });

  factory BMRResult.fromJson(Map<String, dynamic> json) {
    return BMRResult(
      bmr: (json['bmr'] as num).toDouble(),
      unit: json['unit'] ?? 'kcal/day',
      method: json['method'] ?? '',
      userData: UserData.fromJson(json['user_data'] ?? {}),
      description: json['description'] ?? '',
    );
  }
}

class UserData {
  final double weight;
  final double height;
  final int age;
  final String gender;

  UserData({
    required this.weight,
    required this.height,
    required this.age,
    required this.gender,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      age: json['age'] ?? 0,
      gender: json['gender'] ?? '',
    );
  }
}

class TDEEResult {
  final double tdee;
  final double bmr;
  final int activityLevel;
  final double activityFactor;
  final String activityDescription;
  final String unit;
  final String description;

  TDEEResult({
    required this.tdee,
    required this.bmr,
    required this.activityLevel,
    required this.activityFactor,
    required this.activityDescription,
    required this.unit,
    required this.description,
  });

  factory TDEEResult.fromJson(Map<String, dynamic> json) {
    return TDEEResult(
      tdee: (json['tdee'] as num).toDouble(),
      bmr: (json['bmr'] as num).toDouble(),
      activityLevel: json['activity_level'] ?? 2,
      activityFactor: (json['activity_factor'] as num).toDouble(),
      activityDescription: json['activity_description'] ?? '',
      unit: json['unit'] ?? 'kcal/day',
      description: json['description'] ?? '',
    );
  }
}

class NutritionBalanceResult {
  final DatePeriod period;
  final NutritionAverages averages;
  final NutritionPercentages percentages;
  final NutritionReference reference;
  final List<String> recommendations;

  NutritionBalanceResult({
    required this.period,
    required this.averages,
    required this.percentages,
    required this.reference,
    required this.recommendations,
  });

  factory NutritionBalanceResult.fromJson(Map<String, dynamic> json) {
    return NutritionBalanceResult(
      period: DatePeriod.fromJson(json['period'] ?? {}),
      averages: NutritionAverages.fromJson(json['averages'] ?? {}),
      percentages: NutritionPercentages.fromJson(json['percentages'] ?? {}),
      reference: NutritionReference.fromJson(json['reference'] ?? {}),
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }
}

class DatePeriod {
  final String startDate;
  final String endDate;
  final int? days;

  DatePeriod({
    required this.startDate,
    required this.endDate,
    this.days,
  });

  factory DatePeriod.fromJson(Map<String, dynamic> json) {
    return DatePeriod(
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      days: json['days'],
    );
  }
}

class NutritionAverages {
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  final double fiber;
  final double sodium;

  NutritionAverages({
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.fiber,
    required this.sodium,
  });

  factory NutritionAverages.fromJson(Map<String, dynamic> json) {
    return NutritionAverages(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sodium: (json['sodium'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NutritionPercentages {
  final double protein;
  final double fat;
  final double carbohydrates;

  NutritionPercentages({
    required this.protein,
    required this.fat,
    required this.carbohydrates,
  });

  factory NutritionPercentages.fromJson(Map<String, dynamic> json) {
    return NutritionPercentages(
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NutritionReference {
  final double recommendedCalories;
  final double calorieRatio;

  NutritionReference({
    required this.recommendedCalories,
    required this.calorieRatio,
  });

  factory NutritionReference.fromJson(Map<String, dynamic> json) {
    return NutritionReference(
      recommendedCalories: (json['recommended_calories'] as num?)?.toDouble() ?? 0.0,
      calorieRatio: (json['calorie_ratio'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HealthScoreResult {
  final double totalScore;
  final String grade;
  final Map<String, HealthScoreComponent> components;
  final List<String> suggestions;
  final DatePeriod period;

  HealthScoreResult({
    required this.totalScore,
    required this.grade,
    required this.components,
    required this.suggestions,
    required this.period,
  });

  factory HealthScoreResult.fromJson(Map<String, dynamic> json) {
    final componentsMap = <String, HealthScoreComponent>{};
    if (json['components'] != null) {
      (json['components'] as Map<String, dynamic>).forEach((key, value) {
        componentsMap[key] = HealthScoreComponent.fromJson(value);
      });
    }

    return HealthScoreResult(
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] ?? '',
      components: componentsMap,
      suggestions: List<String>.from(json['suggestions'] ?? []),
      period: DatePeriod.fromJson(json['period'] ?? {}),
    );
  }
}

class HealthScoreComponent {
  final double score;
  final double maxScore;
  final String description;

  HealthScoreComponent({
    required this.score,
    required this.maxScore,
    required this.description,
  });

  factory HealthScoreComponent.fromJson(Map<String, dynamic> json) {
    return HealthScoreComponent(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (json['max_score'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
    );
  }
}

class WeightTrendResult {
  final String trend;
  final double weightChange;
  final double weightChangePercentage;
  final List<WeightRecord> records;
  final String analysis;
  final DatePeriod period;

  WeightTrendResult({
    required this.trend,
    required this.weightChange,
    required this.weightChangePercentage,
    required this.records,
    required this.analysis,
    required this.period,
  });

  factory WeightTrendResult.fromJson(Map<String, dynamic> json) {
    final recordsList = <WeightRecord>[];
    if (json['records'] != null) {
      recordsList.addAll(
        (json['records'] as List).map((item) => WeightRecord.fromJson(item))
      );
    }

    return WeightTrendResult(
      trend: json['trend'] ?? '',
      weightChange: (json['weight_change'] as num?)?.toDouble() ?? 0.0,
      weightChangePercentage: (json['weight_change_percentage'] as num?)?.toDouble() ?? 0.0,
      records: recordsList,
      analysis: json['analysis'] ?? '',
      period: DatePeriod.fromJson(json['period'] ?? {}),
    );
  }
}

class WeightRecord {
  final String date;
  final double weight;
  final double? bmi;
  final double? bodyFatPercentage;

  WeightRecord({
    required this.date,
    required this.weight,
    this.bmi,
    this.bodyFatPercentage,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      date: json['date'] ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      bmi: (json['bmi'] as num?)?.toDouble(),
      bodyFatPercentage: (json['body_fat_percentage'] as num?)?.toDouble(),
    );
  }
}