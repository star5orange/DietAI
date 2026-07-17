import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 预算进度卡片组件
///
/// [budget] 月度预算总额
/// [used] 已使用金额
/// [remaining] 剩余金额
/// [isDarkMode] 是否深色模式
/// [onTap] 点击回调（可选）
class BudgetProgressCard extends StatelessWidget {
  final double budget;
  final double used;
  final double remaining;
  final bool isDarkMode;
  final VoidCallback? onTap;

  const BudgetProgressCard({
    super.key,
    required this.budget,
    required this.used,
    required this.remaining,
    this.isDarkMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = budget > 0 ? used / budget : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.lightShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.wallet,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('月度预算', style: AppTextStyles.h6),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBudgetItem('预算', '¥${budget.toStringAsFixed(0)}',
                    AppColors.textSecondary),
                _buildBudgetItem(
                    '已用', '¥${used.toStringAsFixed(1)}', AppColors.primary),
                _buildBudgetItem(
                    '剩余',
                    '¥${remaining.toStringAsFixed(1)}',
                    remaining >= 0 ? AppColors.success : AppColors.error),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.5),
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percent > 1.0
                      ? AppColors.error
                      : (percent > 0.8 ? AppColors.warning : AppColors.success),
                ),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已使用 ${(percent * 100).toStringAsFixed(0)}%',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: AppTextStyles.h6
                .copyWith(color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}
