import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/weight_record_model.dart';

class WeightStatsCard extends ConsumerWidget {
  final AsyncValue<WeightRecord?> latestRecordAsync;
  final AsyncValue<WeightTrend?> trendAsync;

  const WeightStatsCard({
    super.key,
    required this.latestRecordAsync,
    required this.trendAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标题
          const Row(
            children: [
              Icon(
                LucideIcons.scale,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                '体重概况',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 最新体重数据
          latestRecordAsync.when(
            data: (record) {
              if (record == null) {
                return _buildEmptyState();
              }
              return _buildWeightData(record);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            error: (error, _) => _buildErrorState(),
          ),

          const SizedBox(height: 16),

          // 趋势数据
          trendAsync.when(
            data: (trend) {
              if (trend == null) {
                return const SizedBox.shrink();
              }
              return _buildTrendData(trend);
            },
            loading: () => const SizedBox.shrink(),
            error: (error, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightData(WeightRecord record) {
    return Column(
      children: [
        // 当前体重
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '当前体重',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.formattedWeight,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.formattedDate,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // BMI 信息
            if (record.bmi != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'BMI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.formattedBmi,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.bmiCategory,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // 其他数据（如果有）
        if (record.bodyFatPercentage != null || record.muscleMass != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              if (record.bodyFatPercentage != null)
                Expanded(
                  child: _buildMetricItem(
                    '体脂率',
                    record.formattedBodyFat,
                    LucideIcons.droplet,
                  ),
                ),
              if (record.bodyFatPercentage != null && record.muscleMass != null)
                const SizedBox(width: 12),
              if (record.muscleMass != null)
                Expanded(
                  child: _buildMetricItem(
                    '肌肉量',
                    record.formattedMuscleMass,
                    LucideIcons.zap,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrendData(WeightTrend trend) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            trend.trendIcon,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trend.trendText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            trend.formattedChange,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Column(
      children: [
        Icon(
          LucideIcons.scale,
          color: Colors.white70,
          size: 48,
        ),
        SizedBox(height: 12),
        Text(
          '还没有体重记录',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '点击下方按钮开始记录',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return const Column(
      children: [
        Icon(
          LucideIcons.alertCircle,
          color: Colors.white70,
          size: 48,
        ),
        SizedBox(height: 12),
        Text(
          '加载数据失败',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '请检查网络连接后重试',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}