import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../../shared/domain/models/user_model.dart';

/// 启动页面
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // 开始动画
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 检查用户是否已完成引导，决定跳转目标
  Future<void> _checkOnboardingAndNavigate() async {
    try {
      // 调用后端API检查引导状态
      await ref.read(onboardingProvider.notifier).checkOnboardingStatus();
      if (!mounted) return;

      final onboardingState = ref.read(onboardingProvider);
      if (!onboardingState.isCompleted) {
        // 用户从未完成引导，跳转到引导欢迎页
        print('🔄 引导未完成，跳转到引导欢迎页');
        context.go('/onboarding');
        return;
      }
    } catch (e) {
      print('⚠️ 检查引导状态失败: $e');
      // 检查失败时默认跳转到首页，避免阻塞用户
    }

    if (mounted) {
      print('🔄 用户已登录且引导已完成，跳转到首页');
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化
    final authState = ref.watch(authStateProvider);

    // 立即检查当前状态（防止错过已经完成的初始化）
    if (!_hasNavigated) {
      authState.when(
        data: (user) {
          if (_hasNavigated || !mounted) return;
          print('✅ 认证状态：data, user=${user?.username ?? "null"}');
          _hasNavigated = true;
          // 使用 postFrameCallback 避免在 build 中直接调用导航
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (user != null) {
              _checkOnboardingAndNavigate();
            } else {
              print('🔄 用户未登录，跳转到登录页面');
              context.go('/login');
            }
          });
        },
        loading: () {
          print('🔄 认证状态加载中...');
        },
        error: (error, stack) {
          if (_hasNavigated || !mounted) return;
          print('❌ 认证错误：$error');
          _hasNavigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go('/login');
          });
        },
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo容器
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Image.asset('assets/images/logo_welcome.png'),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 应用名称
                    Text(
                      AppConstants.appName,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 应用描述
                    Text(
                      AppConstants.appDescription,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // 加载指示器
                    _buildLoadingIndicator(),

                    const SizedBox(height: 16),

                    // 状态文字
                    Text(
                      '正在初始化...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 32,
      height: 32,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(
          AppColors.primary,
        ),
      ),
    );
  }
}
