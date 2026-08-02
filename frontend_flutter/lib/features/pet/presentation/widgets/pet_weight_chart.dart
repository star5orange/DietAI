import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

/// 宠物体重趋势图组件
/// 使用 fl_chart 绘制折线图
/// records 应为按时间升序排列（最早→最新），组件会自动反转降序数据
class PetWeightChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final double? idealWeightMin;
  final double? idealWeightMax;

  const PetWeightChart({
    super.key,
    required this.records,
    this.idealWeightMin,
    this.idealWeightMax,
  });

  /// 获取按时间升序排列的记录（最早→最新），确保趋势图左→右为旧→新
  List<Map<String, dynamic>> get _sortedRecords {
    final list = List<Map<String, dynamic>>.from(records);
    // 后端返回降序（最新在前），反转为升序
    return list.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedRecords;
    if (sorted.isEmpty) {
      return _buildEmptyState();
    }

    // 解析数据
    final spots = _parseRecordsToSpots(sorted);
    if (spots.isEmpty) {
      return _buildEmptyState();
    }

    // 计算Y轴范围
    final weights =
        sorted.map((r) => (r['weight'] as num?)?.toDouble() ?? 0).toList();
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final yMin = (minWeight - 0.5).floorToDouble();
    final yMax = (maxWeight + 0.5).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 0.5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.borderLight,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 0.5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toStringAsFixed(1)}kg',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sorted.length) {
                    return const SizedBox();
                  }
                  final date = sorted[index]['measured_at'] as String? ?? '';
                  final day = date.length >= 10 ? date.substring(8, 10) : date;
                  return Text(
                    day,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (sorted.length - 1).toDouble(),
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            // 主数据线
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          // 理想体重范围区域
          extraLinesData: ExtraLinesData(
            extraLinesOnTop: false,
            horizontalLines: [
              if (idealWeightMin != null)
                HorizontalLine(
                  y: idealWeightMin!,
                  color: AppColors.success.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 8),
                    labelResolver: (line) => '理想范围',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.success,
                    ),
                  ),
                ),
              if (idealWeightMax != null)
                HorizontalLine(
                  y: idealWeightMax!,
                  color: AppColors.success.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _parseRecordsToSpots(List<Map<String, dynamic>> sorted) {
    return sorted.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final weight = (entry.value['weight'] as num?)?.toDouble() ?? 0;
      return FlSpot(index, weight);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无体重记录',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
