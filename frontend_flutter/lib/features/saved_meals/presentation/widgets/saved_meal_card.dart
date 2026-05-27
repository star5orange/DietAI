import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';

class SavedMealCard extends StatelessWidget {
  final SavedMeal meal;
  final VoidCallback? onTap;
  final Function(String action)? onAction;

  const SavedMealCard({
    super.key,
    required this.meal,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: AppColors.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部：图片和基本信息
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 菜品图片
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.backgroundSecondary,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: meal.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: meal.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.backgroundSecondary,
                                  child: Icon(
                                    LucideIcons.image,
                                    color: AppColors.textTertiary,
                                    size: 32,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.backgroundSecondary,
                                  child: Icon(
                                    LucideIcons.image,
                                    color: AppColors.textTertiary,
                                    size: 32,
                                  ),
                                ),
                              )
                            : Icon(
                                LucideIcons.utensils,
                                color: AppColors.textTertiary,
                                size: 32,
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // 菜品信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 菜品名称和公开状态
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
                              if (meal.isPublic)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '公开',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // 分类和标签
                          if (meal.category != null || (meal.tags?.isNotEmpty ?? false))
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
                                      color: AppColors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      meal.categoryDisplayName,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ...meal.tags?.take(2).map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        tag,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    )) ?? [],
                              ],
                            ),

                          const SizedBox(height: 8),

                          // 营养信息摘要
                          Text(
                            meal.nutritionSummary,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 操作按钮
                    PopupMenuButton<String>(
                      onSelected: (action) => onAction?.call(action),
                      icon: Icon(
                        LucideIcons.moreVertical,
                        color: AppColors.textTertiary,
                      ),
                      itemBuilder: (context) => [
                        if (meal.isPublic && meal.isFavorited != null)
                          PopupMenuItem(
                            value: 'favorite',
                            child: Row(
                              children: [
                                Icon(
                                  meal.isFavorited == true
                                      ? LucideIcons.heart
                                      : LucideIcons.heart,
                                  size: 16,
                                  color: meal.isFavorited == true
                                      ? Colors.red
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(meal.isFavorited == true ? '取消收藏' : '收藏'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'use',
                          child: Row(
                            children: [
                              Icon(LucideIcons.plus, size: 16),
                              SizedBox(width: 8),
                              Text('使用菜品'),
                            ],
                          ),
                        ),
                        if (!meal.isPublic) // 只有自己的菜品才能编辑删除
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(LucideIcons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('编辑'),
                              ],
                            ),
                          ),
                        if (!meal.isPublic) // 只有自己的菜品才能删除
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.trash2,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '删除',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // 描述信息
                if (meal.description != null && meal.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    meal.description!,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // 底部统计信息
                Row(
                  children: [
                    // 使用次数
                    Row(
                      children: [
                        Icon(
                          LucideIcons.repeat,
                          size: 16,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${meal.usageCount}次使用',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 16),

                    // 收藏次数（公开菜品）
                    if (meal.isPublic)
                      Row(
                        children: [
                          Icon(
                            LucideIcons.heart,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${meal.favoriteCount}人收藏',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),

                    const Spacer(),

                    // 创建时间
                    Text(
                      _formatDate(meal.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.year}/${date.month}/${date.day}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    } catch (e) {
      return dateString;
    }
  }
}