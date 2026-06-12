// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Macronutrients _$MacronutrientsFromJson(Map<String, dynamic> json) =>
    Macronutrients(
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbohydrates: (json['carbohydrates'] as num).toDouble(),
      dietaryFiber: (json['dietary_fiber'] as num).toDouble(),
      sugar: (json['sugar'] as num).toDouble(),
    );

Map<String, dynamic> _$MacronutrientsToJson(Macronutrients instance) =>
    <String, dynamic>{
      'protein': instance.protein,
      'fat': instance.fat,
      'carbohydrates': instance.carbohydrates,
      'dietary_fiber': instance.dietaryFiber,
      'sugar': instance.sugar,
    };

VitaminsMinerals _$VitaminsMineralsFromJson(Map<String, dynamic> json) =>
    VitaminsMinerals(
      vitaminA: (json['vitamin_a'] as num?)?.toDouble(),
      vitaminC: (json['vitamin_c'] as num?)?.toDouble(),
      vitaminD: (json['vitamin_d'] as num?)?.toDouble(),
      calcium: (json['calcium'] as num?)?.toDouble(),
      iron: (json['iron'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
      potassium: (json['potassium'] as num?)?.toDouble(),
      cholesterol: (json['cholesterol'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$VitaminsMineralsToJson(VitaminsMinerals instance) =>
    <String, dynamic>{
      'vitamin_a': instance.vitaminA,
      'vitamin_c': instance.vitaminC,
      'vitamin_d': instance.vitaminD,
      'calcium': instance.calcium,
      'iron': instance.iron,
      'sodium': instance.sodium,
      'potassium': instance.potassium,
      'cholesterol': instance.cholesterol,
    };

NutritionFacts _$NutritionFactsFromJson(Map<String, dynamic> json) =>
    NutritionFacts(
      foodItems: (json['food_items'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      macronutrients: Macronutrients.fromJson(
          json['macronutrients'] as Map<String, dynamic>),
      vitaminsMinerals: json['vitamins_minerals'] == null
          ? null
          : VitaminsMinerals.fromJson(
              json['vitamins_minerals'] as Map<String, dynamic>),
      healthLevel: (json['health_level'] as num?)?.toInt(),
    );

Map<String, dynamic> _$NutritionFactsToJson(NutritionFacts instance) =>
    <String, dynamic>{
      'food_items': instance.foodItems,
      'total_calories': instance.totalCalories,
      'macronutrients': instance.macronutrients,
      'vitamins_minerals': instance.vitaminsMinerals,
      'health_level': instance.healthLevel,
    };

Recommendations _$RecommendationsFromJson(Map<String, dynamic> json) =>
    Recommendations(
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      dietaryTips: (json['dietary_tips'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      warnings: (json['warnings'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      alternativeFoods: (json['alternative_foods'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$RecommendationsToJson(Recommendations instance) =>
    <String, dynamic>{
      'recommendations': instance.recommendations,
      'dietary_tips': instance.dietaryTips,
      'warnings': instance.warnings,
      'alternative_foods': instance.alternativeFoods,
    };

AgentAnalysisData _$AgentAnalysisDataFromJson(Map<String, dynamic> json) =>
    AgentAnalysisData(
      imageDescription: json['image_description'] as String,
      nutritionFacts: NutritionFacts.fromJson(
          json['nutrition_facts'] as Map<String, dynamic>),
      recommendations: Recommendations.fromJson(
          json['recommendations'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AgentAnalysisDataToJson(AgentAnalysisData instance) =>
    <String, dynamic>{
      'image_description': instance.imageDescription,
      'nutrition_facts': instance.nutritionFacts,
      'recommendations': instance.recommendations,
    };

NutritionDetail _$NutritionDetailFromJson(Map<String, dynamic> json) =>
    NutritionDetail(
      id: (json['id'] as num).toInt(),
      foodRecordId: (json['food_record_id'] as num).toInt(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbohydrates: (json['carbohydrates'] as num).toDouble(),
      dietaryFiber: (json['dietary_fiber'] as num).toDouble(),
      sugar: (json['sugar'] as num).toDouble(),
      sodium: (json['sodium'] as num).toDouble(),
      cholesterol: (json['cholesterol'] as num).toDouble(),
      vitaminA: (json['vitamin_a'] as num).toDouble(),
      vitaminC: (json['vitamin_c'] as num).toDouble(),
      vitaminD: (json['vitamin_d'] as num).toDouble(),
      calcium: (json['calcium'] as num).toDouble(),
      iron: (json['iron'] as num).toDouble(),
      potassium: (json['potassium'] as num).toDouble(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      analysisMethod: json['analysis_method'] as String?,
    );

Map<String, dynamic> _$NutritionDetailToJson(NutritionDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'food_record_id': instance.foodRecordId,
      'calories': instance.calories,
      'protein': instance.protein,
      'fat': instance.fat,
      'carbohydrates': instance.carbohydrates,
      'dietary_fiber': instance.dietaryFiber,
      'sugar': instance.sugar,
      'sodium': instance.sodium,
      'cholesterol': instance.cholesterol,
      'vitamin_a': instance.vitaminA,
      'vitamin_c': instance.vitaminC,
      'vitamin_d': instance.vitaminD,
      'calcium': instance.calcium,
      'iron': instance.iron,
      'potassium': instance.potassium,
      'confidence_score': instance.confidenceScore,
      'analysis_method': instance.analysisMethod,
    };

FoodRecord _$FoodRecordFromJson(Map<String, dynamic> json) => FoodRecord(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      recordDate: json['record_date'] as String,
      recordTime: json['record_time'] as String?,
      mealType: (json['meal_type'] as num).toInt(),
      foodName: json['food_name'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      recordingMethod: (json['recording_method'] as num?)?.toInt(),
      analysisStatus: (json['analysis_status'] as num?)?.toInt(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String?,
      nutritionDetail: json['nutrition_detail'] == null
          ? null
          : NutritionDetail.fromJson(
              json['nutrition_detail'] as Map<String, dynamic>),
      analysisResult: json['analysis_result'] == null
          ? null
          : AgentAnalysisData.fromJson(
              json['analysis_result'] as Map<String, dynamic>),
      nutritionData: json['nutrition_data'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$FoodRecordToJson(FoodRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'record_date': instance.recordDate,
      'record_time': instance.recordTime,
      'meal_type': instance.mealType,
      'food_name': instance.foodName,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'recording_method': instance.recordingMethod,
      'analysis_status': instance.analysisStatus,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'nutrition_detail': instance.nutritionDetail,
      'analysis_result': instance.analysisResult,
      'nutrition_data': instance.nutritionData,
    };

FoodRecordCreate _$FoodRecordCreateFromJson(Map<String, dynamic> json) =>
    FoodRecordCreate(
      recordDate: json['record_date'] as String,
      recordTime: json['record_time'] as String?,
      mealType: (json['meal_type'] as num).toInt(),
      foodName: json['food_name'] as String,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      recordingMethod: (json['recording_method'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FoodRecordCreateToJson(FoodRecordCreate instance) =>
    <String, dynamic>{
      'record_date': instance.recordDate,
      'record_time': instance.recordTime,
      'meal_type': instance.mealType,
      'food_name': instance.foodName,
      'description': instance.description,
      'image_url': instance.imageUrl,
      'recording_method': instance.recordingMethod,
    };

NutritionDetailCreate _$NutritionDetailCreateFromJson(
        Map<String, dynamic> json) =>
    NutritionDetailCreate(
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble(),
      dietaryFiber: (json['dietary_fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
      cholesterol: (json['cholesterol'] as num?)?.toDouble(),
      vitaminA: (json['vitamin_a'] as num?)?.toDouble(),
      vitaminC: (json['vitamin_c'] as num?)?.toDouble(),
      vitaminD: (json['vitamin_d'] as num?)?.toDouble(),
      calcium: (json['calcium'] as num?)?.toDouble(),
      iron: (json['iron'] as num?)?.toDouble(),
      potassium: (json['potassium'] as num?)?.toDouble(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      analysisMethod: json['analysis_method'] as String?,
    );

Map<String, dynamic> _$NutritionDetailCreateToJson(
        NutritionDetailCreate instance) =>
    <String, dynamic>{
      'calories': instance.calories,
      'protein': instance.protein,
      'fat': instance.fat,
      'carbohydrates': instance.carbohydrates,
      'dietary_fiber': instance.dietaryFiber,
      'sugar': instance.sugar,
      'sodium': instance.sodium,
      'cholesterol': instance.cholesterol,
      'vitamin_a': instance.vitaminA,
      'vitamin_c': instance.vitaminC,
      'vitamin_d': instance.vitaminD,
      'calcium': instance.calcium,
      'iron': instance.iron,
      'potassium': instance.potassium,
      'confidence_score': instance.confidenceScore,
      'analysis_method': instance.analysisMethod,
    };

DailyNutritionSummary _$DailyNutritionSummaryFromJson(
        Map<String, dynamic> json) =>
    DailyNutritionSummary(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      summaryDate: json['summary_date'] as String,
      totalCalories: (json['total_calories'] as num).toDouble(),
      totalProtein: (json['total_protein'] as num).toDouble(),
      totalFat: (json['total_fat'] as num).toDouble(),
      totalCarbohydrates: (json['total_carbohydrates'] as num).toDouble(),
      totalFiber: (json['total_fiber'] as num).toDouble(),
      totalSodium: (json['total_sodium'] as num).toDouble(),
      mealCount: (json['meal_count'] as num).toInt(),
      waterIntake: (json['water_intake'] as num).toDouble(),
      exerciseCalories: (json['exercise_calories'] as num).toDouble(),
      healthScore: (json['health_score'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );

Map<String, dynamic> _$DailyNutritionSummaryToJson(
        DailyNutritionSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'summary_date': instance.summaryDate,
      'total_calories': instance.totalCalories,
      'total_protein': instance.totalProtein,
      'total_fat': instance.totalFat,
      'total_carbohydrates': instance.totalCarbohydrates,
      'total_fiber': instance.totalFiber,
      'total_sodium': instance.totalSodium,
      'meal_count': instance.mealCount,
      'water_intake': instance.waterIntake,
      'exercise_calories': instance.exerciseCalories,
      'health_score': instance.healthScore,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

NutritionTrendPoint _$NutritionTrendPointFromJson(Map<String, dynamic> json) =>
    NutritionTrendPoint(
      date: json['date'] as String,
      values: (json['values'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num?)?.toDouble()),
      ),
    );

Map<String, dynamic> _$NutritionTrendPointToJson(
        NutritionTrendPoint instance) =>
    <String, dynamic>{
      'date': instance.date,
      'values': instance.values,
    };

NutritionTrends _$NutritionTrendsFromJson(Map<String, dynamic> json) =>
    NutritionTrends(
      dateRange: DateRange.fromJson(json['date_range'] as Map<String, dynamic>),
      metrics:
          (json['metrics'] as List<dynamic>).map((e) => e as String).toList(),
      data: (json['data'] as List<dynamic>)
          .map((e) => NutritionTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$NutritionTrendsToJson(NutritionTrends instance) =>
    <String, dynamic>{
      'date_range': instance.dateRange,
      'metrics': instance.metrics,
      'data': instance.data,
    };

DateRange _$DateRangeFromJson(Map<String, dynamic> json) => DateRange(
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
    );

Map<String, dynamic> _$DateRangeToJson(DateRange instance) => <String, dynamic>{
      'start_date': instance.startDate,
      'end_date': instance.endDate,
    };

PaginationInfo _$PaginationInfoFromJson(Map<String, dynamic> json) =>
    PaginationInfo(
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      totalPages: (json['total_pages'] as num).toInt(),
    );

Map<String, dynamic> _$PaginationInfoToJson(PaginationInfo instance) =>
    <String, dynamic>{
      'total': instance.total,
      'page': instance.page,
      'page_size': instance.pageSize,
      'total_pages': instance.totalPages,
    };

FoodRecordsResponse _$FoodRecordsResponseFromJson(Map<String, dynamic> json) =>
    FoodRecordsResponse(
      records: (json['records'] as List<dynamic>)
          .map((e) => FoodRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination:
          PaginationInfo.fromJson(json['pagination'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FoodRecordsResponseToJson(
        FoodRecordsResponse instance) =>
    <String, dynamic>{
      'records': instance.records,
      'pagination': instance.pagination,
    };

FileUploadResponse _$FileUploadResponseFromJson(Map<String, dynamic> json) =>
    FileUploadResponse(
      fileId: json['file_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      objectName: json['object_name'] as String,
      fileSize: (json['file_size'] as num).toInt(),
      contentType: json['content_type'] as String,
      uploadTime: json['upload_time'] as String,
    );

Map<String, dynamic> _$FileUploadResponseToJson(FileUploadResponse instance) =>
    <String, dynamic>{
      'file_id': instance.fileId,
      'file_name': instance.fileName,
      'file_url': instance.fileUrl,
      'object_name': instance.objectName,
      'file_size': instance.fileSize,
      'content_type': instance.contentType,
      'upload_time': instance.uploadTime,
    };

ImageUrlResponse _$ImageUrlResponseFromJson(Map<String, dynamic> json) =>
    ImageUrlResponse(
      objectName: json['object_name'] as String,
      fileUrl: json['file_url'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      expiresAt: json['expires_at'] as String,
    );

Map<String, dynamic> _$ImageUrlResponseToJson(ImageUrlResponse instance) =>
    <String, dynamic>{
      'object_name': instance.objectName,
      'file_url': instance.fileUrl,
      'expires_in': instance.expiresIn,
      'expires_at': instance.expiresAt,
    };
