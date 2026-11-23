import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/services/api_service.dart';

/// AI顾问服务
/// 用于管理AI顾问风格设置和个性化配置
class AdvisorService {
  final ApiService _apiService = ApiService();

  /// 获取当前顾问风格设置
  /// GET /api/ai-advisor/settings
  Future<ApiResponse<Map<String, dynamic>>> getAdvisorSettings() async {
    try {
      final response = await _apiService.get('/ai-advisor/settings');
      // ApiService 已经返回解析后的 ApiResponse，直接使用
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          message: response.message,
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse.failure(
          message: response.message,
          error: 'API返回失败',
        );
      }
    } catch (e) {
      return ApiResponse.failure(
        message: '获取AI顾问设置失败',
        error: e.toString(),
      );
    }
  }

  /// 更新顾问风格设置
  /// PUT /api/ai-advisor/settings
  /// 字段：advisor_style, focus_goal, focus_nutrient, response_style
  Future<ApiResponse<Map<String, dynamic>>> updateAdvisorSettings({
    String? advisorStyle,
    String? focusGoal,
    String? focusNutrient,
    String? responseStyle,
  }) async {
    try {
      final response = await _apiService.put(
        '/ai-advisor/settings',
        data: {
          if (advisorStyle != null) 'advisor_style': advisorStyle,
          if (focusGoal != null) 'focus_goal': focusGoal,
          if (focusNutrient != null) 'focus_nutrient': focusNutrient,
          if (responseStyle != null) 'response_style': responseStyle,
        },
      );
      // ApiService 已经返回解析后的 ApiResponse，直接使用
      if (response.isSuccess && response.data != null) {
        return ApiResponse.success(
          message: response.message,
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse.failure(
          message: response.message,
          error: 'API返回失败',
        );
      }
    } catch (e) {
      return ApiResponse.failure(
        message: '更新AI顾问设置失败',
        error: e.toString(),
      );
    }
  }

  /// 获取顾问风格模板列表
  /// GET /api/ai-advisor/templates
  Future<ApiResponse<List<Map<String, dynamic>>>> getStyleTemplates() async {
    try {
      final response = await _apiService.get('/ai-advisor/templates');
      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final templates = data['templates'] as List<dynamic>?;
        return ApiResponse.success(
          message: response.message,
          data: templates
                  ?.map((t) => Map<String, dynamic>.from(t as Map))
                  .toList() ??
              [],
        );
      }
      return ApiResponse.failure(
        message: response.message,
        error: '获取模板失败',
      );
    } catch (e) {
      return ApiResponse.failure(
        message: '获取风格模板失败',
        error: e.toString(),
      );
    }
  }
}
