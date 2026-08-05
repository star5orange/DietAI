import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/social_models.dart';
import '../providers/social_provider.dart';

/// 好友饮食排行榜页
/// 按好友近7天运动消耗热量排名
class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友饮食排行榜'),
        centerTitle: true,
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, LeaderboardState state) {
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
              onPressed: () => ref.read(leaderboardProvider.notifier).load(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有好友数据，快去添加好友一起运动吧！',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final rankColors = [
      const Color(0xFFFFD700), // 金
      const Color(0xFFC0C0C0), // 银
      const Color(0xFFCD7F32), // 铜
    ];

    return RefreshIndicator(
      onRefresh: () => ref.read(leaderboardProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          final rank = index + 1;
          final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey[400]!;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: rank <= 3
                  ? Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[200],
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
              title: Text(
                item.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: Text('运动 ${item.exerciseCount} 次'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.weeklyBurnedCalories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    '周消耗',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
