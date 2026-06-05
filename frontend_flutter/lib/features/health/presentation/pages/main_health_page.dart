import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/water_service.dart';
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
  DailyNutritionSummary? _dailySummary;
  double _waterIntake = 0.0;
  double _waterGoal = 2000.0;
  double _targetCalories = 2000.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final summaryResult =
          await _foodService.getDailyNutritionSummary(dateStr);
      final waterResult = await _waterService.getBackendWaterIntake(dateStr);

      if (mounted) {
        setState(() {
          _dailySummary = summaryResult.data;
          _waterIntake = waterResult.data ?? 0.0;
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
              const WaterIntakeWidget(),
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
    final waterDisplay = _waterIntake >= 1000
        ? '${(_waterIntake / 1000).toStringAsFixed(2)} / ${(_waterGoal / 1000).toStringAsFixed(2)}'
        : '${_waterIntake.toInt()} / ${(_waterGoal / 1000).toStringAsFixed(2)}';
    final waterUnit = _waterIntake >= 1000 ? 'L' : 'ml / L';
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
                  waterDisplay,
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
