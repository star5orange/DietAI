import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

/// 分析页面聊天服务 - 对应后端 /api/analysis-chat/* 接口
class AnalysisChatService {
  final ApiService _apiService = ApiService();

  /// 基于食物分析结果的聊天
  /// 将分析结果作为上下文信息，自动创建或使用现有的营养咨询会话
  Future<ApiResponse<Map<String, dynamic>>> chatWithAnalysis({
    required String message,
    required Map<String, dynamic> foodAnalysis,
    int? sessionId,
  }) async {
    try {
      final data = {
        'message': message,
        'food_analysis': foodAnalysis,
        if (sessionId != null) 'session_id': sessionId,
      };

      final response = await _apiService.post(
        '/analysis-chat/chat-with-analysis',
        data: data,
      );

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '分析聊天成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '分析聊天失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '分析聊天失败: $e',
      );
    }
  }
}
