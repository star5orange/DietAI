import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

/// 月度饮食预算进度卡片
/// 展示当月消费进度、剩余预算、预算使用百分比
class BudgetProgressCard extends StatelessWidget {
  /// 当月已消费金额
  final double monthCost;

  /// 月度预算总额
  final double monthlyBudget;

  /// 点击卡片回调
  final VoidCallback? onTap;

  const BudgetProgressCard({
    super.key,
    required this.monthCost,
    required this.monthlyBudget,
    this.onTap,
  });

  /// 预算使用比例
  double get _usageRatio =>
      monthlyBudget > 0 ? (monthCost / monthlyBudget).clamp(0.0, 2.0) : 0;

  /// 剩余预算
  double get _remaining => (monthlyBudget - monthCost).clamp(0, double.infinity);

  /// 预算状态颜色
  Color get _statusColor {
    if (_usageRatio >= 1.0) return AppColors.error;
    if (_usageRatio >= 0.8) return AppColors.warning;
    return AppColors.success;
  }

  /// 预算状态文字
  String get _statusText {
    if (_usageRatio >= 1.0) return '已超支';
    if (_usageRatio >= 0.8) return '即将超支';
    return '预算充足';
  }

  @override
  Widget build(BuildContext context) {
    if (monthlyBudget <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.wallet,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('月度饮食预算', style: AppTextStyles.h6),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _usageRatio.clamp(0.0, 1.0),
                backgroundColor: AppColors.backgroundTertiary,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 12),

            // 金额信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountBlock('已消费', monthCost, AppColors.textPrimary),
                _buildAmountBlock('剩余', _remaining, _statusColor),
                _buildAmountBlock('预算', monthlyBudget, AppColors.textSecondary),
              ],
            ),

            // 超支警告
            if (_usageRatio >= 0.8)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.alertTriangle,
                          size: 16, color: _statusColor),
                      const SizedBox(width: 8),
                      Text(
                        _usageRatio >= 1.0
                            ? '已超出月度预算，建议控制饮食开销'
                            : '已使用预算的${(_usageRatio * 100).toInt()}%，注意控制',
                        style: TextStyle(
                            fontSize: 12, color: _statusColor),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountBlock(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          '¥${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.numberXSmall
                .copyWith(color: AppColors.textTertiary)),
      ],
    );
  }
}
