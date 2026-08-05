import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/exam_provider.dart';
import '../../domain/exam_models.dart';

/// 体检指标趋势页面
class ExamTrendPage extends ConsumerStatefulWidget {
  final int userId;
  final String metricName;

  const ExamTrendPage({
    super.key,
    required this.userId,
    required this.metricName,
  });

  @override
  ConsumerState<ExamTrendPage> createState() => _ExamTrendPageState();
}

class _ExamTrendPageState extends ConsumerState<ExamTrendPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(metricTrendProvider.notifier)
          .loadTrend(widget.userId, widget.metricName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metricTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.metricName} 趋势'),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(MetricTrendState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(state.error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(metricTrendProvider.notifier)
                    .loadTrend(widget.userId, widget.metricName);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final trend = state.trend;
    if (trend == null || trend.trend.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无该指标的历史数据', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final points = trend.trend;
    // 计算 y 范围（含参考区间）
    var minValue = points.map((p) => p.metricValue).reduce(math.min);
    var maxValue = points.map((p) => p.metricValue).reduce(math.max);
    if (trend.referenceMin != null) minValue = math.min(minValue, trend.referenceMin!);
    if (trend.referenceMax != null) maxValue = math.max(maxValue, trend.referenceMax!);
    final padding = (maxValue - minValue).abs() * 0.15 + 1.0;
    minValue -= padding;
    maxValue += padding;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 趋势摘要
          if (trend.changeSummary != null)
            _buildSummaryCard(trend),
          const SizedBox(height: 16),
          // 折线图
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.metricName} (${trend.unit ?? ''})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrendChartPainter(
                        points: points,
                        referenceMin: trend.referenceMin,
                        referenceMax: trend.referenceMax,
                        minValue: minValue,
                        maxValue: maxValue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 图例
                  Wrap(
                    spacing: 12,
                    children: [
                      _buildLegend(Colors.blue, '测量值'),
                      if (trend.referenceMin != null &&
                          trend.referenceMax != null)
                        _buildLegend(Colors.orange, '参考范围'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 数据点列表
                  ...points.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              '${p.examDate.year}-${p.examDate.month.toString().padLeft(2, '0')}-${p.examDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600]),
                            ),
                            const Spacer(),
                            Text(
                              '${p.metricValue.toStringAsFixed(2)} ${p.unit ?? ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(MetricTrendResponse trend) {
    final isUp = trend.trendDirection == 'up';
    final isDown = trend.trendDirection == 'down';
    final color = isUp ? Colors.orange : (isDown ? Colors.blue : Colors.green);
    final icon = isUp ? Icons.trending_up : (isDown ? Icons.trending_down : Icons.trending_flat);
    final label = isUp ? '呈上升趋势' : (isDown ? '呈下降趋势' : '保持平稳');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$label · ${trend.changeSummary}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// 趋势折线图绘制器
class _TrendChartPainter extends CustomPainter {
  final List<MetricTrendPoint> points;
  final double? referenceMin;
  final double? referenceMax;
  final double minValue;
  final double maxValue;

  _TrendChartPainter({
    required this.points,
    this.referenceMin,
    this.referenceMax,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final left = 36.0;
    final right = size.width - 12;
    final top = 12.0;
    final bottom = size.height - 24;

    final range = maxValue - minValue;
    if (range <= 0) return;

    double xFor(int index) =>
        left + (right - left) * (points.length == 1 ? 0.5 : index / (points.length - 1));
    double yFor(double value) =>
        bottom - (value - minValue) / range * (bottom - top);

    // 背景网格线（横向刻度）
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    final labelStyle = TextStyle(fontSize: 10, color: Colors.grey[600]);
    const gridCount = 4;
    for (var i = 0; i <= gridCount; i++) {
      final y = top + (bottom - top) * i / gridCount;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      final value = maxValue - (maxValue - minValue) * i / gridCount;
      final tp = TextPainter(
        text: TextSpan(text: value.toStringAsFixed(1), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
    }

    // 参考范围带
    if (referenceMin != null && referenceMax != null) {
      final refTop = yFor(referenceMax!);
      final refBottom = yFor(referenceMin!);
      final refPaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.12);
      canvas.drawRect(
        Rect.fromLTRB(left, refTop, right, refBottom),
        refPaint,
      );
      final refLinePaint = Paint()
        ..color = Colors.orange.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(left, refTop), Offset(right, refTop), refLinePaint);
      canvas.drawLine(
          Offset(left, refBottom), Offset(right, refBottom), refLinePaint);
    }

    // 折线
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (points.length == 1) {
      final center = Offset(xFor(0), yFor(points[0].metricValue));
      canvas.drawCircle(center, 4, linePaint);
    } else {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final x = xFor(i);
        final y = yFor(points[i].metricValue);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // 数据点
    final dotPaint = Paint()..color = Colors.white;
    final dotBorderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < points.length; i++) {
      final center = Offset(xFor(i), yFor(points[i].metricValue));
      canvas.drawCircle(center, 5, dotPaint);
      canvas.drawCircle(center, 5, dotBorderPaint);
    }

    // 底部日期标签（首尾）
    final firstDate = points.first.examDate;
    final lastDate = points.last.examDate;
    String fmt(DateTime d) =>
        '${d.month}/${d.day}';
    final fp = TextPainter(
      text: TextSpan(text: fmt(firstDate), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    fp.paint(canvas, Offset(left, bottom + 6));
    final lp = TextPainter(
      text: TextSpan(text: fmt(lastDate), style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(right - lp.width, bottom + 6));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.referenceMin != referenceMin ||
        oldDelegate.referenceMax != referenceMax ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
