import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingHealthGoalsPage extends ConsumerStatefulWidget {
  const OnboardingHealthGoalsPage({super.key});

  @override
  ConsumerState<OnboardingHealthGoalsPage> createState() => _OnboardingHealthGoalsPageState();
}

class _OnboardingHealthGoalsPageState extends ConsumerState<OnboardingHealthGoalsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  
  int _selectedGoal = 0;
  final _targetWeightController = TextEditingController();
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '健康目标',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/complete'),
            child: const Text('跳过'),
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 进度指示器
                _buildProgressIndicator(3),
                
                const SizedBox(height: 32),
                
                // 标题
                Text(
                  '设置您的健康目标',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '明确的目标有助于制定合适的饮食计划',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 目标选择
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '请选择您的主要目标',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(5, (index) {
                              final goalType = index + 1;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildGoalOption(goalType),
                              );
                            }),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // 目标体重（可选）
                        if (_selectedGoal == 1 || _selectedGoal == 2) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '目标体重 (kg)',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _targetWeightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '请输入目标体重',
                                  filled: true,
                                  fillColor: AppColors.cardBackground,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  prefixIcon: const Icon(
                                    LucideIcons.target,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        
                        // 目标达成时间
                        if (_selectedGoal > 0) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '预期达成时间',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _selectTargetDate,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        LucideIcons.calendar,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _targetDate != null
                                            ? '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'
                                            : '请选择目标日期',
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: _targetDate != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        LucideIcons.chevronDown,
                                        color: AppColors.textSecondary,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // 继续按钮
                AppButton(
                  text: '完成设置',
                  onPressed: _selectedGoal > 0 ? _completeSetup : null,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentStep ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= currentStep ? AppColors.primary : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _buildGoalOption(int goalType) {
    final isSelected = _selectedGoal == goalType;
    final goalData = _getGoalData(goalType);
    
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goalType),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              goalData['icon'],
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goalData['title'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    goalData['description'],
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                LucideIcons.check,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getGoalData(int goalType) {
    switch (goalType) {
      case 1:
        return {
          'icon': LucideIcons.trendingDown,
          'title': '减重',
          'description': '科学减重，保持健康',
        };
      case 2:
        return {
          'icon': LucideIcons.trendingUp,
          'title': '增重',
          'description': '健康增重，营养均衡',
        };
      case 3:
        return {
          'icon': LucideIcons.minus,
          'title': '维持体重',
          'description': '保持当前体重，维持健康',
        };
      case 4:
        return {
          'icon': LucideIcons.dumbbell,
          'title': '增肌',
          'description': '增加肌肉量，提升体质',
        };
      case 5:
        return {
          'icon': LucideIcons.flame,
          'title': '减脂',
          'description': '降低体脂率，塑造体型',
        };
      default:
        return {};
    }
  }

  Future<void> _selectTargetDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (picked != null) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _completeSetup() {
    // 保存健康目标数据
    final healthGoals = [
      {
        'goal_type': _selectedGoal,
        'target_weight': _targetWeightController.text.isNotEmpty
            ? double.tryParse(_targetWeightController.text)
            : null,
        'target_date': _targetDate?.toIso8601String().split('T')[0],
      }
    ];
    
    ref.read(onboardingProvider.notifier).updateHealthGoals(healthGoals);
    
    // 跳转到完成页面
    context.go('/onboarding/complete');
  }
}