import '../../../core/services/api_service.dart';
import '../../../shared/domain/models/api_response.dart';

/// 首页模块布局接口
class HomeLayoutService {
  final ApiService _apiService = ApiService();

  /// 获取解析后的首页布局（含分群规则与用户定制）
  Future<ApiResponse<dynamic>> fetchLayout() async {
    try {
      return await _apiService.get('/home/layout');
    } catch (e) {
      return ApiResponse<dynamic>.failure(
          message: '获取首页布局失败', error: e.toString());
    }
  }

  /// 保存布局定制；reset=true 时恢复按画像自动布局
  Future<ApiResponse<dynamic>> saveLayout({
    List<String>? hiddenModules,
    List<String>? moduleOrder,
    Map<String, dynamic>? preferences,
    bool reset = false,
  }) async {
    try {
      return await _apiService.put('/home/layout', data: {
        if (reset) 'reset': true,
        if (hiddenModules != null) 'hidden_modules': hiddenModules,
        if (moduleOrder != null) 'module_order': moduleOrder,
        if (preferences != null) 'preferences': preferences,
      });
    } catch (e) {
      return ApiResponse<dynamic>.failure(
          message: '保存首页布局失败', error: e.toString());
    }
  }
}
