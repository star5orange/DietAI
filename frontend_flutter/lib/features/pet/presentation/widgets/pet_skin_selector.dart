import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../domain/pet_skin_config.dart';
import '../providers/pet_provider.dart';

/// 桌宠选择器组件
/// 允许用户选择不同的桌宠形象
class PetSkinSelector extends ConsumerWidget {
  final Function(PetSkin)? onSkinSelected;
  final PetSkin? selectedSkin;

  const PetSkinSelector({
    super.key,
    this.onSkinSelected,
    this.selectedSkin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 获取当前皮肤（如果未指定）
    final currentSkin = selectedSkin ?? PetSkin.defaultPet;

    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(LucideIcons.palette,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('选择桌宠形象', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PetSkin.values.map((skin) {
              final isSelected = skin == currentSkin;
              return _buildSkinCard(
                skin: skin,
                isSelected: isSelected,
                onTap: () {
                  if (onSkinSelected != null) {
                    onSkinSelected!(skin);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkinCard({
    required PetSkin skin,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // 桌宠预览（显示开心状态）
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.backgroundCard,
              ),
              child: ClipOval(
                child: Image.asset(
                  kPetSkinConfigs[skin]?.happyGif ?? 'assets/pet/happy.gif',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    LucideIcons.image,
                    size: 30,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 桌宠名称
            Text(
              skin.defaultName,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '当前',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 使用示例
class PetSkinSelectorExample extends ConsumerStatefulWidget {
  const PetSkinSelectorExample({super.key});

  @override
  ConsumerState<PetSkinSelectorExample> createState() =>
      _PetSkinSelectorExampleState();
}

class _PetSkinSelectorExampleState
    extends ConsumerState<PetSkinSelectorExample> {
  PetSkin _selectedSkin = PetSkin.defaultPet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('桌宠选择'),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 桌宠选择器
            PetSkinSelector(
              selectedSkin: _selectedSkin,
              onSkinSelected: (skin) {
                setState(() {
                  _selectedSkin = skin;
                });
                // 这里可以调用后端API保存用户选择
                // ref.read(petProvider.notifier).setSkin(skin.key);
              },
            ),
            const SizedBox(height: 24),
            // 预览区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.lightShadow,
              ),
              child: Column(
                children: [
                  Text('预览', style: AppTextStyles.h6),
                  const SizedBox(height: 16),
                  Text('当前选择: ${_selectedSkin.defaultName}'),
                  // 这里可以显示桌宠的各个状态
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
