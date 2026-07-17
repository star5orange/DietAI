import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';

/// 轻断食每日打卡页面
class FastingCheckinPage extends ConsumerStatefulWidget {
  final int planId;

  const FastingCheckinPage({super.key, this.planId = 0});

  @override
  ConsumerState<FastingCheckinPage> createState() => _FastingCheckinPageState();
}

class _FastingCheckinPageState extends ConsumerState<FastingCheckinPage> {
  String _feeling = 'good';
  String? _notes;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _feelingOptions = [
    {
      'id': 'good',
      'label': '很好',
      'icon': LucideIcons.smile,
      'color': AppColors.success
    },
    {
      'id': 'normal',
      'label': '一般',
      'icon': LucideIcons.meh,
      'color': AppColors.warning
    },
    {
      'id': 'tired',
      'label': '疲惫',
      'icon': LucideIcons.frown,
      'color': AppColors.info
    },
    {
      'id': 'uncomfortable',
      'label': '不适',
      'icon': LucideIcons.alertCircle,
      'color': AppColors.error
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('今日打卡',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 进度卡片
            _buildProgressCard(),
            const SizedBox(height: 24),

            // 断食时长
            _buildFastingTimer(),
            const SizedBox(height: 24),

            // 今日感受
            Text('今日感受', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _feelingOptions
                  .map((option) => _buildFeelingOption(option))
                  .toList(),
            ),
            const SizedBox(height: 24),

            // 备注
            Text('备注（可选）', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '记录今天的感受...',
                filled: true,
                fillColor: AppColors.backgroundCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => _notes = v,
            ),
            const SizedBox(height: 32),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('完成打卡'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.flame, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('连续打卡',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white.withValues(alpha: 0.8))),
                Text('第 5 天',
                    style: AppTextStyles.h4.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('16:8',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingTimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeBlock('14', '时'),
              const SizedBox(width: 8),
              _buildTimeBlock('32', '分'),
              const SizedBox(width: 8),
              _buildTimeBlock('15', '秒'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimerStat('目标', '16小时'),
              Container(width: 1, height: 24, color: AppColors.divider),
              _buildTimerStat('剩余', '1小时28分'),
              Container(width: 1, height: 24, color: AppColors.divider),
              _buildTimerStat('进度', '90%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlock(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.h3.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
          Text(unit,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTimerStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style:
                AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildFeelingOption(Map<String, dynamic> option) {
    final isSelected = _feeling == option['id'];
    return GestureDetector(
      onTap: () => setState(() => _feeling = option['id']),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (option['color'] as Color).withValues(alpha: 0.15)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? option['color'] as Color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(option['icon'] as IconData,
                color: option['color'] as Color, size: 28),
            const SizedBox(height: 8),
            Text(option['label'],
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? option['color'] : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCheckin() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(fastingServiceProvider);
      await service.createCheckin(
        planId: widget.planId,
        checkinDate: DateTime.now().toIso8601String().split('T')[0],
        feeling: _feeling,
        completed: true,
        notes: _notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打卡成功！')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
