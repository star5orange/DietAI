import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 消费趋势折线图组件
///
/// [dailyData] 每日数据列表，每个 Map 至少包含:
///   - 'cost': double (当日消费金额)
///   - 其他字段由 [labelFunc] 和 [showCalories] 使用
/// [labelFunc] 从 Map 生成 X 轴标签的函数
/// [showCalories] 是否显示热量数据（默认 true）
/// [showCost] 是否显示消费数据（默认 true）
class CostTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyData;
  final String Function(Map<String, dynamic>) labelFunc;
  final bool showCalories;
  final bool showCost;

  const CostTrendChart({
    super.key,
    required this.dailyData,
    required this.labelFunc,
    this.showCalories = true,
    this.showCost = true,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text('暂无消费数据',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
        ),
      );
    }

    final maxCost =
        dailyData.map((e) => (e['cost'] as num?)?.toDouble() ?? 0.0).reduce(
              (a, b) => a > b ? a : b,
            );
    final chartMaxY = (maxCost * 1.2).ceilToDouble();

    final totalCost = dailyData.fold<double>(
        0.0, (sum, e) => sum + ((e['cost'] as num?)?.toDouble() ?? 0.0));
    final avgCost = dailyData.isNotEmpty ? totalCost / dailyData.length : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '总计: ¥${totalCost.toStringAsFixed(1)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '日均: ¥${avgCost.toStringAsFixed(1)}',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.divider.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        '¥${value.toInt()}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: dailyData.length <= 7 ? 1 : 5,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyData.length) {
                          return const Text('');
                        }
                        return Text(
                          labelFunc(dailyData[index]),
                          style: AppTextStyles.caption,
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (dailyData.length - 1).toDouble(),
                minY: 0,
                maxY: chartMaxY,
                lineBarsData: [
                  if (showCost)
                    LineChartBarData(
                      spots: dailyData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(),
                            (entry.value['cost'] as num?)?.toDouble() ?? 0.0);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: dailyData.length <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
