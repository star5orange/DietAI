import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/water_service.dart';
import '../../../../services/health_analysis_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../health/presentation/pages/health_goals_page.dart';
import '../../../health/presentation/pages/weight_tracking_page.dart';
import '../../../health/presentation/pages/data_visualization_page.dart';
import '../../../health/presentation/pages/health_analysis_page.dart';
import '../../../health/presentation/pages/exercise_record_page.dart';
import '../../../health/presentation/pages/reminder_settings_page.dart';
import '../../../health/presentation/pages/constitution_quiz_page.dart';
import '../../../health/presentation/pages/wellness_page.dart';
import '../../../../shared/presentation/widgets/water_intake_widget.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
  final FoodService _foodService = FoodService();
  final WaterService _waterService = WaterService();
  final HealthAnalysisService _healthAnalysisService = HealthAnalysisService();
  DailyNutritionSummary? _dailySummary;
  double _waterIntake = 0.0;
  double _waterGoal = 2000.0;
  double _targetCalories = 2000.0;
  bool _isLoading = true;
  Map<String, dynamic>? _weeklySummary;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        _foodService.getDailyNutritionSummary(dateStr),
        _waterService.getDailySummary(dateStr),
        _healthAnalysisService.getWeeklySummary(),
      ]);

      if (mounted) {
        setState(() {
          _dailySummary = (results[0] as ApiResponse<DailyNutritionSummary>).data;
          _waterIntake = ((results[1] as ApiResponse).data?.totalMl ?? 0).toDouble();
          _weeklySummary = (results[2] as ApiResponse<Map<String, dynamic>>).data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('健康'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHealthSummaryCard(),
              const SizedBox(height: 24),
              if (_weeklySummary != null) ...[
                _buildWeeklySummaryCard(),
                const SizedBox(height: 24),
              ],
              WaterIntakeWidget(
                selectedDate: DateTime.now(),
              ),
              const SizedBox(height: 24),
              _buildFeatureGrid(context),
              const SizedBox(height: 24),
              _buildHealthTipsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard() {
    final calories = _dailySummary?.totalCalories ?? 0.0;

    // 统一单位显示水量：≥1000ml 用 L，否则用 ml，最多两位小数去尾部零
    String _fmtLiter(double ml) {
      final liters = ml / 1000;
      return liters.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }

    final useLiter = _waterGoal >= 1000;
    final waterIntakeDisplay =
        useLiter ? _fmtLiter(_waterIntake) : _waterIntake.toInt().toString();
    final waterGoalDisplay =
        useLiter ? _fmtLiter(_waterGoal) : _waterGoal.toInt().toString();
    final waterValue = '$waterIntakeDisplay / $waterGoalDisplay';
    final waterUnit = useLiter ? 'L' : 'ml';

    final caloriesProgress = _targetCalories > 0
        ? (calories / _targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final waterProgress =
        _waterGoal > 0 ? (_waterIntake / _waterGoal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
          Row(
            children: [
              Icon(
                LucideIcons.heart,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '今日健康概览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '卡路里',
                  '${_formatNumber(calories)} / ${_formatNumber(_targetCalories)}',
                  'kcal',
                  caloriesProgress,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '水分',
                  waterValue,
                  waterUnit,
                  waterProgress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '蛋白质',
                  '${_formatNumber(_dailySummary?.totalProtein ?? 0)}',
                  'g',
                  0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '用餐次数',
                  '${_dailySummary?.mealCount ?? 0}',
                  '次',
                  0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    final data = _weeklySummary!;
    final period = data['period'] as Map<String, dynamic>? ?? {};
    final trends = data['trends'] as Map<String, dynamic>? ?? {};
    final goalCompletion = data['goal_completion'] as Map<String, dynamic>? ?? {};
    final weightChange = data['weight_change'] as Map<String, dynamic>?;
    final summaryText = data['summary_text'] as String? ?? '';
    final crowdTag = data['crowd_tag'] as String? ?? '普通';
    final daysWithData = period['days_with_data'] as int? ?? 0;

    // 解析趋势数据
    final calTrend = trends['total_calories'] as Map<String, dynamic>? ?? {};
    final proteinTrend = trends['total_protein'] as Map<String, dynamic>? ?? {};
    final waterTrend = trends['water_intake'] as Map<String, dynamic>? ?? {};
    final exerciseTrend = trends['exercise_calories'] as Map<String, dynamic>? ?? {};

    // 解析目标完成率
    final calGoal = goalCompletion['calories'] as Map<String, dynamic>? ?? {};
    final proteinGoal = goalCompletion['protein'] as Map<String, dynamic>? ?? {};

    final startDate = period['start_date'] as String? ?? '';
    final endDate = period['end_date'] as String? ?? '';
    final periodLabel = _formatPeriodLabel(startDate, endDate);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.calendarRange,
                  color: Color(0xFF8B5CF6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '每周摘要',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysWithData >= 5
                      ? const Color(0xFF43A047).withValues(alpha: 0.1)
                      : const Color(0xFFFFA726).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$daysWithData/7天有数据',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: daysWithData >= 5
                        ? const Color(0xFF43A047)
                        : const Color(0xFFFFA726),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 核心指标趋势行
          Row(
            children: [
              Expanded(
                  child: _buildTrendItem(
                '热量',
                calTrend,
                LucideIcons.flame,
                const Color(0xFFFF6B6B),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildTrendItem(
                '蛋白质',
                proteinTrend,
                LucideIcons.beef,
                const Color(0xFF5B86E5),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildTrendItem(
                '饮水',
                waterTrend,
                LucideIcons.droplets,
                const Color(0xFF06B6D4),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildTrendItem(
                '运动',
                exerciseTrend,
                LucideIcons.dumbbell,
                const Color(0xFFF59E0B),
              )),
            ],
          ),
          const SizedBox(height: 16),

          // 目标完成率
          if (calGoal.isNotEmpty || proteinGoal.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.target,
                          size: 14, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 6),
                      Text(
                        '目标完成率',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (calGoal.isNotEmpty)
                        Expanded(
                            child: _buildGoalProgress(
                                '热量', calGoal, const Color(0xFFFF6B6B))),
                      if (calGoal.isNotEmpty && proteinGoal.isNotEmpty)
                        const SizedBox(width: 12),
                      if (proteinGoal.isNotEmpty)
                        Expanded(
                            child: _buildGoalProgress(
                                '蛋白质', proteinGoal, const Color(0xFF5B86E5))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 体重变化
          if (weightChange != null && weightChange['change_kg'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FAF0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.scale,
                      size: 16, color: Color(0xFF2BAF74)),
                  const SizedBox(width: 8),
                  const Text(
                    '体重变化',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2BAF74),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${weightChange['change_kg'] > 0 ? '+' : ''}${weightChange['change_kg']} kg',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: (weightChange['change_kg'] as num).toDouble() <= 0
                          ? const Color(0xFF2BAF74)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // AI摘要文字
          if (summaryText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.sparkles,
                      size: 16, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summaryText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建趋势指标小卡片
  Widget _buildTrendItem(
      String label, Map<String, dynamic> trend, IconData icon, Color color) {
    final direction = trend['direction'] as String? ?? '持平';
    final changePct = (trend['change_pct'] as num?)?.toDouble() ?? 0.0;
    final currentAvg = (trend['current_avg'] as num?)?.toDouble() ?? 0.0;

    IconData arrowIcon;
    Color arrowColor;
    switch (direction) {
      case '上升':
        arrowIcon = LucideIcons.trendingUp;
        arrowColor = const Color(0xFFFF6B6B);
        break;
      case '下降':
        arrowIcon = LucideIcons.trendingDown;
        arrowColor = const Color(0xFF2BAF74);
        break;
      default:
        arrowIcon = LucideIcons.minus;
        arrowColor = AppColors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            currentAvg > 0 ? currentAvg.toInt().toString() : '-',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Icon(arrowIcon, color: arrowColor, size: 14),
        ],
      ),
    );
  }

  /// 构建目标完成率进度条
  Widget _buildGoalProgress(String label, Map<String, dynamic> goal, Color color) {
    final completionPct =
        (goal['completion_pct'] as num?)?.toDouble() ?? 0.0;
    final actual = (goal['actual'] as num?)?.toDouble() ?? 0.0;
    final target = (goal['target'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text('${completionPct.toInt()}%',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (completionPct / 100).clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${actual.toInt()} / ${target.toInt()}',
          style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
        ),
      ],
    );
  }

  /// 格式化周期标签
  String _formatPeriodLabel(String startDate, String endDate) {
    try {
      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        final s = DateTime.parse(startDate);
        final e = DateTime.parse(endDate);
        return '${s.month}/${s.day} - ${e.month}/${e.day}';
      }
    } catch (_) {}
    return '本周';
  }

  String _formatNumber(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }

  Widget _buildSummaryItem(
      String title, String value, String unit, double progress) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: LucideIcons.target,
        title: '健康目标',
        subtitle: '设置和追踪健康目标',
        color: AppColors.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HealthGoalsPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.scale,
        title: '体重管理',
        subtitle: '记录和追踪体重变化',
        color: AppColors.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeightTrackingPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.barChart3,
        title: '数据分析',
        subtitle: '查看健康数据趋势',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const DataVisualizationPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.brain,
        title: 'AI健康分析',
        subtitle: '获取个性化健康建议',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HealthAnalysisPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.dumbbell,
        title: '运动记录',
        subtitle: '记录运动消耗热量',
        color: const Color(0xFF06B6D4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExerciseRecordPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.bell,
        title: '提醒设置',
        subtitle: '设置饮食健康提醒',
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReminderSettingsPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.clipboardCheck,
        title: '体质自测',
        subtitle: '了解您的中医体质',
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConstitutionQuizPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.leaf,
        title: '养生推荐',
        subtitle: '每日养生建议与食谱',
        color: const Color(0xFF43A047),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WellnessPage()),
        ),
      ),
    ];

    // 根据屏幕宽度自适应列数
    final screenWidth = MediaQuery.of(context).size.width;
    final crossCount = screenWidth >= 600 ? 4 : (screenWidth >= 400 ? 4 : 3);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(feature);
      },
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                feature.title,
                style: AppTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTipsCard() {
    final calories = _dailySummary?.totalCalories ?? 0.0;
    final protein = _dailySummary?.totalProtein ?? 0.0;
    final fat = _dailySummary?.totalFat ?? 0.0;
    final carbs = _dailySummary?.totalCarbohydrates ?? 0.0;
    final fiber = _dailySummary?.totalFiber ?? 0.0;
    final sodium = _dailySummary?.totalSodium ?? 0.0;
    final exerciseCal = _dailySummary?.exerciseCalories ?? 0.0;
    final remaining = _targetCalories - calories + exerciseCal;
    final waterRemaining = _waterGoal - _waterIntake;

    final userProfile = ref.watch(userProfileProvider).value;
    final crowdTag = userProfile?.crowdTag ?? '普通';
    final constitution = userProfile?.constitutionType ?? '平和质';

    // 动态生成贴士列表
    final tips = <MapEntry<String, String>>[];

    // 饮水提示
    if (waterRemaining > 0) {
      tips.add(MapEntry('💧 记得多喝水',
          '今天的饮水量还差${(waterRemaining / 1000).toStringAsFixed(2)}L，保持充足水分有助于新陈代谢。'));
    } else if (_waterIntake > 0) {
      tips.add(MapEntry('💧 饮水达标', '今天的饮水量已达标，继续保持！'));
    }

    // 热量提示
    if (calories == 0) {
      tips.add(MapEntry('🍽️ 开始记录', '今日尚未记录饮食，及时记录可获取个性化建议。'));
    } else if (remaining > 0) {
      tips.add(MapEntry('🍽️ 热量预算', '今日还可摄入约${remaining.toInt()}kcal，注意营养均衡。'));
    } else if (remaining < 0) {
      tips.add(MapEntry(
          '⚠️ 热量超标', '今日热量已超出目标${(-remaining).toInt()}kcal，建议适当增加运动。'));
    } else {
      tips.add(MapEntry('🍽️ 热量达标', '今日热量摄入已达到目标，注意保持营养均衡。'));
    }

    // 高钠提醒
    if (sodium > 2000) {
      tips.add(
          MapEntry('🧂 钠摄入偏高', '今日钠摄入${sodium.toInt()}mg，建议减少盐分，多食冬瓜、薏仁利水。'));
    }

    // 低纤维提醒
    if (fiber < 10 && calories > 0) {
      tips.add(
          MapEntry('🥦 膳食纤维不足', '今日膳食纤维仅${fiber.toInt()}g，建议增加蔬果如燕麦、红薯、绿叶菜。'));
    }

    // 蛋白质提醒
    if (protein < 40 && calories > 0) {
      tips.add(
          MapEntry('🥚 蛋白质不足', '今日蛋白质仅${protein.toInt()}g，建议补充鸡蛋、牛奶、鱼虾等优质蛋白。'));
    }

    // 运动提醒
    if (exerciseCal > 0) {
      tips.add(
          MapEntry('🏃 运动消耗', '今日运动消耗${exerciseCal.toInt()}kcal，继续保持运动习惯！'));
    } else if (calories > _targetCalories * 0.5) {
      tips.add(MapEntry('🏃 适量运动', '今日尚未记录运动，适当活动有助于消耗多余热量。'));
    }

    // 体质相关提示
    final constitutionTip = _getConstitutionTip(constitution, crowdTag);
    if (constitutionTip != null) {
      tips.add(constitutionTip);
    }

    // 人群标签提示
    if (crowdTag == '减脂' && fat > 65) {
      tips.add(
          MapEntry('🔥 脂肪偏高', '今日脂肪摄入${fat.toInt()}g，减脂期建议控制油脂，选择低脂烹饪方式。'));
    } else if (crowdTag == '健身' && protein >= 60) {
      tips.add(
          MapEntry('💪 蛋白质充足', '今日蛋白质${protein.toInt()}g，健身期保持蛋白质摄入有助于肌肉恢复。'));
    }

    // 限制最多显示5条
    final displayTips = tips.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
              Icon(
                LucideIcons.lightbulb,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '今日健康小贴士',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayTips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildHealthTip(tip.key, tip.value),
              )),
        ],
      ),
    );
  }

  /// 根据体质和人群标签返回个性化贴士
  MapEntry<String, String>? _getConstitutionTip(
      String constitution, String crowdTag) {
    switch (constitution) {
      case '阳虚质':
        return MapEntry('☀️ 阳虚体质', '宜温补，多食羊肉、生姜、桂圆，少食生冷寒凉，注意保暖避寒。');
      case '阴虚质':
        return MapEntry('🌙 阴虚体质', '宜滋阴润燥，多食银耳、百合、枸杞，少食辛辣燥热之物。');
      case '气虚质':
        return MapEntry('💨 气虚体质', '宜补气健脾，多食山药、黄芪、红枣，避免过度劳累。');
      case '痰湿质':
        return MapEntry('💧 痰湿体质', '宜健脾祛湿，少食甜腻厚味，多运动排汗，可饮薏仁红豆汤。');
      case '湿热质':
        return MapEntry('🌡️ 湿热体质', '宜清热利湿，多食绿豆、苦瓜、薏仁，少食辛辣油腻。');
      case '血瘀质':
        return MapEntry('❤️ 血瘀体质', '宜活血化瘀，多食山楂、黑豆、醋，适量运动促进气血运行。');
      case '气郁质':
        return MapEntry('😊 气郁体质', '宜疏肝解郁，多食玫瑰花茶、佛手、柑橘类，保持心情舒畅。');
      case '特禀质':
        return MapEntry('🛡️ 特禀体质', '宜益气固表，避免过敏原，饮食清淡均衡，增强免疫力。');
      default:
        return null;
    }
  }

  Widget _buildHealthTip(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
