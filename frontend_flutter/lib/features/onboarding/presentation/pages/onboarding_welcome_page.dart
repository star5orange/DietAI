import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingWelcomePage extends ConsumerStatefulWidget {
  const OnboardingWelcomePage({super.key});

  @override
  ConsumerState<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends ConsumerState<OnboardingWelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
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
    print('📝 OnboardingWelcomePage 正在构建...');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 跳过按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      print('📝 用户点击了跳过按钮');
                      // 调用后端API记录用户已跳过引导，避免下次登录再次弹出
                      try {
                        final service = ref.read(onboardingServiceProvider);
                        await service.updateOnboardingStep(step: 1, completed: true);
                      } catch (e) {
                        print('⚠️ 更新引导步骤失败: $e');
                      }
                      // 同时更新本地状态，避免当前会话中再次弹出
                      ref.read(onboardingProvider.notifier).updateStep(6);
                      if (mounted) {
                        context.go('/');
                      }
                    },
                    child: Text(
                      '跳过',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 欢迎动画
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 120,
                          color: AppColors.primary,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // 标题
                      Text(
                        '欢迎使用 DietAI',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 副标题
                      Text(
                        '让我们为您打造个性化的饮食方案',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // 描述
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
                            _buildFeatureItem(
                              icon: Icons.psychology,
                              title: '智能分析',
                              description: 'AI 驱动的食物识别与营养分析',
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(
                              icon: Icons.favorite,
                              title: '个性化建议',
                              description: '根据您的健康状况定制饮食方案',
                            ),
                            const SizedBox(height: 12),
                            _buildFeatureItem(
                              icon: Icons.trending_up,
                              title: '健康追踪',
                              description: '全面记录您的饮食与健康数据',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 开始按钮
              AppButton(
                text: '开始设置',
                onPressed: () {
                  print('📝 用户点击了开始设置按钮');
                  context.go('/onboarding/basic-info');
                },
                variant: AppButtonVariant.primary,
              ),
              
              const SizedBox(height: 16),
              
              // 进度指示器
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 6; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == 0 ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == 0 ? AppColors.primary : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}