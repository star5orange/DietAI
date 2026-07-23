import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';

/// AI顾问风格设置模型
class AdvisorSettings {
  final String? advisorStyle;
  final String? focusGoal;
  final String? focusNutrient;
  final String? responseStyle;
  // 宠物专属字段
  final String? petAdvisorStyle;
  final String? petFocusGoal;

  const AdvisorSettings({
    this.advisorStyle,
    this.focusGoal,
    this.focusNutrient,
    this.responseStyle,
    this.petAdvisorStyle,
    this.petFocusGoal,
  });

  factory AdvisorSettings.fromJson(Map<String, dynamic> json) {
    return AdvisorSettings(
      advisorStyle: json['advisor_style'],
      focusGoal: json['focus_goal'],
      focusNutrient: json['focus_nutrient'],
      responseStyle: json['response_style'],
      petAdvisorStyle: json['pet_advisor_style'],
      petFocusGoal: json['pet_focus_goal'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (advisorStyle != null) 'advisor_style': advisorStyle,
      if (focusGoal != null) 'focus_goal': focusGoal,
      if (focusNutrient != null) 'focus_nutrient': focusNutrient,
      if (responseStyle != null) 'response_style': responseStyle,
      if (petAdvisorStyle != null) 'pet_advisor_style': petAdvisorStyle,
      if (petFocusGoal != null) 'pet_focus_goal': petFocusGoal,
    };
  }
}

/// AI顾问风格设置服务
class AdvisorService {
  final ApiService _apiService;

  AdvisorService(this._apiService);

  /// 获取当前顾问风格设置
  Future<AdvisorSettings> getSettings() async {
    final response = await _apiService.dio.get('/ai-advisor/settings');
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      return AdvisorSettings.fromJson(data['data'] as Map<String, dynamic>);
    }
    return const AdvisorSettings();
  }

  /// 更新顾问风格设置
  Future<void> updateSettings(AdvisorSettings settings) async {
    final response = await _apiService.dio.put(
      '/ai-advisor/settings',
      data: settings.toJson(),
    );
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['message'] ?? '保存设置失败');
    }
  }
}

/// Provider 定义
final advisorServiceProvider = Provider<AdvisorService>((ref) {
  return AdvisorService(ApiService());
});

final advisorSettingsProvider = FutureProvider<AdvisorSettings>((ref) async {
  final service = ref.watch(advisorServiceProvider);
  return service.getSettings();
});
