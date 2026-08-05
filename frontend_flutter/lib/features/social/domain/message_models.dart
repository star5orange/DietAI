/// 消息
class Message {
  final int id;
  final int senderId;
  final int? receiverId;
  final String content;
  final String messageType;
  final Map<String, dynamic>? extraData;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? senderUsername;
  final String? senderAvatarUrl;

  Message({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.extraData,
    this.readAt,
    required this.createdAt,
    this.senderUsername,
    this.senderAvatarUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // 解析时间并转换为本地时间
    DateTime? parseTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return null;
      final parsed = DateTime.tryParse(timeStr);
      if (parsed == null) return null;
      // 如果是 UTC 时间，转换为本地时间
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    return Message(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int?,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      extraData: json['extra_data'] as Map<String, dynamic>?,
      readAt: parseTime(json['read_at'] as String?),
      createdAt: parseTime(json['created_at'] as String?) ?? DateTime.now(),
      senderUsername: json['sender_username'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      'extra_data': extraData,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'sender_username': senderUsername,
      'sender_avatar_url': senderAvatarUrl,
    };
  }

  bool isMine(int currentUserId) => senderId == currentUserId;
}

/// 聊天室
class ChatRoom {
  final int userId;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatRoom({
    required this.userId,
    required this.username,
    this.realName,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    // 解析时间并转换为本地时间
    DateTime? parseTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return null;
      final parsed = DateTime.tryParse(timeStr);
      if (parsed == null) return null;
      // 如果是 UTC 时间，转换为本地时间
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }

    return ChatRoom(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['real_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: parseTime(json['last_message_time'] as String?),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'real_name': realName,
      'avatar_url': avatarUrl,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }
}

/// 消息历史
class MessageHistory {
  final List<Message> messages;
  final bool hasMore;

  MessageHistory({
    this.messages = const [],
    this.hasMore = false,
  });

  factory MessageHistory.fromJson(Map<String, dynamic> json) {
    return MessageHistory(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hasMore: json['has_more'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messages': messages.map((e) => e.toJson()).toList(),
      'has_more': hasMore,
    };
  }
}

/// 离线消息发送者信息
class OfflineSender {
  final int senderId;
  final String senderUsername;
  final String? senderAvatarUrl;
  final List<Message> messages;
  final int unreadCount;

  OfflineSender({
    required this.senderId,
    required this.senderUsername,
    this.senderAvatarUrl,
    this.messages = const [],
    this.unreadCount = 0,
  });

  factory OfflineSender.fromJson(Map<String, dynamic> json) {
    return OfflineSender(
      senderId: json['sender_id'] as int,
      senderUsername: json['sender_username'] as String? ?? '',
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'sender_username': senderUsername,
      'sender_avatar_url': senderAvatarUrl,
      'messages': messages.map((e) => e.toJson()).toList(),
      'unread_count': unreadCount,
    };
  }
}

/// 离线消息响应
class OfflineMessagesResponse {
  final int totalUnread;
  final List<OfflineSender> senders;

  OfflineMessagesResponse({
    this.totalUnread = 0,
    this.senders = const [],
  });

  factory OfflineMessagesResponse.fromJson(Map<String, dynamic> json) {
    return OfflineMessagesResponse(
      totalUnread: json['total_unread'] as int? ?? 0,
      senders: (json['senders'] as List<dynamic>?)
              ?.map((e) => OfflineSender.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_unread': totalUnread,
      'senders': senders.map((e) => e.toJson()).toList(),
    };
  }
}
