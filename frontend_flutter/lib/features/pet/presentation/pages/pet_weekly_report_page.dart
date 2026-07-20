import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/real_pet_api_service.dart';

/// 饮食周报页面
/// 展示近7天热量趋势 + 营养分析（从后端API加载）
class PetWeeklyReportPage extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetWeeklyReportPage({super.key, required this.pet});

  @override
  State<PetWeeklyReportPage> createState() => _PetWeeklyReportPageState();
}

class _PetWeeklyReportPageState extends State<PetWeeklyReportPage> {
  final RealPetApiService _api = RealPetApiService();
  List<Map<String, dynamic>> _weeklyData = [];
  int _targetCalories = 250;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  Future<void> _loadWeeklyData() async {
    setState(() => _isLoading = true);
    final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();

    // 先加载喂食计划获取目标热量
    try {
      final planRes = await _api.getFeedingPlan(petId);
      if (planRes.isSuccess && planRes.data != null) {
        _targetCalories = (planRes.data!['daily_calories'] as num?)?.round() ??
            _targetCalories;
      }
    } catch (_) {}

    // 获取近7天每日汇总
    final weekData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayLabel =
          ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
      final dateLabel = DateFormat('MM/dd').format(date);

      int calories = 0;
      double protein = 0;
      double fat = 0;

      try {
        final summaryRes = await _api.getDailySummary(petId, dateStr);
        if (summaryRes.isSuccess && summaryRes.data != null) {
          calories = (summaryRes.data!['total_calories'] as num?)?.round() ?? 0;
          protein =
              (summaryRes.data!['total_protein'] as num?)?.toDouble() ?? 0;
          fat = (summaryRes.data!['total_fat'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {
        // 当天无数据，保持0
      }

      String status;
      if (_targetCalories > 0) {
        final ratio = calories / _targetCalories;
        if (ratio < 0.7) {
          status = '偏低';
        } else if (ratio > 1.3) {
          status = '偏高';
        } else {
          status = '达标';
        }
      } else {
        status = calories > 0 ? '达标' : '无数据';
      }

      weekData.add({
        'day': dayLabel,
        'date': dateLabel,
        'calories': calories,
        'protein': double.parse(protein.toStringAsFixed(1)),
        'fat': double.parse(fat.toStringAsFixed(1)),
        'status': status,
      });
    }

    if (mounted) {
      setState(() {
        _weeklyData = weekData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData =
        _weeklyData.any((d) => ((d['calories'] as num?)?.toInt() ?? 0) > 0);
    final avgCalories = hasData
        ? (_weeklyData
                    .map((d) => (d['calories'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) /
                _weeklyData.length)
            .round()
        : 0;
    final onTargetDays = _weeklyData.where((d) => d['status'] == '达标').length;
    final totalCalories = _weeklyData.fold<int>(
        0, (s, d) => s + ((d['calories'] as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.pet['name']} - 饮食周报',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 周报概览卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '本周概览',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSummaryItem('日均热量', '${avgCalories}kcal'),
                            _buildSummaryItem('达标天数', '$onTargetDays/7'),
                            _buildSummaryItem('总摄入', '${totalCalories}kcal'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 7天趋势柱状图
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.trendingUp,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('热量趋势',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '目标线：$_targetCalories kcal/天',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: _buildBarChart(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 每日明细
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('每日明细',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ..._weeklyData.map((d) => _buildDayItem(d)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AI周报总结
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.sparkles,
                                color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('周报总结',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _generateSummaryText(avgCalories, onTargetDays),
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _generateSummaryText(int avgCalories, int onTargetDays) {
    final now = DateTime.now();
    final weekStart =
        DateFormat('MM/dd').format(now.subtract(const Duration(days: 6)));
    final weekEnd = DateFormat('MM/dd').format(now);

    if (avgCalories == 0) {
      return '$weekStart - $weekEnd 暂无饮食记录。请及时为宠物添加饮食记录，以便生成周报。';
    }

    final rate = (onTargetDays / 7 * 100).toInt();
    String comment;
    if (rate >= 80) {
      comment = '整体表现优秀，喂养节奏把控得当。';
    } else if (rate >= 50) {
      comment = '基本达标，部分天数需注意调整喂食量。';
    } else {
      comment = '达标率偏低，建议关注每日喂食量，避免过度或不足。';
    }

    return '$weekStart - $weekEnd 本周日均摄入 ${avgCalories}kcal，'
        '达标率 $rate%。$comment';
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_weeklyData.isEmpty ||
        _weeklyData
            .every((d) => ((d['calories'] as num?)?.toInt() ?? 0) == 0)) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: AppColors.textTertiary)),
      );
    }

    final maxCal = _weeklyData
        .map((d) => (d['calories'] as num?)?.toInt() ?? 0)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final chartMax =
        (maxCal > _targetCalories ? maxCal : _targetCalories * 1.0) * 1.2;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _weeklyData.map((d) {
        final calories = ((d['calories'] as num?)?.toInt() ?? 0).toDouble();
        final height = chartMax > 0 ? (calories / chartMax * 160) : 0.0;

        Color barColor;
        switch (d['status']) {
          case '偏低':
            barColor = AppColors.warning;
          case '偏高':
            barColor = AppColors.error;
          default:
            barColor = AppColors.primary;
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  calories > 0 ? '${calories.toInt()}' : '',
                  style: TextStyle(
                      fontSize: 10,
                      color: barColor,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Container(
                  height: height.clamp(2.0, 160.0),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.7),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d['day'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayItem(Map<String, dynamic> day) {
    Color statusColor;
    IconData statusIcon;
    switch (day['status']) {
      case '偏低':
        statusColor = AppColors.warning;
        statusIcon = LucideIcons.trendingDown;
      case '偏高':
        statusColor = AppColors.error;
        statusIcon = LucideIcons.trendingUp;
      default:
        statusColor = AppColors.success;
        statusIcon = LucideIcons.check;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 日期
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(day['day'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(day['date'] as String,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 营养数据
          Expanded(
            child: Row(
              children: [
                _buildNutrientChip(
                    '${day['calories']} kcal', AppColors.caloriesColor),
                const SizedBox(width: 8),
                _buildNutrientChip('蛋白 ${day['protein']}g', AppColors.primary),
                const SizedBox(width: 8),
                _buildNutrientChip('脂肪 ${day['fat']}g', AppColors.warning),
              ],
            ),
          ),

          // 状态图标
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 4),
          Text(
            day['status'] as String? ?? '',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: statusColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
