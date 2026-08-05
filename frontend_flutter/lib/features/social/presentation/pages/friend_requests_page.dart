import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../domain/social_models.dart';
import '../providers/social_provider.dart';
import '../widgets/relationship_label_dialog.dart';

/// 好友申请页面
class FriendRequestsPage extends ConsumerWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友申请'),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, PendingRequestsState state) {
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
              onPressed: () => ref
                  .read(pendingRequestsProvider.notifier)
                  .loadPendingRequests(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无待处理申请', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pendingRequestsProvider.notifier).loadPendingRequests(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.requests.length,
        itemBuilder: (context, index) {
          final request = state.requests[index];
          return _RequestTile(request: request);
        },
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final FriendRequest request;

  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              backgroundImage: request.senderAvatarUrl != null
                  ? NetworkImage(request.senderAvatarUrl!)
                  : null,
              child: request.senderAvatarUrl == null
                  ? const Icon(Icons.person, size: 28, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.senderRealName ?? request.senderUsername,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.relationshipType == 'family'
                        ? '请求添加你为家人'
                        : '请求添加你为好友',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (request.relationshipLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '对方称你为「${request.relationshipLabel}」',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
            // 操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () =>
                      _handleRequest(context, ref, request.requestId, 'accept'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('接受'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () =>
                      _handleRequest(context, ref, request.requestId, 'reject'),
                  child: const Text('拒绝', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequest(
      BuildContext context, WidgetRef ref, int requestId, String action) async {
    String? label;
    // 接受家人申请时，可设置对方与我的关系称谓（按对方性别推荐）
    if (action == 'accept' && request.relationshipType == 'family') {
      label = await showRelationshipLabelDialog(
        context,
        title: '${request.senderRealName ?? request.senderUsername} 和你是什么关系',
        gender: request.senderGender,
      );
      if (!context.mounted) return;
    }

    final success = await ref
        .read(pendingRequestsProvider.notifier)
        .handleRequest(requestId, action, relationshipLabel: label);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(success ? (action == 'accept' ? '已接受' : '已拒绝') : '操作失败')),
      );
    }
  }
}
