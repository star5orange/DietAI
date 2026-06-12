import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/exercise_service.dart';
import '../../../../services/wellness_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'constitution_quiz_page.dart';
import '../../../profile/domain/services/user_service.dart';

class DataVisualizationPage extends ConsumerStatefulWidget {
  const DataVisualizationPage({super.key});

  @override
  ConsumerState<DataVisualizationPage> createState() =>
      _DataVisualizationPageState();
}

class _DataVisualizationPageState extends ConsumerState<DataVisualizationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FoodService _foodService = FoodService();
  final ExerciseService _exerciseService = ExerciseService();
  final WellnessService _wellnessService = WellnessService();

  NutritionTrends? _nutritionTrends;
  List<DailyNutritionSummary> _weeklySummaries = [];
  Map<String, dynamic>? _exerciseStats;
  String? _constitutionType;
  String? _crowdTag;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final endDate = DateFormat('yyyy-MM-dd').format(now);
    final startDate =
        DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 29)));

    try {
      // 并行加载所有数据
      final results = await Future.wait([
        _foodService.getNutritionTrends(
          startDate: startDate,
          endDate: endDate,
        ),
        _loadWeeklySummaries(now),
        _exerciseService.getExerciseStatistics(period: '7d'),
        _loadConstitutionType(),
      ]);

      if (mounted) {
        setState(() {
          _nutritionTrends = (results[0] as ApiResponse<NutritionTrends>).data;
          _weeklySummaries = results[1] as List<DailyNutritionSummary>;
          _exerciseStats =
              (results[2] as ApiResponse<Map<String, dynamic>>).data;
          _constitutionType = results[3] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<DailyNutritionSummary>> _loadWeeklySummaries(DateTime now) async {
    final summaries = <DailyNutritionSummary>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        final result = await _foodService.getDailyNutritionSummary(dateStr);
        if (result.data != null) {
          summaries.add(result.data!);
        }
      } catch (_) {}
    }
    return summaries;
  }

  Future<String?> _loadConstitutionType() async {
    try {
      final profile = ref.read(userProfileProvider).value;
      _crowdTag = profile?.crowdTag;
      return profile?.constitutionType;
    } catch (_) {
      return null;
    }
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
        title: Text('数据可视化',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '周度摘要'),
            Tab(text: '营养趋势'),
            Tab(text: '健康画像'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWeeklySummaryTab(),
                  _buildNutritionTrendsTab(),
                  _buildPersonaDashboardTab(),
                ],
              ),
            ),
    );
  }

  // ==================== Tab 1: 周度摘要 ====================

  Widget _buildWeeklySummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeeklyNutritionCard(),
          const SizedBox(height: 20),
          _buildWeeklyExerciseChart(),
        ],
      ),
    );
  }

  Widget _buildWeeklyNutritionCard() {
    if (_weeklySummaries.isEmpty) {
      return _buildEmptyCard(
          '暂无本周饮食数据\n快去记录您的第一餐吧！', LucideIcons.utensilsCrossed);
    }

    final totalCal =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalCalories);
    final totalProtein =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalProtein);
    final totalFat =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalFat);
    final totalCarbs = _weeklySummaries.fold<double>(
        0, (sum, s) => sum + s.totalCarbohydrates);
    final avgCal =
        _weeklySummaries.isNotEmpty ? totalCal / _weeklySummaries.length : 0.0;
    final totalWater =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.waterIntake);
    final totalExercise =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.exerciseCalories);

    // 格式化水量：后端 water_intake 单位已经是升(L)，最多两位小数去尾部零
    final waterDisplay =
        totalWater.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('本周营养总览', LucideIcons.clipboardList),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildStatCard('总热量', '${totalCal.toInt()}', 'kcal',
                AppColors.caloriesColor, LucideIcons.flame),
            const SizedBox(width: 10),
            _buildStatCard('日均热量', '${avgCal.toInt()}', 'kcal',
                AppColors.proteinColor, LucideIcons.target),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('蛋白质', '${totalProtein.toStringAsFixed(0)}g', '本周',
                AppColors.proteinColor, LucideIcons.fish),
            const SizedBox(width: 10),
            _buildStatCard('脂肪', '${totalFat.toStringAsFixed(0)}g', '本周',
                AppColors.fatColor, LucideIcons.droplets),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('碳水', '${totalCarbs.toStringAsFixed(0)}g', '本周',
                AppColors.carbsColor, LucideIcons.wheat),
            const SizedBox(width: 10),
            _buildStatCard('饮水量', '${waterDisplay}L', '本周', AppColors.info,
                LucideIcons.glassWater),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('运动消耗', '${totalExercise.toInt()}', 'kcal',
                const Color(0xFFFF6B6B), LucideIcons.dumbbell),
            const SizedBox(width: 10),
            _buildStatCard('记录天数', '${_weeklySummaries.length}', '天',
                AppColors.success, LucideIcons.calendarCheck),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyExerciseChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('运动消耗趋势', LucideIcons.activity),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.lightShadow,
          ),
          child: _weeklySummaries.isEmpty
              ? const Center(child: Text('暂无运动数据'))
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _weeklySummaries
                            .map((s) => s.exerciseCalories)
                            .reduce(max) *
                        1.3,
                    barGroups: _weeklySummaries.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.exerciseCalories,
                            color: const Color(0xFFFF6B6B),
                            width: 16,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= _weeklySummaries.length) {
                              return const SizedBox.shrink();
                            }
                            final date =
                                _weeklySummaries[value.toInt()].summaryDate;
                            final parsed = DateTime.tryParse(date);
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                parsed != null
                                    ? DateFormat('MM/dd').format(parsed)
                                    : '',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
        ),
      ],
    );
  }

  // ==================== Tab 2: 营养趋势 ====================

  Widget _buildNutritionTrendsTab() {
    if (_nutritionTrends == null || _nutritionTrends!.data.isEmpty) {
      return _buildEmptyCard('暂无趋势数据\n记录足够多的饮食后即可查看趋势', LucideIcons.trendingUp);
    }

    final points = _nutritionTrends!.data;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('热量趋势 (30天)', LucideIcons.flame),
          const SizedBox(height: 12),
          _buildLineChart(
            points,
            'calories',
            AppColors.caloriesColor,
            'kcal',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('三大营养素趋势', LucideIcons.pieChart),
          const SizedBox(height: 12),
          _buildLineChart(
            points,
            'protein',
            AppColors.proteinColor,
            'g',
          ),
          const SizedBox(height: 12),
          _buildLineChart(
            points,
            'fat',
            AppColors.fatColor,
            'g',
          ),
          const SizedBox(height: 12),
          _buildLineChart(
            points,
            'carbohydrates',
            AppColors.carbsColor,
            'g',
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(
    List<NutritionTrendPoint> points,
    String metric,
    Color color,
    String unit,
  ) {
    final spots = <FlSpot>[];
    double maxY = 0;

    for (int i = 0; i < points.length; i++) {
      final val = points[i].values[metric] ?? 0;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val;
    }

    if (maxY == 0) {
      return _buildEmptyMiniCard('暂无${_metricLabel(metric)}数据');
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: (points.length / 6).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.tryParse(points[idx].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      date != null ? DateFormat('MM/dd').format(date) : '',
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
            horizontalInterval: maxY > 0 ? maxY / 4 : 50,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  // ==================== Tab 3: 健康画像 ====================

  Widget _buildPersonaDashboardTab() {
    final constitutionName = _constitutionName(_constitutionType);
    final constitutionColor = _constitutionColor(_constitutionType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 体质画像
          _buildSectionHeader('体质画像', LucideIcons.user),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  constitutionColor,
                  constitutionColor.withValues(alpha: 0.7)
                ],
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
                    Icon(_constitutionIcon(_constitutionType),
                        color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      constitutionName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ConstitutionQuizPage()),
                        ).then((_) => _loadAllData());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('重新测评',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _constitutionDescription(_constitutionType),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 人群标签
          if (_crowdTag != null && _crowdTag != '普通')
            _buildCrowdTagCard(_crowdTag!),
          if (_crowdTag != null && _crowdTag != '普通')
            const SizedBox(height: 20),

          // 健康指标环形图
          _buildSectionHeader('健康指标', LucideIcons.gauge),
          const SizedBox(height: 12),
          _buildHealthGauges(),
          const SizedBox(height: 20),

          // 营养结构分析
          _buildSectionHeader('营养结构', LucideIcons.pieChart),
          const SizedBox(height: 12),
          _buildNutritionPieChart(),
          const SizedBox(height: 20),

          // 建议
          _buildPersonaAdvice(),
        ],
      ),
    );
  }

  Widget _buildHealthGauges() {
    if (_weeklySummaries.isEmpty) {
      return _buildEmptyMiniCard('暂无健康数据');
    }

    final avgCal =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalCalories) /
            _weeklySummaries.length;
    final avgProtein =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalProtein) /
            _weeklySummaries.length;
    final avgWater =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.waterIntake) /
            _weeklySummaries.length;

    return Row(
      children: [
        Expanded(
            child: _gaugeCard(
                '热量', avgCal, 2000, 'kcal', AppColors.caloriesColor)),
        const SizedBox(width: 10),
        Expanded(
            child:
                _gaugeCard('蛋白质', avgProtein, 60, 'g', AppColors.proteinColor)),
        const SizedBox(width: 10),
        Expanded(
            child: _gaugeCard('饮水', avgWater / 1000, 2, 'L', AppColors.info)),
      ],
    );
  }

  Widget _gaugeCard(
      String label, double value, double target, String unit, Color color) {
    final ratio = (value / target).clamp(0.0, 1.5);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: ratio > 1 ? 1 : ratio,
                    strokeWidth: 5,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(
                      ratio > 1 ? AppColors.warning : color,
                    ),
                  ),
                ),
                Text(
                  unit == 'L'
                      ? value.toStringAsFixed(1)
                      : value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          Text('目标 $target$unit',
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildNutritionPieChart() {
    if (_weeklySummaries.isEmpty) {
      return _buildEmptyMiniCard('暂无营养数据');
    }

    final totalProtein =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalProtein);
    final totalFat =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.totalFat);
    final totalCarbs = _weeklySummaries.fold<double>(
        0, (sum, s) => sum + s.totalCarbohydrates);
    final total = totalProtein + totalFat + totalCarbs;

    if (total == 0) {
      return _buildEmptyMiniCard('暂无营养数据');
    }

    final proteinPct = totalProtein / total * 100;
    final fatPct = totalFat / total * 100;
    final carbsPct = totalCarbs / total * 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: totalProtein,
                    color: AppColors.proteinColor,
                    title: '${proteinPct.toStringAsFixed(0)}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: totalFat,
                    color: AppColors.fatColor,
                    title: '${fatPct.toStringAsFixed(0)}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: totalCarbs,
                    color: AppColors.carbsColor,
                    title: '${carbsPct.toStringAsFixed(0)}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 0,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _legendItem('蛋白质', AppColors.proteinColor,
                    '${totalProtein.toStringAsFixed(0)}g'),
                const SizedBox(height: 8),
                _legendItem('脂肪', AppColors.fatColor,
                    '${totalFat.toStringAsFixed(0)}g'),
                const SizedBox(height: 8),
                _legendItem('碳水', AppColors.carbsColor,
                    '${totalCarbs.toStringAsFixed(0)}g'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonaAdvice() {
    final advice = _personaAdvice(_constitutionType);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.lightbulb,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text('个性化建议',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          ...advice.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          )),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ==================== Helpers ====================

  Widget _buildStatCard(
      String label, String value, String unit, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppColors.lightShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrowdTagCard(String crowdTag) {
    final config = _crowdTagConfig(crowdTag);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(config['icon'] as IconData, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config['label'] as String,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(config['tip'] as String,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _crowdTagConfig(String tag) {
    switch (tag) {
      case '减脂':
        return {
          'label': '减脂人群',
          'icon': LucideIcons.flame,
          'gradient': const [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          'tip': '建议关注热量缺口，高蛋白低碳水饮食，配合有氧运动',
        };
      case '健身':
        return {
          'label': '健身人群',
          'icon': LucideIcons.dumbbell,
          'gradient': const [Color(0xFF667EEA), Color(0xFF764BA2)],
          'tip': '建议保证蛋白质摄入充足，关注训练前后营养补充',
        };
      case '养生':
        return {
          'label': '养生人群',
          'icon': LucideIcons.heart,
          'gradient': const [Color(0xFF43A047), Color(0xFF66BB6A)],
          'tip': '建议根据体质和季节选择食材，饮食均衡温和',
        };
      default:
        return {
          'label': tag,
          'icon': LucideIcons.user,
          'gradient': [AppColors.primary, AppColors.primaryLight],
          'tip': '根据个人健康状况调整饮食结构',
        };
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMiniCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(message,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
      ),
    );
  }

  Widget _legendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }

  String _metricLabel(String metric) {
    switch (metric) {
      case 'calories':
        return '热量';
      case 'protein':
        return '蛋白质';
      case 'fat':
        return '脂肪';
      case 'carbohydrates':
        return '碳水';
      default:
        return metric;
    }
  }

  String _constitutionName(String? type) {
    const map = {
      '平和质': '平和质',
      '气虚质': '气虚质',
      '阳虚质': '阳虚质',
      '阴虚质': '阴虚质',
      '痰湿质': '痰湿质',
      '湿热质': '湿热质',
      '血瘀质': '血瘀质',
      '气郁质': '气郁质',
      '特禀质': '特禀质',
      '平和': '平和质',
      'qixu': '气虚质',
      'yangxu': '阳虚质',
      'yinxu': '阴虚质',
      'tanshi': '痰湿质',
      'shire': '湿热质',
      'xueyu': '血瘀质',
      'qiyu': '气郁质',
      'tebing': '特禀质',
      'pinghe': '平和质',
    };
    return map[type] ?? '待测评';
  }

  Color _constitutionColor(String? type) {
    const map = {
      '平和质': Color(0xFF22C55E),
      '气虚质': Color(0xFFEAB308),
      '阳虚质': Color(0xFFEF4444),
      '阴虚质': Color(0xFF8B5CF6),
      '痰湿质': Color(0xFF06B6D4),
      '湿热质': Color(0xFFF97316),
      '血瘀质': Color(0xFFDC2626),
      '气郁质': Color(0xFF64748B),
      '特禀质': Color(0xFFEC4899),
      '平和': Color(0xFF22C55E),
      'qixu': Color(0xFFEAB308),
      'yangxu': Color(0xFFEF4444),
      'yinxu': Color(0xFF8B5CF6),
      'tanshi': Color(0xFF06B6D4),
      'shire': Color(0xFFF97316),
      'xueyu': Color(0xFFDC2626),
      'qiyu': Color(0xFF64748B),
      'tebing': Color(0xFFEC4899),
      'pinghe': Color(0xFF22C55E),
    };
    return map[type] ?? AppColors.primary;
  }

  IconData _constitutionIcon(String? type) {
    const map = {
      '平和质': LucideIcons.sun,
      '气虚质': LucideIcons.wind,
      '阳虚质': LucideIcons.flame,
      '阴虚质': LucideIcons.moon,
      '痰湿质': LucideIcons.droplets,
      '湿热质': LucideIcons.thermometer,
      '血瘀质': LucideIcons.droplet,
      '气郁质': LucideIcons.cloud,
      '特禀质': LucideIcons.shieldAlert,
    };
    return map[_constitutionName(type)] ?? LucideIcons.user;
  }

  String _constitutionDescription(String? type) {
    const map = {
      '平和质': '阴阳气血调和，体态适中，面色润泽，精力充沛',
      '气虚质': '元气不足，容易疲劳，气短懒言，抵抗力较弱',
      '阳虚质': '阳气不足，手足不温，畏寒怕冷，精神不振',
      '阴虚质': '阴液亏少，口燥咽干，手足心热，易烦躁',
      '痰湿质': '痰湿凝聚，体型肥胖，腹部松软，面部油腻',
      '湿热质': '湿热内蕴，面垢油光，易生痤疮，口苦口干',
      '血瘀质': '血行不畅，肤色晦暗，色素沉着，易瘀斑',
      '气郁质': '气机郁滞，神情抑郁，忧虑脆弱，情绪低落',
      '特禀质': '先天失常，过敏体质，易对环境食物过敏',
    };
    return map[_constitutionName(type)] ?? '完成体质测评，了解您的体质类型';
  }

  List<String> _personaAdvice(String? type) {
    const map = {
      '平和质': [
        '继续保持均衡饮食、适度运动、规律作息的良好习惯',
        '饮食宜粗细搭配，荤素合理，不宜偏食',
        '每周保持150分钟中等强度运动',
      ],
      '气虚质': [
        '宜食益气健脾食物：山药、黄芪、大枣、小米',
        '避免过度劳累，适合散步、太极拳等柔和运动',
        '保证充足睡眠，避免熬夜耗气',
      ],
      '阳虚质': [
        '宜食温阳食物：羊肉、生姜、桂圆、核桃',
        '注意保暖，避免生冷食物和寒冷环境',
        '适合慢跑、日光浴，以动生阳',
      ],
      '阴虚质': [
        '宜食滋阴食物：银耳、百合、枸杞、鸭肉',
        '避免辛辣燥热食物，保持心情平和',
        '避免熬夜，保证充足睡眠以养阴',
      ],
      '痰湿质': [
        '宜食健脾利湿食物：薏米、冬瓜、荷叶、白萝卜',
        '减少甜食油腻，增加运动量，控制体重',
        '居住环境宜通风干燥，避免潮湿',
      ],
      '湿热质': [
        '宜食清热利湿食物：绿豆、苦瓜、黄瓜、莲藕',
        '忌辛辣油腻，戒烟限酒',
        '保持皮肤清洁，适当运动排汗',
      ],
      '血瘀质': [
        '宜食活血化瘀食物：山楂、黑豆、醋、红花',
        '适度有氧运动促进血液循环',
        '保持心情舒畅，避免久坐不动',
      ],
      '气郁质': [
        '宜食行气解郁食物：柑橘、玫瑰花、薄荷',
        '多参加社交活动，培养兴趣爱好',
        '适合瑜伽、冥想等放松运动',
      ],
      '特禀质': [
        '明确过敏原并严格避免接触',
        '饮食清淡，避免含致敏物质的食物',
        '增强体质，适当锻炼提高免疫力',
      ],
    };
    return map[_constitutionName(type)] ??
        [
          '完成体质测评，获取个性化建议',
          '点击上方"重新测评"按钮进行体质自测',
        ];
  }
}
