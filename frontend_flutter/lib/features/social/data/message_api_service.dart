import '../../../core/services/api_service.dart';
import '../../../shared/domain/models/api_response.dart';
import '../domain/message_models.dart';

/// 消息 API 服务
/// 对接后端 /api/messages/* 端点
class MessageApiService {
  final ApiService _api = ApiService();

  ApiResponse<Map<String, dynamic>> _wrapMap(ApiResponse<dynamic> res) {
    return ApiResponse<Map<String, dynamic>>(
      success: res.success,
      message: res.message,
      data: res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : null,
    );
  }

  // ==================== 发送消息 ====================

  /// 发送消息
  Future<ApiResponse<Message>> sendMessage({
    required int receiverId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final res = await _api.post('/messages/send', data: {
        'receiver_id': receiverId,
        'content': content,
        'message_type': messageType,
        if (extraData != null) 'extra_data': extraData,
      });
      if (res.success && res.data is Map<String, dynamic>) {
        final message = Message.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: message);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '发送消息失败', error: e.toString());
    }
  }

  // ==================== 聊天列表 ====================

  /// 获取聊天列表
  Future<ApiResponse<List<ChatRoom>>> getChatList() async {
    try {
      final res = await _api.get('/messages/chat-list');
      if (res.success && res.data is List) {
        final rooms = (res.data as List)
            .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(message: res.message, data: rooms);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取聊天列表失败', error: e.toString());
    }
  }

  // ==================== 消息历史 ====================

  /// 获取消息历史
  Future<ApiResponse<MessageHistory>> getMessageHistory(
    int targetUserId, {
    int limit = 20,
    int? beforeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      };
      final res = await _api.get('/messages/history/$targetUserId',
          queryParameters: queryParams);
      if (res.success && res.data is Map<String, dynamic>) {
        final history =
            MessageHistory.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: history);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取消息历史失败', error: e.toString());
    }
  }

  // ==================== 戳一戳 ====================

  /// 发送戳一戳
  Future<ApiResponse<void>> sendPoke(int targetUserId,
      {String pokeType = 'general'}) async {
    try {
      final res = await _api.post('/messages/poke', data: {
        'target_user_id': targetUserId,
        'poke_type': pokeType,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '发送戳一戳失败', error: e.toString());
    }
  }

  // ==================== 未读消息 ====================

  /// 获取未读消息数
  Future<ApiResponse<int>> getUnreadCount() async {
    try {
      final res = await _api.get('/messages/unread-count');
      if (res.success && res.data is Map<String, dynamic>) {
        final count =
            (res.data as Map<String, dynamic>)['unread_count'] as int? ?? 0;
        return ApiResponse.success(message: res.message, data: count);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取未读消息数失败', error: e.toString());
    }
  }

  // ==================== 食物分享 ====================

  /// 分享食物记录给好友
  Future<ApiResponse<Message>> shareFoodRecord({
    required int receiverId,
    required int foodRecordId,
  }) async {
    try {
      final res = await _api.post(
        '/messages/share-food',
        queryParameters: {
          'receiver_id': receiverId,
          'food_record_id': foodRecordId,
        },
      );
      if (res.success && res.data is Map<String, dynamic>) {
        final message = Message.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: message);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '分享食物记录失败', error: e.toString());
    }
  }

  // ==================== 离线消息 ====================

  /// 获取离线消息（用户上线后调用）
  Future<ApiResponse<OfflineMessagesResponse>> getOfflineMessages() async {
    try {
      final res = await _api.get('/messages/offline-messages');
      if (res.success && res.data is Map<String, dynamic>) {
        final response =
            OfflineMessagesResponse.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: response);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取离线消息失败', error: e.toString());
    }
  }

  // ==================== 图片上传 ====================

  /// 上传图片
  Future<ApiResponse<String>> uploadImage(String filePath) async {
    try {
      final res = await _api.uploadFile('/messages/upload-image', filePath);
      if (res.success && res.data is Map<String, dynamic>) {
        final imageUrl =
            (res.data as Map<String, dynamic>)['image_url'] as String?;
        if (imageUrl != null) {
          return ApiResponse.success(message: res.message, data: imageUrl);
        }
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '上传图片失败', error: e.toString());
    }
  }
}
