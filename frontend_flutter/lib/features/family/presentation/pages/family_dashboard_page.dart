import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/tts_service.dart';
import '../../../social/presentation/providers/family_provider.dart';

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
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 异常提醒卡片
          if (state.alerts.isNotEmpty) _buildAlertsCard(context, state.alerts),
          if (state.alerts.isNotEmpty) const SizedBox(height: 16),
          // 家庭成员卡片列表
          ...state.members.map((member) => _buildMemberCard(context, member)),
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

  Widget _buildMemberCard(BuildContext context, FamilyMemberSummary member) {
    final calorieProgress = member.targetCalories > 0
        ? (member.totalCalories / member.targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final waterProgress = member.waterGoal > 0
        ? (member.waterIntake / member.waterGoal).clamp(0.0, 1.0)
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
                    '${member.totalCalories.toInt()} / ${member.targetCalories.toInt()} kcal',
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
                    '${member.waterIntake}ml / ${member.waterGoal}ml',
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
              // 宠物状态
              if (member.realPets.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.pets, size: 16, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      '宠物: ${member.realPets.map((p) => p['name'] as String? ?? '').join(', ')}',
                      style: const TextStyle(fontSize: 12),
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
}
