import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';

/// 复食指导页面
class FastingRefeedPage extends ConsumerStatefulWidget {
  final int planId;

  const FastingRefeedPage({super.key, this.planId = 0});

  @override
  ConsumerState<FastingRefeedPage> createState() => _FastingRefeedPageState();
}

class _FastingRefeedPageState extends ConsumerState<FastingRefeedPage> {
  int _currentPhase = 0;
  RefeedGuide? _guide;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    try {
      final service = ref.read(fastingServiceProvider);
      _guide = await service.getRefeedGuide(widget.planId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _phases {
    if (_guide?.phases.isNotEmpty == true) {
      return _guide!.phases
          .map((p) => {
                'name': p['description'] ?? '',
                'time': 'Day ${p['day']}',
                'desc': p['description'] ?? '',
                'tips': (p['foods'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [],
                'foods': (p['foods'] as List<dynamic>?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [],
              })
          .toList();
    }
    // 默认阶段（离线可用）
    return _defaultPhases;
  }

  static const _defaultPhases = <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final phases = _phases;
    if (phases.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('暂无非断食日，无需复食指导',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
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
            // 进度指示器
            _buildPhaseIndicator(),
            const SizedBox(height: 24),

            // 当前阶段详情
            ..._phases
                .asMap()
                .entries
                .map((entry) => _buildPhaseCard(entry.key, entry.value)),
            const SizedBox(height: 24),

            // 免责声明
            if (_guide?.disclaimer.isNotEmpty == true)
              _buildDisclaimerCard(_guide!.disclaimer),

            // 注意事项
            _buildWarningCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: _phases.asMap().entries.map((entry) {
          final isActive = entry.key <= _currentPhase;
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.divider,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isActive ? Colors.white : AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.value['name'],
                  style: AppTextStyles.caption.copyWith(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPhaseCard(int index, Map<String, dynamic> phase) {
    final isActive = index == _currentPhase;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : AppColors.divider.withValues(alpha: 0.3),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isActive,
        onExpansionChanged: (expanded) => setState(() => _currentPhase = index),
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.textTertiary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            LucideIcons.utensils,
            color: isActive ? Colors.white : AppColors.textTertiary,
            size: 20,
          ),
        ),
        title: Text(phase['name'],
            style:
                AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('${phase['time']} · ${phase['desc']}',
            style: AppTextStyles.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('注意事项',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...(phase['tips'] as List).map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.check,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(tip, style: AppTextStyles.bodySmall)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                Text('推荐食物',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (phase['foods'] as List)
                      .map((food) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(food,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.success)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
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
      title: Text('复食指导',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildDisclaimerCard(String disclaimer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertCircle, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              disclaimer,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.alertTriangle, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('重要提醒',
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600, color: AppColors.warning)),
                const SizedBox(height: 4),
                Text(
                  '复食期间请避免暴饮暴食，如有不适请及时就医。糖尿病患者需特别注意血糖变化。',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
