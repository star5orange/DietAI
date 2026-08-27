import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/presentation/widgets/animated_progress_circle.dart';
import '../../../social/presentation/providers/family_provider.dart';
import '../widgets/enhanced_meal_card.dart';

/// 增强版主页
class EnhancedHomePage extends ConsumerStatefulWidget {
  const EnhancedHomePage({super.key});

  @override
  ConsumerState<EnhancedHomePage> createState() => _EnhancedHomePageState();
}

class _EnhancedHomePageState extends ConsumerState<EnhancedHomePage>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  late AnimationController _cardAnimationController;
  late Animation<double> _cardSlideAnimation;

  // 模拟数据
  final int dailyCalorieTarget = 2000;
  final int consumedCalories = 1200;
  final int remainingCalories = 800;

  final Map<String, dynamic> nutritionProgress = {
    'protein': {'current': 45, 'target': 150},
    'carbs': {'current': 180, 'target': 250},
    'fat': {'current': 35, 'target': 67},
  };

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(
      begin: -50,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardSlideAnimation = Tween<double>(
      begin: 100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // 启动动画
    Future.delayed(const Duration(milliseconds: 100), () {
      _headerAnimationController.forward();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      _cardAnimationController.forward();
    });

    // 加载家庭看板数据
    Future.microtask(() {
      ref.read(familyDashboardProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyDashboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 增强版应用栏
          _buildEnhancedAppBar(),

          // 主要内容
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 家庭健康看板入口
                if (familyState.members.isNotEmpty) ...[
                  _buildFamilyDashboardCard(familyState),
                  const SizedBox(height: 20),
                ],

                // 今日概览卡片
                _buildTodayOverviewCard(),

                const SizedBox(height: 20),

                // 营养进度卡片
                _buildNutritionProgressCard(),

                const SizedBox(height: 20),

                // 餐次卡片列表
                _buildMealCards(),

                const SizedBox(height: 20),

                // 快速操作区域
                _buildQuickActionsSection(),

                const SizedBox(height: 100), // 底部留白
              ],
            ),
          ),
        ],
      ),
      // 浮动添加按钮
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFamilyDashboardCard(FamilyDashboardState state) {
    return GestureDetector(
      onTap: () => context.push('/family-dashboard'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.users,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '家庭健康看板',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.members.length}位家人',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 显示前3位家人的健康摘要
            Row(
              children: state.members.take(3).map((member) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: member.avatarUrl != null
                              ? NetworkImage(member.avatarUrl!)
                              : null,
                          child: member.avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 20, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          member.realName ?? member.username,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member.totalCalories != null
                              ? '${member.totalCalories!.toInt()} kcal'
                              : '已隐藏',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // 异常提醒
            if (state.alerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.alertCircle,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${state.alerts.length}条异常提醒',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2BAF74),
                Color(0xFF3ECC7A),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _headerAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _headerSlideAnimation.value),
                  child: FadeTransition(
                    opacity: _headerFadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // 头像
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.user,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '早安，用户',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '今天也要保持健康饮食哦！',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 通知按钮
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    LucideIcons.bell,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {},
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard() {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlideAnimation.value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      color: Color(0xFF2BAF74),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '今日摄入概览',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${DateTime.now().month}月${DateTime.now().day}日',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2BAF74),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 卡路里进度圆环
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: AnimatedProgressCircle(
                        progress: consumedCalories / dailyCalorieTarget,
                        size: 120,
                        strokeWidth: 8,
                        backgroundColor: const Color(0xFFE6FAF0),
                        progressColor: const Color(0xFF2BAF74),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$consumedCalories',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF222222),
                              ),
                            ),
                            Text(
                              '/ $dailyCalorieTarget',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const Text(
                              '卡路里',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildCalorieInfoItem(
                            '剩余',
                            remainingCalories,
                            const Color(0xFF2BAF74),
                            LucideIcons.target,
                          ),
                          const SizedBox(height: 16),
                          _buildCalorieInfoItem(
                            '已消耗',
                            consumedCalories,
                            const Color(0xFF4ECDC4),
                            LucideIcons.flame,
                          ),
                          const SizedBox(height: 16),
                          _buildCalorieInfoItem(
                            '目标',
                            dailyCalorieTarget,
                            const Color(0xFFFFE66D),
                            LucideIcons.flag,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalorieInfoItem(
      String label, int value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionProgressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                LucideIcons.activity,
                color: Color(0xFF2BAF74),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '营养素摄入进度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNutritionProgressItem(
            '蛋白质',
            nutritionProgress['protein']['current'],
            nutritionProgress['protein']['target'],
            const Color(0xFF4ECDC4),
            'g',
          ),
          const SizedBox(height: 12),
          _buildNutritionProgressItem(
            '碳水化合物',
            nutritionProgress['carbs']['current'],
            nutritionProgress['carbs']['target'],
            const Color(0xFFFFE66D),
            'g',
          ),
          const SizedBox(height: 12),
          _buildNutritionProgressItem(
            '脂肪',
            nutritionProgress['fat']['current'],
            nutritionProgress['fat']['target'],
            const Color(0xFFFF8B94),
            'g',
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionProgressItem(
      String name, int current, int target, Color color, String unit) {
    final progress = (current / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
            Text(
              '$current / $target $unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildMealCards() {
    return Column(
      children: [
        EnhancedMealCard(
          mealType: 'breakfast',
          title: '早餐',
          foods: [
            {'name': '燕麦粥', 'calories': 250, 'image': null},
            {'name': '香蕉', 'calories': 105, 'image': null},
          ],
          targetCalories: 500,
          consumedCalories: 355,
          primaryColor: const Color(0xFFFFB347),
          icon: LucideIcons.sunrise,
          onAddFood: () => _handleAddFood('breakfast'),
          onViewDetails: () => _handleViewMealDetails('breakfast'),
        ),
        EnhancedMealCard(
          mealType: 'lunch',
          title: '午餐',
          foods: [
            {'name': '鸡胸肉沙拉', 'calories': 320, 'image': null},
            {'name': '苹果', 'calories': 80, 'image': null},
          ],
          targetCalories: 700,
          consumedCalories: 400,
          primaryColor: const Color(0xFF87CEEB),
          icon: LucideIcons.sun,
          onAddFood: () => _handleAddFood('lunch'),
          onViewDetails: () => _handleViewMealDetails('lunch'),
        ),
        EnhancedMealCard(
          mealType: 'dinner',
          title: '晚餐',
          foods: [],
          targetCalories: 600,
          consumedCalories: 0,
          primaryColor: const Color(0xFF9370DB),
          icon: LucideIcons.moon,
          onAddFood: () => _handleAddFood('dinner'),
          onViewDetails: () => _handleViewMealDetails('dinner'),
        ),
        EnhancedMealCard(
          mealType: 'snack',
          title: '加餐',
          foods: [
            {'name': '坚果', 'calories': 160, 'image': null},
          ],
          targetCalories: 200,
          consumedCalories: 160,
          primaryColor: const Color(0xFFFF69B4),
          icon: LucideIcons.coffee,
          onAddFood: () => _handleAddFood('snack'),
          onViewDetails: () => _handleViewMealDetails('snack'),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快速操作',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  '拍照识别',
                  LucideIcons.camera,
                  const Color(0xFF2BAF74),
                  () => _handleCameraAction(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  'AI咨询',
                  LucideIcons.messageCircle,
                  const Color(0xFF4ECDC4),
                  () => _handleAIConsultation(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  '历史记录',
                  LucideIcons.history,
                  const Color(0xFFFFE66D),
                  () => _handleViewHistory(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2BAF74),
            Color(0xFF3ECC7A),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2BAF74).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _handleCameraAction,
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(
          LucideIcons.plus,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  void _handleAddFood(String mealType) {
    // TODO: 实现添加食物功能
    print('添加食物到 $mealType');
  }

  void _handleViewMealDetails(String mealType) {
    // TODO: 实现查看餐次详情
    print('查看 $mealType 详情');
  }

  void _handleCameraAction() {
    // TODO: 实现相机拍照功能
    print('打开相机');
  }

  void _handleAIConsultation() {
    // TODO: 实现AI咨询功能
    print('打开AI咨询');
  }

  void _handleViewHistory() {
    // TODO: 实现查看历史记录
    print('查看历史记录');
  }
}
