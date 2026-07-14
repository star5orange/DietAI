import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../providers/pet_provider.dart';
import '../widgets/pet_animation_widget.dart';
import '../../domain/services/pet_service.dart';
import 'pet_detail_page.dart';

/// 宠物首页
/// 展示宠物动画组件、快速操作按钮、连续达标天数徽章
class PetHomePage extends ConsumerStatefulWidget {
  const PetHomePage({super.key});

  @override
  ConsumerState<PetHomePage> createState() => _PetHomePageState();
}

class _PetHomePageState extends ConsumerState<PetHomePage> {
  final PetService _petService = PetService();

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
        title: Text(
          petState.petName,
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings,
                color: AppColors.textSecondary),
            onPressed: () => _navigateToDetail(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 宠物动画展示
            _buildPetSection(petState),
            const SizedBox(height: 24),

            // 连续达标天数徽章
            _buildStreakBadge(petState),
            const SizedBox(height: 24),

            // 状态面板
            _buildStatusPanel(petState),
            const SizedBox(height: 24),

            // 快速操作按钮
            _buildQuickActions(),
            const SizedBox(height: 24),

            // 导航到详情页按钮
            _buildNavigationButton(),
          ],
        ),
      ),
    );
  }

  /// 宠物动画展示区域
  Widget _buildPetSection(PetState petState) {
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
          // 宠物动画组件
          PetAnimationWidget(
            size: 160,
            showLevelBadge: true,
            showMoodIndicator: true,
            enableInteraction: true,
            skin: petState.currentSkin, // 使用用户选择的皮肤
          ),
          const SizedBox(height: 16),

          // 宠物状态文字
          Text(
            petState.dialogue,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 连续达标天数徽章
  Widget _buildStreakBadge(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          // 连续达标天数
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning,
                  AppColors.warningLight,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.calendar,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  '${petState.currentStreak}天',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 描述文字
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连续达标',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  petState.currentStreak > 0
                      ? '已连续${petState.currentStreak}天达标！继续保持哦~'
                      : '还没有连续达标记录，开始努力吧！',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (petState.longestStreak > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '最长记录：${petState.longestStreak}天',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 状态面板
  Widget _buildStatusPanel(PetState petState) {
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
              Text('今日状态', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),

          // 饮食进度
          _buildProgressItem(
            '饮食达标率',
            petState.foodProgress,
            AppColors.caloriesColor,
            LucideIcons.utensils,
          ),
          const SizedBox(height: 12),

          // 饮水进度
          _buildProgressItem(
            '饮水达标率',
            petState.waterProgress,
            AppColors.info,
            LucideIcons.droplet,
          ),
          const SizedBox(height: 16),

          // 经验值进度
          _buildExpProgress(petState),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String label,
    double progress,
    Color color,
    IconData icon,
  ) {
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
              '${(progress * 100).toInt()}%',
              style: AppTextStyles.numberXSmall.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildExpProgress(PetState petState) {
    final progress = petState.maxExp > 0 ? petState.exp / petState.maxExp : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.zap, size: 16, color: AppColors.success),
            const SizedBox(width: 8),
            Text('经验值', style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(
              '${petState.exp}/${petState.maxExp}',
              style:
                  AppTextStyles.numberXSmall.copyWith(color: AppColors.success),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  /// 快速操作按钮
  Widget _buildQuickActions() {
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
              Text('快速互动', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton('喂食', LucideIcons.cookie, AppColors.warning,
                  () {
                _doInteract('feed', '喂食成功！+10经验值', 10);
              }),
              _buildActionButton('玩耍', LucideIcons.gamepad2, AppColors.info,
                  () {
                _doInteract('play', '玩耍成功！+8经验值', 8);
              }),
              _buildActionButton(
                  '抚摸', LucideIcons.heartHandshake, AppColors.success, () {
                _doInteract('pet', '抚摸成功！+5经验值', 5);
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _doInteract(String action, String message, int exp) {
    _petService.petInteract(action: action);
    ref.read(petProvider.notifier).addExp(exp);
    _showSnackBar(message);
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导航到详情页按钮
  Widget _buildNavigationButton() {
    return GestureDetector(
      onTap: _navigateToDetail,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.mediumShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.arrowRight, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              '查看详情',
              style: AppTextStyles.buttonMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PetDetailPage()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.sparkles, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
