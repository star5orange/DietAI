import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/exercise_model.dart';
import '../../../../services/exercise_service.dart';
import '../../../profile/domain/services/user_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import 'exercise_history_page.dart';

class ExerciseRecordPage extends StatefulWidget {
  const ExerciseRecordPage({super.key});

  @override
  State<ExerciseRecordPage> createState() => _ExerciseRecordPageState();
}

class _ExerciseRecordPageState extends State<ExerciseRecordPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ExerciseService _exerciseService = ExerciseService();
  List<ExerciseRecord> _records = [];
  DailyExerciseSummary? _todaySummary;
  bool _isLoading = true;
  String? _crowdTag;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadCrowdTag();
  }

  Future<void> _loadCrowdTag() async {
    try {
      final userService = UserService(ApiService());
      final result = await userService.getUserProfile();
      if (result.success && result.data != null) {
        if (mounted) {
          setState(() => _crowdTag = result.data!.crowdTag);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd')
          .format(now.subtract(const Duration(days: 30)));
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      // 从后端获取30天内的运动记录
      final recordsResult = await _exerciseService.getRemoteExerciseRecords(
        startDate: startDate,
        endDate: endDate,
        limit: 200,
      );

      if (mounted) {
        final records = (recordsResult.data ?? [])
            .map((json) => ExerciseRecord.fromJson(json))
            .toList();

        // 计算今日汇总
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final todayRecords =
            records.where((r) => r.recordedAt.startsWith(todayStr)).toList();
        final todaySummary = DailyExerciseSummary(
          date: todayStr,
          totalCaloriesBurned:
              todayRecords.fold(0.0, (sum, r) => sum + r.caloriesBurned),
          totalDurationMinutes:
              todayRecords.fold(0, (sum, r) => sum + r.durationMinutes),
          exerciseCount: todayRecords.length,
        );

        setState(() {
          _records = records;
          _todaySummary = todaySummary;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '运动记录',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddExerciseModal(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textInverse,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(LucideIcons.activity, size: 18),
                  text: '今日概览',
                ),
                Tab(
                  icon: Icon(LucideIcons.list, size: 18),
                  text: '历史记录',
                ),
                Tab(
                  icon: Icon(LucideIcons.barChart3, size: 18),
                  text: '统计图表',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayOverviewTab(),
                _buildHistoryListTab(),
                _buildStatisticsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExerciseModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        label: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '记录',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.2,
              ),
            ),
            Text(
              '运动',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodaySummaryCard(),
            const SizedBox(height: 20),
            _buildTodayRecordsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    final summary = _todaySummary;
    final calories = summary?.totalCaloriesBurned ?? 0.0;
    final duration = summary?.totalDurationMinutes ?? 0;
    final count = summary?.exerciseCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.flame, color: AppColors.textInverse, size: 24),
              SizedBox(width: 12),
              Text(
                '今日运动概览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textInverse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '消耗热量',
                  '${calories.toStringAsFixed(0)}',
                  'kcal',
                  LucideIcons.flame,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '运动时长',
                  '$duration',
                  '分钟',
                  LucideIcons.clock,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '运动次数',
                  '$count',
                  '次',
                  LucideIcons.repeat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.whiteWithOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.whiteWithOpacity(0.7), size: 16),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textInverse,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.whiteWithOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.whiteWithOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRecordsList() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayRecords =
        _records.where((r) => r.recordedAt.startsWith(todayStr)).toList();

    if (todayRecords.isEmpty) {
      return _buildEmptyState('今天还没有运动记录', '点击下方按钮开始记录运动');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日记录',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...todayRecords.map((record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildExerciseRecordCard(record),
            )),
      ],
    );
  }

  Widget _buildHistoryListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExerciseHistoryPage()),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.calendarRange,
                      color: AppColors.textInverse, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '查看完整运动历史',
                      style: TextStyle(
                        color: AppColors.textInverse,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight,
                      color: AppColors.textInverse, size: 18),
                ],
              ),
            ),
          ),
          Expanded(
            child: _records.isEmpty
                ? _buildEmptyState('还没有运动记录', '开始记录您的运动，追踪健康进展')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExerciseRecordCard(_records[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRecordCard(ExerciseRecord record) {
    final typeLabel = ExerciseType.getLabel(record.exerciseType);
    final typeIcon = _getExerciseIcon(record.exerciseType);
    final hasStrengthDetail = record.exerciseType == 'strength' &&
        record.strengthDetail != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          record.exerciseName,
                          style: AppTextStyles.h6.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.formattedDate,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.formattedCalories,
                    style: AppTextStyles.h6.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.formattedDuration,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18),
                color: AppColors.textTertiary,
                onPressed: () => _showDeleteConfirmation(record),
              ),
            ],
          ),
          // 力量训练详情展示
          if (hasStrengthDetail) ...[
            const SizedBox(height: 12),
            _buildStrengthDetailDisplay(record.strengthDetail!),
          ],
        ],
      ),
    );
  }

  Widget _buildStrengthDetailDisplay(Map<String, dynamic> detail) {
    final muscleGroups =
        (detail['muscle_groups'] as List<dynamic>?)?.cast<String>() ?? [];
    final sets =
        (detail['sets'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (muscleGroups.isNotEmpty) ...[
            Row(
              children: [
                const Icon(LucideIcons.target, size: 14, color: Color(0xFF66BB6A)),
                const SizedBox(width: 6),
                Text('训练肌群',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF66BB6A),
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: muscleGroups.map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(g,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF66BB6A),
                    )),
              )).toList(),
            ),
            if (sets.isNotEmpty) const SizedBox(height: 10),
          ],
          if (sets.isNotEmpty) ...[
            Row(
              children: [
                const Icon(LucideIcons.dumbbell, size: 14, color: Color(0xFF66BB6A)),
                const SizedBox(width: 6),
                Text('训练内容',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF66BB6A),
                    )),
              ],
            ),
            const SizedBox(height: 6),
            ...sets.map((s) {
              final item = s as Map<String, dynamic>;
              final exercise = item['exercise'] as String? ?? '';
              final setCount = item['sets'] as int? ?? 0;
              final reps = item['reps'] as int? ?? 0;
              final weight = item['weight_kg'] as num?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(exercise,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          )),
                    ),
                    Text(
                      '$setCount组×$reps次${weight != null ? ' ${weight}kg' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  IconData _getExerciseIcon(String type) {
    switch (type) {
      case 'running':
        return LucideIcons.bike;
      case 'walking':
        return LucideIcons.footprints;
      case 'cycling':
        return LucideIcons.bike;
      case 'swimming':
        return LucideIcons.waves;
      case 'yoga':
        return LucideIcons.heart;
      case 'strength':
        return LucideIcons.dumbbell;
      case 'hiit':
        return LucideIcons.zap;
      case 'dance':
        return LucideIcons.music;
      case 'basketball':
      case 'football':
        return LucideIcons.trophy;
      case 'badminton':
      case 'tennis':
        return LucideIcons.target;
      default:
        return LucideIcons.activity;
    }
  }

  Widget _buildStatisticsTab() {
    if (_records.isEmpty) {
      return _buildEmptyState('还没有运动记录', '开始记录运动后即可查看统计图表');
    }

    // 按天汇总过去7天的运动数据
    final now = DateTime.now();
    final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dailyData = <_ExerciseDailyStat>[];
    double maxCalories = 0;

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayRecords =
          _records.where((r) => r.recordedAt.startsWith(dateStr)).toList();

      final calories =
          dayRecords.fold<double>(0, (sum, r) => sum + r.caloriesBurned);
      final duration =
          dayRecords.fold<int>(0, (sum, r) => sum + r.durationMinutes);
      final count = dayRecords.length;

      dailyData.add(_ExerciseDailyStat(
        date: date,
        label: dayNames[date.weekday - 1],
        calories: calories,
        duration: duration,
        count: count,
      ));

      if (calories > maxCalories) maxCalories = calories;
    }

    // 本周汇总
    final weekCal = dailyData.fold<double>(0, (sum, d) => sum + d.calories);
    final weekDur = dailyData.fold<int>(0, (sum, d) => sum + d.duration);
    final weekCnt = dailyData.fold<int>(0, (sum, d) => sum + d.count);
    final activeDays = dailyData.where((d) => d.count > 0).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 本周统计卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.trendingUp,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('本周运动统计',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatItem('总消耗', '${weekCal.toInt()}', 'kcal',
                          LucideIcons.flame),
                      _buildStatItem(
                          '总时长', '$weekDur', '分钟', LucideIcons.clock),
                      _buildStatItem(
                          '运动次数', '$weekCnt', '次', LucideIcons.repeat),
                      _buildStatItem('活跃天数', '$activeDays', '天',
                          LucideIcons.calendarCheck),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 每日消耗柱状图
            _buildSectionTitle('每日消耗 (kcal)', LucideIcons.barChart3),
            const SizedBox(height: 12),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.lightShadow,
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCalories > 0 ? maxCalories * 1.3 : 300,
                  barGroups: dailyData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.calories,
                          color: e.value.count > 0
                              ? const Color(0xFFFF6B6B)
                              : AppColors.borderLight,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= dailyData.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              dailyData[idx].label,
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
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 运动类型分布
            _buildSectionTitle('运动类型分布', LucideIcons.pieChart),
            const SizedBox(height: 12),
            _buildExerciseTypeDistribution(),
            const SizedBox(height: 24),

            // 周运动时长趋势
            _buildSectionTitle('每日运动时长 (分钟)', LucideIcons.activity),
            const SizedBox(height: 12),
            Container(
              height: 160,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.lightShadow,
              ),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY:
                      dailyData.map((d) => d.duration.toDouble()).reduce(max) *
                          1.3,
                  lineBarsData: [
                    LineChartBarData(
                      spots: dailyData
                          .asMap()
                          .entries
                          .map((e) => FlSpot(
                              e.key.toDouble(), e.value.duration.toDouble()))
                          .toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= dailyData.length)
                            return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(dailyData[idx].label,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary)),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseTypeDistribution() {
    // 按类型汇总
    final typeMap = <String, _ExerciseTypeStat>{};
    for (final r in _records) {
      final key = r.exerciseType;
      if (typeMap.containsKey(key)) {
        typeMap[key] = typeMap[key]!.addRecord(r);
      } else {
        typeMap[key] = _ExerciseTypeStat(
            type: r.exerciseType,
            count: 1,
            calories: r.caloriesBurned,
            duration: r.durationMinutes);
      }
    }

    final typeList = typeMap.values.toList()
      ..sort((a, b) => b.calories.compareTo(a.calories));

    if (typeList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: Text('暂无运动数据',
                style: TextStyle(color: AppColors.textTertiary))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: typeList.map((t) {
          final total = typeList.fold<double>(0, (s, i) => s + i.calories);
          final pct =
              total > 0 ? (t.calories / total * 100).toStringAsFixed(0) : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getTypeColor(t.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getExerciseIcon(t.type),
                      size: 18, color: _getTypeColor(t.type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(ExerciseType.getLabel(t.type),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Text('${t.calories.toInt()} kcal',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: total > 0 ? t.calories / total : 0,
                          backgroundColor:
                              _getTypeColor(t.type).withValues(alpha: 0.1),
                          valueColor:
                              AlwaysStoppedAnimation(_getTypeColor(t.type)),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'running':
        return const Color(0xFFFF6B6B);
      case 'walking':
        return const Color(0xFF4ECDC4);
      case 'cycling':
        return const Color(0xFFFFA726);
      case 'swimming':
        return const Color(0xFF42A5F5);
      case 'yoga':
        return const Color(0xFFAB47BC);
      case 'strength':
        return const Color(0xFF66BB6A);
      case 'hiit':
        return const Color(0xFFEF5350);
      case 'dance':
        return const Color(0xFFEC4899);
      default:
        return AppColors.primary;
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.dumbbell,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddExerciseModal(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('添加记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExerciseModal(
        onRecordAdded: _loadData,
        exerciseService: _exerciseService,
        crowdTag: _crowdTag,
      ),
    );
  }

  void _showDeleteConfirmation(ExerciseRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record.exerciseName}」的运动记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final recordId = int.tryParse(record.id);
              if (recordId == null) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('删除失败: 无效的记录ID'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
                return;
              }
              final result =
                  await _exerciseService.deleteRemoteExerciseRecord(recordId);
              if (result.success) {
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('运动记录已删除'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('删除失败: ${result.message}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverse,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

// Helper models for statistics tab
class _ExerciseDailyStat {
  final DateTime date;
  final String label;
  final double calories;
  final int duration;
  final int count;

  const _ExerciseDailyStat({
    required this.date,
    required this.label,
    required this.calories,
    required this.duration,
    required this.count,
  });
}

class _StrengthSetEntry {
  final exerciseController = TextEditingController();
  final setsController = TextEditingController();
  final repsController = TextEditingController();
  final weightController = TextEditingController();
}

class _ExerciseTypeStat {
  final String type;
  int count;
  double calories;
  int duration;

  _ExerciseTypeStat({
    required this.type,
    required this.count,
    required this.calories,
    required this.duration,
  });

  _ExerciseTypeStat addRecord(ExerciseRecord r) {
    count++;
    calories += r.caloriesBurned;
    duration += r.durationMinutes;
    return this;
  }
}

class _AddExerciseModal extends StatefulWidget {
  final VoidCallback onRecordAdded;
  final ExerciseService exerciseService;
  final String? crowdTag;

  const _AddExerciseModal({
    required this.onRecordAdded,
    required this.exerciseService,
    this.crowdTag,
  });

  @override
  State<_AddExerciseModal> createState() => _AddExerciseModalState();
}

class _AddExerciseModalState extends State<_AddExerciseModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'running';
  bool _isAutoCalories = true;
  bool _isSubmitting = false;

  // 力量训练详情
  final List<String> _selectedMuscleGroups = [];
  final List<_StrengthSetEntry> _strengthSets = [];

  static const List<String> _muscleGroupOptions = [
    '胸', '背', '肩', '二头', '三头', '核心', '大腿', '小腿', '臀',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateAutoCalories() {
    if (!_isAutoCalories) return;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final calories =
        widget.exerciseService.estimateCalories(_selectedType, duration);
    _caloriesController.text = calories.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: bottomPadding + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '记录运动',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '运动类型',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: 8),
              _buildExerciseTypeGrid(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '运动名称（可选）',
                  hintText: '例如：晨跑、游泳训练',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.tag, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '运动时长（分钟）',
                  hintText: '例如：30',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.clock, size: 20),
                  suffixText: '分钟',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入运动时长';
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) return '请输入有效时长';
                  return null;
                },
                onChanged: (_) => _updateAutoCalories(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '消耗热量',
                    style: AppTextStyles.labelLarge,
                  ),
                  const Spacer(),
                  Text(
                    _isAutoCalories ? '自动估算' : '手动输入',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Switch(
                    value: _isAutoCalories,
                    onChanged: (v) {
                      setState(() => _isAutoCalories = v);
                      if (v) _updateAutoCalories();
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                enabled: !_isAutoCalories,
                decoration: InputDecoration(
                  labelText: '消耗热量（kcal）',
                  hintText: '例如：200',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.flame, size: 20),
                  suffixText: 'kcal',
                  filled: _isAutoCalories,
                  fillColor: _isAutoCalories
                      ? AppColors.backgroundSecondary
                      : Colors.transparent,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入消耗热量';
                  final val = double.tryParse(v);
                  if (val == null || val < 0) return '请输入有效热量';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '记录运动感受或其他信息',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(LucideIcons.fileText, size: 20),
                  ),
                ),
              ),
              // 力量训练详情（健身用户展示完整详情，非健身用户展示简化提示）
              if (_selectedType == 'strength') ...[
                const SizedBox(height: 20),
                if (widget.crowdTag == '健身')
                  _buildStrengthDetailSection()
                else
                  _buildSimplifiedStrengthHint(),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textInverse),
                          ),
                        )
                      : const Text(
                          '保存记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTypeGrid() {
    List<MapEntry<String, String>> entries = ExerciseType.entries.toList();
    // 健身用户将力量训练排到第一个
    if (widget.crowdTag == '健身') {
      final strengthIdx = entries.indexWhere((e) => e.key == 'strength');
      if (strengthIdx > 0) {
        final strength = entries.removeAt(strengthIdx);
        entries.insert(0, strength);
      }
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final isSelected = _selectedType == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedType = entry.key);
            _updateAutoCalories();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStrengthDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.dumbbell, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('力量训练详情',
                style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        // 肌群选择
        Text('训练肌群', style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _muscleGroupOptions.map((group) {
            final isSelected = _selectedMuscleGroups.contains(group);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedMuscleGroups.remove(group);
                  } else {
                    _selectedMuscleGroups.add(group);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(group,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // 训练组列表
        Row(
          children: [
            Text('训练组', style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w500)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _strengthSets.add(_StrengthSetEntry());
                });
              },
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('添加组'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._strengthSets.asMap().entries.map((entry) {
          final idx = entry.key;
          final set = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('组 ${idx + 1}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() => _strengthSets.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: set.exerciseController,
                          decoration: InputDecoration(
                            labelText: '动作',
                            hintText: '卧推',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: set.setsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '组数',
                            hintText: '4',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: set.repsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '次数',
                            hintText: '12',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: set.weightController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'kg',
                            hintText: '60',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSimplifiedStrengthHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF66BB6A).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 18, color: Color(0xFF66BB6A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '切换至「健身」人群标签可记录训练肌群、组数×次数、负重等详情',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();

      // 构建力量训练详情
      Map<String, dynamic>? strengthDetail;
      if (_selectedType == 'strength' &&
          (_selectedMuscleGroups.isNotEmpty || _strengthSets.isNotEmpty)) {
        strengthDetail = {
          'muscle_groups': _selectedMuscleGroups,
          'sets': _strengthSets
              .where((s) => s.exerciseController.text.trim().isNotEmpty)
              .map((s) => {
                    'exercise': s.exerciseController.text.trim(),
                    'sets': int.tryParse(s.setsController.text) ?? 0,
                    'reps': int.tryParse(s.repsController.text) ?? 0,
                    'weight_kg': double.tryParse(s.weightController.text),
                  })
              .where((s) => (s['sets'] as int) > 0 && (s['reps'] as int) > 0)
              .toList(),
        };
      }

      final result = await widget.exerciseService.createRemoteExerciseRecord(
        exerciseName:
            name.isEmpty ? ExerciseType.getLabel(_selectedType) : name,
        exerciseType: _selectedType,
        durationMinutes: int.parse(_durationController.text),
        caloriesBurned: double.parse(_caloriesController.text),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        strengthDetail: strengthDetail,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onRecordAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor:
                result.success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
