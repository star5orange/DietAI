import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';

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
    
    // 延迟后进行认证检查
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    // 等待动画完成
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    // 直接检查认证状态并跳转
    _handleAuthStateChange();
  }

  void _handleAuthStateChange() {
    final authState = ref.read(authStateProvider);
    
    authState.when(
      data: (user) {
        if (!mounted) return;
        if (user != null) {
          // 已登录，跳转到首页
          print('🔄 用户已登录，跳转到首页');
          context.go('/');
        } else {
          // 未登录，跳转到登录页面
          print('🔄 用户未登录，跳转到登录页面');
          context.go('/login');
        }
      },
      loading: () {
        // 认证状态加载中，等待下一次状态更新
        print('🔄 认证状态加载中...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _handleAuthStateChange();
          }
        });
      },
      error: (error, stack) {
        if (!mounted) return;
        print('❌ 认证错误: $error');
        // 认证错误，跳转到登录页面
        context.go('/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      child: const Center(
                        child: Text(
                          '🥗',
                          style: TextStyle(fontSize: 48),
                        ),
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