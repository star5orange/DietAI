import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/weight_records_provider.dart';

class WeightChart extends ConsumerWidget {
  final int days;

  const WeightChart({
    super.key,
    required this.days,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recentWeightRecordsProvider);

    return recordsAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const Center(
            child: Text(
              '暂无数据\n开始记录体重以查看趋势图',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        // 过滤指定天数内的数据
        final now = DateTime.now();
        final cutoffDate = now.subtract(Duration(days: days));
        final filteredRecords = records.where((record) {
          try {
            final recordDate = DateTime.parse(record.measuredAt);
            return recordDate.isAfter(cutoffDate);
          } catch (e) {
            return false;
          }
        }).toList();

        if (filteredRecords.isEmpty) {
          return const Center(
            child: Text(
              '该时间段内暂无数据',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        // 按时间排序（从早到晚）
        filteredRecords.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));

        // 创建图表数据点
        final spots = <FlSpot>[];
        double minWeight = double.infinity;
        double maxWeight = double.negativeInfinity;

        for (int i = 0; i < filteredRecords.length; i++) {
          final weight = filteredRecords[i].weight;
          spots.add(FlSpot(i.toDouble(), weight));
          
          if (weight < minWeight) minWeight = weight;
          if (weight > maxWeight) maxWeight = weight;
        }

        // 计算合适的Y轴范围
        final weightRange = maxWeight - minWeight;
        final padding = weightRange * 0.1; // 10%的padding
        final yMin = (minWeight - padding).clamp(0.0, double.infinity).toDouble();
        final yMax = (maxWeight + padding).toDouble();

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (yMax - yMin) / 4,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: AppColors.divider.withValues(alpha: 0.3),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: (yMax - yMin) / 4,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (filteredRecords.length / 4).clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < filteredRecords.length) {
                      try {
                        final date = DateTime.parse(filteredRecords[index].measuredAt);
                        return Text(
                          '${date.month}/${date.day}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      } catch (e) {
                        return const Text('');
                      }
                    }
                    return const Text('');
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: false,
            ),
            minX: 0,
            maxX: (filteredRecords.length - 1).toDouble(),
            minY: yMin,
            maxY: yMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
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
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: AppColors.cardBackground,
                tooltipRoundedRadius: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (index >= 0 && index < filteredRecords.length) {
                      final record = filteredRecords[index];
                      try {
                        final date = DateTime.parse(record.measuredAt);
                        return LineTooltipItem(
                          '${date.month}/${date.day}\n${spot.y.toStringAsFixed(1)}kg',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      } catch (e) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)}kg',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }
                    }
                    return null;
                  }).toList();
                },
              ),
              handleBuiltInTouches: true,
            ),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Text(
          '加载图表失败: $error',
          style: const TextStyle(
            color: AppColors.error,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}