import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/family_provider.dart';
import '../providers/social_provider.dart';
import '../../domain/social_models.dart';

/// 家庭健康看板卡片（聚合所有家人的健康摘要）
///
/// 上方是简单摘要（几位家人、几条提醒），点击展开后展示每位家人的
/// 饮水/热量/宠物/体检状态、异常提醒与体检记录入口。
class FamilyDashboardCard extends ConsumerStatefulWidget {
  const FamilyDashboardCard({super.key});

  @override
  ConsumerState<FamilyDashboardCard> createState() =>
      _FamilyDashboardCardState();
}

/// 看板卡片状态（展开/收起）
class _FamilyDashboardCardState extends ConsumerState<FamilyDashboardCard> {
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
  Widget build(BuildContext context) {
    final state = ref.watch(familyDashboardProvider);

    if (state.members.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final todayText = '${now.month}月${now.day}日';
    final alertCount = state.alerts.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // 上方是简单摘要，下方点击展开展示丰富详情
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        iconColor: AppColors.primary,
        collapsedIconColor: Colors.grey,
        leading:
            const Icon(Icons.home_filled, color: AppColors.primary, size: 20),
        title: const Text(
          '家庭健康',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${state.members.length}位家人 · $todayText'
          '${alertCount > 0 ? ' · ⚠️ $alertCount 条提醒' : ''}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
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
          // 固定入口：体检记录（选择查看对象后进入）
          const Divider(height: 16),
          _buildExamEntry(context, ref),
        ],
      ),
    );
  }

  /// 体检记录固定入口
  Widget _buildExamEntry(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showExamOwnerPicker(context, ref),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '体检记录',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const Text(
              '按日期查看',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// 选人弹窗：自己 + 家庭成员
  void _showExamOwnerPicker(BuildContext context, WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);
    final family = ref.read(friendListProvider).family;

    final List<({String label, String? subtitle, int userId})> options = [
      (
        label: currentUser?.username ?? '我自己',
        subtitle: '自己',
        userId: currentUser?.id ?? 0,
      ),
      ...family.map((f) => (
            label: f.note ?? f.realName ?? f.username,
            subtitle: '家人',
            userId: f.userId,
          )),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择查看对象',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map((o) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              o.subtitle == '自己'
                                  ? Icons.person
                                  : Icons.family_restroom,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(o.label),
                          subtitle:
                              o.subtitle != null ? Text(o.subtitle!) : null,
                          trailing: const Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push(
                              '/exam/reports',
                              extra: {'userId': o.userId},
                            );
                          },
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
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
    // 数据权限隐藏信号：主人隐藏了热量/饮水/体检等字段，或桌宠被隐藏
    final dataHidden =
        member.totalCalories == null && member.waterIntake == null;
    final mood = _FamilyDashboardCardState._moods[member.virtualPetMood] ??
        (emoji: '🐾', label: member.virtualPetMood);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 头像 + 右上角 📸 入口：点击直接打开相机为家人拍体检报告
              Stack(
                clipBehavior: Clip.none,
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
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: GestureDetector(
                      onTap: () => context.push(
                        '/exam/upload',
                        extra: {
                          'ownerUserId': member.userId,
                          'ownerName': _displayName,
                        },
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.photo_camera,
                            size: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
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
          // 饮水 + 热量（数据权限隐藏时显示"已隐藏"）
          Row(
            children: [
              _MetricText(
                emoji: '💧',
                text: member.waterIntake != null && member.waterGoal != null
                    ? '${member.waterIntake}/${member.waterGoal}'
                    : '已隐藏',
              ),
              const SizedBox(width: 16),
              _MetricText(
                emoji: '🍚',
                text: member.totalCalories != null &&
                        member.targetCalories != null
                    ? '${member.totalCalories!.round()}/${member.targetCalories!.round()}'
                    : '已隐藏',
              ),
            ],
          ),
          // 虚拟桌宠（人人都有，只显示心情，不显示体型）
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: member.virtualPetName != null && mood.label != null
                ? Text(
                    '🧚 ${member.virtualPetName}: ${mood.emoji} ${mood.label}',
                    style: const TextStyle(fontSize: 13),
                  )
                : Text(
                    '🧚 桌宠状态已隐藏',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
          ),
          // 真实宠物（可选）
          if (member.realPets == null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '🐱 真实宠物数据已隐藏',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else if (member.realPets!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '（无真实宠物）',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            ...member.realPets!.map((p) {
              final species = (p['species'] as String?) ?? '';
              final name = (p['name'] as String?) ?? '';
              final healthScore = p['health_score'] as int?;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${_FamilyDashboardCardState._speciesEmoji(species)} $name'
                  '${healthScore != null ? ': 😊 健康分 $healthScore' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          // 体检摘要（可点击进入家人的体检报告；数据被隐藏时显示提示）
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
            )
          else if (dataHidden)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '🏥 体检数据已隐藏',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
