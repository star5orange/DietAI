import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../pet/presentation/providers/pet_provider.dart';
import '../../../pet/data/pet_storage.dart';
import '../../../pet/data/real_pet_api_service.dart';
import '../../../pet/domain/pet_state_calculator.dart';
import '../../../pet/domain/pet_skin_config.dart';
import '../../../pet/presentation/widgets/pet_bubble.dart';
import '../../../pet/presentation/widgets/pet_animation_widget.dart';
import '../../../pet/presentation/pages/real_pet_detail_page.dart';
import '../../../pet/presentation/pages/add_pet_page.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/water_service.dart';
import '../../../../services/goal_tracking_service.dart';
import '../../../../shared/utils/species_utils.dart';

class MyPetPage extends ConsumerStatefulWidget {
  const MyPetPage({super.key});

  @override
  ConsumerState<MyPetPage> createState() => _MyPetPageState();
}

class _MyPetPageState extends ConsumerState<MyPetPage>
    with TickerProviderStateMixin {
  // Tab controller
  late TabController _tabController;
  static const int _virtualPetTabIndex = 0;
  static const int _realPetTabIndex = 1;

  // Animation controllers
  late AnimationController _bounceController;
  late AnimationController _bubbleController;
  late AnimationController _pulseController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _bubbleOpacity;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _bubbleSlide;

  // Bubble state
  bool _bubbleVisible = false;
  String _bubbleText = '';
  Timer? _autoBubbleTimer;
  Timer? _bubbleHideTimer;

  // Services
  final FoodService _foodService = FoodService();
  final WaterService _waterService = WaterService();
  final GoalTrackingService _goalTrackingService = GoalTrackingService();

  // 真实宠物列表
  List<Map<String, dynamic>> _realPets = [];
  bool _realPetsLoading = true;

  // Stats
  bool _statsLoading = true;
  double _foodProgress = 0.0;
  double _waterProgress = 0.0;
  double _consumedCalories = 0;
  double _targetCalories = 2000;
  int _waterTotalMl = 0;
  int _waterGoalMl = 2000;

  // Pet types
  static const List<Map<String, dynamic>> _petTypes = [
    {
      'type': 'cat',
      'name': '灵巧型',
      'description': '轻盈灵动，陪伴你健康饮食',
      'icon': Icons.pets,
      'color': Color(0xFF2BAF74),
    },
    {
      'type': 'dog',
      'name': '活力型',
      'description': '元气满满，监督你按时吃饭',
      'icon': Icons.cruelty_free,
      'color': Color(0xFFFF9800),
    },
    {
      'type': 'rabbit',
      'name': '温柔型',
      'description': '温婉细腻，提醒你营养均衡',
      'icon': Icons.emoji_nature,
      'color': Color(0xFFE91E63),
    },
    {
      'type': 'bear',
      'name': '守护型',
      'description': '沉稳可靠，守护你的健康目标',
      'icon': Icons.emoji_food_beverage,
      'color': Color(0xFF795548),
    },
  ];

  @override
  void initState() {
    super.initState();
    // 初始化Tab控制器
    _tabController = TabController(length: 2, vsync: this);

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bubbleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );
    _bubbleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _startAutoBubble();
    _loadStats();
    _fetchRealPets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bounceController.dispose();
    _bubbleController.dispose();
    _pulseController.dispose();
    _autoBubbleTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

  // ==================== Bubble ====================

  void _startAutoBubble() {
    _autoBubbleTimer?.cancel();
    _autoBubbleTimer = Timer.periodic(
      const Duration(minutes: 2, seconds: 30),
      (_) {
        final petState = ref.read(petProvider);
        if (petState.expression == PetExpression.calm ||
            petState.expression == PetExpression.happy) {
          _showBubble(petState.dialogue);
        }
      },
    );
  }

  void _showBubble(String text) {
    if (!mounted) return;
    setState(() {
      _bubbleText = text;
      _bubbleVisible = true;
    });
    _bubbleController.forward();

    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _bubbleController.reverse().then((_) {
        if (mounted) setState(() => _bubbleVisible = false);
      });
    });
  }

  // ==================== Tap & Interact ====================

  void _onTapPet() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    ref.read(petProvider.notifier).onTap();
    final petState = ref.read(petProvider);
    _showBubble(petState.dialogue);
  }

  // ==================== Load Data ====================

  Future<void> _loadStats() async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);

      // 获取动态热量目标
      double target = 2000.0;
      try {
        final goalResult = await _goalTrackingService.getDailyStatus();
        if (goalResult.success && goalResult.data != null) {
          final dailyTargets = goalResult.data!['daily_targets'];
          if (dailyTargets != null && dailyTargets['calories'] != null) {
            target = (dailyTargets['calories'] as num).toDouble();
          }
        }
      } catch (_) {
        // 获取目标失败时使用默认值 2000
      }

      final foodResult = await _foodService.getDailySummary(today);
      if (foodResult.success && foodResult.data != null) {
        final summary = foodResult.data!;
        final consumed = summary.totalCalories;
        if (mounted) {
          setState(() {
            _consumedCalories = consumed;
            _targetCalories = target;
            _foodProgress =
                target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
          });
        }
      }

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
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _fetchRealPets() async {
    setState(() => _realPetsLoading = true);
    final api = RealPetApiService();
    final result = await api.getPets();
    if (mounted) {
      setState(() {
        _realPetsLoading = false;
        if (result.isSuccess && result.data != null) {
          final pets = result.data!['pets'] as List<dynamic>? ?? [];
          _realPets = pets.map((p) => p as Map<String, dynamic>).toList();
        }
      });
    }
  }

  // ==================== Build ====================

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          '我的宠物',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2BAF74),
          unselectedLabelColor: const Color(0xFF999999),
          indicatorColor: const Color(0xFF2BAF74),
          labelStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '精灵伙伴'),
            Tab(text: '真实宠物'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 虚拟精灵伙伴（保留原有内容）
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPetDisplaySection(petState),
                const SizedBox(height: 20),
                _buildVisibilityToggle(petState),
                const SizedBox(height: 20),
                _buildPetTypeSelector(petState),
                const SizedBox(height: 20),
                _buildStatsPanel(petState),
              ],
            ),
          ),
          // Tab 2: 真实宠物
          _buildRealPetTab(),
        ],
      ),
    );
  }

  // ==================== 真实宠物 Tab ====================

  /// 真实宠物Tab内容
  Widget _buildRealPetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 添加宠物按钮
          GestureDetector(
            onTap: () => _showAddPetDialog(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2BAF74), Color(0xFF4ECDC4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.plus, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '添加真实宠物',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 宠物列表标题
          const Text(
            '我的宠物',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),

          if (_realPetsLoading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (_realPets.isEmpty)
            _buildEmptyRealPetsHint()
          else
            ..._realPets.map((pet) => _buildRealPetCard(pet)),
        ],
      ),
    );
  }

  Widget _buildEmptyRealPetsHint() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('还没有添加宠物',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
          const SizedBox(height: 4),
          Text('点击上方按钮添加你的第一只宠物吧',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  /// 真实宠物卡片
  Widget _buildRealPetCard(Map<String, dynamic> pet) {
    final species = pet['species'] as String? ?? '';
    final speciesIcon = getSpeciesIcon(species);
    final avatarUrl = pet['avatar_url'] as String?;
    final petName = pet['name'] as String? ?? '未命名';
    final petBreed = pet['breed'] as String? ?? '';
    final birthDateStr = pet['birth_date'] as String?;

    // 计算年龄
    String ageText = '未知';
    if (birthDateStr != null) {
      try {
        final birth = DateTime.parse(birthDateStr);
        final now = DateTime.now();
        final years = now.year - birth.year;
        if (years > 0) {
          ageText = '$years岁';
        } else {
          final months =
              now.month - birth.month + (now.day >= birth.day ? 0 : -1);
          ageText = '${months > 0 ? months : 1}个月';
        }
      } catch (_) {
        ageText = '未知';
      }
    }

    return GestureDetector(
      onTap: () => _navigateToPetDetail(pet),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 头像
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          speciesIcon,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      )
                    : Icon(
                        speciesIcon,
                        size: 32,
                        color: AppColors.primary,
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          petName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (petBreed.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            petBreed,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(speciesIcon,
                          size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '$species · $ageText',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 箭头
            const Icon(
              LucideIcons.chevronRight,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示添加宠物对话框
  void _showAddPetDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPetPage(),
      ),
    );
    // 重新加载宠物列表
    if (result != null) {
      _fetchRealPets();
    }
  }

  /// 跳转到宠物详情页
  void _navigateToPetDetail(Map<String, dynamic> pet) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealPetDetailPage(pet: pet),
      ),
    );
    // 如果详情页有修改(编辑/删除)，刷新列表
    if (result == 'deleted' || result == true) {
      _fetchRealPets();
    }
  }

  // ==================== Pet Display (interactive) ====================

  Widget _buildPetDisplaySection(PetState petState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2BAF74), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2BAF74).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Name + Level
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _showRenameDialog(petState),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        petState.petName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.pencil,
                        size: 14, color: Colors.white70),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Lv.${petState.level} ${petState.levelName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            petState.dialogue,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),

          // Animated pet with bubble
          GestureDetector(
            onTap: _onTapPet,
            child: Column(
              children: [
                if (_bubbleVisible)
                  FadeTransition(
                    opacity: _bubbleOpacity,
                    child: SlideTransition(
                      position: _bubbleSlide,
                      child: PetBubble(text: _bubbleText),
                    ),
                  ),
                if (_bubbleVisible) const SizedBox(height: 6),
                ScaleTransition(
                  scale: _bounceAnimation,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: PetAnimationWidget(
                      size: 160,
                      showLevelBadge: false,
                      enableInteraction: false,
                      skin: petState.currentSkin, // 使用当前选择的桌宠皮肤
                      customAvatarUrl: petState.customAvatarUrl, // AI 自定义头像
                      emotionUrls: petState.emotionUrls, // AI 情绪变体
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tap hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.hand, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  '点击互动',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Visibility Toggle ====================

  Widget _buildVisibilityToggle(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: petState.visible
                  ? const Color(0xFF2BAF74).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              petState.visible ? LucideIcons.eye : LucideIcons.eyeOff,
              color: petState.visible ? const Color(0xFF2BAF74) : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '在首页显示精灵',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  petState.visible ? '精灵正在首页陪伴你' : '精灵已隐藏，长按可重新开启',
                  style: TextStyle(
                    fontSize: 13,
                    color: petState.visible
                        ? const Color(0xFF2BAF74)
                        : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: petState.visible,
            onChanged: (value) {
              ref.read(petProvider.notifier).setPetVisible(value);
            },
            activeColor: const Color(0xFF2BAF74),
          ),
        ],
      ),
    );
  }

  // ==================== Pet Type Selector (桌宠选择) ====================

  Widget _buildPetTypeSelector(PetState petState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择精灵',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 12),
        // 桌宠列表（每行显示2个）
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: PetSkin.values.length,
          itemBuilder: (context, index) {
            final skin = PetSkin.values[index];
            final isSelected = petState.currentSkin == skin;
            final skinConfig = kPetSkinConfigs[skin];
            // 显示每个桌宠的独立名称
            final displayName = ref.read(petProvider.notifier).getPetName(skin);

            return GestureDetector(
              onTap: () {
                // 立即切换桌宠
                ref.read(petProvider.notifier).setPetSkin(skin);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE8E8E8),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行（包含名称和修改按钮）
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // 所有桌宠都显示修改按钮
                                GestureDetector(
                                  onTap: () =>
                                      _showEditPetNameDialog(skin, displayName),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      LucideIcons.pencil,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '当前',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 桌宠状态预览（显示各个状态的GIF）
                    if (skinConfig != null)
                      Row(
                        children: [
                          _buildPetStatePreview(skinConfig.happyGif, '开心'),
                          const SizedBox(width: 8),
                          _buildPetStatePreview(skinConfig.normalGif, '正常'),
                          const SizedBox(width: 8),
                          _buildPetStatePreview(skinConfig.hungryGif, '饥饿'),
                          const SizedBox(width: 8),
                          _buildPetStatePreview(skinConfig.anxiousGif, '焦虑'),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// 显示修改桌宠名称的对话框
  void _showEditPetNameDialog(PetSkin skin, String currentName) {
    final TextEditingController nameController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('修改${skin.defaultName}的名称'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: '请输入桌宠名称',
              border: OutlineInputBorder(),
            ),
            maxLength: 10, // 限制最多10个字符
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  // 为指定皮肤设置名称
                  ref
                      .read(petProvider.notifier)
                      .setPetName(newName, skin: skin);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${skin.defaultName}的名称已更新')),
                  );
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  /// 构建桌宠状态预览组件
  Widget _buildPetStatePreview(String gifPath, String label) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                gifPath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.backgroundSecondary,
                  child: const Icon(
                    LucideIcons.image,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Stats Panel ====================

  Widget _buildStatsPanel(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Icon(LucideIcons.activity,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text('宠物状态',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222))),
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
          const SizedBox(height: 16),

          // Food progress
          _buildStatBar(
            '饮食达标率',
            _consumedCalories,
            _targetCalories,
            AppColors.caloriesColor,
            LucideIcons.utensils,
            progress: _foodProgress,
          ),
          const SizedBox(height: 14),

          // Water progress
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

          // Level + Exp
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.star,
                          color: Colors.white, size: 22),
                      const SizedBox(height: 6),
                      Text('Lv.${petState.level}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.zap,
                            size: 14, color: AppColors.caloriesColor),
                        const SizedBox(width: 6),
                        const Text('经验值',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF222222))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _getExpProgress(petState),
                        backgroundColor:
                            AppColors.caloriesColor.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.caloriesColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${petState.exp} EXP',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.caloriesColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Streak
          Row(
            children: [
              const Icon(LucideIcons.calendar,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text('连续达标',
                  style: TextStyle(fontSize: 14, color: Color(0xFF222222))),
              const Spacer(),
              Text('${petState.currentStreak}天',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
              if (petState.longestStreak > 0) ...[
                const SizedBox(width: 14),
                Text('最长 ${petState.longestStreak}天',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
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
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF444444))),
            const Spacer(),
            Text(
              unit == 'ml'
                  ? '${current.toInt()}/${max.toInt()} ml'
                  : '${current.toInt()}/${max.toInt()} kcal',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
            ),
            const SizedBox(width: 6),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: p,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ==================== Helpers ====================

  double _getExpProgress(PetState petState) {
    final currentLevelExp = PetStorage.expForLevel(petState.level);
    final nextLevelExp = PetStorage.expForLevel(petState.level + 1);
    if (nextLevelExp <= currentLevelExp) return 1.0;
    return ((petState.exp - currentLevelExp) / (nextLevelExp - currentLevelExp))
        .clamp(0.0, 1.0);
  }

  String _getExpressionName(PetExpression expression) {
    const names = {
      PetExpression.satisfied: '满足',
      PetExpression.anxious: '焦虑',
      PetExpression.happy: '开心',
      PetExpression.calm: '平静',
      PetExpression.expect: '期待',
      PetExpression.weak: '虚弱',
      PetExpression.hungry: '饥饿',
    };
    return names[expression] ?? '平静';
  }

  void _showRenameDialog(PetState petState) {
    final controller = TextEditingController(text: petState.petName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('为你的精灵命名'),
        content: TextField(
          controller: controller,
          maxLength: 10,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '输入新名字',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: const Color(0xFFF5F7F6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(petProvider.notifier).setPetName(name);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2BAF74),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
