import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/message_api_service.dart';
import '../../domain/message_models.dart';

/// 消息 API 服务 Provider
final messageApiServiceProvider = Provider<MessageApiService>((ref) {
  return MessageApiService();
});

/// 聊天列表状态
class ChatListState {
  final List<ChatRoom> rooms;
  final bool isLoading;
  final String? error;

  ChatListState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  ChatListState copyWith({
    List<ChatRoom>? rooms,
    bool? isLoading,
    String? error,
  }) {
    return ChatListState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 聊天列表 Provider
class ChatListNotifier extends StateNotifier<ChatListState> {
  final MessageApiService _apiService;

  ChatListNotifier(this._apiService) : super(ChatListState());

  Future<void> loadChatList() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getChatList();
      if (response.success && response.data != null) {
        state = state.copyWith(
          rooms: response.data!,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final chatListProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  return ChatListNotifier(ref.watch(messageApiServiceProvider));
});

/// 消息历史状态
class MessageHistoryState {
  final int targetUserId;
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  MessageHistoryState({
    required this.targetUserId,
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.error,
  });

  MessageHistoryState copyWith({
    int? targetUserId,
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return MessageHistoryState(
      targetUserId: targetUserId ?? this.targetUserId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// 消息历史 Provider
class MessageHistoryNotifier extends StateNotifier<MessageHistoryState> {
  final MessageApiService _apiService;

  MessageHistoryNotifier(this._apiService)
      : super(MessageHistoryState(targetUserId: 0));

  Future<void> loadHistory(int targetUserId) async {
    state = MessageHistoryState(targetUserId: targetUserId, isLoading: true);
    try {
      final response = await _apiService.getMessageHistory(targetUserId);
      if (response.success && response.data != null) {
        state = state.copyWith(
          messages: response.data!.messages,
          hasMore: response.data!.hasMore,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoading: true);
    try {
      final lastMessageId =
          state.messages.isNotEmpty ? state.messages.first.id : null;
      final response = await _apiService.getMessageHistory(
        state.targetUserId,
        beforeId: lastMessageId,
      );
      if (response.success && response.data != null) {
        state = state.copyWith(
          messages: [...response.data!.messages, ...state.messages],
          hasMore: response.data!.hasMore,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendMessage(String content,
      {String messageType = 'text', int? currentUserId}) async {
    try {
      final response = await _apiService.sendMessage(
        receiverId: state.targetUserId,
        content: content,
        messageType: messageType,
      );
      if (response.success && response.data != null) {
        state = state.copyWith(
          messages: [...state.messages, response.data!],
        );
      } else {
        // 即使 API 返回失败，也添加一个临时消息到本地（乐观更新）
        // 这样用户至少能看到自己发送的内容
        final tempMsg = Message(
          id: DateTime.now().millisecondsSinceEpoch,
          senderId: currentUserId ?? 0,
          content: content,
          messageType: messageType,
          createdAt: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, tempMsg],
        );
      }
      return response.success;
    } catch (e) {
      // 即使请求失败，也添加临时消息
      final tempMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        senderId: currentUserId ?? 0,
        content: content,
        messageType: messageType,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, tempMsg],
      );
      return false;
    }
  }

  /// 通过 WebSocket 实时收到新消息时追加（按 id 去重）
  void appendMessage(Message msg) {
    if (msg.senderId != state.targetUserId) return;
    final exists = state.messages.any((m) => m.id == msg.id);
    if (exists) return;
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  /// 合并离线消息到消息列表（按时间排序，按 id 去重）
  void mergeOfflineMessages(List<Message> messages) {
    if (messages.isEmpty) return;
    final existingIds = state.messages.map((m) => m.id).toSet();
    final merged = [...state.messages];
    for (final msg in messages) {
      if (!existingIds.contains(msg.id)) {
        merged.add(msg);
      }
    }
    // 按时间正序排列
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(messages: merged);
  }

  Future<bool> sendPoke(String pokeType, {int? currentUserId}) async {
    try {
      final response =
          await _apiService.sendPoke(state.targetUserId, pokeType: pokeType);
      // 戳一戳也需要更新本地消息列表
      if (response.success) {
        final pokeContent = {
              "water": "戳了戳你，提醒你喝水 💧",
              "eat": "戳了戳你，提醒你吃饭 ",
              "general": "戳了戳你 👋"
            }[pokeType] ??
            "戳了戳你 👋";

        final pokeMsg = Message(
          id: DateTime.now().millisecondsSinceEpoch,
          senderId: currentUserId ?? 0,
          content: pokeContent,
          messageType: 'poke',
          extraData: {'poke_type': pokeType},
          createdAt: DateTime.now(),
        );
        state = state.copyWith(
          messages: [...state.messages, pokeMsg],
        );
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  void clearHistory() {
    state = MessageHistoryState(targetUserId: 0);
  }
}

final messageHistoryProvider =
    StateNotifierProvider<MessageHistoryNotifier, MessageHistoryState>((ref) {
  return MessageHistoryNotifier(ref.watch(messageApiServiceProvider));
});

/// 未读消息数 Provider
final unreadCountProvider = StateProvider<int>((ref) => 0);

/// 未读消息数 Notifier
class UnreadCountNotifier extends StateNotifier<int> {
  final MessageApiService _apiService;

  UnreadCountNotifier(this._apiService) : super(0);

  Future<void> loadUnreadCount() async {
    try {
      final response = await _apiService.getUnreadCount();
      if (response.success && response.data != null) {
        state = response.data!;
      }
    } catch (e) {
      // 静默失败
    }
  }

  void setCount(int count) {
    state = count;
  }
}

final unreadCountNotifierProvider =
    StateNotifierProvider<UnreadCountNotifier, int>((ref) {
  return UnreadCountNotifier(ref.watch(messageApiServiceProvider));
});
