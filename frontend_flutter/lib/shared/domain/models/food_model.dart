import 'package:json_annotation/json_annotation.dart';

part 'food_model.g.dart';

/// 营养素信息
@JsonSerializable()
class Macronutrients {
  final double protein;
  final double fat;
  final double carbohydrates;
  @JsonKey(name: 'dietary_fiber')
  final double dietaryFiber;
  final double sugar;

  const Macronutrients({
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.dietaryFiber,
    required this.sugar,
  });

  factory Macronutrients.fromJson(Map<String, dynamic> json) =>
      _$MacronutrientsFromJson(json);
  Map<String, dynamic> toJson() => _$MacronutrientsToJson(this);
}

/// 维生素和矿物质信息
@JsonSerializable()
class VitaminsMinerals {
  @JsonKey(name: 'vitamin_a')
  final double? vitaminA;
  @JsonKey(name: 'vitamin_c')
  final double? vitaminC;
  @JsonKey(name: 'vitamin_d')
  final double? vitaminD;
  final double? calcium;
  final double? iron;
  final double? sodium;
  final double? potassium;
  final double? cholesterol;

  const VitaminsMinerals({
    this.vitaminA,
    this.vitaminC,
    this.vitaminD,
    this.calcium,
    this.iron,
    this.sodium,
    this.potassium,
    this.cholesterol,
  });

  factory VitaminsMinerals.fromJson(Map<String, dynamic> json) =>
      _$VitaminsMineralsFromJson(json);
  Map<String, dynamic> toJson() => _$VitaminsMineralsToJson(this);
}

/// 营养成分
@JsonSerializable()
class NutritionFacts {
  @JsonKey(name: 'food_items')
  final List<String>? foodItems;
  @JsonKey(name: 'total_calories')
  final double totalCalories;
  final Macronutrients macronutrients;
  @JsonKey(name: 'vitamins_minerals')
  final VitaminsMinerals? vitaminsMinerals;
  @JsonKey(name: 'health_level')
  final int? healthLevel;

  const NutritionFacts({
    this.foodItems,
    required this.totalCalories,
    required this.macronutrients,
    this.vitaminsMinerals,
    this.healthLevel,
  });

  factory NutritionFacts.fromJson(Map<String, dynamic> json) =>
      _$NutritionFactsFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionFactsToJson(this);
}

/// 行动项
@JsonSerializable()
class ActionItem {
  final String action;
  final String priority; // high/medium/low

  const ActionItem({
    required this.action,
    required this.priority,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) =>
      _$ActionItemFromJson(json);
  Map<String, dynamic> toJson() => _$ActionItemToJson(this);
}

/// 推荐建议
@JsonSerializable()
class Recommendations {
  final List<String>? recommendations;
  @JsonKey(name: 'dietary_tips')
  final List<String>? dietaryTips;
  final List<String>? warnings;
  @JsonKey(name: 'alternative_foods')
  final List<String>? alternativeFoods;
  @JsonKey(name: 'action_items')
  final List<ActionItem>? actionItems;

  const Recommendations({
    this.recommendations,
    this.dietaryTips,
    this.warnings,
    this.alternativeFoods,
    this.actionItems,
  });

  factory Recommendations.fromJson(Map<String, dynamic> json) =>
      _$RecommendationsFromJson(json);
  Map<String, dynamic> toJson() => _$RecommendationsToJson(this);
}

/// Agent分析结果
@JsonSerializable()
class AgentAnalysisData {
  @JsonKey(name: 'image_description')
  final String imageDescription;
  @JsonKey(name: 'nutrition_facts')
  final NutritionFacts nutritionFacts;
  final Recommendations recommendations;

  const AgentAnalysisData({
    required this.imageDescription,
    required this.nutritionFacts,
    required this.recommendations,
  });

  factory AgentAnalysisData.fromJson(Map<String, dynamic> json) =>
      _$AgentAnalysisDataFromJson(json);
  Map<String, dynamic> toJson() => _$AgentAnalysisDataToJson(this);
}

/// 营养详情
@JsonSerializable()
class NutritionDetail {
  final int id;
  @JsonKey(name: 'food_record_id')
  final int foodRecordId;
  final double calories;
  final double protein;
  final double fat;
  final double carbohydrates;
  @JsonKey(name: 'dietary_fiber')
  final double dietaryFiber;
  final double sugar;
  final double sodium;
  final double cholesterol;
  @JsonKey(name: 'vitamin_a')
  final double vitaminA;
  @JsonKey(name: 'vitamin_c')
  final double vitaminC;
  @JsonKey(name: 'vitamin_d')
  final double vitaminD;
  final double calcium;
  final double iron;
  final double potassium;
  @JsonKey(name: 'confidence_score')
  final double? confidenceScore;
  @JsonKey(name: 'analysis_method')
  final String? analysisMethod;

  const NutritionDetail({
    required this.id,
    required this.foodRecordId,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrates,
    required this.dietaryFiber,
    required this.sugar,
    required this.sodium,
    required this.cholesterol,
    required this.vitaminA,
    required this.vitaminC,
    required this.vitaminD,
    required this.calcium,
    required this.iron,
    required this.potassium,
    this.confidenceScore,
    this.analysisMethod,
  });

  factory NutritionDetail.fromJson(Map<String, dynamic> json) =>
      _$NutritionDetailFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionDetailToJson(this);
}

/// 食物记录
@JsonSerializable()
class FoodRecord {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'record_date')
  final String recordDate;
  @JsonKey(name: 'record_time')
  final String? recordTime;
  @JsonKey(name: 'meal_type')
  final int mealType;
  @JsonKey(name: 'food_name')
  final String? foodName;
  final String? description;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'recording_method')
  final int? recordingMethod;
  @JsonKey(name: 'analysis_status')
  final int? analysisStatus;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;
  @JsonKey(name: 'nutrition_detail')
  final NutritionDetail? nutritionDetail;
  @JsonKey(name: 'analysis_result')
  final AgentAnalysisData? analysisResult;
  @JsonKey(name: 'nutrition_data')
  final Map<String, dynamic>? nutritionData;

  const FoodRecord({
    required this.id,
    required this.userId,
    required this.recordDate,
    this.recordTime,
    required this.mealType,
    this.foodName,
    this.description,
    this.imageUrl,
    this.recordingMethod,
    this.analysisStatus,
    required this.createdAt,
    this.updatedAt,
    this.nutritionDetail,
    this.analysisResult,
    this.nutritionData,
  });

  factory FoodRecord.fromJson(Map<String, dynamic> json) =>
      _$FoodRecordFromJson(json);
  Map<String, dynamic> toJson() => _$FoodRecordToJson(this);

  /// 获取餐次类型名称
  String get mealTypeName {
    switch (mealType) {
      case 1:
        return '早餐';
      case 2:
        return '午餐';
      case 3:
        return '晚餐';
      case 4:
        return '加餐';
      default:
        return '未知';
    }
  }

  /// 获取分析状态名称
  String get analysisStatusName {
    switch (analysisStatus) {
      case 1:
        return '待分析';
      case 2:
        return '分析中';
      case 3:
        return '已完成';
      case null:
        return '未知';
      default:
        return '未知';
    }
  }
}

/// 创建食物记录的请求
@JsonSerializable()
class FoodRecordCreate {
  @JsonKey(name: 'record_date')
  final String recordDate;
  @JsonKey(name: 'record_time')
  final String? recordTime;
  @JsonKey(name: 'meal_type')
  final int mealType;
  @JsonKey(name: 'food_name')
  final String foodName;
  final String? description;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'recording_method')
  final int? recordingMethod;

  const FoodRecordCreate({
    required this.recordDate,
    this.recordTime,
    required this.mealType,
    required this.foodName,
    this.description,
    this.imageUrl,
    this.recordingMethod,
  });

  factory FoodRecordCreate.fromJson(Map<String, dynamic> json) =>
      _$FoodRecordCreateFromJson(json);
  Map<String, dynamic> toJson() => _$FoodRecordCreateToJson(this);
}

/// 创建营养详情的请求
@JsonSerializable()
class NutritionDetailCreate {
  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbohydrates;
  @JsonKey(name: 'dietary_fiber')
  final double? dietaryFiber;
  final double? sugar;
  final double? sodium;
  final double? cholesterol;
  @JsonKey(name: 'vitamin_a')
  final double? vitaminA;
  @JsonKey(name: 'vitamin_c')
  final double? vitaminC;
  @JsonKey(name: 'vitamin_d')
  final double? vitaminD;
  final double? calcium;
  final double? iron;
  final double? potassium;
  @JsonKey(name: 'confidence_score')
  final double? confidenceScore;
  @JsonKey(name: 'analysis_method')
  final String? analysisMethod;

  const NutritionDetailCreate({
    this.calories,
    this.protein,
    this.fat,
    this.carbohydrates,
    this.dietaryFiber,
    this.sugar,
    this.sodium,
    this.cholesterol,
    this.vitaminA,
    this.vitaminC,
    this.vitaminD,
    this.calcium,
    this.iron,
    this.potassium,
    this.confidenceScore,
    this.analysisMethod,
  });

  factory NutritionDetailCreate.fromJson(Map<String, dynamic> json) =>
      _$NutritionDetailCreateFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionDetailCreateToJson(this);
}

/// 每日营养汇总
@JsonSerializable()
class DailyNutritionSummary {
  final int id;
  @JsonKey(name: 'user_id')
  final int userId;
  @JsonKey(name: 'summary_date')
  final String summaryDate;
  @JsonKey(name: 'total_calories')
  final double totalCalories;
  @JsonKey(name: 'total_protein')
  final double totalProtein;
  @JsonKey(name: 'total_fat')
  final double totalFat;
  @JsonKey(name: 'total_carbohydrates')
  final double totalCarbohydrates;
  @JsonKey(name: 'total_fiber')
  final double totalFiber;
  @JsonKey(name: 'total_sodium')
  final double totalSodium;
  @JsonKey(name: 'meal_count')
  final int mealCount;
  @JsonKey(name: 'water_intake')
  final double waterIntake;
  @JsonKey(name: 'exercise_calories')
  final double exerciseCalories;
  @JsonKey(name: 'health_score')
  final double? healthScore;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'updated_at')
  final String updatedAt;

  const DailyNutritionSummary({
    required this.id,
    required this.userId,
    required this.summaryDate,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbohydrates,
    required this.totalFiber,
    required this.totalSodium,
    required this.mealCount,
    required this.waterIntake,
    required this.exerciseCalories,
    this.healthScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyNutritionSummary.fromJson(Map<String, dynamic> json) =>
      _$DailyNutritionSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$DailyNutritionSummaryToJson(this);
}

/// 营养趋势数据点
@JsonSerializable()
class NutritionTrendPoint {
  final String date;
  final Map<String, double?> values;

  const NutritionTrendPoint({
    required this.date,
    required this.values,
  });

  factory NutritionTrendPoint.fromJson(Map<String, dynamic> json) =>
      _$NutritionTrendPointFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionTrendPointToJson(this);
}

/// 营养趋势数据
@JsonSerializable()
class NutritionTrends {
  @JsonKey(name: 'date_range')
  final DateRange dateRange;
  final List<String> metrics;
  final List<NutritionTrendPoint> data;

  const NutritionTrends({
    required this.dateRange,
    required this.metrics,
    required this.data,
  });

  factory NutritionTrends.fromJson(Map<String, dynamic> json) =>
      _$NutritionTrendsFromJson(json);
  Map<String, dynamic> toJson() => _$NutritionTrendsToJson(this);
}

/// 日期范围
@JsonSerializable()
class DateRange {
  @JsonKey(name: 'start_date')
  final String startDate;
  @JsonKey(name: 'end_date')
  final String endDate;

  const DateRange({
    required this.startDate,
    required this.endDate,
  });

  factory DateRange.fromJson(Map<String, dynamic> json) =>
      _$DateRangeFromJson(json);
  Map<String, dynamic> toJson() => _$DateRangeToJson(this);
}

/// 分页信息
@JsonSerializable()
class PaginationInfo {
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  @JsonKey(name: 'total_pages')
  final int totalPages;

  const PaginationInfo({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) =>
      _$PaginationInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PaginationInfoToJson(this);
}

/// 食物记录列表响应
@JsonSerializable()
class FoodRecordsResponse {
  final List<FoodRecord> records;
  final PaginationInfo pagination;

  const FoodRecordsResponse({
    required this.records,
    required this.pagination,
  });

  factory FoodRecordsResponse.fromJson(Map<String, dynamic> json) =>
      _$FoodRecordsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$FoodRecordsResponseToJson(this);
}

/// 文件上传响应
@JsonSerializable()
class FileUploadResponse {
  @JsonKey(name: 'file_id')
  final String fileId;
  @JsonKey(name: 'file_name')
  final String fileName;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'object_name')
  final String objectName;
  @JsonKey(name: 'file_size')
  final int fileSize;
  @JsonKey(name: 'content_type')
  final String contentType;
  @JsonKey(name: 'upload_time')
  final String uploadTime;

  const FileUploadResponse({
    required this.fileId,
    required this.fileName,
    required this.fileUrl,
    required this.objectName,
    required this.fileSize,
    required this.contentType,
    required this.uploadTime,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) =>
      _$FileUploadResponseFromJson(json);
  Map<String, dynamic> toJson() => _$FileUploadResponseToJson(this);
}

/// 图片URL响应
@JsonSerializable()
class ImageUrlResponse {
  @JsonKey(name: 'object_name')
  final String objectName;
  @JsonKey(name: 'file_url')
  final String fileUrl;
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  @JsonKey(name: 'expires_at')
  final String expiresAt;

  const ImageUrlResponse({
    required this.objectName,
    required this.fileUrl,
    required this.expiresIn,
    required this.expiresAt,
  });

  factory ImageUrlResponse.fromJson(Map<String, dynamic> json) =>
      _$ImageUrlResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ImageUrlResponseToJson(this);
}

/// 每日汇总的类型别名
typedef DailySummary = DailyNutritionSummary;
