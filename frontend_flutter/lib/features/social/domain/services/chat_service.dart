import '../../data/message_api_service.dart';
import '../../domain/message_models.dart';

/// 聊天业务逻辑服务
/// 封装消息功能的业务规则和数据转换
class ChatService {
  final MessageApiService _apiService;

  ChatService(this._apiService);

  /// 发送消息
  Future<bool> sendMessage({
    required int receiverId,
    required String content,
    String messageType = 'text',
    Map<String, dynamic>? extraData,
  }) async {
    if (content.trim().isEmpty) {
      return false;
    }
    final response = await _apiService.sendMessage(
      receiverId: receiverId,
      content: content,
      messageType: messageType,
      extraData: extraData,
    );
    return response.success;
  }

  /// 发送戳一戳
  Future<bool> sendPoke(int targetUserId, {String pokeType = 'general'}) async {
    final response = await _apiService.sendPoke(targetUserId, pokeType: pokeType);
    return response.success;
  }

  /// 获取聊天列表
  Future<List<ChatRoom>> getChatList() async {
    final response = await _apiService.getChatList();
    if (response.success && response.data != null) {
      return response.data!;
    }
    return [];
  }

  /// 获取消息历史
  Future<MessageHistory?> getMessageHistory(
    int targetUserId, {
    int limit = 20,
    int? beforeId,
  }) async {
    final response = await _apiService.getMessageHistory(
      targetUserId,
      limit: limit,
      beforeId: beforeId,
    );
    if (response.success && response.data != null) {
      return response.data;
    }
    return null;
  }

  /// 获取未读消息数
  Future<int> getUnreadCount() async {
    final response = await _apiService.getUnreadCount();
    if (response.success && response.data != null) {
      return response.data!;
    }
    return 0;
  }

  /// 格式化消息时间
  String formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(time).inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }

  /// 获取最后一条消息的预览文本
  String getLastMessagePreview(ChatRoom room) {
    if (room.lastMessage == null || room.lastMessage!.isEmpty) {
      return '暂无消息';
    }
    if (room.lastMessage!.length > 20) {
      return '${room.lastMessage!.substring(0, 20)}...';
    }
    return room.lastMessage!;
  }

  /// 计算总未读数
  int calculateTotalUnreadCount(List<ChatRoom> rooms) {
    return rooms.fold(0, (sum, room) => sum + room.unreadCount);
  }

  /// 按时间排序聊天列表
  List<ChatRoom> sortChatRoomsByTime(List<ChatRoom> rooms) {
    final sorted = List<ChatRoom>.from(rooms);
    sorted.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });
    return sorted;
  }

  /// 按未读数排序聊天列表
  List<ChatRoom> sortChatRoomsByUnread(List<ChatRoom> rooms) {
    final sorted = List<ChatRoom>.from(rooms);
    sorted.sort((a, b) => b.unreadCount.compareTo(a.unreadCount));
    return sorted;
  }
}
