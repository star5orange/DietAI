import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../shared/utils/species_utils.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_animation_widget.dart';
import '../../domain/services/pet_service.dart';
import 'pet_detail_page.dart';
import 'add_pet_page.dart';
import 'real_pet_detail_page.dart';
import '../../data/real_pet_api_service.dart';

/// 我的宠物统一入口页
/// 顶部 Tab 切换：精灵伙伴（虚拟宠物）/ 我的宠物（真实宠物）
class MyPetPage extends ConsumerStatefulWidget {
  const MyPetPage({super.key});

  @override
  ConsumerState<MyPetPage> createState() => _MyPetPageState();
}

class _MyPetPageState extends ConsumerState<MyPetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PetService _petService = PetService();

  // 真实宠物数据
  List<Map<String, dynamic>> _realPets = [];
  bool _isLoadingRealPets = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRealPets();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _realPets.isEmpty && !_isLoadingRealPets) {
      _loadRealPets();
    }
  }

  Future<void> _loadRealPets() async {
    setState(() => _isLoadingRealPets = true);
    try {
      final api = RealPetApiService();
      final res = await api.getPets();
      if (res.isSuccess && res.data != null) {
        final pets = res.data!['pets'] as List<dynamic>? ?? [];
        _realPets =
            pets.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingRealPets = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 自定义 Tab 栏
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // AppBar 部分
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            '我的宠物',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  // Tab 栏
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      dividerColor: Colors.transparent,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textTertiary,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: '精灵伙伴'),
                        Tab(text: '我的宠物'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Tab 内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: 虚拟精灵伙伴
                _buildVirtualPetTab(petState),
                // Tab 2: 真实宠物
                _buildRealPetTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _navigateToAddPet,
              backgroundColor: AppColors.primary,
              child: const Icon(LucideIcons.plus, color: Colors.white),
            )
          : null,
    );
  }

  // ========== 虚拟精灵 Tab ==========

  Widget _buildVirtualPetTab(PetState petState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 宠物动画展示
          _buildVirtualPetAnimation(petState),
          const SizedBox(height: 20),

          // 状态面板
          _buildVirtualPetStatus(petState),
          const SizedBox(height: 20),

          // 快速操作按钮
          _buildQuickActions(),
          const SizedBox(height: 20),

          // 导航到详情页按钮
          _buildNavigationButton(),
        ],
      ),
    );
  }

  Widget _buildVirtualPetAnimation(PetState petState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primarySurface, AppColors.backgroundCard],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Column(
        children: [
          PetAnimationWidget(
            size: 140,
            showLevelBadge: true,
            showMoodIndicator: true,
            enableInteraction: true,
            skin: petState.currentSkin,
            customAvatarUrl: petState.customAvatarUrl, // AI 自定义头像
            emotionUrls: petState.emotionUrls, // AI 情绪变体
          ),
          const SizedBox(height: 12),
          Text(
            (petState.dialogue.isEmpty) ? '嗯~' : petState.dialogue,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVirtualPetStatus(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          _buildStatusItem(
            LucideIcons.award,
            '等级',
            'Lv.${petState.level}',
            AppColors.warning,
          ),
          const SizedBox(width: 16),
          _buildStatusItem(
            LucideIcons.zap,
            '经验',
            '${petState.exp}/${petState.maxExp}',
            AppColors.info,
          ),
          const SizedBox(width: 16),
          _buildStatusItem(
            LucideIcons.flame,
            '连续',
            '${petState.currentStreak}天',
            AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            LucideIcons.candy,
            '喂食',
            AppColors.caloriesColor,
            () => _petService.petFeed(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            LucideIcons.droplet,
            '喂水',
            AppColors.info,
            () => _petService.petInteract(action: 'water'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            LucideIcons.heart,
            '抚摸',
            AppColors.error,
            () => _petService.petTouch(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PetDetailPage()),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(LucideIcons.settings, size: 18),
        label: const Text('精灵设置'),
      ),
    );
  }

  // ========== 真实宠物 Tab ==========

  Widget _buildRealPetTab() {
    if (_isLoadingRealPets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_realPets.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadRealPets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _realPets.length,
        itemBuilder: (context, index) {
          final pet = _realPets[index];
          return _buildRealPetCard(pet);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Center(
                child: Icon(Icons.pets, size: 48, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '还没有添加宠物',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击下方按钮添加您的真实宠物',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToAddPet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('添加宠物'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealPetCard(Map<String, dynamic> pet) {
    final name = (pet['name'] as String?) ?? '未命名';
    final species = (pet['species'] as String?) ?? 'cat';
    final breed = (pet['breed'] as String?) ?? '';
    final avatarUrl = (pet['avatar_url'] as String?) ?? '';

    final speciesIcon = getSpeciesIcon(species);
    final speciesLabel = getSpeciesLabel(species);

    return GestureDetector(
      onTap: () => _navigateToRealPetDetail(pet),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                image: avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl.isEmpty
                  ? Icon(speciesIcon, color: AppColors.primary, size: 28)
                  : null,
            ),
            const SizedBox(width: 16),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          speciesLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    breed.isNotEmpty ? breed : '未知品种',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // 箭头
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ========== 导航 ==========

  void _navigateToAddPet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPetPage()),
    );
    _loadRealPets();
  }

  void _navigateToRealPetDetail(Map<String, dynamic> pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealPetDetailPage(pet: pet),
      ),
    );
    _loadRealPets();
  }
}
