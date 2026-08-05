import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/weekly_report_provider.dart';

/// 家庭周报页面
class WeeklyReportPage extends ConsumerStatefulWidget {
  const WeeklyReportPage({super.key});

  @override
  ConsumerState<WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends ConsumerState<WeeklyReportPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(weeklyReportProvider.notifier).loadWeeklyReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weeklyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭健康周报'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(WeeklyReportState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '加载失败: ${state.error}',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(weeklyReportProvider.notifier).loadWeeklyReport();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final report = state.report;
    if (report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_late, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无周报数据',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(weeklyReportProvider.notifier).loadWeeklyReport();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 周报时间范围
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '本周健康报告',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${report.weekStart} ~ ${report.weekEnd}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 家庭成员列表
            const Text(
              '家庭成员健康数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (report.members.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          '暂无家庭成员数据',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...report.members.map((member) => _buildMemberCard(member)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(FamilyMemberWeeklyData member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成员信息
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: member.avatarUrl != null
                      ? NetworkImage(member.avatarUrl!)
                      : null,
                  child: member.avatarUrl == null
                      ? Icon(Icons.person, color: AppColors.primary)
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '健康评分: ${member.healthScore}分',
                        style: TextStyle(
                          fontSize: 14,
                          color: _getHealthScoreColor(member.healthScore),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getHealthScoreColor(member.healthScore)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getHealthScoreText(member.healthScore),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getHealthScoreColor(member.healthScore),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 健康数据
            Row(
              children: [
                Expanded(
                  child: _buildDataItem(
                    icon: Icons.local_fire_department,
                    label: '平均热量',
                    value: '${member.avgCalories.toStringAsFixed(0)} kcal',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataItem(
                    icon: Icons.water_drop,
                    label: '平均饮水',
                    value: '${member.avgWater.toStringAsFixed(0)} ml',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            // 体检异常追踪
            if (member.examSummary != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildExamSummary(member.examSummary!),
            ],

            // 成就
            if (member.achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                '本周成就',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.achievements.map((achievement) {
                  return Chip(
                    avatar: const Icon(Icons.emoji_events,
                        size: 16, color: Colors.amber),
                    label: Text(achievement),
                    backgroundColor: Colors.amber.withOpacity(0.1),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamSummary(Map<String, dynamic> exam) {
    final dateStr = exam['latest_exam_date'] as String? ?? '';
    final abnormalCount = exam['abnormal_count'] as int? ?? 0;
    final daysSince = exam['days_since_exam'] as int?;
    final nextCheckup = exam['next_checkup_days'] as int?;
    final abnormalMetrics = (exam['abnormal_metrics'] as List?) ?? [];

    final dateText = dateStr.isNotEmpty ? dateStr.substring(0, 10) : '未知';
    final abnormalText = abnormalCount > 0
        ? '${abnormalCount} 项异常：${abnormalMetrics.join('、')}'
        : '指标正常';

    String checkupText;
    Color checkupColor;
    if (abnormalCount > 0 && nextCheckup != null) {
      checkupText = nextCheckup > 0 ? '建议 $nextCheckup 天后复查' : '已到建议复查时间';
      checkupColor = nextCheckup > 0 ? Colors.orange : Colors.red;
    } else {
      checkupText = '建议每年定期体检';
      checkupColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.health_and_safety, size: 18, color: Colors.teal),
            SizedBox(width: 6),
            Text(
              '体检追踪',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '最近体检: $dateText（$daysSince 天前）',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 4),
        Text(
          abnormalText,
          style: TextStyle(
            fontSize: 13,
            color: abnormalCount > 0 ? Colors.red : Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          checkupText,
          style: TextStyle(fontSize: 13, color: checkupColor),
        ),
      ],
    );
  }

  Widget _buildDataItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getHealthScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getHealthScoreText(int score) {
    if (score >= 80) return '优秀';
    if (score >= 60) return '良好';
    if (score >= 40) return '一般';
    return '需改善';
  }
}
