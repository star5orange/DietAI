import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/water_service.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_animation_widget.dart';

/// 宠物详情页
/// 包含：大型宠物动画、状态面板(心情/等级/经验)
class PetDetailPage extends ConsumerStatefulWidget {
  const PetDetailPage({super.key});

  @override
  ConsumerState<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends ConsumerState<PetDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  final FoodService _foodService = FoodService();
  final WaterService _waterService = WaterService();

  // 实际饮食/饮水数据
  bool _statsLoading = true;
  double _foodProgress = 0.0;
  double _waterProgress = 0.0;
  double _consumedCalories = 0;
  double _targetCalories = 2000;
  int _waterTotalMl = 0;
  int _waterGoalMl = 2000;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }


  /// 从后端加载实际饮食和饮水数据
  Future<void> _loadStats() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // 加载饮食数据
      final foodResult = await _foodService.getDailySummary(today);
      if (foodResult.success && foodResult.data != null) {
        final summary = foodResult.data!;
        final consumed = summary.totalCalories;
        const target = 2000.0;
        if (mounted) {
          setState(() {
            _consumedCalories = consumed;
            _targetCalories = target;
            _foodProgress =
                target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
          });
        }
      }

      // 加载饮水数据
      final waterResult = await _waterService.getDailySummary(today);
      if (waterResult.success && waterResult.data != null) {
        final summary = waterResult.data!;
        if (mounted) {
          setState(() {
            _waterTotalMl = summary.totalMl;
            _waterGoalMl = summary.goalMl;
            _waterProgress = summary.progress;
          });
        }
      }
    } catch (_) {
      // 加载失败使用默认值
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  void _onTapPet() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    ref.read(petProvider.notifier).onTap();
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);

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
        title: Text(petState.petName,
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon:
                const Icon(LucideIcons.share2, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPetDisplaySection(petState),
            const SizedBox(height: 24),
            _buildStatsPanel(petState),
          ],
        ),
      ),
    );
  }

  /// 大型宠物展示区域
  Widget _buildPetDisplaySection(PetState petState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primarySurface,
            AppColors.backgroundCard,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Column(
        children: [
          // 宠物名称和等级
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(petState.levelName,
                  style: AppTextStyles.h4.copyWith(color: AppColors.primary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Lv.${petState.level}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(petState.dialogue,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
          const SizedBox(height: 20),

          // 宠物动画
          GestureDetector(
            onTap: _onTapPet,
            child: ScaleTransition(
              scale: _bounceAnimation,
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: PetAnimationWidget(
                  size: 180,
                  showLevelBadge: false,
                  enableInteraction: false,
                  skin: petState.currentSkin, // 使用用户选择的皮肤
                  customAvatarUrl: petState.customAvatarUrl, // AI 自定义头像
                  emotionUrls: petState.emotionUrls, // AI 情绪变体
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 点击提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.hand, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('点击互动',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 状态面板
  Widget _buildStatsPanel(PetState petState) {
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
          Row(
            children: [
              const Icon(LucideIcons.activity,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('宠物状态', style: AppTextStyles.h6),
              if (_statsLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 饮食达标率（实际数据）
          _buildStatBar(
            '饮食达标率',
            _consumedCalories,
            _targetCalories,
            AppColors.caloriesColor,
            LucideIcons.utensils,
            progress: _foodProgress,
          ),
          const SizedBox(height: 16),

          // 饮水达标率（实际数据）
          _buildStatBar(
            '饮水达标率',
            _waterTotalMl.toDouble(),
            _waterGoalMl.toDouble(),
            AppColors.info,
            LucideIcons.droplet,
            progress: _waterProgress,
            unit: 'ml',
          ),
          const SizedBox(height: 16),

          // 等级和经验
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildLevelCard(petState.level),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildExpBar(petState.exp, petState.maxExp),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 连续达标天数
          Row(
            children: [
              const Icon(LucideIcons.calendar,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text('连续达标', style: AppTextStyles.bodyMedium),
              const Spacer(),
              Text(
                '${petState.currentStreak}天',
                style: AppTextStyles.numberXSmall
                    .copyWith(color: AppColors.warning),
              ),
              if (petState.longestStreak > 0) ...[
                const SizedBox(width: 16),
                Text('最长 ${petState.longestStreak}天',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(
    String label,
    double current,
    double max,
    Color color,
    IconData icon, {
    double? progress,
    String unit = '%',
  }) {
    final p = progress ?? (max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0);
    final pct = (p * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(
              unit == 'ml'
                  ? '${current.toInt()}/${max.toInt()} ml'
                  : '${current.toInt()}/${max.toInt()} kcal',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Text('${pct}%',
                style: AppTextStyles.numberXSmall.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLevelCard(int level) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.star, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text('Lv.$level',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ],
      ),
    );
  }

  Widget _buildExpBar(int exp, int maxExp) {
    final progress = maxExp > 0 ? (exp / maxExp).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.zap,
                size: 16, color: AppColors.caloriesColor),
            const SizedBox(width: 8),
            Text('经验值', style: AppTextStyles.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.caloriesColor.withValues(alpha: 0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.caloriesColor),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text('$exp/$maxExp EXP',
            style: AppTextStyles.numberXSmall
                .copyWith(color: AppColors.caloriesColor)),
      ],
    );
  }

}


