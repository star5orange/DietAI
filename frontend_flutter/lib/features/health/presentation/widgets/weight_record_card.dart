import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/weight_record_model.dart';

class WeightRecordCard extends StatelessWidget {
  final WeightRecord record;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const WeightRecordCard({
    super.key,
    required this.record,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardBackground, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部 - 时间和操作菜单
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.scale,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.formattedDate,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.notes != null && record.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.notes!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  LucideIcons.moreVertical,
                  color: AppColors.textSecondary,
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(LucideIcons.edit2, size: 16),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit?.call();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 主要数据展示
          Row(
            children: [
              // 体重
              Expanded(
                child: _buildMetricCard(
                  '体重',
                  record.formattedWeight,
                  LucideIcons.scale,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              // BMI
              Expanded(
                child: _buildMetricCard(
                  'BMI',
                  record.formattedBmi,
                  LucideIcons.activity,
                  _getBmiColor(record.bmi),
                ),
              ),
            ],
          ),
          
          // 可选数据
          if (record.bodyFatPercentage != null || record.muscleMass != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (record.bodyFatPercentage != null)
                  Expanded(
                    child: _buildMetricCard(
                      '体脂率',
                      record.formattedBodyFat,
                      LucideIcons.droplet,
                      AppColors.warning,
                    ),
                  ),
                if (record.bodyFatPercentage != null && record.muscleMass != null)
                  const SizedBox(width: 12),
                if (record.muscleMass != null)
                  Expanded(
                    child: _buildMetricCard(
                      '肌肉量',
                      record.formattedMuscleMass,
                      LucideIcons.zap,
                      AppColors.success,
                    ),
                  ),
              ],
            ),
          ],
          
          // BMI 分类标签
          if (record.bmi != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getBmiColor(record.bmi).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'BMI分类: ${record.bmiCategory}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: _getBmiColor(record.bmi),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBmiColor(double? bmi) {
    if (bmi == null) return AppColors.textSecondary;
    
    if (bmi < 18.5) return AppColors.info;     // 偏瘦 - 蓝色
    if (bmi < 24) return AppColors.success;    // 正常 - 绿色
    if (bmi < 28) return AppColors.warning;    // 超重 - 橙色
    return AppColors.error;                    // 肥胖 - 红色
  }
}