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
  /// 返回所有可用的预设风格模板
  Future<ApiResponse<List<Map<String, dynamic>>>> getStyleTemplates() async {
    try {
      // 返回前端硬编码的预设模板（无需后端API）
      const templates = [
        {
          'advisor_style': 'nutritionist',
          'name': '注册营养师',
          'description': '专业、数据驱动，专注于营养科学和膳食规划',
          'focus_goal': 'balanced',
          'focus_nutrient': 'calories',
          'response_style': 'detailed',
        },
        {
          'advisor_style': 'fitness_coach',
          'name': '运动营养教练',
          'description': '严格、激励，专注于运动营养和体能训练',
          'focus_goal': 'muscle_gain',
          'focus_nutrient': 'protein',
          'response_style': 'concise',
        },
        {
          'advisor_style': 'tcm_healer',
          'name': '中医养生顾问',
          'description': '温和、传统，专注于节气养生和体质调理',
          'focus_goal': 'wellness',
          'focus_nutrient': 'micronutrient',
          'response_style': 'example_rich',
        },
        {
          'advisor_style': 'encouraging_friend',
          'name': '健康伙伴',
          'description': '友善、温暖，专注于生活习惯和可持续改变',
          'focus_goal': 'fat_loss',
          'focus_nutrient': 'calories',
          'response_style': 'detailed',
        },
      ];
      return ApiResponse.success(
        message: '获取风格模板成功',
        data: templates.map((t) => Map<String, dynamic>.from(t)).toList(),
      );
    } catch (e) {
      return ApiResponse.failure(
        message: '获取风格模板失败',
        error: e.toString(),
      );
    }
  }
}
