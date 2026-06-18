import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

/// 提醒通知卡片组件
class ReminderNotificationCard extends StatelessWidget {
  final String title;
  final String description;
  final String reminderType; // 'water' | 'meal'
  final String? timeText;
  final bool isEnabled;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  const ReminderNotificationCard({
    super.key,
    required this.title,
    required this.description,
    required this.reminderType,
    this.timeText,
    this.isEnabled = true,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWater = reminderType == 'water';
    final accentColor = isWater ? AppColors.info : AppColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? accentColor.withValues(alpha: 0.3)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isWater ? LucideIcons.droplets : LucideIcons.utensils,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeText!,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onToggle != null)
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                  activeColor: accentColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
