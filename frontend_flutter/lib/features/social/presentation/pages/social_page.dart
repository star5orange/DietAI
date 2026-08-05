import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/websocket_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/family_provider.dart';
import '../providers/message_provider.dart';
import '../providers/social_provider.dart';
import '../widgets/family_dashboard_card.dart';
import '../widgets/family_member_card.dart';
import '../widgets/friend_card.dart';

/// 社交主页 - 家人与好友
class SocialPage extends ConsumerStatefulWidget {
  const SocialPage({super.key});

  @override
  ConsumerState<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends ConsumerState<SocialPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Function()? _prevOnConnected;
  Function()? _prevOnDisconnected;
  Function(int, bool)? _prevOnOnlineStatusChanged;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 加载数据
    Future.microtask(() {
      ref.read(friendListProvider.notifier).loadFriendList();
      ref.read(pendingRequestsProvider.notifier).loadPendingRequests();
      // 加载会话列表（用于展示未读消息徽标）
      ref.read(chatListProvider.notifier).loadChatList();
    });

    // 订阅 WebSocket 事件，实时刷新好友/家人在线状态
    final ws = WebSocketService();
    _prevOnConnected = ws.onConnected;
    _prevOnDisconnected = ws.onDisconnected;
    _prevOnOnlineStatusChanged = ws.onOnlineStatusChanged;
    ws.onConnected = _refreshAllOnlineStatus;
    ws.onDisconnected = _refreshAllOnlineStatus;
    ws.onOnlineStatusChanged = _handleOnlineStatusChanged;
  }

  /// 重新连接/断开时刷新所有好友家人的在线状态
  void _refreshAllOnlineStatus() {
    final state = ref.read(friendListProvider);
    for (final member in state.family) {
      ref.read(onlineStatusProvider(member.userId).notifier).refresh();
    }
    for (final friend in state.friends) {
      ref.read(onlineStatusProvider(friend.userId).notifier).refresh();
    }
  }

  /// 收到好友上下线推送，直接更新对应卡片状态
  void _handleOnlineStatusChanged(int userId, bool isOnline) {
    if (!mounted) return;
    ref.read(onlineStatusProvider(userId).notifier).setOnline(isOnline);
  }

  @override
  void dispose() {
    _tabController.dispose();
    final ws = WebSocketService();
    if (identical(ws.onConnected, _refreshAllOnlineStatus)) {
      ws.onConnected = _prevOnConnected;
    }
    if (identical(ws.onDisconnected, _refreshAllOnlineStatus)) {
      ws.onDisconnected = _prevOnDisconnected;
    }
    if (identical(ws.onOnlineStatusChanged, _handleOnlineStatusChanged)) {
      ws.onOnlineStatusChanged = _prevOnOnlineStatusChanged;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingState = ref.watch(pendingRequestsProvider);
    final pendingCount = pendingState.requests.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('家人与好友'),
        actions: [
          // 排行榜按钮
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push('/social/leaderboard'),
            tooltip: '好友排行榜',
          ),
          // 邀请码按钮
          IconButton(
            icon: const Icon(Icons.vpn_key),
            onPressed: () => context.push('/social/invite-code'),
            tooltip: '邀请码',
          ),
          // 搜索按钮
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/social/search'),
          ),
          // 好友申请按钮
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () => context.push('/social/requests'),
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$pendingCount',
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
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '家人'),
            Tab(text: '好友'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FamilyTab(),
          _FriendsTab(),
        ],
      ),
    );
  }
}

class _FamilyTab extends ConsumerStatefulWidget {
  const _FamilyTab();

  @override
  ConsumerState<_FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends ConsumerState<_FamilyTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(familyDashboardProvider.notifier).load();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(friendListProvider.notifier).loadFriendList(),
      ref.read(familyDashboardProvider.notifier).load(),
      ref.read(chatListProvider.notifier).loadChatList(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendListProvider);
    final chatState = ref.watch(chatListProvider);
    final unreadMap = {
      for (final room in chatState.rooms) room.userId: room.unreadCount,
    };

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(state.error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(friendListProvider.notifier).loadFriendList(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.family.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有添加家人', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/social/search'),
              icon: const Icon(Icons.person_add),
              label: const Text('添加家人'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // 第一项为家庭健康看板，其后为家人卡片
        itemCount: state.family.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const FamilyDashboardCard();
          }
          final member = state.family[index - 1];
          return FamilyMemberCard(
            member: member,
            unreadCount: unreadMap[member.userId] ?? 0,
            onTap: () => context.push('/social/family-health/${member.userId}'),
            onLongPress: () => _showRemoveDialog(
                context, ref, member.relationId, member.username),
          );
        },
      ),
    );
  }

  void _showRemoveDialog(
      BuildContext context, WidgetRef ref, int relationId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解除家人关系'),
        content: Text('确定要解除与 $name 的家人关系吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(friendListProvider.notifier)
                  .removeRelation(relationId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已解除关系' : '解除关系失败')),
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _FriendsTab extends ConsumerWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(friendListProvider);
    final chatState = ref.watch(chatListProvider);
    final unreadMap = {
      for (final room in chatState.rooms) room.userId: room.unreadCount,
    };

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有添加好友', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/social/search'),
              icon: const Icon(Icons.person_add),
              label: const Text('添加好友'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.read(friendListProvider.notifier).loadFriendList(),
          ref.read(chatListProvider.notifier).loadChatList(),
        ]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.friends.length,
        itemBuilder: (context, index) {
          final friend = state.friends[index];
          return FriendCard(
            friend: friend,
            unreadCount: unreadMap[friend.userId] ?? 0,
            onTap: () => context.push('/social/chat/${friend.userId}'),
            onLongPress: () => _showRemoveDialog(
                context, ref, friend.relationId, friend.username),
          );
        },
      ),
    );
  }

  void _showRemoveDialog(
      BuildContext context, WidgetRef ref, int relationId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友 $name 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(friendListProvider.notifier)
                  .removeRelation(relationId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已删除好友' : '删除好友失败')),
                );
              }
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
