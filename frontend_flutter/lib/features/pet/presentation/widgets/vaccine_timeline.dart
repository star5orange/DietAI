import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';

/// 疫苗记录时间线组件
class VaccineTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> vaccines;

  const VaccineTimeline({
    super.key,
    required this.vaccines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.syringe, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                '疫苗接种记录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 时间线
          for (int i = 0; i < vaccines.length; i++)
            _buildTimelineItem(vaccines[i], i, vaccines.length),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> vaccine, int index, int total) {
    final isLast = index == total - 1;
    final status = vaccine['status'] as String? ?? '正常';

    Color? statusColor;
    IconData? statusIcon;

    switch (status) {
      case '已过期':
        statusColor = AppColors.error;
        statusIcon = LucideIcons.xCircle;
      case '即将到期':
        statusColor = AppColors.warning;
        statusIcon = LucideIcons.alertCircle;
      default:
        statusColor = AppColors.success;
        statusIcon = LucideIcons.checkCircle;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间线指示器
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.borderLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 内容
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vaccine['name'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildInfoChip('接种日', vaccine['date'] as String? ?? '-'),
                      const SizedBox(width: 12),
                      _buildInfoChip('下次', vaccine['next_date'] as String? ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}