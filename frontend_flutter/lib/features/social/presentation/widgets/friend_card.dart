import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../domain/social_models.dart';
import '../providers/social_provider.dart';
import 'health_summary_card.dart';
import 'relationship_label_dialog.dart';

/// 好友卡片组件
class FriendCard extends ConsumerWidget {
  final UserRelation friend;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int unreadCount;

  const FriendCard({
    super.key,
    required this.friend,
    this.onTap,
    this.onLongPress,
    this.unreadCount = 0,
  });

  Future<void> _showUpgradeDialog(BuildContext context, WidgetRef ref) async {
    // 先选择对方与我的关系称谓（可跳过，按对方性别推荐）
    final label = await showRelationshipLabelDialog(
      context,
      title: '${friend.realName ?? friend.username} 和你是什么关系',
      initial: friend.note,
      gender: friend.gender,
    );
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('升级为家人'),
        content: Text(
          '确定要将 ${friend.realName ?? friend.username} 升级为家人吗？\n'
          '升级后双方可以查看详细健康数据、代记录饮食等。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFF2BAF74)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(friendListProvider.notifier)
        .upgradeToFamily(friend.userId, relationshipLabel: label);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已发送家人邀请，等待对方确认' : '升级为家人失败'),
        ),
      );
    }
  }

  void _showEditNoteDialog(BuildContext context, WidgetRef ref) async {
    final label = await showRelationshipLabelDialog(
      context,
      title: '编辑与${friend.realName ?? friend.username}的关系',
      initial: friend.note,
      gender: friend.gender,
    );
    if (label == null || !context.mounted) return;
    final success = await ref
        .read(friendListProvider.notifier)
        .updateRelationNote(friend.relationId, label);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '称谓已更新' : '更新称谓失败')),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友 ${friend.realName ?? friend.username} 吗？'),
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
                  .removeRelation(friend.relationId);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineState = ref.watch(onlineStatusProvider(friend.userId));
    final healthAsync = ref.watch(friendHealthProvider(friend.userId));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 头像 + 在线状态指示器
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: friend.avatarUrl != null
                            ? NetworkImage(friend.avatarUrl!)
                            : null,
                        child: friend.avatarUrl == null
                            ? const Icon(Icons.person,
                                size: 28, color: Colors.grey)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: onlineState.isOnline
                                ? Colors.green
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      // 未读消息徽标
                      if (unreadCount > 0)
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
                              '$unreadCount',
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
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.realName ?? friend.username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                friend.note ?? '好友',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (onlineState.isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '在线',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 升级为家人按钮
                  IconButton(
                    icon: const Icon(Icons.family_restroom,
                        color: Color(0xFF2BAF74), size: 22),
                    tooltip: '升级为家人',
                    onPressed: () => _showUpgradeDialog(context, ref),
                  ),
                  // 编辑称谓按钮
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: '编辑关系称谓',
                    onPressed: () => _showEditNoteDialog(context, ref),
                  ),
                  // 删除好友按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 22),
                    tooltip: '删除好友',
                    onPressed: () => _showDeleteDialog(context, ref),
                  ),
                  const SizedBox(width: 4),
                  // 箭头
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              // 好友基础健康信息（今日热量/喝水达标/宠物心情）
              healthAsync.when(
                data: (health) => HealthSummaryCard(
                  totalCalories: health.totalCalories,
                  targetCalories: health.targetCalories,
                  waterIntake: health.waterIntake,
                  waterGoal: health.waterGoal,
                  petMood: health.petMood,
                  petName: health.petName,
                ),
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
