import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';

class SavedMealCard extends StatelessWidget {
  final SavedMeal meal;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onUse;

  const SavedMealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 菜品图片
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      image: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(meal.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: meal.imageUrl == null || meal.imageUrl!.isEmpty
                        ? Icon(
                            LucideIcons.utensils,
                            color: AppColors.primary.withValues(alpha: 0.4),
                            size: 32,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 菜品名称
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meal.mealName,
                                style: AppTextStyles.h6.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 分类和标签
                        if (meal.category != null ||
                            (meal.tags?.isNotEmpty ?? false))
                          Wrap(
                            spacing: 8,
                            children: [
                              if (meal.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    meal.categoryDisplayName,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ...?meal.tags?.map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        // 营养摘要
                        Text(
                          meal.nutritionSummary,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 底部操作栏
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.borderLight,
                    width: 0.5,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 来源标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: meal.source == 'record'
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      meal.source == 'record' ? '来自拍照收藏' : '手动创建',
                      style: AppTextStyles.caption.copyWith(
                        color: meal.source == 'record'
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  // 右侧操作按钮
                  Row(
                    children: [
                      // 使用按钮
                      if (onUse != null)
                        TextButton.icon(
                          onPressed: onUse,
                          icon: Icon(LucideIcons.plus, size: 16),
                          label: Text('使用'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),

                      // 编辑按钮
                      if (onEdit != null)
                        IconButton(
                          onPressed: onEdit,
                          icon: Icon(LucideIcons.pencil, size: 18),
                          color: AppColors.textSecondary,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),

                      // 删除按钮
                      if (onDelete != null)
                        IconButton(
                          onPressed: onDelete,
                          icon: Icon(LucideIcons.trash2, size: 18),
                          color: AppColors.error,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                    ],
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
