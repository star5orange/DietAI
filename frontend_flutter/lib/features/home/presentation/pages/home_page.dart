import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      if (mounted) {
        setState(() {
          _todayRecords = result.data?.records ?? [];
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

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
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
                        _buildCalorieCard(remainingCalories, currentCalories),
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
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ChatPage(sessionType: 1, title: '营养顾问'),
                  ),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.bot,
                          size: 14, color: AppColors.textInverse),
                      const SizedBox(width: 4),
                      Text('AI教练',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textInverse,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ChatPage(sessionType: 1, title: 'AI助手'),
                  ),
                ),
                child: Container(
                  width: 36,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.messageCircle,
                      size: 16, color: AppColors.textInverse),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('0',
                    style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textInverse,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
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
          final date = DateTime.now().subtract(Duration(days: 3 - index));
          final isSelected = _isSameDay(date, _selectedDate);
          final dayNames = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

          return GestureDetector(
            onTap: () {
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNames[date.weekday % 7],
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
          );
        },
      ),
    );
  }

  Widget _buildCalorieCard(int remainingCalories, double currentCalories) {
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
                  Text('卡路里摄入', style: AppTextStyles.h4),
                  const SizedBox(height: 4),
                  Text('每日目标 ${_targetCalories.round()} kcal',
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
    return Container(
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
            decoration: const BoxDecoration(
              gradient: AppColors.warningGradient,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: const Icon(LucideIcons.leaf,
                color: AppColors.textInverse, size: 24),
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
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('即将上线',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.warning)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('根据您的体质，每日推送个性化养生建议',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
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
        'icon': LucideIcons.utensils,
        'gradient': AppColors.dinnerGradient,
        'type': 3
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
                Text(record.foodName,
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
      builder: (context) => _FoodNameDialog(initialValue: record.foodName),
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
        content: Text('确定要删除"${record.foodName}"吗？此操作不可撤销。',
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('食物记录已删除'), backgroundColor: AppColors.success));
      _refreshData();
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
    if (mealName == '早餐' || mealName == '午餐' || mealName == '晚餐') {
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
          Text('今日宏观营养素', style: AppTextStyles.h4),
          const SizedBox(height: 16),
          _buildNutrientProgress(
              '蛋白质', protein, targetProtein, AppColors.proteinColor),
          const SizedBox(height: 12),
          _buildNutrientProgress(
              '碳水化合物', carbs, targetCarbs, AppColors.carbsColor),
          const SizedBox(height: 12),
          _buildNutrientProgress('脂肪', fat, targetFat, AppColors.fatColor),
        ],
      ),
    );
  }

  Widget _buildNutrientProgress(
      String name, double current, double target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name,
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            Text('${current.round()}g / ${target.round()}g',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(4)),
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
