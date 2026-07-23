import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

class WellnessService {
  final ApiService _apiService = ApiService();

  /// 获取养生知识
  Future<ApiResponse<List<Map<String, dynamic>>>> getWellnessTips({
    String? category,
    bool randomizeSeasons = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) {
        queryParams['category'] = category;
      }
      if (randomizeSeasons) {
        queryParams['randomize_seasons'] = true;
      }

      final response = await _apiService.dio.get(
        '/wellness/tips',
        queryParameters: queryParams,
      );

      final result = ApiResponse.fromJson(
        response.data,
        (json) => (json as List).map((e) => e as Map<String, dynamic>).toList(),
      );

      return result;
    } catch (e) {
      return ApiResponse(
        success: false,
        data: <Map<String, dynamic>>[],
        message: '养生知识接口不可用',
      );
    }
  }

  /// 获取当前节气信息
  Future<ApiResponse<Map<String, dynamic>>> getCurrentSolarTerm() async {
    try {
      final response = await _apiService.dio.get(
        '/wellness/current-solar-term',
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取当前节气失败: $e',
      );
    }
  }

  /// 获取每日养生推荐
  Future<ApiResponse<Map<String, dynamic>>> getDailyRecommendation({
    String? constitutionType,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (constitutionType != null) {
        queryParams['constitution_type'] = constitutionType;
      }

      final response = await _apiService.dio.get(
        '/wellness/daily-recommendation',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '每日推荐接口不可用',
      );
    }
  }

  /// 获取节气列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getSolarTerms({
    int year = 2026,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/wellness/solar-terms',
        queryParameters: {'year': year},
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => (json as List).map((e) => e as Map<String, dynamic>).toList(),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        data: <Map<String, dynamic>>[],
        message: '节气数据接口不可用',
      );
    }
  }
}
