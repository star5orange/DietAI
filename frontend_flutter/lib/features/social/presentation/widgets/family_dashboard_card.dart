import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/family_provider.dart';

/// 家庭健康看板卡片（聚合所有家人的健康摘要）
class FamilyDashboardCard extends ConsumerWidget {
  const FamilyDashboardCard({super.key});

  static const Map<String, ({String emoji, String label})> _moods = {
    'happy': (emoji: '😊', label: '开心'),
    'normal': (emoji: '🙂', label: '平静'),
    'hungry': (emoji: '😰', label: '饥饿'),
    'weak': (emoji: '😵', label: '虚弱'),
  };

  static String _speciesEmoji(String species) {
    switch (species.toLowerCase()) {
      case 'cat':
        return '🐱';
      case 'dog':
        return '🐕';
      default:
        return '🐾';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(familyDashboardProvider);

    if (state.members.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final todayText = '${now.month}月${now.day}日';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：🏠 家庭健康 + 日期
            Row(
              children: [
                const Icon(Icons.home_filled,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 6),
                const Text(
                  '家庭健康',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  todayText,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(height: 20),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              // 每位家人一段
              ...state.members.map((m) => _MemberSection(member: m)),
            // 提醒区
            if (state.alerts.isNotEmpty) ...[
              const Divider(height: 16),
              ...state.alerts.map((a) => _AlertRow(alert: a)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 单个家人摘要段
class _MemberSection extends ConsumerWidget {
  final FamilyMemberSummary member;

  const _MemberSection({required this.member});

  String get _displayName => member.note ?? member.realName ?? member.username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = FamilyDashboardCard._moods[member.virtualPetMood] ??
        (emoji: '🐾', label: member.virtualPetMood);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[200],
                backgroundImage: member.avatarUrl != null
                    ? NetworkImage(member.avatarUrl!)
                    : null,
                child: member.avatarUrl == null
                    ? const Icon(Icons.person, size: 16, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _displayName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 快捷操作
              _ActionButton(
                icon: Icons.water_drop_outlined,
                label: '提醒喝水',
                onPressed: () async {
                  final success = await ref
                      .read(familyDashboardProvider.notifier)
                      .remindWater(member.userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(success ? '已向$_displayName发送喝水提醒' : '提醒发送失败'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.restaurant_outlined,
                label: '帮记录',
                onPressed: () =>
                    context.push('/social/family-health/${member.userId}'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 饮水 + 热量
          Row(
            children: [
              _MetricText(
                emoji: '💧',
                text: '${member.waterIntake}/${member.waterGoal}',
              ),
              const SizedBox(width: 16),
              _MetricText(
                emoji: '🍚',
                text:
                    '${member.totalCalories.round()}/${member.targetCalories.round()}',
              ),
            ],
          ),
          // 虚拟桌宠（人人都有，只显示心情，不显示体型）
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '🧚 ${member.virtualPetName}: ${mood.emoji} ${mood.label}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          // 真实宠物（可选）
          if (member.realPets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '（无真实宠物）',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...member.realPets.map((p) {
              final species = (p['species'] as String?) ?? '';
              final name = (p['name'] as String?) ?? '';
              final healthScore = p['health_score'] as int?;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${FamilyDashboardCard._speciesEmoji(species)} $name'
                  '${healthScore != null ? ': 😊 健康分 $healthScore' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          // 体检摘要（可点击进入家人的体检报告）
          if (member.examSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () => context.push(
                  '/exam/reports',
                  extra: {'userId': member.userId},
                ),
                child: Row(
                  children: [
                    const Text('🏥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _examSummaryText(member.examSummary!),
                        style: TextStyle(
                          fontSize: 13,
                          color:
                              (member.examSummary!['abnormal_count'] as int? ??
                                          0) >
                                      0
                                  ? Colors.red
                                  : Colors.grey[800],
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 14, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 组装体检摘要文案：最近体检日期 + 异常项
  String _examSummaryText(Map<String, dynamic> exam) {
    final dateStr = exam['latest_exam_date'] as String?;
    final abnormal = exam['abnormal_count'] as int? ?? 0;
    final dateText = dateStr != null && dateStr.isNotEmpty
        ? '最近体检: ${dateStr.substring(0, 10)}'
        : '最近体检: 未知';
    final abnormalText = abnormal > 0 ? ' · ⚠️ $abnormal 项异常' : ' · ✅ 指标正常';
    return '$dateText$abnormalText';
  }
}

/// 提醒行
class _AlertRow extends StatelessWidget {
  final FamilyAlert alert;

  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              alert.message,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

/// 指标文本（💧 800/2000）
class _MetricText extends StatelessWidget {
  final String emoji;
  final String text;

  const _MetricText({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$emoji $text',
      style: const TextStyle(fontSize: 13),
    );
  }
}

/// 小型操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
