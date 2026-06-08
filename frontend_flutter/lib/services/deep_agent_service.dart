import 'dart:convert';
import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

/// DietDeepAgent 服务 - 对应后端 /api/deep/* 接口
class DeepAgentService {
  final ApiService _apiService = ApiService();

  /// 统一对话入口（支持文字+图片）
  /// 返回 SSE 流式响应
  Stream<Map<String, dynamic>> chatStream({
    required String message,
    String? sessionId,
  }) async* {
    try {
      final data = {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
      };

      await for (final chunk
          in _apiService.postStream('/deep/chat', data: data)) {
        if (chunk.trim().isEmpty) continue;

        if (chunk.startsWith('data: ')) {
          final jsonStr = chunk.substring(6);
          try {
            final decoded = json.decode(jsonStr);
            if (decoded is Map<String, dynamic>) {
              yield decoded;
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      yield {
        'type': 'error',
        'message': 'DeepAgent对话失败: $e',
      };
    }
  }

  /// 食物图像分析
  /// 返回 SSE 流式响应
  Stream<Map<String, dynamic>> analyzeFoodImageStream() async* {
    try {
      await for (final chunk in _apiService.postStream('/deep/analyze')) {
        if (chunk.trim().isEmpty) continue;

        if (chunk.startsWith('data: ')) {
          final jsonStr = chunk.substring(6);
          try {
            final decoded = json.decode(jsonStr);
            if (decoded is Map<String, dynamic>) {
              yield decoded;
            }
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      yield {
        'type': 'error',
        'message': '食物图像分析失败: $e',
      };
    }
  }

  /// 获取今日营养状态
  Future<ApiResponse<Map<String, dynamic>>> getDailyStatus() async {
    try {
      final response = await _apiService.get('/deep/daily-status');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取营养状态成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取营养状态失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取营养状态失败: $e',
      );
    }
  }

  /// 查看用户记忆（调试用）
  Future<ApiResponse<Map<String, dynamic>>> getUserMemory(String uid) async {
    try {
      final response = await _apiService.get('/deep/memory/$uid');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取用户记忆成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取用户记忆失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取用户记忆失败: $e',
      );
    }
  }
}
