import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// AI 顾问风格选择器组件
///
/// [selectedStyle] 当前选中的风格 ID
/// [styles] 风格列表，每个 Map 包含 'id', 'name', 'icon', 'desc' 字段
/// [onChanged] 选中风格变化时的回调
class AdvisorStyleSelector extends StatelessWidget {
  final String selectedStyle;
  final List<Map<String, dynamic>> styles;
  final ValueChanged<String> onChanged;

  const AdvisorStyleSelector({
    super.key,
    required this.selectedStyle,
    required this.styles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: styles.map((style) => _buildStyleCard(style)).toList(),
    );
  }

  Widget _buildStyleCard(Map<String, dynamic> style) {
    final isSelected = selectedStyle == style['id'];
    return GestureDetector(
      onTap: () => onChanged(style['id'] as String),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.divider.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isSelected ? AppColors.primary : AppColors.textTertiary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                style['icon'] as IconData,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style['name'] as String,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    style['desc'] as String,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(LucideIcons.check, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
