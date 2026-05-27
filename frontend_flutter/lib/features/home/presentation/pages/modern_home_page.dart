import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/presentation/widgets/widgets.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 现代化主页 - 展示新UI系统
class ModernHomePage extends StatefulWidget {
  const ModernHomePage({super.key});

  @override
  State<ModernHomePage> createState() => _ModernHomePageState();
}

class _ModernHomePageState extends State<ModernHomePage> {
  // 模拟数据
  final int dailyCalorieTarget = 2000;
  final int consumedCalories = 1200;
  final int remainingCalories = 800;

  final Map<String, dynamic> nutritionProgress = {
    'protein': {'current': 45, 'target': 150, 'color': AppColors.proteinColor},
    'carbs': {'current': 180, 'target': 250, 'color': AppColors.carbsColor},
    'fat': {'current': 35, 'target': 67, 'color': AppColors.fatColor},
  };

  final List<Map<String, dynamic>> mealData = [
    {
      'type': 'breakfast',
      'title': '早餐',
      'icon': LucideIcons.sunrise,
      'gradient': AppColors.breakfastGradient,
      'foods': [
        {'name': '燕麦粥', 'calories': 250},
        {'name': '香蕉', 'calories': 105},
      ],
      'target': 500,
      'consumed': 355,
    },
    {
      'type': 'lunch',
      'title': '午餐',
      'icon': LucideIcons.sun,
      'gradient': AppColors.lunchGradient,
      'foods': [
        {'name': '鸡胸肉沙拉', 'calories': 320},
        {'name': '苹果', 'calories': 80},
      ],
      'target': 700,
      'consumed': 400,
    },
    {
      'type': 'dinner',
      'title': '晚餐',
      'icon': LucideIcons.moon,
      'gradient': AppColors.dinnerGradient,
      'foods': [],
      'target': 600,
      'consumed': 0,
    },
    {
      'type': 'snack',
      'title': '加餐',
      'icon': LucideIcons.coffee,
      'gradient': AppColors.snackGradient,
      'foods': [
        {'name': '坚果', 'calories': 160},
      ],
      'target': 200,
      'consumed': 160,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveContainer(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 现代化应用栏
            _buildModernAppBar(),

            // 主要内容
            SliverToBoxAdapter(
              child: StaggeredAnimationBuilder(
                staggerDelay: const Duration(milliseconds: 100),
                children: [
                  // 今日概览卡片
                  _buildTodayOverviewCard(),

                  const ResponsiveSpacing.vertical(height: 24),

                  // 营养进度卡片
                  _buildNutritionProgressCard(),

                  const ResponsiveSpacing.vertical(height: 24),

                  // 餐次卡片列表
                  _buildMealCardsGrid(),

                  const ResponsiveSpacing.vertical(height: 24),

                  // 快速操作区域
                  _buildQuickActionsSection(),

                  const ResponsiveSpacing.vertical(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      // 现代化浮动按钮
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: ResponsiveUtils.getValue(
        context,
        mobile: 140.0,
        tablet: 160.0,
        desktop: 180.0,
      ),
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: FadeInAnimation(
              duration: AnimationDurations.medium,
              child: Padding(
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // 现代化头像
                        Container(
                          width: ResponsiveUtils.getValue(
                            context,
                            mobile: 50.0,
                            tablet: 60.0,
                            desktop: 70.0,
                          ),
                          height: ResponsiveUtils.getValue(
                            context,
                            mobile: 50.0,
                            tablet: 60.0,
                            desktop: 70.0,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.whiteWithOpacity(0.2),
                                AppColors.whiteWithOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.whiteWithOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.user,
                            color: AppColors.textInverse,
                            size: ResponsiveUtils.getValue(
                              context,
                              mobile: 24.0,
                              tablet: 28.0,
                              desktop: 32.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '早安，用户',
                                style: AppTextStyles.h3
                                    .copyWith(
                                      color: AppColors.textInverse,
                                      fontWeight: FontWeight.w800,
                                    )
                                    .responsive(context),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '今天也要保持健康饮食哦！',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(
                                      color: AppColors.whiteWithOpacity(0.9),
                                    )
                                    .responsive(context),
                              ),
                            ],
                          ),
                        ),
                        // 现代化通知按钮
                        ModernIconButton(
                          icon: LucideIcons.bell,
                          variant: ModernButtonVariant.ghost,
                          foregroundColor: AppColors.textInverse,
                          showBadge: true,
                          badgeText: '3',
                          tooltip: '通知',
                          onPressed: () => _handleNotifications(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard() {
    return ModernCard(
      variant: ModernCardVariant.elevated,
      size: ModernCardSize.large,
      header: ModernCardHeader(
        title: '今日摄入概览',
        subtitle: '${DateTime.now().month}月${DateTime.now().day}日',
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryWithOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            LucideIcons.calendar,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
      child: ResponsiveLayout(
        mobile: _buildCalorieOverviewMobile(),
        tablet: _buildCalorieOverviewDesktop(),
        desktop: _buildCalorieOverviewDesktop(),
      ),
    );
  }

  Widget _buildCalorieOverviewMobile() {
    return Column(
      children: [
        // 卡路里圆环
        SizedBox(
          width: 120,
          height: 120,
          child: AnimatedProgressCircle(
            progress: consumedCalories / dailyCalorieTarget,
            size: 120,
            strokeWidth: 8,
            backgroundColor: AppColors.primaryWithOpacity(0.1),
            progressColor: AppColors.primary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$consumedCalories',
                  style: AppTextStyles.numberMedium,
                ),
                Text(
                  '/ $dailyCalorieTarget',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '卡路里',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 统计信息
        ResponsiveGrid(
          mobileColumns: 3,
          spacing: 8,
          children: [
            _buildCalorieInfoCard('剩余', remainingCalories, AppColors.success),
            _buildCalorieInfoCard('已消耗', consumedCalories, AppColors.primary),
            _buildCalorieInfoCard('目标', dailyCalorieTarget, AppColors.warning),
          ],
        ),
      ],
    );
  }

  Widget _buildCalorieOverviewDesktop() {
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: AnimatedProgressCircle(
            progress: consumedCalories / dailyCalorieTarget,
            size: 120,
            strokeWidth: 8,
            backgroundColor: AppColors.primaryWithOpacity(0.1),
            progressColor: AppColors.primary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$consumedCalories',
                  style: AppTextStyles.numberMedium,
                ),
                Text(
                  '/ $dailyCalorieTarget',
                  style: AppTextStyles.bodySmall,
                ),
                Text(
                  '卡路里',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            children: [
              _buildCalorieInfoCard('剩余', remainingCalories, AppColors.success),
              const SizedBox(height: 16),
              _buildCalorieInfoCard('已消耗', consumedCalories, AppColors.primary),
              const SizedBox(height: 16),
              _buildCalorieInfoCard(
                  '目标', dailyCalorieTarget, AppColors.warning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieInfoCard(String label, int value, Color color) {
    return ModernCard(
      variant: ModernCardVariant.filled,
      size: ModernCardSize.small,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForLabel(label),
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: AppTextStyles.numberSmall.copyWith(color: color),
                ),
                Text(
                  label,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case '剩余':
        return LucideIcons.target;
      case '已消耗':
        return LucideIcons.flame;
      case '目标':
        return LucideIcons.flag;
      default:
        return LucideIcons.circle;
    }
  }

  Widget _buildNutritionProgressCard() {
    return ModernCard(
      variant: ModernCardVariant.elevated,
      size: ModernCardSize.medium,
      header: ModernCardHeader(
        title: '营养素摄入进度',
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondaryWithOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            LucideIcons.activity,
            color: AppColors.secondary,
            size: 20,
          ),
        ),
      ),
      child: Column(
        children: nutritionProgress.entries.map((entry) {
          final name = _getNutritionName(entry.key);
          final current = entry.value['current'] as int;
          final target = entry.value['target'] as int;
          final color = entry.value['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildNutritionProgressItem(name, current, target, color),
          );
        }).toList(),
      ),
    );
  }

  String _getNutritionName(String key) {
    switch (key) {
      case 'protein':
        return '蛋白质';
      case 'carbs':
        return '碳水化合物';
      case 'fat':
        return '脂肪';
      default:
        return key;
    }
  }

  Widget _buildNutritionProgressItem(
      String name, int current, int target, Color color) {
    final progress = (current / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: AppTextStyles.labelMedium,
            ),
            Text(
              '$current / $target g',
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCardsGrid() {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 2,
      spacing: 16,
      runSpacing: 16,
      children: mealData.map((meal) => _buildMealCard(meal)).toList(),
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final progress = meal['consumed'] / meal['target'];

    return ModernCard(
      variant: ModernCardVariant.elevated,
      size: ModernCardSize.medium,
      onTap: () => _handleMealTap(meal['type']),
      header: ModernCardHeader(
        title: meal['title'],
        subtitle: '${meal['consumed']} / ${meal['target']} 卡路里',
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: meal['gradient'],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            meal['icon'],
            color: AppColors.textInverse,
            size: 20,
          ),
        ),
        trailing: ModernIconButton(
          icon: LucideIcons.plus,
          size: ModernButtonSize.small,
          variant: ModernButtonVariant.outline,
          onPressed: () => _handleAddFood(meal['type']),
        ),
      ),
      child: Column(
        children: [
          // 进度条
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: meal['gradient'],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          if (meal['foods'].isNotEmpty) ...[
            const SizedBox(height: 12),
            ...meal['foods'].map<Widget>((food) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      food['name'],
                      style: AppTextStyles.bodySmall,
                    ),
                    Text(
                      '${food['calories']} 卡',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '暂无记录',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return ModernCard(
      variant: ModernCardVariant.elevated,
      size: ModernCardSize.medium,
      header: const ModernCardHeader(
        title: '快速操作',
      ),
      child: ResponsiveGrid(
        mobileColumns: 3,
        tabletColumns: 3,
        desktopColumns: 3,
        spacing: 12,
        children: [
          _buildQuickActionButton(
            '拍照识别',
            LucideIcons.camera,
            AppColors.primary,
            () => _handleCameraAction(),
          ),
          _buildQuickActionButton(
            'AI咨询',
            LucideIcons.messageCircle,
            AppColors.secondary,
            () => _handleAIConsultation(),
          ),
          _buildQuickActionButton(
            '历史记录',
            LucideIcons.history,
            AppColors.warning,
            () => _handleViewHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ModernButton(
      text: title,
      icon: icon,
      variant: ModernButtonVariant.outline,
      size: ModernButtonSize.small,
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      foregroundColor: color,
    );
  }

  Widget _buildModernFAB() {
    return ModernButton.gradient(
      text: '',
      icon: LucideIcons.plus,
      shape: ModernButtonShape.pill,
      size: ModernButtonSize.large,
      gradient: AppColors.primaryGradient,
      pulse: true,
      onPressed: _handleCameraAction,
    );
  }

  // 事件处理方法
  void _handleNotifications() {
    // TODO: 实现通知功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通知功能开发中...')),
    );
  }

  void _handleMealTap(String mealType) {
    // TODO: 实现餐次详情
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('查看 $mealType 详情')),
    );
  }

  void _handleAddFood(String mealType) {
    // TODO: 实现添加食物功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('添加食物到 $mealType')),
    );
  }

  void _handleCameraAction() {
    // TODO: 实现相机拍照功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开相机')),
    );
  }

  void _handleAIConsultation() {
    // TODO: 实现AI咨询功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开AI咨询')),
    );
  }

  void _handleViewHistory() {
    // TODO: 实现查看历史记录
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('查看历史记录')),
    );
  }
}
