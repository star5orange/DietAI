import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/water_service.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_animation_widget.dart';
import '../../domain/services/pet_service.dart';

/// 宠物详情页
/// 包含：大型宠物动画、状态面板(心情/等级/经验)、解锁内容列表、互动面板
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

  final PetService _petService = PetService();
  final FoodService _foodService = FoodService();
  final WaterService _waterService = WaterService();
  List<Map<String, dynamic>> _unlockables = [];
  bool _unlockablesLoading = true;

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
    _loadUnlockables();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadUnlockables() async {
    try {
      final response = await _petService.getUnlockables();
      if (response.success && response.data != null) {
        final items = response.data!['unlockables'] as List<dynamic>? ??
            response.data!['items'] as List<dynamic>? ??
            [];
        final petState = ref.read(petProvider);
        setState(() {
          _unlockables = items.map((e) {
            final requiredLevel = e['required_level'] as int?;
            final requiredStreak = e['required_streak'] as int?;
            // 客户端根据用户状态计算是否已解锁
            bool isUnlocked = e['is_unlocked'] == true;
            if (!isUnlocked) {
              final levelOk =
                  requiredLevel == null || petState.level >= requiredLevel;
              final streakOk = requiredStreak == null ||
                  petState.currentStreak >= requiredStreak;
              isUnlocked = levelOk && streakOk;
            }
            return {
              'name': e['name'] ?? '',
              'unlock_type': e['unlock_type'] as String? ?? '',
              'unlock_key': e['unlock_key'] as String? ?? '',
              'description': e['description'] as String? ?? '',
              'required_level': requiredLevel,
              'required_streak': requiredStreak,
              'is_unlocked': isUnlocked,
            };
          }).toList();
        });
      }
    } catch (_) {
      // 使用默认数据
    } finally {
      if (mounted) setState(() => _unlockablesLoading = false);
    }
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'skin':
        return LucideIcons.shirt;
      case 'action':
        return LucideIcons.sparkles;
      case 'achievement':
        return LucideIcons.trophy;
      default:
        return LucideIcons.gift;
    }
  }

  void _onTapPet() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    ref.read(petProvider.notifier).onTap();
  }

  Future<void> _onInteract(String action) async {
    try {
      await _petService.petInteract(action: action);
      final notifier = ref.read(petProvider.notifier);
      switch (action) {
        case 'feed':
          notifier.addExp(10);
          break;
        case 'play':
          notifier.addExp(8);
          break;
        case 'train':
          notifier.addExp(12);
          break;
        default:
          notifier.addExp(5);
      }
      if (mounted) {
        _showFeedback(action);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('互动失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showFeedback(String action) {
    final messages = {
      'feed': '喂食成功！+10经验值',
      'play': '玩耍成功！+8经验值',
      'train': '训练成功！+12经验值',
      'pet': '抚摸成功！+5经验值',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.sparkles, color: Colors.white),
            const SizedBox(width: 12),
            Text(messages[action] ?? '互动成功！'),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
            const SizedBox(height: 24),
            _buildAchievementsSection(),
            const SizedBox(height: 24),
            _buildInteractionPanel(),
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

  /// 解锁内容列表
  Widget _buildAchievementsSection() {
    if (_unlockablesLoading && _unlockables.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.lightShadow,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final displayItems =
        _unlockables.isNotEmpty ? _unlockables : _defaultUnlockables;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.trophy,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('解锁内容', style: AppTextStyles.h6),
                ],
              ),
              Text(
                  '${displayItems.where((a) => a['is_unlocked'] == true).length}/${displayItems.length}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              return _buildUnlockableCard(
                  displayItems[index] as Map<String, dynamic>);
            },
          ),
        ],
      ),
    );
  }

  static const _defaultUnlockables = [
    {
      'name': '默认外观',
      'description': '可爱的基础宠物形象',
      'unlock_type': 'skin',
      'unlock_key': 'default',
      'required_level': 1,
      'required_streak': null,
      'is_unlocked': true,
    },
    {
      'name': '夏日清凉',
      'description': '夏日海滩风格外观',
      'unlock_type': 'skin',
      'unlock_key': 'summer',
      'required_level': 3,
      'required_streak': null,
      'is_unlocked': false,
    },
    {
      'name': '开心转圈',
      'description': '达标后的开心转圈动作',
      'unlock_type': 'action',
      'unlock_key': 'happy_spin',
      'required_level': null,
      'required_streak': 3,
      'is_unlocked': false,
    },
    {
      'name': '金色光效',
      'description': '升级时的金色闪光效果',
      'unlock_type': 'effect',
      'unlock_key': 'gold_sparkle',
      'required_level': 10,
      'required_streak': null,
      'is_unlocked': false,
    },
  ];

  Widget _buildUnlockableCard(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final description = item['description'] as String? ?? '';
    final unlockType = item['unlock_type'] as String;
    final requiredLevel = item['required_level'] as int?;
    final requiredStreak = item['required_streak'] as int?;
    final isUnlocked = item['is_unlocked'] as bool;

    final petState = ref.watch(petProvider);
    final icon = _iconForType(unlockType);

    // 计算解锁进度
    double progress = 0.0;
    String conditionText = '自动解锁';
    String progressText = '';

    if (requiredLevel != null) {
      final currentLevel = petState.level;
      progress = (currentLevel / requiredLevel).clamp(0.0, 1.0);
      conditionText = '需要 Lv.$requiredLevel';
      progressText =
          isUnlocked ? '已解锁' : 'Lv.$currentLevel / Lv.$requiredLevel';
    } else if (requiredStreak != null) {
      final currentStreak = petState.currentStreak;
      progress = (currentStreak / requiredStreak).clamp(0.0, 1.0);
      conditionText = '连续达标${requiredStreak}天';
      progressText =
          isUnlocked ? '已解锁' : '${currentStreak}天 / ${requiredStreak}天';
    }

    final canUnlock = !isUnlocked && progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? AppColors.primarySurface
            : AppColors.backgroundTertiary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 图标
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 26,
                color: isUnlocked ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 14),
            // 信息 + 进度条
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isUnlocked
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        description,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // 进度条或条件文字
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conditionText,
                              style: AppTextStyles.caption.copyWith(
                                color: isUnlocked
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                                fontWeight: isUnlocked
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (progressText.isNotEmpty)
                              Text(
                                progressText,
                                style: AppTextStyles.numberXSmall.copyWith(
                                  color: isUnlocked
                                      ? AppColors.success
                                      : AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isUnlocked)
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                canUnlock ? AppColors.warning : AppColors.info,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 解锁按钮或已解锁标记
            if (canUnlock)
              GestureDetector(
                onTap: () => _doUnlock(item),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '解锁',
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else if (isUnlocked)
              Icon(LucideIcons.checkCircle, color: AppColors.success, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _doUnlock(Map<String, dynamic> item) async {
    // 先本地乐观更新，再尝试同步后端
    setState(() {
      final idx = _unlockables.indexOf(item);
      if (idx >= 0) {
        _unlockables[idx] = {...item, 'is_unlocked': true};
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(LucideIcons.trophy, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${item['name']} 解锁成功！'),
          ]),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    // 尝试同步后端（失败不影响本地状态）
    final unlockType = item['unlock_type'] as String;
    try {
      await _petService.petInteract(
        action: 'unlock',
        itemId: '${unlockType}:${item['unlock_key']}',
      );
    } catch (_) {
      // 后端不支持 unlock action，本地已更新即可
    }
  }

  /// 互动面板
  Widget _buildInteractionPanel() {
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
              const Icon(LucideIcons.gamepad2,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('互动面板', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _interactions.length,
            itemBuilder: (context, index) {
              final item = _interactions[index];
              return _buildInteractionButton(
                  item['name'] as String,
                  item['icon'] as IconData,
                  item['effect'] as String,
                  item['action'] as String);
            },
          ),
        ],
      ),
    );
  }

  static const _interactions = [
    {
      'name': '抚摸',
      'icon': LucideIcons.heartHandshake,
      'effect': '+5经验',
      'action': 'pet',
    },
    {
      'name': '喂食',
      'icon': LucideIcons.cookie,
      'effect': '+10经验',
      'action': 'feed',
    },
    {
      'name': '玩耍',
      'icon': LucideIcons.gamepad2,
      'effect': '+8经验',
      'action': 'play',
    },
    {
      'name': '训练',
      'icon': LucideIcons.graduationCap,
      'effect': '+12经验',
      'action': 'train',
    },
  ];

  Widget _buildInteractionButton(
    String name,
    IconData icon,
    String effect,
    String action,
  ) {
    return GestureDetector(
      onTap: () => _onInteract(action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w500)),
                  Text(effect,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.success)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
