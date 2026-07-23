import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/real_pet_api_service.dart';

/// 宠物饮食日报页面
/// 展示当日热量/蛋白质/脂肪摄入进度 + 餐次明细
class PetDailyReportPage extends StatefulWidget {
  final Map<String, dynamic> pet;
  final DateTime? date;

  const PetDailyReportPage({super.key, required this.pet, this.date});

  @override
  State<PetDailyReportPage> createState() => _PetDailyReportPageState();
}

class _PetDailyReportPageState extends State<PetDailyReportPage> {
  final RealPetApiService _api = RealPetApiService();
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  int _targetCalories = 250;
  double _targetProtein = 20;
  double _targetFat = 10;
  List<Map<String, dynamic>> _feedingRecords = [];

  late DateTime _selectedDate;

  int get _petId => (widget.pet['id'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 获取喂食计划（目标热量）
    try {
      final planRes = await _api.getFeedingPlan(_petId);
      if (planRes.isSuccess && planRes.data != null) {
        _targetCalories =
            (planRes.data!['daily_calories'] as num?)?.round() ?? 250;
        _targetProtein =
            (planRes.data!['daily_protein'] as num?)?.toDouble() ?? 20;
        _targetFat =
            (planRes.data!['daily_fat'] as num?)?.toDouble() ?? 10;
      }
    } catch (_) {}

    // 获取当日汇总
    try {
      final summaryRes = await _api.getDailySummary(_petId, dateStr);
      if (summaryRes.isSuccess && summaryRes.data != null) {
        _summary = Map<String, dynamic>.from(summaryRes.data!);
      }
    } catch (_) {}

    // 获取当日饮食记录
    try {
      final feedRes = await _api.getFeedingRecords(_petId);
      if (feedRes.isSuccess && feedRes.data != null) {
        final allRecords = feedRes.data!['records'] as List<dynamic>? ?? [];
        final dateStrFilter = dateStr;
        _feedingRecords = allRecords.where((r) {
          final recordTime = (r as Map)['record_time'] as String?;
          if (recordTime == null) return false;
          return recordTime.startsWith(dateStrFilter);
        }).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          m['food'] = m['food_name'] ?? '';
          m['amount_g'] = (m['amount_grams'] as num?)?.toDouble() ?? 0;
          return m;
        }).toList();
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _prevDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadData();
  }

  void _nextDay() {
    if (!_isToday(_selectedDate)) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      });
      _loadData();
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final totalCal = (_summary['total_calories'] as num?)?.toInt() ?? 0;
    final totalProtein = (_summary['total_protein'] as num?)?.toDouble() ?? 0;
    final totalFat = (_summary['total_fat'] as num?)?.toDouble() ?? 0;
    final mealCount = (_summary['meal_count'] as num?)?.toInt() ?? 0;
    final waterMl = (_summary['total_water_ml'] as num?)?.toInt() ?? 0;

    final calProgress = _targetCalories > 0 ? totalCal / _targetCalories : 0.0;
    final proteinProgress = _targetProtein > 0 ? totalProtein / _targetProtein : 0.0;
    final fatProgress = _targetFat > 0 ? totalFat / _targetFat : 0.0;

    final dateLabel = DateFormat('MM月dd日 EEEE', 'zh_CN').format(_selectedDate);
    final isToday = _isToday(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.pet['name']} - 日报',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.chevronLeft,
                color: AppColors.textSecondary, size: 20),
            onPressed: _prevDay,
          ),
          Text(dateLabel.substring(5, 10),
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          IconButton(
            icon: Icon(LucideIcons.chevronRight,
                color: isToday ? AppColors.textTertiary : AppColors.textSecondary,
                size: 20),
            onPressed: isToday ? null : _nextDay,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 热量进度环
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildProgressRing(
                              calProgress.clamp(0.0, 1.0),
                              '${totalCal}',
                              'kcal',
                              AppColors.caloriesColor,
                              size: 100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '目标 $_targetCalories kcal',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusText(calProgress),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(calProgress),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 营养素分布
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
                            Icon(LucideIcons.pieChart, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('营养素摄入',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutrientProgress(
                                '蛋白质',
                                totalProtein,
                                _targetProtein,
                                'g',
                                AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildNutrientProgress(
                                '脂肪',
                                totalFat,
                                _targetFat,
                                'g',
                                AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildNutrientProgress(
                                '饮水',
                                waterMl.toDouble(),
                                200,
                                'ml',
                                AppColors.info,
                              ),
                            ),
                            Expanded(child: Container()),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 餐次明细
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(LucideIcons.utensilsCrossed,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('餐次明细',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '共 $mealCount 餐',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_feedingRecords.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '今日暂无饮食记录',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          )
                        else
                          ...(_feedingRecords.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final r = entry.value;
                            return _buildMealItem(
                              '第${idx + 1}餐',
                              r['food'] ?? '',
                              (r['calories'] as num?)?.toInt() ?? 0,
                              r['amount_g']?.toStringAsFixed(0) ?? '0',
                            );
                          })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AI 建议（可选）
                  if (totalCal > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.sparkles, color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text('今日建议',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _generateDailyAdvice(totalCal, _targetCalories, mealCount),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProgressRing(double progress, String value, String unit, Color color,
      {double size = 80}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: size > 80 ? 22 : 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientProgress(
      String label, double current, double target, String unit, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(
              '${current.toStringAsFixed(1)} / ${target.toStringAsFixed(1)} $unit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildMealItem(String meal, String food, int calories, String amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(LucideIcons.bone, color: AppColors.primary, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  food.isNotEmpty ? food : '宠物食品',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$calories kcal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.caloriesColor,
                ),
              ),
              Text(
                '$amount g',
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStatusText(double progress) {
    if (progress < 0.7) return '摄入偏低，建议适当增加喂食量';
    if (progress > 1.2) return '摄入偏高，注意控制喂食量';
    return '摄入达标，继续保持';
  }

  Color _getStatusColor(double progress) {
    if (progress < 0.7) return AppColors.warning;
    if (progress > 1.2) return AppColors.error;
    return AppColors.success;
  }

  String _generateDailyAdvice(int total, int target, int meals) {
    final ratio = total / target;
    if (meals == 0) {
      return '今日暂无饮食记录，请及时为宠物添加饮食。';
    }
    if (ratio < 0.7) {
      return '今日摄入偏低，建议在下一餐适当增加喂食量，或额外补充零食。确保宠物获得足够的营养。';
    }
    if (ratio > 1.2) {
      return '今日摄入偏高，建议适当减少下一餐的喂食量，或增加宠物的运动量。';
    }
    return '今日饮食摄入达标，营养均衡。建议保持规律的喂食时间和适量的运动，让宠物保持健康活力。';
  }
}