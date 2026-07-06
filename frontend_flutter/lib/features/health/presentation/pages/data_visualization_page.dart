import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../../services/food_service.dart';
import '../../../../services/exercise_service.dart';
import '../../../../services/wellness_service.dart';
import '../../../../services/water_service.dart';
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
  final WaterService _waterService = WaterService();

  NutritionTrends? _nutritionTrends;
  List<DailyNutritionSummary> _weeklySummaries = [];
  Map<String, dynamic>? _exerciseStats;
  String? _constitutionType;
  String? _crowdTag;
  bool _isLoading = true;

  // 规律统计数据
  Map<String, dynamic>? _waterStats;
  Map<String, dynamic>? _mealRegularity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        _waterService.getWaterStatistics(period: '7d'),
        _loadMealRegularity(),
      ]);

      if (mounted) {
        setState(() {
          _nutritionTrends = (results[0] as ApiResponse<NutritionTrends>).data;
          _weeklySummaries = results[1] as List<DailyNutritionSummary>;
          _exerciseStats =
              (results[2] as ApiResponse<Map<String, dynamic>>).data;
          _constitutionType = results[3] as String?;
          _waterStats =
              (results[4] as ApiResponse<Map<String, dynamic>>).data;
          _mealRegularity = results[5] as Map<String, dynamic>?;
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
      // 直接调API获取最新数据，避免provider缓存问题
      final userService = UserService(ApiService());
      final result = await userService.getUserProfile();
      if (result.success && result.data != null) {
        _crowdTag = result.data!.crowdTag;
        return result.data!.constitutionType;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadMealRegularity() async {
    try {
      final ApiService apiService = ApiService();
      final response = await apiService.get(
        '/health/meal-regularity',
        queryParameters: {'days': 14},
      );
      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
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
            Tab(text: '规律统计'),
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
                  _buildRegularityTab(),
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

    // 根据人群标签差异化展示统计卡片
    final tag = _crowdTag ?? '普通';
    List<Widget> statRows;
    if (tag == '减脂') {
      // 减脂：突出热量缺口和运动消耗
      final calorieDeficit = (avgCal > 0 && totalCal > 0)
          ? (2000 * _weeklySummaries.length - totalCal).toInt()
          : 0;
      statRows = [
        Row(
          children: [
            _buildStatCard('总热量', '${totalCal.toInt()}', 'kcal',
                AppColors.caloriesColor, LucideIcons.flame),
            const SizedBox(width: 10),
            _buildStatCard('热量缺口', '$calorieDeficit', 'kcal',
                const Color(0xFF43A047), LucideIcons.trendingDown),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('运动消耗', '${totalExercise.toInt()}', 'kcal',
                const Color(0xFFFF6B6B), LucideIcons.dumbbell),
            const SizedBox(width: 10),
            _buildStatCard('蛋白质', '${totalProtein.toStringAsFixed(0)}g', '本周',
                AppColors.proteinColor, LucideIcons.fish),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('脂肪', '${totalFat.toStringAsFixed(0)}g', '本周',
                AppColors.fatColor, LucideIcons.droplets),
            const SizedBox(width: 10),
            _buildStatCard('饮水量', '${waterDisplay}L', '本周', AppColors.info,
                LucideIcons.glassWater),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('碳水', '${totalCarbs.toStringAsFixed(0)}g', '本周',
                AppColors.carbsColor, LucideIcons.wheat),
            const SizedBox(width: 10),
            _buildStatCard('记录天数', '${_weeklySummaries.length}', '天',
                AppColors.success, LucideIcons.calendarCheck),
          ],
        ),
      ];
    } else if (tag == '健身') {
      // 健身：突出蛋白质和碳水
      final avgProtein = _weeklySummaries.isNotEmpty
          ? totalProtein / _weeklySummaries.length
          : 0.0;
      statRows = [
        Row(
          children: [
            _buildStatCard('蛋白质', '${totalProtein.toStringAsFixed(0)}g', '本周',
                AppColors.proteinColor, LucideIcons.fish),
            const SizedBox(width: 10),
            _buildStatCard('日均蛋白', '${avgProtein.toStringAsFixed(0)}', 'g',
                AppColors.proteinColor, LucideIcons.target),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('碳水', '${totalCarbs.toStringAsFixed(0)}g', '本周',
                AppColors.carbsColor, LucideIcons.wheat),
            const SizedBox(width: 10),
            _buildStatCard('运动消耗', '${totalExercise.toInt()}', 'kcal',
                const Color(0xFF667EEA), LucideIcons.dumbbell),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('总热量', '${totalCal.toInt()}', 'kcal',
                AppColors.caloriesColor, LucideIcons.flame),
            const SizedBox(width: 10),
            _buildStatCard('脂肪', '${totalFat.toStringAsFixed(0)}g', '本周',
                AppColors.fatColor, LucideIcons.droplets),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('饮水量', '${waterDisplay}L', '本周', AppColors.info,
                LucideIcons.glassWater),
            const SizedBox(width: 10),
            _buildStatCard('记录天数', '${_weeklySummaries.length}', '天',
                AppColors.success, LucideIcons.calendarCheck),
          ],
        ),
      ];
    } else {
      // 普通/养生：均衡展示
      statRows = [
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
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('本周营养总览', LucideIcons.clipboardList),
        const SizedBox(height: 12),
        ...statRows,
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
    final tag = _crowdTag ?? '普通';

    // 根据人群标签调整图表顺序和重点
    List<Widget> trendCharts;
    if (tag == '减脂') {
      // 减脂：热量趋势优先，蛋白质次之
      trendCharts = [
        _buildSectionHeader('热量趋势 (30天)', LucideIcons.flame),
        const SizedBox(height: 12),
        _buildLineChart(points, 'calories', AppColors.caloriesColor, 'kcal'),
        const SizedBox(height: 24),
        _buildSectionHeader('蛋白质趋势', LucideIcons.beef),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'protein', AppColors.proteinColor, 'g'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'fat', AppColors.fatColor, 'g'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'carbohydrates', AppColors.carbsColor, 'g'),
      ];
    } else if (tag == '健身') {
      // 健身：蛋白质趋势优先，碳水次之
      trendCharts = [
        _buildSectionHeader('蛋白质趋势 (30天)', LucideIcons.beef),
        const SizedBox(height: 12),
        _buildLineChart(points, 'protein', AppColors.proteinColor, 'g'),
        const SizedBox(height: 24),
        _buildSectionHeader('碳水趋势', LucideIcons.wheat),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'carbohydrates', AppColors.carbsColor, 'g'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'calories', AppColors.caloriesColor, 'kcal'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'fat', AppColors.fatColor, 'g'),
      ];
    } else {
      // 普通/养生：均衡展示
      trendCharts = [
        _buildSectionHeader('热量趋势 (30天)', LucideIcons.flame),
        const SizedBox(height: 12),
        _buildLineChart(points, 'calories', AppColors.caloriesColor, 'kcal'),
        const SizedBox(height: 24),
        _buildSectionHeader('三大营养素趋势', LucideIcons.pieChart),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'protein', AppColors.proteinColor, 'g'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'fat', AppColors.fatColor, 'g'),
        const SizedBox(height: 12),
        _buildLabeledChart(points, 'carbohydrates', AppColors.carbsColor, 'g'),
      ];
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: trendCharts,
      ),
    );
  }

  Widget _buildLabeledChart(
    List<NutritionTrendPoint> points,
    String metric,
    Color color,
    String unit,
  ) {
    final label = _metricLabel(metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$label ($unit)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        _buildLineChart(points, metric, color, unit),
      ],
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
    final avgCarbs = _weeklySummaries.fold<double>(
            0, (sum, s) => sum + s.totalCarbohydrates) /
        _weeklySummaries.length;
    final avgWater =
        _weeklySummaries.fold<double>(0, (sum, s) => sum + s.waterIntake) /
            _weeklySummaries.length;
    final avgExercise = _weeklySummaries.fold<double>(
            0, (sum, s) => sum + s.exerciseCalories) /
        _weeklySummaries.length;

    // 根据人群标签差异化展示健康指标
    final tag = _crowdTag ?? '普通';
    List<Widget> gauges;
    if (tag == '减脂') {
      // 减脂：热量缺口 + 运动消耗 + 体重变化(用饮水占位)
      gauges = [
        Expanded(
            child: _gaugeCard(
                '热量缺口', 2000 - avgCal, 500, 'kcal', AppColors.caloriesColor)),
        const SizedBox(width: 10),
        Expanded(
            child: _gaugeCard(
                '运动消耗', avgExercise, 300, 'kcal', const Color(0xFFFF6B6B))),
        const SizedBox(width: 10),
        Expanded(
            child: _gaugeCard('饮水', avgWater / 1000, 2, 'L', AppColors.info)),
      ];
    } else if (tag == '健身') {
      // 健身：蛋白质达标 + 碳水摄入 + 训练消耗
      gauges = [
        Expanded(
            child:
                _gaugeCard('蛋白质', avgProtein, 120, 'g', AppColors.proteinColor)),
        const SizedBox(width: 10),
        Expanded(
            child: _gaugeCard('碳水', avgCarbs, 300, 'g', AppColors.carbsColor)),
        const SizedBox(width: 10),
        Expanded(
            child: _gaugeCard(
                '训练消耗', avgExercise, 400, 'kcal', const Color(0xFF667EEA))),
      ];
    } else {
      // 普通/养生：均衡展示
      gauges = [
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
      ];
    }

    return Row(children: gauges);
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
    final constitutionAdvice = _personaAdvice(_constitutionType);
    final crowdAdvice = _crowdTagAdvice(_crowdTag);
    final allAdvice = [...crowdAdvice, ...constitutionAdvice];
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
          ...allAdvice.map((item) => Padding(
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

  List<String> _crowdTagAdvice(String? tag) {
    const map = {
      '减脂': [
        '保持每日热量缺口在300-500kcal，避免过度节食',
        '优先选择高蛋白低脂食物，增加饱腹感',
        '每周至少150分钟有氧运动，配合力量训练效果更佳',
      ],
      '健身': [
        '训练后30分钟内补充蛋白质和碳水，促进肌肉修复',
        '蛋白质摄入建议1.6-2.2g/kg体重，分多餐摄入',
        '保证充足碳水为训练供能，避免低碳水影响训练质量',
      ],
      '养生': [
        '根据节气选择当季食材，顺应自然饮食',
        '饮食定时定量，避免暴饮暴食',
        '注意体质调理，饮食温和均衡',
      ],
    };
    return map[tag ?? ''] ?? [];
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

  // ==================== Tab 4: 规律统计 ====================

  Widget _buildRegularityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWaterRegularityCard(),
          const SizedBox(height: 20),
          _buildMealRegularityCard(),
        ],
      ),
    );
  }

  Widget _buildWaterRegularityCard() {
    final stats = _waterStats;
    if (stats == null) {
      return _buildEmptyCard('暂无饮水统计数据\n开始记录饮水量吧！', LucideIcons.droplets);
    }

    final goalMetDays = stats['goal_met_days'] as int? ?? 0;
    final totalDays = stats['total_days'] as int? ?? 7;
    final complianceRate = stats['compliance_rate'] as num? ?? 0;
    final avgDailyMl = stats['average_daily_ml'] as num? ?? 0;
    final dailyData = stats['daily_data'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('饮水规律', LucideIcons.droplets),
        const SizedBox(height: 12),
        // 概览卡片
        Row(
          children: [
            _buildStatCard('达标天数', '$goalMetDays', '/$totalDays天',
                AppColors.info, LucideIcons.checkCircle2),
            const SizedBox(width: 10),
            _buildStatCard('达标率', '${(complianceRate.toDouble() * 100).toStringAsFixed(0)}', '%',
                AppColors.info, LucideIcons.target),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatCard('日均饮水', '${avgDailyMl.toInt()}', 'ml',
                AppColors.info, LucideIcons.glassWater),
            const SizedBox(width: 10),
            _buildStatCard('记录天数', '${dailyData.length}', '天',
                AppColors.info, LucideIcons.calendarCheck),
          ],
        ),
        const SizedBox(height: 16),
        // 7天饮水柱状图
        if (dailyData.isNotEmpty) ...[
          _buildSectionHeader('近7天饮水量', LucideIcons.barChart3),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.lightShadow,
            ),
            child: _buildWaterBarChart(dailyData),
          ),
        ],
      ],
    );
  }

  Widget _buildWaterBarChart(Map<String, dynamic> dailyData) {
    // 排序并取最近7天
    final sortedKeys = dailyData.keys.toList()..sort();
    final recentKeys = sortedKeys.length > 7
        ? sortedKeys.sublist(sortedKeys.length - 7)
        : sortedKeys;

    if (recentKeys.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxMl = dailyData.values
        .map((v) => (v as num).toDouble())
        .reduce(max);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxMl > 0 ? maxMl * 1.3 : 3000,
        barGroups: recentKeys.asMap().entries.map((e) {
          final ml = (dailyData[e.value] as num).toDouble();
          final isGoalMet = ml >= 2000; // 默认目标2000ml
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: ml,
                color: isGoalMet ? AppColors.success : AppColors.info,
                width: 20,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value >= 1000) {
                  return Text('${(value / 1000).toStringAsFixed(1)}L',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary));
                }
                return Text('${value.toInt()}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary));
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
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= recentKeys.length) {
                  return const SizedBox.shrink();
                }
                final dateStr = recentKeys[idx];
                final parsed = DateTime.tryParse(dateStr);
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    parsed != null ? DateFormat('MM/dd').format(parsed) : '',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppColors.cardBackground,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final dateStr = recentKeys[group.x.toInt()];
              return BarTooltipItem(
                '$dateStr\n${rod.toY.toInt()} ml',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMealRegularityCard() {
    final data = _mealRegularity;
    if (data == null) {
      return _buildEmptyCard('暂无饮食规律数据\n记录更多餐食后即可分析', LucideIcons.utensilsCrossed);
    }

    final overallScore = data['overall_score'] as num? ?? 0;
    final overallGrade = data['overall_grade'] as String? ?? '--';
    final daysAnalyzed = data['days_analyzed'] as int? ?? 0;
    final meals = data['meals'] as Map<String, dynamic>? ?? {};
    final suggestions = data['suggestions'] as List? ?? [];

    // 规律度颜色
    Color scoreColor;
    if (overallScore >= 90) {
      scoreColor = AppColors.success;
    } else if (overallScore >= 75) {
      scoreColor = AppColors.info;
    } else if (overallScore >= 60) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('饮食规律', LucideIcons.utensilsCrossed),
        const SizedBox(height: 12),
        // 总体评分
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scoreColor, scoreColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overallGrade,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '分析周期: $daysAnalyzed 天',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${overallScore.toInt()}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Text('分',
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 各餐详情
        ...meals.entries.map((entry) {
          final meal = entry.value as Map<String, dynamic>;
          final mealName = meal['meal_name'] as String? ?? '';
          final score = meal['regularity_score'] as num? ?? 0;
          final grade = meal['grade'] as String? ?? '';
          final recordedDays = meal['recorded_days'] as int? ?? 0;
          final missedDays = meal['missed_days'] as int? ?? 0;
          final completionRate = meal['completion_rate'] as num? ?? 0;

          Color mealColor;
          if (score >= 90) {
            mealColor = AppColors.success;
          } else if (score >= 75) {
            mealColor = AppColors.info;
          } else if (score >= 60) {
            mealColor = AppColors.warning;
          } else {
            mealColor = AppColors.error;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                      Text(mealName,
                          style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: mealColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(grade,
                            style: TextStyle(
                                fontSize: 12,
                                color: mealColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score.toDouble() / 100,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                      color: mealColor,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('规律度 ${score.toInt()}分',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text('记录$recordedDays天 / 缺餐$missedDays天',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text('完成率${completionRate.toDouble().toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        // 建议
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader('改善建议', LucideIcons.lightbulb),
          const SizedBox(height: 8),
          ...suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: Text(s.toString(),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }
}
