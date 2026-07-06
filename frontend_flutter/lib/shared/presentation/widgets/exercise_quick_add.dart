import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

/// 首页运动快捷入口组件
class ExerciseQuickAdd extends StatelessWidget {
  final VoidCallback? onTap;
  final double? todayCalories;
  final int? todayDuration;

  const ExerciseQuickAdd({
    super.key,
    this.onTap,
    this.todayCalories,
    this.todayDuration,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = todayCalories != null && todayCalories! > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: hasData
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (hasData
                      ? const Color(0xFFFF6B6B)
                      : AppColors.primary)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.dumbbell,
                    color: AppColors.textInverse, size: 20),
                const SizedBox(width: 8),
                Text(
                  '运动记录',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textInverse,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasData ? LucideIcons.flame : LucideIcons.footprints,
                    color: AppColors.whiteWithOpacity(0.7),
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  if (hasData) ...[
                    Text(
                      '${todayCalories!.toInt()} kcal / ${todayDuration ?? 0}分钟',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.whiteWithOpacity(0.9),
                      ),
                    ),
                  ] else ...[
                    Text('记录你的运动',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.whiteWithOpacity(0.7))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.whiteWithOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.whiteWithOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.plus,
                      color: AppColors.textInverse, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    hasData ? '继续记录' : '记录运动',
                    style: const TextStyle(
                        color: AppColors.textInverse,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
