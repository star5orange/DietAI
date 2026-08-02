import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../services/goal_tracking_service.dart';
import '../widgets/weight_chart.dart';

class GoalProgressDetailPage extends ConsumerStatefulWidget {
  final int? goalId;
  final String goalTypeText;
  final double? targetWeight;

  const GoalProgressDetailPage({
    super.key,
    this.goalId,
    required this.goalTypeText,
    this.targetWeight,
  });

  @override
  ConsumerState<GoalProgressDetailPage> createState() =>
      _GoalProgressDetailPageState();
}

class _GoalProgressDetailPageState
    extends ConsumerState<GoalProgressDetailPage> {
  final GoalTrackingService _trackingService = GoalTrackingService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _progressData;
  Map<String, dynamic>? _dailyStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _trackingService.getProgress(),
        _trackingService.getDailyStatus(),
      ]);

      final progressResult = results[0] as ApiResponse<Map<String, dynamic>>;
      final dailyResult = results[1] as ApiResponse<Map<String, dynamic>>;

      if (!mounted) return;

      if (progressResult.success) {
        _progressData = progressResult.data;
      }
      if (dailyResult.success) {
        _dailyStatus = dailyResult.data;
      }

      if (_progressData == null && _dailyStatus == null) {
        _error = progressResult.message;
      }
    } catch (e) {
      if (mounted) {
        _error = '加载失败: $e';
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${widget.goalTypeText}进度',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWeightProgress(),
                        const SizedBox(height: 16),
                        _buildDailyStatus(),
                        const SizedBox(height: 16),
                        _buildWeightChart(),
                        const SizedBox(height: 16),
                        _buildBodyMetrics(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(_error ?? '加载失败', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildWeightProgress() {
    final weightProgress = _progressData?['weight_progress'] as Map<String, dynamic>?;
    if (weightProgress == null) return const SizedBox.shrink();

    final startingWeight = weightProgress['starting_weight'];
    final currentWeight = weightProgress['current_weight'];
    final targetWeight = weightProgress['target_weight'] ?? widget.targetWeight;
    final progressPct = (weightProgress['progress_percentage'] as num?)?.toDouble() ?? 0;
    final remaining = weightProgress['remaining'];
    final trend = weightProgress['trend'] as String? ?? 'stable';

    final trendText = trend == 'on_track' ? '进度正常' : trend == 'off_track' ? '需加把劲' : '保持稳定';
    final trendColor = trend == 'on_track'
        ? AppColors.success
        : trend == 'off_track'
            ? AppColors.warning
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.target, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('体重进度', style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(trendText, style: TextStyle(fontSize: 12, color: trendColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              minHeight: 12,
              backgroundColor: AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text('${progressPct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Weight numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWeightStage('起始', startingWeight),
              const Icon(LucideIcons.arrowRight, color: AppColors.textSecondary, size: 18),
              _buildWeightStage('当前', currentWeight),
              const Icon(LucideIcons.arrowRight, color: AppColors.textSecondary, size: 18),
              _buildWeightStage('目标', targetWeight),
            ],
          ),
          if (remaining != null) ...[
            const SizedBox(height: 12),
            Text(
              '还需${trend == "on_track" ? "减" : "调整"} ${(remaining as num).toStringAsFixed(1)} kg',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightStage(String label, dynamic value) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          value != null ? '${(value as num).toStringAsFixed(1)} kg' : '--',
          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDailyStatus() {
    if (_dailyStatus == null) return const SizedBox.shrink();

    final targets = _dailyStatus!['daily_targets'] as Map<String, dynamic>?;
    final consumed = _dailyStatus!['today_consumed'] as Map<String, dynamic>?;
    final bmr = _dailyStatus!['bmr'];
    final tdee = _dailyStatus!['tdee'];

    if (targets == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.flame, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Text('今日执行情况', style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          _buildNutritionRow('热量', targets['calories'], consumed?['calories'], 'kcal'),
          const SizedBox(height: 10),
          _buildNutritionRow('蛋白质', targets['protein'], consumed?['protein'], 'g'),
          const SizedBox(height: 10),
          _buildNutritionRow('碳水', targets['carbs'], consumed?['carbs'], 'g'),
          const SizedBox(height: 10),
          _buildNutritionRow('脂肪', targets['fat'], consumed?['fat'], 'g'),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, dynamic target, dynamic actual, String unit) {
    final t = (target as num?)?.toDouble() ?? 0;
    final a = (actual as num?)?.toDouble() ?? 0;
    final pct = t > 0 ? a / t : 0.0;
    final isOver = a > t;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            Text(
              '${a.toStringAsFixed(0)} / ${t.toStringAsFixed(0)} $unit',
              style: TextStyle(fontSize: 13, color: isOver ? AppColors.warning : AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(isOver ? AppColors.warning : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.trendingUp, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('体重趋势', style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: WeightChart(days: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMetrics() {
    final bmr = _dailyStatus?['bmr'];
    final tdee = _dailyStatus?['tdee'];
    final recordCount = _progressData?['weight_records_count'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('身体数据', style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCard('BMR', bmr != null ? '${(bmr as num).toStringAsFixed(0)}' : '--', 'kcal/天', LucideIcons.activity),
              const SizedBox(width: 12),
              _buildMetricCard('TDEE', tdee != null ? '${(tdee as num).toStringAsFixed(0)}' : '--', 'kcal/天', LucideIcons.zap),
              const SizedBox(width: 12),
              _buildMetricCard('已记录', recordCount != null ? '$recordCount' : '--', '次体重', LucideIcons.scale),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
