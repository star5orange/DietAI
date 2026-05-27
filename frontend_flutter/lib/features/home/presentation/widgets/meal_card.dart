import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';

class MealData {
  final int id;
  final String name;
  final IconData icon;
  final Color iconColor;
  final int calories;

  const MealData({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.calories,
  });
}

class MealCard extends StatelessWidget {
  final MealData meal;
  final VoidCallback onRecord;

  const MealCard({
    super.key,
    required this.meal,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 餐次图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: meal.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              meal.icon,
              color: meal.iconColor,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // 餐次信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.name,
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meal.calories > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${meal.calories} 卡路里',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 记录按钮
          AppButton.primary(
            text: '记录',
            icon: LucideIcons.plus,
            size: AppButtonSize.small,
            onPressed: onRecord,
          ),
        ],
      ),
    );
  }
} 