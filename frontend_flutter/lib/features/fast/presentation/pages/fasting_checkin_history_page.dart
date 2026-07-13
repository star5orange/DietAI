import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';

/// 打卡记录历史页面
class FastingCheckinHistoryPage extends ConsumerStatefulWidget {
  final int planId;

  const FastingCheckinHistoryPage({super.key, this.planId = 0});

  @override
  ConsumerState<FastingCheckinHistoryPage> createState() =>
      _FastingCheckinHistoryPageState();
}

class _FastingCheckinHistoryPageState
    extends ConsumerState<FastingCheckinHistoryPage> {
  List<FastingCheckin> _checkins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCheckins();
  }

  Future<void> _loadCheckins() async {
    try {
      final service = ref.read(fastingServiceProvider);
      final checkins = await service.getCheckins(widget.planId);
      setState(() => _checkins = checkins);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计卡片
            _buildStatsCards(),
            const SizedBox(height: 24),

            // 记录列表
            Text('历史记录', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            ..._buildCheckinList(),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('打卡记录',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStatsCards() {
    final totalCheckins = _checkins.length;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('总打卡', '${totalCheckins}次',
              LucideIcons.calendarCheck, AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
              '最长连续', '7天', LucideIcons.flame, AppColors.warning),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _buildCheckinList() {
    if (_checkins.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('暂无打卡记录')),
        ),
      ];
    }
    return _checkins.map((record) => _buildCheckinCard(record)).toList();
  }

  Widget _buildCheckinCard(FastingCheckin record) {
    final feelingMap = {
      'good': {
        'label': '很好',
        'icon': LucideIcons.smile,
        'color': AppColors.success
      },
      'normal': {
        'label': '一般',
        'icon': LucideIcons.meh,
        'color': AppColors.warning
      },
      'tired': {
        'label': '疲惫',
        'icon': LucideIcons.frown,
        'color': AppColors.info
      },
      'uncomfortable': {
        'label': '不适',
        'icon': LucideIcons.alertCircle,
        'color': AppColors.error
      },
    };

    final feeling = feelingMap[record.feeling]!;
    final date = DateTime.tryParse(record.checkinDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (feeling['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feeling['icon'] as IconData,
                color: feeling['color'] as Color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${date!.month}月${date.day}日',
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            (feeling['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(feeling['label'] as String,
                          style: AppTextStyles.caption
                              .copyWith(color: feeling['color'] as Color)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (record.weight != null)
                  Text('体重: ${record.weight!.toStringAsFixed(1)}kg',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                if (record.notes != null)
                  Text(record.notes!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
