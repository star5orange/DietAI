import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

/// 当日热量环：已摄入 vs 目标，圆环中心显示剩余 / 超出。
///
/// 从旧首页的「今日热量」卡抽出（旧首页精简后融入历史页），
/// 首页与历史页各自传入自己的目标值与标题，环的呈现只保留这一份实现。
class DailyCalorieRing extends StatelessWidget {
  /// 当日已摄入热量（kcal）
  final double currentCalories;

  /// 当日目标热量（kcal）
  final double targetCalories;

  /// 标题，如「今日热量」「热量预算」
  final String title;

  /// 标题下的小字，如「每日目标 2000 kcal」
  final String caption;

  /// 点铅笔修改目标；传 null 则不显示编辑按钮
  /// （历史页不重复这个入口，改目标在健康页）
  final VoidCallback? onEditTarget;

  const DailyCalorieRing({
    super.key,
    required this.currentCalories,
    required this.targetCalories,
    required this.title,
    required this.caption,
    this.onEditTarget,
  });

  static const double _ringSize = 108;
  static const double _strokeWidth = 8;

  @override
  Widget build(BuildContext context) {
    final remaining = (targetCalories - currentCalories).round();
    final over = remaining < 0;
    final progress = targetCalories <= 0
        ? 0.0
        : (currentCalories / targetCalories).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h5),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const Spacer(),
            if (onEditTarget != null)
              IconButton(
                onPressed: onEditTarget,
                icon: const Icon(LucideIcons.edit2, size: 20),
                color: AppColors.textSecondary,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: _ringSize,
            height: _ringSize,
            child: Stack(
              children: [
                Container(
                  width: _ringSize,
                  height: _ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.borderLight, width: _strokeWidth),
                  ),
                ),
                SizedBox(
                  width: _ringSize,
                  height: _ringSize,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: _strokeWidth,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      over ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        over ? '${remaining.abs()}' : '$remaining',
                        style: AppTextStyles.numberMedium
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      Text(
                        over ? '超出 kcal' : '剩余 kcal',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: over
                              ? AppColors.warning
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}