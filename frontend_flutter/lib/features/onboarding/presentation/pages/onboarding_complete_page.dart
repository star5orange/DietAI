import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingCompletePage extends ConsumerStatefulWidget {
  const OnboardingCompletePage({super.key});

  @override
  ConsumerState<OnboardingCompletePage> createState() => _OnboardingCompletePageState();
}

class _OnboardingCompletePageState extends ConsumerState<OnboardingCompletePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 成功动画
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.success,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.check,
                          color: AppColors.success,
                          size: 60,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 成功文案
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            '设置完成！',
                            style: AppTextStyles.h2.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            '感谢您完成个人信息设置',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // 数据摘要
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '您的专属健康档案已创建',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildSummaryItem(
                                  icon: LucideIcons.user,
                                  title: '基本信息',
                                  completed: onboardingState.basicInfo.isNotEmpty,
                                ),
                                _buildSummaryItem(
                                  icon: LucideIcons.activity,
                                  title: '身体数据',
                                  completed: onboardingState.physicalData.isNotEmpty,
                                ),
                                _buildSummaryItem(
                                  icon: LucideIcons.target,
                                  title: '健康目标',
                                  completed: onboardingState.healthGoals.isNotEmpty,
                                ),
                                _buildSummaryItem(
                                  icon: LucideIcons.heart,
                                  title: '健康状况',
                                  completed: onboardingState.medicalConditions.isNotEmpty || 
                                           onboardingState.allergies.isNotEmpty,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // 提示信息
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.info.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.lightbulb,
                                  color: AppColors.info,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '现在您可以开始记录饮食，获取个性化的营养建议了！',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 开始使用按钮
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    AppButton(
                      text: onboardingState.isLoading ? '保存中...' : '开始使用 DietAI',
                      onPressed: onboardingState.isLoading ? null : _completeOnboarding,
                      variant: AppButtonVariant.primary,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextButton(
                      onPressed: () => context.go('/onboarding/basic-info'),
                      child: Text(
                        '重新设置',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required bool completed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            completed ? LucideIcons.checkCircle : LucideIcons.circle,
            color: completed ? AppColors.success : AppColors.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            color: completed ? AppColors.primary : AppColors.textTertiary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: completed ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    try {
      await ref.read(onboardingProvider.notifier).completeOnboarding();
      
      if (mounted) {
        // 跳转到主页
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}