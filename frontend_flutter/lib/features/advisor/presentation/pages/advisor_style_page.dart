import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/advisor_service.dart';
import '../widgets/advisor_style_selector.dart';

/// AI顾问风格设置页面
class AdvisorStylePage extends ConsumerStatefulWidget {
  const AdvisorStylePage({super.key});

  @override
  ConsumerState<AdvisorStylePage> createState() => _AdvisorStylePageState();
}

class _AdvisorStylePageState extends ConsumerState<AdvisorStylePage> {
  String _selectedStyle = 'nutritionist';
  String? _selectedFocusGoal;
  String? _selectedFocusNutrient;
  String _selectedResponseStyle = 'friendly';

  final List<Map<String, dynamic>> _advisorStyles = [
    {
      'id': 'nutritionist',
      'name': '营养师',
      'icon': LucideIcons.apple,
      'desc': '专业营养知识，科学饮食建议'
    },
    {
      'id': 'fitness_coach',
      'name': '健身教练',
      'icon': LucideIcons.dumbbell,
      'desc': '运动营养搭配，增肌减脂指导'
    },
    {
      'id': 'tcm_healer',
      'name': '中医养生师',
      'icon': LucideIcons.heart,
      'desc': '体质辨识，食疗养生建议'
    },
    {
      'id': 'encouraging_friend',
      'name': '鼓励型伙伴',
      'icon': LucideIcons.users,
      'desc': '轻松鼓励，陪伴式健康管理'
    },
    {
      'id': 'motivator',
      'name': '励志伙伴',
      'icon': LucideIcons.star,
      'desc': '积极鼓励，陪伴式减脂'
    },
  ];

  final List<String> _focusGoals = [
    '减脂塑形',
    '增肌增重',
    '控糖稳糖',
    '养生调理',
    '均衡健康',
  ];

  final List<String> _focusNutrients = [
    '热量',
    '蛋白质',
    '碳水化合物',
    '脂肪',
    '微量元素',
  ];

  final List<Map<String, String>> _responseStyles = [
    {'id': 'professional', 'name': '专业严谨'},
    {'id': 'friendly', 'name': '亲切友好'},
    {'id': 'motivating', 'name': '激励鼓舞'},
    {'id': 'detailed', 'name': '详尽细致'},
  ];

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
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
          'AI顾问风格',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('保存',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('选择顾问风格', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            AdvisorStyleSelector(
              selectedStyle: _selectedStyle,
              styles: _advisorStyles,
              onChanged: (style) => setState(() => _selectedStyle = style),
            ),
            const SizedBox(height: 24),
            Text('关注目标（可选）', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _focusGoals
                  .map((goal) => _buildChip(
                        label: goal,
                        isSelected: _selectedFocusGoal == goal,
                        onTap: () => setState(() => _selectedFocusGoal =
                            _selectedFocusGoal == goal ? null : goal),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('关注营养素（可选）', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _focusNutrients
                  .map((nutrient) => _buildChip(
                        label: nutrient,
                        isSelected: _selectedFocusNutrient == nutrient,
                        onTap: () => setState(() => _selectedFocusNutrient =
                            _selectedFocusNutrient == nutrient
                                ? null
                                : nutrient),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('回复风格', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            ..._responseStyles.map((style) => _buildResponseStyleRadio(style)),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildResponseStyleRadio(Map<String, String> style) {
    final isSelected = _selectedResponseStyle == style['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedResponseStyle = style['id']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: style['id']!,
              groupValue: _selectedResponseStyle,
              onChanged: (value) =>
                  setState(() => _selectedResponseStyle = value!),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              style['name']!,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(advisorServiceProvider);

      // 将中文标签映射为后端ID
      final goalMap = {
        '减脂塑形': 'fat_loss',
        '增肌增重': 'muscle_gain',
        '控糖稳糖': 'sugar_control',
        '养生调理': 'wellness',
        '均衡健康': 'balanced',
      };
      final nutrientMap = {
        '热量': 'calories',
        '蛋白质': 'protein',
        '碳水化合物': 'carb',
        '脂肪': 'fat',
        '微量元素': 'micronutrient',
      };

      await service.updateSettings(AdvisorSettings(
        advisorStyle: _selectedStyle,
        focusGoal:
            _selectedFocusGoal != null ? goalMap[_selectedFocusGoal] : null,
        focusNutrient: _selectedFocusNutrient != null
            ? nutrientMap[_selectedFocusNutrient]
            : null,
        responseStyle: _selectedResponseStyle,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
