import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';

/// 断食进度追踪页
/// 展示计划完成进度、体重变化趋势、打卡统计
class FastingProgressPage extends ConsumerStatefulWidget {
  final int planId;

  const FastingProgressPage({super.key, this.planId = 0});

  @override
  ConsumerState<FastingProgressPage> createState() =>
      _FastingProgressPageState();
}

class _FastingProgressPageState extends ConsumerState<FastingProgressPage> {
  FastingProgress? _progress;
  FastingPlan? _plan;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(fastingServiceProvider);
      final results = await Future.wait([
        service.getProgress(widget.planId),
        service.getPlans(),
      ]);
      final progress = results[0] as FastingProgress;
      final plans = results[1] as List<FastingPlan>;
      if (mounted) {
        setState(() {
          _progress = progress;
          _plan = plans.cast<FastingPlan?>().firstWhere(
                (p) => p!.planId == widget.planId,
                orElse: () => null,
              );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载进度失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 计算日均体重变化
  double? get _dailyAvgChange {
    final p = _progress;
    final chart = p?.chart;
    if (chart == null || chart.length < 2) return null;

    final firstW = chart.first['weight'];
    final lastW = chart.last['weight'];
    if (firstW == null || lastW == null) return null;

    final days = chart.length;
    return ((lastW as num).toDouble() - (firstW as num).toDouble()) / days;
  }

  // 计算距目标体重的差距
  double? get _weightToGoal {
    if (_plan?.targetWeight == null || _progress?.weightCurrent == null) {
      return null;
    }
    return _progress!.weightCurrent! - _plan!.targetWeight!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('进度追踪',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMessage != null && _progress == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    final p = _progress!;
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressOverview(p),
            const SizedBox(height: 20),
            _buildWeightChart(p),
            const SizedBox(height: 20),
            _buildStatsGrid(p),
          ],
        ),
      ),
    );
  }

  // ==================== 进度概览卡片 ====================
  Widget _buildProgressOverview(FastingProgress p) {
    final rate = p.completionRate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.timer, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Text('计划进度',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${rate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${p.daysElapsed}',
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('/ ${p.daysTotal} 天',
                    style:
                        const TextStyle(fontSize: 16, color: Colors.white70)),
              ),
              const Spacer(),
              if (p.weightChange != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.weightChange! < 0
                          ? '↓ ${p.weightChange!.abs().toStringAsFixed(1)}'
                          : '↑ ${p.weightChange!.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const Text('kg 体重变化',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 体重变化图表 ====================
  Widget _buildWeightChart(FastingProgress p) {
    final chartData = p.chart;
    // 过滤出有效的体重数据点
    final points = <Map<String, dynamic>>[];
    for (final c in chartData) {
      if (c['weight'] != null && (c['weight'] as num).toDouble() > 0) {
        points.add(c);
      }
    }

    if (points.isEmpty) {
      return _buildEmptyCard(
        '体重变化',
        LucideIcons.scale,
        '暂无体重数据，打卡时记录体重后将在此展示变化趋势',
      );
    }

    final weights = points.map((c) => (c['weight'] as num).toDouble()).toList();
    final targetW = _plan?.targetWeight;
    final allValues = [...weights, if (targetW != null) targetW];
    final minW = allValues.reduce((a, b) => a < b ? a : b);
    final maxW = allValues.reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(0.5, double.infinity).toDouble();
    final minY = (minW - range * 0.2).clamp(0, double.infinity).toDouble();
    final maxY = maxW + range * 0.2;

    final weightChange = p.weightChange;
    final dailyAvg = _dailyAvgChange;
    final toGoal = _weightToGoal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('体重变化趋势', LucideIcons.scale),
              const Spacer(),
              if (weightChange != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: weightChange < 0
                        ? AppColors.success.withValues(alpha: 0.1)
                        : (weightChange > 0
                            ? AppColors.warning.withValues(alpha: 0.1)
                            : AppColors.textTertiary.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    weightChange < 0
                        ? '↓ ${weightChange.abs().toStringAsFixed(1)} kg'
                        : weightChange > 0
                            ? '↑ ${weightChange.toStringAsFixed(1)} kg'
                            : '持平',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: weightChange < 0
                          ? AppColors.success
                          : (weightChange > 0
                              ? AppColors.warning
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  // 体重曲线
                  LineChartBarData(
                    spots: points.asMap().entries.map((e) {
                      return FlSpot(
                          e.key.toDouble(), e.value['weight'] as double);
                    }).toList(),
                    isCurved: true,
                    color: const Color(0xFF43E97B),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final isFirst = index == 0;
                        final isLast = index == weights.length - 1;
                        return FlDotCirclePainter(
                          radius: isFirst || isLast ? 4.5 : 3,
                          color: isFirst || isLast
                              ? const Color(0xFF43E97B)
                              : AppColors.backgroundCard,
                          strokeWidth: 2,
                          strokeColor: const Color(0xFF43E97B),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF43E97B).withValues(alpha: 0.08),
                    ),
                  ),
                  // 目标体重虚线
                  if (targetW != null)
                    LineChartBarData(
                      spots: [
                        FlSpot(0, targetW),
                        FlSpot((points.length - 1).toDouble(), targetW),
                      ],
                      isCurved: false,
                      color: AppColors.warning.withValues(alpha: 0.6),
                      barWidth: 1.5,
                      dashArray: [6, 4],
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                ],
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      interval: range > 2 ? 1 : 0.5,
                      getTitlesWidget: (value, meta) {
                        // Show target weight marker
                        final isTarget =
                            targetW != null && (value - targetW).abs() < 0.05;
                        return Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 10,
                            color: isTarget
                                ? AppColors.warning
                                : AppColors.textTertiary,
                            fontWeight:
                                isTarget ? FontWeight.w600 : FontWeight.w400,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: points.length > 7
                          ? (points.length / 6).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final date =
                            DateTime.tryParse(points[idx]['date'] ?? '');
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            date != null
                                ? DateFormat('MM/dd').format(date)
                                : '',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    final isTarget =
                        targetW != null && (value - targetW).abs() < 0.05;
                    return FlLine(
                      color: isTarget
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : AppColors.borderLight,
                      strokeWidth: isTarget ? 1.5 : 1,
                      dashArray: isTarget ? [4, 4] : null,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.spotIndex;
                        final date = idx < points.length
                            ? DateTime.tryParse(points[idx]['date'] ?? '')
                            : null;
                        return LineTooltipItem(
                          '${date != null ? DateFormat('M/d').format(date) : ''}\n${spot.y.toStringAsFixed(1)} kg',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 图表图例和统计摘要
          Row(
            children: [
              _buildLegendDot(const Color(0xFF43E97B)),
              const SizedBox(width: 6),
              Text('实测体重',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              if (targetW != null) ...[
                const SizedBox(width: 16),
                _buildLegendDot(AppColors.warning, dashed: true),
                const SizedBox(width: 6),
                Text('目标 ${targetW.toStringAsFixed(1)} kg',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
              const Spacer(),
              Text(
                '${points.first['weight']} → ${points.last['weight']} kg',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          // 日均变化和距离目标
          if (dailyAvg != null || toGoal != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (dailyAvg != null) ...[
                  const Icon(LucideIcons.trendingDown,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '日均 ${dailyAvg.abs().toStringAsFixed(2)} kg/${dailyAvg < 0 ? '↓' : '↑'}',
                    style: AppTextStyles.caption.copyWith(
                      color:
                          dailyAvg < 0 ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
                const Spacer(),
                if (toGoal != null)
                  Text(
                    toGoal > 0
                        ? '距目标还差 ${toGoal.toStringAsFixed(1)} kg'
                        : '已达成目标体重！',
                    style: AppTextStyles.caption.copyWith(
                      color: toGoal > 0
                          ? AppColors.textTertiary
                          : AppColors.success,
                      fontWeight:
                          toGoal <= 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, IconData icon, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          _sectionHeader(title, icon),
          const SizedBox(height: 32),
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, {bool dashed = false}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: dashed ? null : color,
        border: dashed ? Border.all(color: color, width: 1.5) : null,
        shape: BoxShape.circle,
      ),
    );
  }

  // ==================== 统计指标网格 ====================
  Widget _buildStatsGrid(FastingProgress p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('数据统计', LucideIcons.barChart3),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard('连续打卡', '${p.streakDays} 天',
                    LucideIcons.flame, AppColors.caloriesColor)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    '打卡率',
                    '${p.completionRate.toStringAsFixed(0)}%',
                    LucideIcons.checkCircle2,
                    AppColors.success)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    '起始体重',
                    p.weightStart != null
                        ? '${p.weightStart!.toStringAsFixed(1)} kg'
                        : '--',
                    LucideIcons.trendingUp,
                    AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    '当前体重',
                    p.weightCurrent != null
                        ? '${p.weightCurrent!.toStringAsFixed(1)} kg'
                        : '--',
                    LucideIcons.trendingDown,
                    AppColors.warning)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    '体重变化',
                    p.weightChange != null
                        ? '${p.weightChange!.toStringAsFixed(1)} kg'
                        : '--',
                    LucideIcons.scale,
                    (p.weightChange ?? 0) < 0
                        ? AppColors.success
                        : AppColors.warning)),
            const SizedBox(width: 12),
            Expanded(child: _buildFeelingCard(p.feelingAvg)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: AppTextStyles.numberXSmall.copyWith(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildFeelingCard(String feeling) {
    final feelingInfo = _getFeelingInfo(feeling);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: feelingInfo['color'].withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(feelingInfo['icon'] as IconData,
                color: feelingInfo['color'], size: 18),
          ),
          const SizedBox(height: 12),
          Text(feelingInfo['label'] as String,
              style: AppTextStyles.numberXSmall.copyWith(
                  color: feelingInfo['color'] as Color,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('主要体感',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Map<String, dynamic> _getFeelingInfo(String feeling) {
    switch (feeling) {
      case 'good':
        return {
          'icon': LucideIcons.smile,
          'label': '良好',
          'color': AppColors.success,
        };
      case 'normal':
        return {
          'icon': LucideIcons.meh,
          'label': '正常',
          'color': AppColors.primary,
        };
      case 'tired':
        return {
          'icon': LucideIcons.frown,
          'label': '疲劳',
          'color': AppColors.warning,
        };
      case 'uncomfortable':
        return {
          'icon': LucideIcons.alertCircle,
          'label': '不适',
          'color': AppColors.error,
        };
      default:
        return {
          'icon': LucideIcons.meh,
          'label': feeling,
          'color': AppColors.textSecondary,
        };
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
