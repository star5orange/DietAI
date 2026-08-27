import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../data/message_api_service.dart';
import '../../domain/message_models.dart';
import '../../domain/services/chat_service.dart';
import '../providers/message_provider.dart';
import '../providers/social_provider.dart';

/// 会话列表页 - 展示所有家人/好友的聊天会话
class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final ChatService _chatService = ChatService(MessageApiService());
  final WebSocketService _wsService = WebSocketService();

  @override
  void initState() {
    super.initState();
    // 正在消息列表页，抑制全局新消息本地通知（列表本身会实时刷新）
    WebSocketService.suppressNewMessageNotification = true;
    // 订阅全局 WebSocket：收到新消息时刷新会话列表（置顶 + 未读数）
    _wsService.onMessageReceived = (_) {
      if (mounted) {
        ref.read(chatListProvider.notifier).loadChatList();
      }
    };
    // 加载会话列表
    Future.microtask(() {
      ref.read(chatListProvider.notifier).loadChatList();
    });
  }

  @override
  void dispose() {
    WebSocketService.suppressNewMessageNotification = false;
    // 清除回调，避免离开页面后仍触发刷新
    if (_wsService.onMessageReceived != null) {
      _wsService.onMessageReceived = null;
    }
    super.dispose();
  }

  /// 根据最后一条消息内容生成摘要（区分图片/戳一戳/食物卡片）
  String _lastMessagePreview(ChatRoom room) {
    final content = room.lastMessage?.trim() ?? '';
    if (content.isEmpty) return '暂无消息';
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return '[图片]';
    }
    if (content.contains('戳了戳你')) return '[戳一戳]';
    // 食物卡片内容形如 "食物名 xxx 卡"
    if (RegExp(r'\d+(\.\d+)?\s*卡$').hasMatch(content)) return '[食物卡片]';
    return content.length > 20 ? '${content.substring(0, 20)}...' : content;
  }

  Future<void> _refresh() async {
    await ref.read(chatListProvider.notifier).loadChatList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    // 按最后消息时间倒序排序
    final rooms = _chatService.sortChatRoomsByTime(state.rooms);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
      ),
      body: state.isLoading && rooms.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('暂无会话', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/social/search'),
                        icon: const Icon(Icons.person_add),
                        label: const Text('去添加好友'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return _ChatRoomTile(
                        room: room,
                        preview: _lastMessagePreview(room),
                        timeText: room.lastMessageTime != null
                            ? _chatService
                                .formatMessageTime(room.lastMessageTime!)
                            : '',
                        onTap: () {
                          // 与现有入口一致的跳转方式
                          context.push(
                            '/social/chat/${room.userId}',
                            extra: {
                              'name': room.realName ?? room.username,
                              'avatarUrl': room.avatarUrl,
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

/// 单个会话条目
class _ChatRoomTile extends ConsumerWidget {
  final ChatRoom room;
  final String preview;
  final String timeText;
  final VoidCallback onTap;

  const _ChatRoomTile({
    required this.room,
    required this.preview,
    required this.timeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineState = ref.watch(onlineStatusProvider(room.userId));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 头像 + 在线绿点 + 未读角标
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: room.avatarUrl != null
                      ? NetworkImage(room.avatarUrl!)
                      : null,
                  child: room.avatarUrl == null
                      ? const Icon(Icons.person, size: 28, color: Colors.grey)
                      : null,
                ),
                if (onlineState.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                if (room.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // 名字 + 最后消息摘要
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.realName ?? room.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 13,
                      color: room.unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: room.unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 时间
            Text(
              timeText,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
