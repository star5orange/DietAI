import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import '../../../../shared/presentation/widgets/water_intake_widget.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../widgets/food_record_modal.dart';
import '../../../camera/presentation/pages/camera_page.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../health/presentation/pages/exercise_record_page.dart';
import '../../../pet/presentation/providers/pet_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'meal_selection_page.dart';
import 'text_describe_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final FoodService _foodService = FoodService();
  List<FoodRecord> _todayRecords = [];
  DailyNutritionSummary? _dailySummary;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  double _targetCalories = 2000.0;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    await _loadDataForDate(DateTime.now());
  }

  Future<void> _loadDataForDate(DateTime date) async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final result = await _foodService.getFoodRecords(
        startDate: dateStr,
        endDate: dateStr,
      );
      DailyNutritionSummary? summary;
      try {
        final summaryResult =
            await _foodService.getDailyNutritionSummary(dateStr);
        summary = summaryResult.data;
      } catch (_) {}

      if (mounted) {
        setState(() {
          _todayRecords = result.data?.records ?? [];
          _dailySummary = summary;
          _isLoading = false;
        });
        _updatePetState();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showError(context, e.toString());
      }
    }
  }

  void _updatePetState() {
    final currentCalories = _dailySummary?.totalCalories ?? 0.0;
    final noRecordToday = _todayRecords.isEmpty;
    ref.read(petProvider.notifier).updateState(
          consumed: currentCalories,
          target: _targetCalories,
          noRecordToday: noRecordToday,
        );
  }

  Future<void> _refreshData() async {
    await _loadTodayData();
    ref.read(petProvider.notifier).onFoodRecorded();
  }

  @override
  Widget build(BuildContext context) {
    final currentCalories = _dailySummary?.totalCalories ?? 0.0;
    final remainingCalories = (_targetCalories - currentCalories).round();
    final userProfile = ref.watch(userProfileProvider).value;
    final crowdTag = userProfile?.crowdTag ?? '普通';

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const ChatPage(sessionType: 1, title: 'AI营养顾问'),
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 6,
        heroTag: 'ai_chat_fab',
        child: const Icon(LucideIcons.messageCircle,
            size: 28, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildDateSelector(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                color: AppColors.primary,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        _buildCrowdTagHighlight(crowdTag),
                        const SizedBox(height: 20),
                        _buildCalorieCard(
                            remainingCalories, currentCalories, crowdTag),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: SizedBox(
                                height: 300,
                                child: WaterIntakeWidget(onTapDetails: () {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildExerciseQuickEntry(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildHealthTipCard(),
                        const SizedBox(height: 24),
                        _buildFoodIntakeSection(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateText = isToday ? '今天' : DateFormat('M月d日').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.backgroundCard,
      child: Row(
        children: [
          Text(dateText, style: AppTextStyles.headlineSmall),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      height: 80,
      color: AppColors.backgroundCard,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          // 计算本周一的日期
          final now = DateTime.now();
          final monday = now.subtract(Duration(days: now.weekday - 1));
          final date = monday.add(Duration(days: index));
          final isSelected = _isSameDay(date, _selectedDate);
          final today = DateTime(now.year, now.month, now.day);
          final isFutureDate =
              DateTime(date.year, date.month, date.day).isAfter(today);
          final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

          return GestureDetector(
            onTap: isFutureDate
                ? null
                : () {
                    setState(() => _selectedDate = date);
                    _loadDataForDate(date);
                  },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.primaryGradient : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Opacity(
                opacity: isFutureDate ? 0.35 : 1.0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNames[date.weekday - 1],
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.textInverse
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        color: isSelected
                            ? AppColors.textInverse
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalorieCard(
      int remainingCalories, double currentCalories, String crowdTag) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      crowdTag == '减脂'
                          ? '热量缺口'
                          : crowdTag == '健身'
                              ? '能量摄入'
                              : '卡路里摄入',
                      style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text(
                      crowdTag == '减脂'
                          ? '今日热量缺口 ${remainingCalories >= 0 ? remainingCalories : 0} kcal'
                          : crowdTag == '健身'
                              ? '蛋白质目标 150g'
                              : '每日目标 ${_targetCalories.round()} kcal',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: _showEditCalorieGoalDialog,
                icon: const Icon(LucideIcons.edit2, size: 20),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppColors.borderLight, width: 8),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: currentCalories / _targetCalories > 1.0
                          ? 1.0
                          : currentCalories / _targetCalories,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        remainingCalories >= 0
                            ? AppColors.primary
                            : AppColors.warning,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          remainingCalories >= 0
                              ? '$remainingCalories'
                              : '${remainingCalories.abs()}',
                          style: AppTextStyles.numberLarge
                              .copyWith(color: AppColors.textPrimary),
                        ),
                        Text(
                          remainingCalories >= 0 ? '剩余 kcal' : '超出 kcal',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: remainingCalories >= 0
                                ? AppColors.textTertiary
                                : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildMacroNutrientsCard(),
        ],
      ),
    );
  }

  Widget _buildExerciseQuickEntry() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
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
              Icon(LucideIcons.dumbbell,
                  color: AppColors.textInverse, size: 20),
              SizedBox(width: 8),
              Text('运动记录',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textInverse)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.footprints,
                      color: AppColors.whiteWithOpacity(0.7), size: 40),
                  const SizedBox(height: 8),
                  const Text('动起来！',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textInverse)),
                  const SizedBox(height: 4),
                  Text('记录你的运动',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.whiteWithOpacity(0.7))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExerciseRecordPage()),
            ).then((_) => _refreshData()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.whiteWithOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.whiteWithOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.plus,
                      color: AppColors.textInverse, size: 16),
                  SizedBox(width: 6),
                  Text('记录运动',
                      style: TextStyle(
                          color: AppColors.textInverse,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTipCard() {
    final userProfile = ref.watch(userProfileProvider).value;
    final crowdTag = userProfile?.crowdTag ?? '普通';
    final constitution = userProfile?.constitutionType ?? '平和质';
    final tip = _getPersonalizedTip(crowdTag, constitution);

    return GestureDetector(
      onTap: () => context.push('/wellness'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.lightShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: tip.gradient,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
              child: Icon(tip.icon, color: AppColors.textInverse, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('今日养生',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: tip.tagColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tip.tagName,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: tip.tagColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(tip.description,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 根据体质、人群标签和当日饮食数据生成个性化养生建议
  _WellnessTip _getPersonalizedTip(String crowdTag, String constitution) {
    final cal = _dailySummary?.totalCalories ?? 0.0;
    final protein = _dailySummary?.totalProtein ?? 0.0;
    final fat = _dailySummary?.totalFat ?? 0.0;
    final carbs = _dailySummary?.totalCarbohydrates ?? 0.0;
    final fiber = _dailySummary?.totalFiber ?? 0.0;
    final sodium = _dailySummary?.totalSodium ?? 0.0;
    final noRecord = _todayRecords.isEmpty;

    // 节气标签（简化：按月份取）
    final month = DateTime.now().month;
    final solarTerms = {
      1: '大寒',
      2: '立春',
      3: '惊蛰',
      4: '清明',
      5: '立夏',
      6: '芒种',
      7: '小暑',
      8: '立秋',
      9: '白露',
      10: '寒露',
      11: '立冬',
      12: '大雪',
    };
    final term = solarTerms[month] ?? '芒种';

    // 优先基于当日饮食数据给出针对性建议
    if (noRecord) {
      return _WellnessTip(
        icon: LucideIcons.utensils,
        gradient: AppColors.primaryGradient,
        tagColor: AppColors.primary,
        tagName: constitution,
        description: '今日尚未记录饮食，及时记录可获取个性化养生建议',
      );
    }

    // 高钠提醒
    if (sodium > 2000) {
      return _WellnessTip(
        icon: LucideIcons.droplets,
        gradient: const LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF90CAF9)]),
        tagColor: const Color(0xFF42A5F5),
        tagName: term,
        description: '今日钠摄入偏高(${sodium.toInt()}mg)，建议多饮水、减少盐分，可食用冬瓜、薏仁利水',
      );
    }

    // 低纤维提醒
    if (fiber < 10) {
      return _WellnessTip(
        icon: LucideIcons.salad,
        gradient: const LinearGradient(
            colors: [Color(0xFF66BB6A), Color(0xFFA5D6A7)]),
        tagColor: const Color(0xFF66BB6A),
        tagName: term,
        description: '今日膳食纤维不足(${fiber.toInt()}g)，建议增加蔬果摄入，如燕麦、红薯、绿叶菜',
      );
    }

    // 按人群标签推荐
    if (crowdTag == '减脂') {
      if (cal > _targetCalories) {
        return _WellnessTip(
          icon: LucideIcons.flame,
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]),
          tagColor: const Color(0xFFFF6B6B),
          tagName: term,
          description: '今日热量已超标，建议晚餐以蔬菜为主，搭配30分钟有氧运动消耗多余热量',
        );
      }
      return _WellnessTip(
        icon: LucideIcons.flame,
        gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)]),
        tagColor: const Color(0xFFFF6B6B),
        tagName: term,
        description: '减脂期注意控制碳水比例，多食高蛋白低脂食物如鸡胸、鱼虾，避免油炸',
      );
    }

    if (crowdTag == '健身') {
      if (protein < 60) {
        return _WellnessTip(
          icon: LucideIcons.dumbbell,
          gradient: const LinearGradient(
              colors: [Color(0xFF4ECDC4), Color(0xFF6EE7DE)]),
          tagColor: const Color(0xFF4ECDC4),
          tagName: term,
          description: '今日蛋白质摄入不足(${protein.toInt()}g)，建议补充鸡蛋、牛奶或蛋白粉促进肌肉恢复',
        );
      }
      return _WellnessTip(
        icon: LucideIcons.dumbbell,
        gradient: const LinearGradient(
            colors: [Color(0xFF4ECDC4), Color(0xFF6EE7DE)]),
        tagColor: const Color(0xFF4ECDC4),
        tagName: term,
        description: '健身期注意训练后30分钟内补充蛋白质和碳水，保证充足睡眠促进恢复',
      );
    }

    if (crowdTag == '养生') {
      return _getConstitutionTip(constitution, term);
    }

    // 普通人群：按体质推荐
    return _getConstitutionTip(constitution, term);
  }

  /// 按中医体质推荐
  _WellnessTip _getConstitutionTip(String constitution, String term) {
    final cal = _dailySummary?.totalCalories ?? 0.0;
    final fat = _dailySummary?.totalFat ?? 0.0;

    switch (constitution) {
      case '阳虚质':
        return _WellnessTip(
          icon: LucideIcons.sun,
          gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
          tagColor: const Color(0xFFFF9800),
          tagName: term,
          description: '阳虚体质宜温补，多食羊肉、生姜、桂圆，少食生冷寒凉，注意保暖避寒',
        );
      case '阴虚质':
        return _WellnessTip(
          icon: LucideIcons.moon,
          gradient: const LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
          tagColor: const Color(0xFF9C27B0),
          tagName: term,
          description: '阴虚体质宜滋阴润燥，多食银耳、百合、枸杞，少食辛辣燥热之物',
        );
      case '气虚质':
        return _WellnessTip(
          icon: LucideIcons.wind,
          gradient: const LinearGradient(
              colors: [Color(0xFFFFC107), Color(0xFFFFD54F)]),
          tagColor: const Color(0xFFFFC107),
          tagName: term,
          description: '气虚体质宜补气健脾，多食山药、黄芪、红枣，避免过度劳累和剧烈运动',
        );
      case '痰湿质':
        if (fat > 65) {
          return _WellnessTip(
            icon: LucideIcons.droplets,
            gradient: const LinearGradient(
                colors: [Color(0xFF78909C), Color(0xFFB0BEC5)]),
            tagColor: const Color(0xFF78909C),
            tagName: term,
            description: '今日脂肪摄入偏高(${fat.toInt()}g)，痰湿体质宜清淡祛湿，多食薏仁、冬瓜、荷叶茶',
          );
        }
        return _WellnessTip(
          icon: LucideIcons.droplets,
          gradient: const LinearGradient(
              colors: [Color(0xFF78909C), Color(0xFFB0BEC5)]),
          tagColor: const Color(0xFF78909C),
          tagName: term,
          description: '痰湿体质宜健脾祛湿，少食甜腻厚味，多运动排汗，可饮薏仁红豆汤',
        );
      case '湿热质':
        return _WellnessTip(
          icon: LucideIcons.thermometer,
          gradient: const LinearGradient(
              colors: [Color(0xFFF44336), Color(0xFFEF9A9A)]),
          tagColor: const Color(0xFFF44336),
          tagName: term,
          description: '湿热体质宜清热利湿，多食绿豆、苦瓜、薏仁，少食辛辣油腻和甜食',
        );
      case '血瘀质':
        return _WellnessTip(
          icon: LucideIcons.heart,
          gradient: const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFFF48FB1)]),
          tagColor: const Color(0xFFE91E63),
          tagName: term,
          description: '血瘀体质宜活血化瘀，多食山楂、黑豆、醋，适量运动促进气血运行',
        );
      case '气郁质':
        return _WellnessTip(
          icon: LucideIcons.smile,
          gradient: const LinearGradient(
              colors: [Color(0xFF7E57C2), Color(0xFFB39DDB)]),
          tagColor: const Color(0xFF7E57C2),
          tagName: term,
          description: '气郁体质宜疏肝解郁，多食玫瑰花茶、佛手、柑橘类，保持心情舒畅',
        );
      case '特禀质':
        return _WellnessTip(
          icon: LucideIcons.shield,
          gradient: const LinearGradient(
              colors: [Color(0xFF26A69A), Color(0xFF80CBC4)]),
          tagColor: const Color(0xFF26A69A),
          tagName: term,
          description: '特禀体质宜益气固表，避免过敏原，饮食清淡均衡，增强免疫力',
        );
      default: // 平和质
        if (cal > _targetCalories * 1.1) {
          return _WellnessTip(
            icon: LucideIcons.leaf,
            gradient: AppColors.warningGradient,
            tagColor: AppColors.success,
            tagName: term,
            description: '今日热量摄入偏高，建议适当控制饮食量，增加蔬果比例，保持均衡',
          );
        }
        return _WellnessTip(
          icon: LucideIcons.leaf,
          gradient: AppColors.warningGradient,
          tagColor: AppColors.success,
          tagName: term,
          description: '平和体质保持均衡饮食即可，注意顺应节气调养，规律作息适度运动',
        );
    }
  }

  Widget _buildFoodIntakeSection() {
    final meals = [
      {
        'name': '早餐',
        'icon': LucideIcons.coffee,
        'gradient': AppColors.breakfastGradient,
        'type': 1
      },
      {
        'name': '午餐',
        'icon': LucideIcons.salad,
        'gradient': AppColors.lunchGradient,
        'type': 2
      },
      {
        'name': '晚餐',
        'icon': LucideIcons.moon,
        'gradient': AppColors.dinnerGradient,
        'type': 3
      },
      {
        'name': '加餐',
        'icon': LucideIcons.croissant,
        'gradient': AppColors.snackGradient,
        'type': 4
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('食物摄入', style: AppTextStyles.h4),
        const SizedBox(height: 16),
        ...meals.map((meal) => _buildMealItem(
              meal['name'] as String,
              meal['icon'] as IconData,
              meal['gradient'] as LinearGradient,
              meal['type'] as int,
            )),
      ],
    );
  }

  Widget _buildMealItem(
      String name, IconData icon, LinearGradient gradient, int mealType) {
    final mealRecords =
        _todayRecords.where((record) => record.mealType == mealType).toList();
    final mealCalories = mealRecords.fold<double>(
      0.0,
      (sum, record) {
        final calories = record.analysisResult?.nutritionFacts.totalCalories ??
            record.nutritionDetail?.calories ??
            0.0;
        return sum + calories;
      },
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textInverse, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _showMealRecordsModal(name, mealType),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w500)),
                  if (mealRecords.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(LucideIcons.zap,
                            size: 16, color: AppColors.caloriesColor),
                        const SizedBox(width: 4),
                        Text('${mealCalories.round()} kcal',
                            style: AppTextStyles.numberXSmall.copyWith(
                                color: AppColors.caloriesColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${mealRecords.length} 项食物',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text('还没有记录',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _showFoodRecordModal(name),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.plus,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('记录',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMealRecordsModal(String mealName, int mealType) {
    final mealRecords =
        _todayRecords.where((record) => record.mealType == mealType).toList();
    if (mealRecords.isEmpty) {
      _showFoodRecordModal(mealName);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('$mealName记录', style: AppTextStyles.h4),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showFoodRecordModal(mealName);
                    },
                    icon: const Icon(LucideIcons.plus,
                        size: 18, color: AppColors.primary),
                    label: const Text('添加',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: mealRecords.length,
                itemBuilder: (context, index) =>
                    _buildMealRecordItem(mealRecords[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealRecordItem(FoodRecord record) {
    final calories = record.analysisResult?.nutritionFacts.totalCalories ??
        record.nutritionDetail?.calories ??
        0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
            Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.backgroundTertiary),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  record.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.backgroundTertiary,
                    child: const Icon(LucideIcons.image,
                        color: AppColors.textHint, size: 24),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.backgroundTertiary),
              child: const Icon(LucideIcons.utensils,
                  color: AppColors.textHint, size: 24),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.foodName ?? '未命名食物',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('${calories.round()} kcal',
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.caloriesColor,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                  onPressed: () => _editFoodRecordName(record),
                  icon: const Icon(LucideIcons.edit2, size: 18),
                  color: AppColors.info),
              IconButton(
                  onPressed: () => _deleteFoodRecord(record),
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editFoodRecordName(FoodRecord record) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) =>
          _FoodNameDialog(initialValue: record.foodName ?? ''),
    );
    if (result != null && result != record.foodName) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('食物名称已更新为: $result'),
          backgroundColor: AppColors.success));
      _refreshData();
    }
  }

  Future<void> _deleteFoodRecord(FoodRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除食物记录', style: AppTextStyles.h4),
        content: Text('确定要删除"${record.foodName ?? '未命名食物'}"吗？此操作不可撤销。',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await _foodService.deleteFoodRecord(record.id);
      if (result.success || result.notFound) {
        final today = DateTime.now();
        final dateString =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        await _foodService.invalidateRecordsCache(dateString);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.notFound ? '记录已不存在，已从列表移除' : '食物记录已删除'),
            backgroundColor: AppColors.success));
        _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('删除失败: ${result.message}'),
            backgroundColor: AppColors.error));
      }
    }
  }

  void _showFoodRecordModal(String mealName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodRecordModal(
        mealName: mealName,
        onRecordMethod: (method) {
          Navigator.pop(context);
          _handleRecordMethod(method, mealName);
        },
      ),
    );
  }

  void _handleRecordMethod(String method, String mealName) {
    if (mealName == '早餐' ||
        mealName == '午餐' ||
        mealName == '晚餐' ||
        mealName == '加餐') {
      final mealType = _getMealTypeFromName(mealName);
      _executeRecordMethod(method, mealName, mealType);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MealSelectionPage(recordMethod: method)),
      ).then((result) {
        if (result != null) {
          _executeRecordMethod(
              method, result['mealName'] as String, result['mealType'] as int);
        }
      });
    }
  }

  void _executeRecordMethod(String method, String mealName, int mealType) {
    switch (method) {
      case 'ai_scan':
        Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        CameraPage(mealName: mealName, mealType: mealType)))
            .then((_) => _refreshData());
        break;
      case 'text_describe':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TextDescribePage(
                    mealName: mealName, mealType: mealType))).then((result) {
          if (result == true) _refreshData();
        });
        break;
      case 'voice_record':
        print('语音记录 - $mealName');
        break;
      case 'saved_meals':
        Navigator.pushNamed(context, '/saved-meals');
        break;
      case 'barcode_scan':
        print('条形码扫描 - $mealName');
        break;
    }
  }

  int _getMealTypeFromName(String mealName) {
    switch (mealName) {
      case '早餐':
        return 1;
      case '午餐':
        return 2;
      case '晚餐':
        return 3;
      case '加餐':
        return 4;
      case '夜宵':
        return 5;
      default:
        return 1;
    }
  }

  /// 根据人群标签显示差异化高亮卡片
  Widget _buildCrowdTagHighlight(String crowdTag) {
    if (crowdTag == '减脂') {
      final currentCalories = _dailySummary?.totalCalories ?? 0.0;
      final deficit = (_targetCalories - currentCalories).round();
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.flame, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('热量缺口追踪',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    deficit > 0 ? '还需消耗 $deficit kcal 达到目标' : '已达成今日减脂目标！',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                deficit > 0 ? '$deficit' : '0',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else if (crowdTag == '健身') {
      final protein = _dailySummary?.totalProtein ?? 0.0;
      const targetProtein = 150.0;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4ECDC4), Color(0xFF6EE7DE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.dumbbell, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('蛋白质摄入追踪',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    '今日已摄入 ${protein.round()}g / 目标 ${targetProtein.round()}g',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${protein.round()}g',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      // 普通或养生：均衡展示三大营养素比例
      final protein = _dailySummary?.totalProtein ?? 0.0;
      final carbs = _dailySummary?.totalCarbohydrates ?? 0.0;
      final fat = _dailySummary?.totalFat ?? 0.0;
      final total = protein + carbs + fat;
      final proteinPct =
          total > 0 ? (protein * 4 / (total * 4) * 100).round() : 0;
      final carbsPct = total > 0 ? (carbs * 4 / (total * 4) * 100).round() : 0;
      final fatPct = total > 0 ? (fat * 9 / (total * 4) * 100).round() : 0;

      // 判断均衡度
      final isBalanced = proteinPct >= 10 &&
          proteinPct <= 35 &&
          carbsPct >= 45 &&
          carbsPct <= 65 &&
          fatPct >= 20 &&
          fatPct <= 35;
      final statusText = total == 0
          ? '今日尚未记录饮食'
          : isBalanced
              ? '三大营养素比例均衡'
              : '营养素比例有待调整';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2BAF74), Color(0xFF4ECDC4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  total == 0
                      ? LucideIcons.utensils
                      : isBalanced
                          ? LucideIcons.checkCircle2
                          : LucideIcons.alertCircle,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(crowdTag == '养生' ? '养生均衡饮食' : '均衡饮食追踪',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(statusText,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMacroBar(
                        '蛋白质', proteinPct, 15, 35, const Color(0xFF4FC3F7)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroBar(
                        '碳水', carbsPct, 45, 65, const Color(0xFFFFB74D)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMacroBar(
                        '脂肪', fatPct, 20, 35, const Color(0xFFEF5350)),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// 营养素比例条
  Widget _buildMacroBar(
      String label, int pct, int minTarget, int maxTarget, Color color) {
    final inRange = pct >= minTarget && pct <= maxTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(
              inRange ? Colors.white : color,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 2),
        Text('$pct%',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: inRange ? Colors.white : color)),
      ],
    );
  }

  Future<void> _showEditCalorieGoalDialog() async {
    final result = await showDialog<double>(
      context: context,
      builder: (context) =>
          _CalorieGoalDialog(initialValue: _targetCalories.round().toString()),
    );
    if (result != null) {
      setState(() => _targetCalories = result);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('卡路里目标已设置为 ${result.round()} kcal'),
          backgroundColor: AppColors.success));
    }
  }

  Widget _buildMacroNutrientsCard() {
    final protein = _dailySummary?.totalProtein ?? 0.0;
    final carbs = _dailySummary?.totalCarbohydrates ?? 0.0;
    final fat = _dailySummary?.totalFat ?? 0.0;
    const targetProtein = 150.0;
    const targetCarbs = 250.0;
    const targetFat = 65.0;

    // 获取人群标签
    final userProfile = ref.watch(userProfileProvider).value;
    final crowdTag = userProfile?.crowdTag ?? '普通';

    // 根据人群标签决定展示顺序
    List<Map<String, dynamic>> nutrientList;
    if (crowdTag == '健身') {
      // 健身：蛋白质优先
      nutrientList = [
        {
          'name': '蛋白质',
          'current': protein,
          'target': targetProtein,
          'color': AppColors.proteinColor,
          'highlight': true
        },
        {
          'name': '碳水化合物',
          'current': carbs,
          'target': targetCarbs,
          'color': AppColors.carbsColor,
          'highlight': false
        },
        {
          'name': '脂肪',
          'current': fat,
          'target': targetFat,
          'color': AppColors.fatColor,
          'highlight': false
        },
      ];
    } else if (crowdTag == '减脂') {
      // 减脂：碳水控制优先
      nutrientList = [
        {
          'name': '碳水化合物',
          'current': carbs,
          'target': targetCarbs,
          'color': AppColors.carbsColor,
          'highlight': true
        },
        {
          'name': '蛋白质',
          'current': protein,
          'target': targetProtein,
          'color': AppColors.proteinColor,
          'highlight': false
        },
        {
          'name': '脂肪',
          'current': fat,
          'target': targetFat,
          'color': AppColors.fatColor,
          'highlight': false
        },
      ];
    } else {
      // 普通/养生：均衡展示
      nutrientList = [
        {
          'name': '蛋白质',
          'current': protein,
          'target': targetProtein,
          'color': AppColors.proteinColor,
          'highlight': false
        },
        {
          'name': '碳水化合物',
          'current': carbs,
          'target': targetCarbs,
          'color': AppColors.carbsColor,
          'highlight': false
        },
        {
          'name': '脂肪',
          'current': fat,
          'target': targetFat,
          'color': AppColors.fatColor,
          'highlight': false
        },
      ];
    }

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
          Text(
              crowdTag == '健身'
                  ? '今日营养重点'
                  : crowdTag == '减脂'
                      ? '热量来源分析'
                      : '今日宏观营养素',
              style: AppTextStyles.h4),
          const SizedBox(height: 16),
          ...nutrientList.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildNutrientProgress(
                  n['name'] as String,
                  n['current'] as double,
                  n['target'] as double,
                  n['color'] as Color,
                  isHighlight: n['highlight'] as bool,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildNutrientProgress(
      String name, double current, double target, Color color,
      {bool isHighlight = false}) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(name,
                    style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight:
                            isHighlight ? FontWeight.w700 : FontWeight.w500,
                        color: isHighlight ? color : AppColors.textPrimary)),
                if (isHighlight) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('重点关注',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                ],
              ],
            ),
            Text('${current.round()}g / ${target.round()}g',
                style: AppTextStyles.bodySmall.copyWith(
                    color: isHighlight ? color : AppColors.textSecondary,
                    fontWeight:
                        isHighlight ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: isHighlight ? 10 : 8,
          decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(isHighlight ? 5 : 4)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalorieGoalDialog extends StatefulWidget {
  final String initialValue;
  const _CalorieGoalDialog({required this.initialValue});

  @override
  State<_CalorieGoalDialog> createState() => _CalorieGoalDialogState();
}

class _CalorieGoalDialogState extends State<_CalorieGoalDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('设置每日卡路里目标', style: AppTextStyles.h4),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('请输入您的每日卡路里摄入目标',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '卡路里目标',
              suffixText: 'kcal',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 8),
          Text('建议范围：1200-3000 kcal',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(_controller.text);
            if (value != null && value >= 800 && value <= 5000) {
              Navigator.pop(context, value);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('请输入有效的卡路里值 (800-5000)'),
                  backgroundColor: AppColors.error));
            }
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse),
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 养生推荐数据模型
class _WellnessTip {
  final IconData icon;
  final LinearGradient gradient;
  final Color tagColor;
  final String tagName;
  final String description;

  const _WellnessTip({
    required this.icon,
    required this.gradient,
    required this.tagColor,
    required this.tagName,
    required this.description,
  });
}

class _FoodNameDialog extends StatefulWidget {
  final String initialValue;
  const _FoodNameDialog({required this.initialValue});

  @override
  State<_FoodNameDialog> createState() => _FoodNameDialogState();
}

class _FoodNameDialogState extends State<_FoodNameDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('编辑食物名称', style: AppTextStyles.h4),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
                labelText: '食物名称', border: OutlineInputBorder()),
            autofocus: true,
            maxLength: 100,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) Navigator.pop(context, name);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
