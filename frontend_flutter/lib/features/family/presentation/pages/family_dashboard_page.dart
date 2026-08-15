import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/family_provider.dart';
import '../../../social/presentation/providers/social_provider.dart';

/// 家庭健康看板页面
class FamilyDashboardPage extends ConsumerStatefulWidget {
  const FamilyDashboardPage({super.key});

  @override
  ConsumerState<FamilyDashboardPage> createState() =>
      _FamilyDashboardPageState();
}

class _FamilyDashboardPageState extends ConsumerState<FamilyDashboardPage> {
  final TtsService _ttsService = TtsService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notifier = ref.read(familyDashboardProvider.notifier);
      notifier.loadDashboard();
      notifier.loadAlerts();
      ref.read(familyAchievementsProvider.notifier).loadAchievements();
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  Future<void> _speakAlerts(List<FamilyAlert> alerts) async {
    if (alerts.isEmpty) return;
    final buffer = StringBuffer();
    buffer.write('家庭健康提醒：');
    for (var alert in alerts) {
      buffer.write('${alert.message}。');
    }
    setState(() => _isSpeaking = true);
    try {
      await _ttsService.speak(buffer.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音播报失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(familyDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭健康看板'),
        actions: [
          IconButton(
            tooltip: '家庭周报',
            icon: const Icon(Icons.assessment),
            onPressed: () => context.push('/family/weekly-report'),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, FamilyDashboardState state) {
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
              onPressed: () {
                final notifier = ref.read(familyDashboardProvider.notifier);
                notifier.loadDashboard();
                notifier.loadAlerts();
                ref
                    .read(familyAchievementsProvider.notifier)
                    .loadAchievements();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.members.isEmpty) {
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
      onRefresh: () async {
        final notifier = ref.read(familyDashboardProvider.notifier);
        await Future.wait([
          notifier.loadDashboard(),
          notifier.loadAlerts(),
          ref.read(familyAchievementsProvider.notifier).loadAchievements(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 家庭成就卡片
          _buildAchievementCard(context),
          const SizedBox(height: 16),
          // 异常提醒卡片
          if (state.alerts.isNotEmpty) _buildAlertsCard(context, state.alerts),
          if (state.alerts.isNotEmpty) const SizedBox(height: 16),
          // 家庭成员卡片列表
          ...state.members.map((member) => _buildMemberCard(context, member)),
          // 体检记录入口
          _buildExamEntry(context),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context, List<FamilyAlert> alerts) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '异常提醒',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.stop : Icons.volume_up,
                    color: _isSpeaking ? Colors.red : Colors.orange,
                  ),
                  tooltip: _isSpeaking ? '停止播报' : '语音播报',
                  onPressed: _isSpeaking
                      ? () => _ttsService.stop()
                      : () => _speakAlerts(alerts),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        alert.severity == 'warning'
                            ? Icons.warning
                            : Icons.info,
                        size: 16,
                        color: alert.severity == 'warning'
                            ? Colors.orange
                            : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// 桌宠心情/饥饿文字（配合心情 emoji）
  String _petMoodText(String? mood, int? hungerHours) {
    if (mood == null) return '';
    const moodMap = {
      'happy': '😊',
      'normal': '',
      'hungry': '🍽️饥饿',
      'weak': '🥺虚弱',
    };
    final emoji = moodMap[mood] ?? '';
    final hours =
        (hungerHours != null && hungerHours > 0) ? ' $hungerHours小时未喂' : '';
    return '$emoji$hours';
  }

  /// 体检摘要文字（最新体检日期 + 异常项数 + 复查提醒）
  String _examSummaryText(Map<String, dynamic> exam) {
    final date = exam['latest_exam_date'] as String?;
    final abnormal = exam['abnormal_count'] as num?;
    final parts = <String>[];
    if (date != null) parts.add('体检:$date');
    if (abnormal != null && abnormal > 0) {
      parts.add('⚠️$abnormal项异常');
    } else if (date != null) {
      parts.add('无异常');
    }
    // 复查提醒：基于 followup_date 计算剩余天数 / 是否已过
    final followup = exam['followup_date'] as String?;
    if (followup != null && followup.isNotEmpty) {
      final followupDate = DateTime.tryParse(followup);
      if (followupDate != null) {
        final now = DateTime.now();
        final today0 = DateTime(now.year, now.month, now.day);
        final days = followupDate.difference(today0).inDays;
        if (days < 0) {
          parts.add('⚠️已过复查期');
        } else if (days == 0) {
          parts.add('今天复查');
        } else {
          parts.add('复查:$followup($days天)');
        }
      } else {
        parts.add('复查:$followup');
      }
    } else if (abnormal != null && abnormal > 0) {
      parts.add('请按时复查');
    }
    return parts.isEmpty ? '' : parts.join(' · ');
  }

  Widget _buildMemberCard(BuildContext context, FamilyMemberSummary member) {
    // 数据权限隐藏：null 表示对方隐藏了该字段
    final showCalories =
        member.totalCalories != null && member.targetCalories != null;
    final showWater = member.waterIntake != null && member.waterGoal != null;
    final calorieProgress = showCalories
        ? (member.totalCalories! / member.targetCalories!).clamp(0.0, 1.0)
        : 0.0;
    final waterProgress = showWater
        ? (member.waterIntake! / member.waterGoal!).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/social/family-health/${member.userId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：头像 + 名字
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: member.avatarUrl != null
                        ? NetworkImage(member.avatarUrl!)
                        : null,
                    child: member.avatarUrl == null
                        ? const Icon(Icons.person, size: 24, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.realName ?? member.username,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '家人',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
              // 快捷操作：拍照 / 提醒喝水 / 帮记录
              Row(
                children: [
                  _ActionButton(
                    icon: Icons.photo_camera,
                    label: '拍照',
                    onPressed: () => context.push(
                      '/exam/upload',
                      extra: {
                        'ownerUserId': member.userId,
                        'ownerName': member.realName ?? member.username,
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
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
                            content: Text(success ? '已发送喝水提醒' : '提醒发送失败'),
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
              const SizedBox(height: 16),
              // 热量进度
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  const Text('热量', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(
                    showCalories
                        ? '${member.totalCalories!.toInt()} / ${member.targetCalories!.toInt()} kcal'
                        : '已隐藏',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: calorieProgress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
              const SizedBox(height: 16),
              // 饮水进度
              Row(
                children: [
                  const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                  const SizedBox(width: 4),
                  const Text('饮水', style: TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(
                    showWater
                        ? '${member.waterIntake!}ml / ${member.waterGoal!}ml'
                        : '已隐藏',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: waterProgress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              // 宠物状态（虚拟桌宠 + 真实宠物健康分；真实宠物被隐藏时为 null，不展示）
              if (member.virtualPetName != null ||
                  (member.realPets != null && member.realPets!.isNotEmpty)) ...[
                const SizedBox(height: 12),
                if (member.virtualPetName != null)
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined,
                          size: 16, color: Colors.purple),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '桌宠: ${member.virtualPetName}${_petMoodText(member.virtualPetMood, member.hungerHours)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                if (member.realPets != null && member.realPets!.isNotEmpty) ...[
                  if (member.virtualPetName != null) const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.pets, size: 16, color: Colors.purple),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '宠物: ${member.realPets!.map((p) {
                            final name = p['name'] as String? ?? '';
                            final score = p['health_score'];
                            return score != null ? '$name (健康分$score)' : name;
                          }).join(', ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              // 体检摘要（最新体检日期 + 异常项数）
              if (member.examSummary != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.monitor_heart_outlined,
                        size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _examSummaryText(member.examSummary!),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 家庭成就卡片：展示已解锁徽章 + "健康家庭"成就判定
  Widget _buildAchievementCard(BuildContext context) {
    final achievementState = ref.watch(familyAchievementsProvider);
    final achievements = achievementState.achievements;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, size: 20, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  '家庭成就',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (achievementState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (achievements.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '暂无已解锁成就',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: achievements
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFE082)),
                          ),
                          child: Text(
                            '🏆 ${a.title}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFF57F17),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 4),
            // 健康家庭成就状态行：已解锁展示，未解锁可点击判定
            if (achievementState.healthFamilyDayUnlocked)
              const Row(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    '已解锁健康家庭成就',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2BAF74),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              InkWell(
                onTap: achievementState.isChecking
                    ? null
                    : () => ref
                        .read(familyAchievementsProvider.notifier)
                        .checkHealthFamilyDay(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text(
                        '健康家庭成就未解锁',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      if (achievementState.isChecking)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Text(
                          '点击判定',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (achievementState.checkResult != null) ...[
              const SizedBox(height: 6),
              Text(
                achievementState.checkResult!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF57F17)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 体检记录入口（选择查看对象后进入）
  Widget _buildExamEntry(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: () => _showExamOwnerPicker(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  /// 选人弹窗：自己 + 家庭成员
  void _showExamOwnerPicker(BuildContext context) {
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
