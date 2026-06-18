import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/food_service.dart';
import '../../../../services/exercise_service.dart';
import '../../../../services/saved_meal_service.dart';
import '../../../../services/goal_tracking_service.dart';
import '../../../../services/wellness_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import '../../../../shared/presentation/widgets/water_intake_widget.dart';
import '../../../../shared/presentation/widgets/exercise_quick_add.dart';
import '../../../../shared/presentation/widgets/solar_term_today_widget.dart';
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
import '../../../saved_meals/presentation/pages/saved_meals_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Offset _fabOffset = const Offset(0, 0);
  bool _fabInitialized = false;
  final FoodService _foodService = FoodService();
  List<FoodRecord> _todayRecords = [];
  DailyNutritionSummary? _dailySummary;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  double _targetCalories = 2000.0;
  double _targetProtein = 150.0;
  double _targetCarbs = 250.0;
  double _targetFat = 65.0;
  final GoalTrackingService _goalTrackingService = GoalTrackingService();
  int _streakDays = 0;
  final WellnessService _wellnessService = WellnessService();
  String? _solarTermChanged; // 节气切换时显示新节气名，null表示无切换
  String? _solarTermWellness; // 新节气养生要点
  Map<String, dynamic>? _upcomingSolarTerm; // 即将到来的节气（3天内）
  final ExerciseService _exerciseService = ExerciseService();
  final SavedMealService _savedMealService = SavedMealService();
  double _todayExerciseCalories = 0.0;
  int _todayExerciseDuration = 0;
  List<SavedMeal> _favoriteMeals = [];

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    await _loadDataForDate(DateTime.now());
    _checkSolarTermChange();
  }

  /// 检测节气是否切换，如果切换则显示通知横幅
  Future<void> _checkSolarTermChange() async {
    try {
      final result = await _wellnessService.getCurrentSolarTerm();
      if (!result.success || result.data == null) return;

      final currentTerm = result.data!['name'] as String? ?? '';
      final wellness = result.data!['wellness'] as String? ?? '';
      final upcoming = result.data!['upcoming'] as Map<String, dynamic>?;
      final prefs = await SharedPreferences.getInstance();
      final lastTerm = prefs.getString('last_solar_term') ?? '';

      if (lastTerm.isNotEmpty && currentTerm != lastTerm) {
        // 节气已切换
        if (mounted) {
          setState(() {
            _solarTermChanged = currentTerm;
            _solarTermWellness = wellness;
          });
        }
      }

      // 检查即将到来的节气（3天内）
      if (upcoming != null && mounted) {
        final upcomingName = upcoming['name'] as String? ?? '';
        final daysAhead = upcoming['days_ahead'] as int? ?? 0;
        final lastUpcoming = prefs.getString('last_upcoming_solar_term') ?? '';
        // 仅当节气预告未展示过时显示
        if (upcomingName.isNotEmpty && '$upcomingName$daysAhead' != lastUpcoming) {
          setState(() => _upcomingSolarTerm = upcoming);
        }
      }

      // 更新缓存的节气
      await prefs.setString('last_solar_term', currentTerm);
    } catch (_) {
      // 非关键功能，静默失败
    }
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

      // 加载连续打卡天数
      try {
        final userService = ref.read(userServiceProvider);
        final statsResult = await userService.getUserStats();
        if (statsResult.isSuccess && statsResult.data != null) {
          _streakDays = statsResult.data!.streakDays;
        }
      } catch (_) {}

      // 加载今日运动数据
      try {
        final exerciseResult =
            await _exerciseService.getDailySummary(dateStr);
        if (exerciseResult.success && exerciseResult.data != null) {
          _todayExerciseCalories =
              exerciseResult.data!.totalCaloriesBurned;
          _todayExerciseDuration =
              exerciseResult.data!.totalDurationMinutes;
        }
      } catch (_) {}

      // 加载收藏餐食（取前6个常用）
      try {
        final mealsResult = await _savedMealService.getSavedMeals(pageSize: 6);
        if (mealsResult.success && mealsResult.data != null) {
          _favoriteMeals = mealsResult.data!;
        }
      } catch (_) {}

      // 加载个性化每日营养目标
      try {
        final goalResult = await _goalTrackingService.getDailyStatus();
        if (goalResult.success && goalResult.data != null) {
          final targets = goalResult.data!['daily_targets'] as Map<String, dynamic>?;
          if (targets != null) {
            _targetCalories = (targets['calories'] as num?)?.toDouble() ?? _targetCalories;
            _targetProtein = (targets['protein'] as num?)?.toDouble() ?? _targetProtein;
            _targetCarbs = (targets['carbs'] as num?)?.toDouble() ?? _targetCarbs;
            _targetFat = (targets['fat'] as num?)?.toDouble() ?? _targetFat;
          }
        }
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
    await _loadDataForDate(_selectedDate);
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
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          // 初始化位置：右下角默认FAB位置
          if (!_fabInitialized) {
            _fabOffset = Offset(
              constraints.maxWidth - 64,
              constraints.maxHeight - 160,
            );
            _fabInitialized = true;
          }
          return Stack(
            children: [
              Positioned(
                left: _fabOffset.dx,
                top: _fabOffset.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _fabOffset = Offset(
                        (_fabOffset.dx + details.delta.dx)
                            .clamp(0, constraints.maxWidth - 56),
                        (_fabOffset.dy + details.delta.dy)
                            .clamp(0, constraints.maxHeight - 56),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    // 松手后吸附到左侧或右侧
                    setState(() {
                      final snapLeft = _fabOffset.dx < constraints.maxWidth / 2;
                      _fabOffset = Offset(
                        snapLeft ? 16.0 : constraints.maxWidth - 72,
                        _fabOffset.dy,
                      );
                    });
                  },
                  child: FloatingActionButton(
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
                ),
              ),
            ],
          );
        },
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
                                child: WaterIntakeWidget(
                                  onTapDetails: () {},
                                  selectedDate: _selectedDate,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 300,
                                child: ExerciseQuickAdd(
                                  todayCalories: _todayExerciseCalories > 0
                                      ? _todayExerciseCalories
                                      : null,
                                  todayDuration: _todayExerciseDuration > 0
                                      ? _todayExerciseDuration
                                      : null,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ExerciseRecordPage()),
                                  ).then((_) => _refreshData()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // 节气切换通知横幅
                        if (_solarTermChanged != null)
                          _buildSolarTermChangeBanner(),
                        if (_solarTermChanged != null)
                          const SizedBox(height: 12),
                        // 节气预告横幅（3天内即将到来）
                        if (_upcomingSolarTerm != null)
                          _buildUpcomingSolarTermBanner(),
                        if (_upcomingSolarTerm != null)
                          const SizedBox(height: 12),
                        SolarTermTodayWidget(
                          onTapDetails: () => context.push('/wellness'),
                          crowdTag: crowdTag,
                        ),
                        const SizedBox(height: 24),
                        if (_favoriteMeals.isNotEmpty) ...[
                          _buildFavoriteMealsSection(),
                          const SizedBox(height: 24),
                        ],
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

  /// 节气切换通知横幅
  Widget _buildSolarTermChangeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA726), Color(0xFFFFB74D)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA726).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.sun, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '节气已切换：$_solarTermChanged',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (_solarTermWellness != null &&
                    _solarTermWellness!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _solarTermWellness!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              context.push('/wellness');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '查看',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _solarTermChanged = null;
                _solarTermWellness = null;
              });
            },
            child: const Icon(
              LucideIcons.x,
              color: Colors.white70,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// 节气预告横幅（提前3天提醒饮食调整）
  Widget _buildUpcomingSolarTermBanner() {
    final name = _upcomingSolarTerm!['name'] as String? ?? '';
    final daysAhead = _upcomingSolarTerm!['days_ahead'] as int? ?? 0;
    final wellness = _upcomingSolarTerm!['wellness'] as String? ?? '';
    final season = _upcomingSolarTerm!['season'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF66BB6A).withValues(alpha: 0.9),
            const Color(0xFF81C784).withValues(alpha: 0.9),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF66BB6A).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarClock, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$daysAhead天后$season·$name',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (wellness.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '建议提前调整饮食：$wellness',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              context.push('/wellness');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '查看',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final key = '$name$daysAhead';
              await prefs.setString('last_upcoming_solar_term', key);
              setState(() => _upcomingSolarTerm = null);
            },
            child: const Icon(
              LucideIcons.x,
              color: Colors.white70,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final now = DateTime.now();
    final showMonthYear = _selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        !isToday;
    final dateText = isToday ? '今天' : DateFormat('M月d日').format(_selectedDate);
    final suffixText =
        showMonthYear ? DateFormat('yyyy年M月').format(_selectedDate) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.backgroundCard,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showDatePicker(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dateText, style: AppTextStyles.headlineSmall),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
          if (suffixText != null) ...[
            const SizedBox(width: 8),
            Text(
              suffixText,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
          const Spacer(),
          if (_streakDays > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.flame, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '连续 $_streakDays 天',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: '选择日期查看记录',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (selectedDate != null && mounted) {
      setState(() => _selectedDate = selectedDate);
      _loadDataForDate(selectedDate);
    }
  }

  Widget _buildDateSelector() {
    // 计算 _selectedDate 所在周的周一
    final monday =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final now = DateTime.now();

    return Container(
      height: 80,
      color: AppColors.backgroundCard,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
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

  Widget _buildFavoriteMealsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('常用餐食', style: AppTextStyles.h4),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedMealsPage()),
              ),
              child: Text('查看全部',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _favoriteMeals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final meal = _favoriteMeals[index];
              return _buildFavoriteMealCard(meal);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteMealCard(SavedMeal meal) {
    final cal = meal.nutrition?.calories.round() ?? 0;
    return GestureDetector(
      onTap: () => _quickAddFromSavedMeal(meal),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.lightShadow,
          border: Border.all(color: AppColors.primaryWithOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              meal.mealName,
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (meal.category != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryWithOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  meal.categoryDisplayName,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.zap,
                    size: 12, color: AppColors.caloriesColor),
                const SizedBox(width: 3),
                Text('$cal kcal',
                    style: AppTextStyles.numberXSmall.copyWith(
                      color: AppColors.caloriesColor,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddFromSavedMeal(SavedMeal meal) async {
    // 判断当前时间段对应的餐次
    final hour = DateTime.now().hour;
    int mealType;
    if (hour < 10) {
      mealType = 1; // 早餐
    } else if (hour < 14) {
      mealType = 2; // 午餐
    } else if (hour < 20) {
      mealType = 3; // 晚餐
    } else {
      mealType = 4; // 加餐
    }

    final mealNames = ['早餐', '午餐', '晚餐', '加餐'];
    await _createFoodRecordFromSavedMeal(
      meal,
      mealNames[mealType - 1],
      mealType,
      DateTime.now().toIso8601String(),
    );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐次标题行
          Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w500)),
                    if (mealRecords.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(LucideIcons.zap,
                              size: 14, color: AppColors.caloriesColor),
                          const SizedBox(width: 3),
                          Text('${mealCalories.round()} kcal',
                              style: AppTextStyles.numberXSmall.copyWith(
                                  color: AppColors.caloriesColor,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('${mealRecords.length} 项',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('还没有记录',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showFoodRecordModal(name),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // 内联食物记录列表
          if (mealRecords.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 8),
            ...mealRecords.map((record) => _buildInlineMealRecord(record)),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineMealRecord(FoodRecord record) {
    final calories = record.analysisResult?.nutritionFacts.totalCalories ??
        record.nutritionDetail?.calories ??
        0.0;
    final protein = record.analysisResult?.nutritionFacts.macronutrients.protein ??
        record.nutritionDetail?.protein ??
        0.0;
    final fat = record.analysisResult?.nutritionFacts.macronutrients.fat ??
        record.nutritionDetail?.fat ??
        0.0;
    final carbs = record.analysisResult?.nutritionFacts.macronutrients.carbohydrates ??
        record.nutritionDetail?.carbohydrates ??
        0.0;

    // 格式化就餐时间
    String? timeText;
    if (record.recordTime != null && record.recordTime!.isNotEmpty) {
      try {
        final timeParts = record.recordTime!.split(':');
        if (timeParts.length >= 2) {
          timeText = '${timeParts[0]}:${timeParts[1]}';
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // 食物图片或图标
          if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
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
                        color: AppColors.textHint, size: 18),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.backgroundTertiary),
              child: const Icon(LucideIcons.utensils,
                  color: AppColors.textHint, size: 18),
            ),
          // 食物名称和营养信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(record.foodName ?? '未命名食物',
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (timeText != null) ...[
                      const SizedBox(width: 4),
                      Icon(LucideIcons.clock,
                          size: 11, color: AppColors.textTertiary),
                      const SizedBox(width: 1),
                      Text(timeText,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textTertiary, fontSize: 10)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${calories.round()}kcal',
                        style: AppTextStyles.numberXSmall.copyWith(
                            color: AppColors.caloriesColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10)),
                    if (protein > 0)
                      Text('蛋白${protein.round()}g',
                          style: AppTextStyles.numberXSmall.copyWith(
                              color: AppColors.proteinColor, fontSize: 9)),
                    if (carbs > 0)
                      Text('碳水${carbs.round()}g',
                          style: AppTextStyles.numberXSmall.copyWith(
                              color: AppColors.carbsColor, fontSize: 9)),
                    if (fat > 0)
                      Text('脂肪${fat.round()}g',
                          style: AppTextStyles.numberXSmall.copyWith(
                              color: AppColors.fatColor, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ),
          // 编辑和删除按钮
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _editFoodRecordName(record),
                child: const Icon(LucideIcons.edit2,
                    size: 14, color: AppColors.info),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _deleteFoodRecord(record),
                child: const Icon(LucideIcons.trash2,
                    size: 14, color: AppColors.error),
              ),
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
      _showTimePicker(method, mealName, mealType);
    } else {
      _showTimePickerForOther(method, mealName);
    }
  }

  Future<void> _showTimePicker(
      String method, String mealName, int mealType) async {
    final now = DateTime.now();
    final initialTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: '选择用餐时间',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null && mounted) {
      final selectedTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
      _executeRecordMethod(
          method, mealName, mealType, selectedTime.toIso8601String());
    }
  }

  Future<void> _showTimePickerForOther(String method, String mealName) async {
    final now = DateTime.now();
    final initialTime = TimeOfDay(hour: now.hour, minute: now.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: '选择用餐时间',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (picked != null && mounted) {
      final selectedTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MealSelectionPage(recordMethod: method)),
      ).then((result) {
        if (result != null) {
          _executeRecordMethod(method, result['mealName'] as String,
              result['mealType'] as int, selectedTime.toIso8601String());
        }
      });
    }
  }

  Future<void> _executeRecordMethod(
      String method, String mealName, int mealType,
      [String? recordTime]) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    switch (method) {
      case 'ai_scan':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CameraPage(
                    mealName: mealName,
                    mealType: mealType,
                    recordDate: dateStr,
                    recordTime: recordTime))).then((_) => _refreshData());
        break;
      case 'text_describe':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TextDescribePage(
                    mealName: mealName,
                    mealType: mealType,
                    recordDate: dateStr,
                    recordTime: recordTime))).then((result) {
          if (result == true) _refreshData();
        });
        break;
      case 'voice_record':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('语音记录功能即将推出，敬请期待'),
            backgroundColor: AppColors.warning,
          ),
        );
        break;
      case 'saved_meals':
        await _navigateToSavedMeals(mealName, mealType, recordTime);
        break;
    }
  }

  Future<void> _navigateToSavedMeals(String mealName, int mealType,
      [String? recordTime]) async {
    final meal =
        await Navigator.of(context, rootNavigator: true).push<SavedMeal>(
      MaterialPageRoute(builder: (_) => const SavedMealsPage()),
    );
    if (meal != null && mounted) {
      _createFoodRecordFromSavedMeal(meal, mealName, mealType, recordTime);
    }
  }

  Future<void> _createFoodRecordFromSavedMeal(
      SavedMeal meal, String mealName, int mealType,
      [String? recordTime]) async {
    try {
      final foodService = FoodService();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final record = FoodRecordCreate(
        recordDate: dateStr,
        recordTime: recordTime ?? DateTime.now().toIso8601String(),
        mealType: mealType,
        foodName: meal.mealName,
        description: meal.description,
        imageUrl: meal.imageUrl,
        recordingMethod: 4,
      );

      final result = await foodService.createFoodRecord(record);
      if (result.success && result.data != null) {
        if (meal.nutrition != null) {
          try {
            await foodService.addNutritionDetail(
              result.data!.id,
              NutritionDetailCreate(
                calories: meal.nutrition!.calories,
                protein: meal.nutrition!.protein,
                fat: meal.nutrition!.fat,
                carbohydrates: meal.nutrition!.carbohydrates,
                dietaryFiber: meal.nutrition!.dietaryFiber,
                sugar: meal.nutrition!.sugar,
                sodium: meal.nutrition!.sodium,
                cholesterol: meal.nutrition!.cholesterol,
                analysisMethod: 'saved_meal',
              ),
            );
          } catch (_) {
            // 营养详情添加失败不影响主流程
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${meal.mealName} 已记录到$mealName'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _refreshData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('记录失败: ${result.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('记录失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
      final targetProtein = _targetProtein;
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
      // 尝试同步到后端重新计算目标
      try {
        final recalcResult = await _goalTrackingService.recalculateTargets();
        if (recalcResult.success && recalcResult.data != null) {
          final targets = recalcResult.data!['daily_targets'] as Map<String, dynamic>?;
          if (targets != null) {
            setState(() {
              _targetCalories = (targets['calories'] as num?)?.toDouble() ?? _targetCalories;
              _targetProtein = (targets['protein'] as num?)?.toDouble() ?? _targetProtein;
              _targetCarbs = (targets['carbs'] as num?)?.toDouble() ?? _targetCarbs;
              _targetFat = (targets['fat'] as num?)?.toDouble() ?? _targetFat;
            });
          }
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('卡路里目标已设置为 ${result.round()} kcal'),
          backgroundColor: AppColors.success));
    }
  }

  Widget _buildMacroNutrientsCard() {
    final protein = _dailySummary?.totalProtein ?? 0.0;
    final carbs = _dailySummary?.totalCarbohydrates ?? 0.0;
    final fat = _dailySummary?.totalFat ?? 0.0;
    final targetProtein = _targetProtein;
    final targetCarbs = _targetCarbs;
    final targetFat = _targetFat;

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
          // 营养素比例环形图
          if (protein + carbs + fat > 0) ...[
            Center(
              child: SizedBox(
                height: 120,
                width: 120,
                child: CustomPaint(
                  painter: _MacroDonutPainter(
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    proteinColor: AppColors.proteinColor,
                    carbsColor: AppColors.carbsColor,
                    fatColor: AppColors.fatColor,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(protein + carbs * 4 + fat * 9).round()}',
                          style: AppTextStyles.numberMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text('kcal',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 图例
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend('蛋白质', protein, AppColors.proteinColor),
                const SizedBox(width: 16),
                _buildLegend('碳水', carbs, AppColors.carbsColor),
                const SizedBox(width: 16),
                _buildLegend('脂肪', fat, AppColors.fatColor),
              ],
            ),
            const SizedBox(height: 16),
          ],
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

  Widget _buildLegend(String label, double value, Color color) {
    final total = (_dailySummary?.totalProtein ?? 0) + (_dailySummary?.totalCarbohydrates ?? 0) + (_dailySummary?.totalFat ?? 0);
    final percent = total > 0 ? (value / total * 100).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label $percent%', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
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

/// 宏量营养素环形图绘制器
class _MacroDonutPainter extends CustomPainter {
  final double protein;
  final double carbs;
  final double fat;
  final Color proteinColor;
  final Color carbsColor;
  final Color fatColor;

  _MacroDonutPainter({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = protein + carbs + fat;
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.3;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 背景圆环
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.backgroundTertiary;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // 绘制各段
    double startAngle = -3.14159265 / 2; // 从顶部开始
    final segments = [
      (protein, proteinColor),
      (carbs, carbsColor),
      (fat, fatColor),
    ];

    for (final (value, color) in segments) {
      if (value <= 0) continue;
      final sweepAngle = (value / total) * 2 * 3.14159265;
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.protein != protein ||
        oldDelegate.carbs != carbs ||
        oldDelegate.fat != fat;
  }
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
