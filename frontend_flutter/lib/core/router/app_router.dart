import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/camera/presentation/pages/camera_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/food_history_test_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/health/presentation/pages/main_health_page.dart';
import '../../features/health/presentation/pages/reminder_settings_page.dart';
import '../../features/health/presentation/pages/constitution_quiz_page.dart';
import '../../features/saved_meals/presentation/pages/saved_meals_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_basic_info_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_physical_data_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_health_goals_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_complete_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/models/user_model.dart';
import '../../shared/presentation/widgets/main_scaffold.dart';
import '../../shared/presentation/pages/splash_page.dart';

/// 认证状态变化监听器 - 仅通知路由刷新，不重建GoRouter实例
class AuthNotifier extends ChangeNotifier {
  AuthNotifier(Ref ref) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) {
      notifyListeners();
    });
  }
}

final authNotifierProvider = Provider<AuthNotifier>((ref) {
  return AuthNotifier(ref);
});

/// 路由配置Provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: ref.watch(authNotifierProvider),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.whenOrNull(
            data: (user) => user != null,
          ) ??
          false;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      final isOnboardingRoute = state.matchedLocation.startsWith('/onboarding');

      final isSplashRoute = state.matchedLocation == '/splash';

      // 如果在启动页面，让其自然完成
      if (isSplashRoute) {
        return null;
      }

      // 如果未登录且不在认证页面或引导页面，重定向到登录页
      if (!isLoggedIn && !isAuthRoute && !isOnboardingRoute) {
        print('🔄 未登录用户访问非认证页面，重定向到登录页: ${state.matchedLocation}');
        return '/login';
      }

      // 如果已登录且在认证页面，重定向到首页
      if (isLoggedIn && isAuthRoute) {
        print('🔄 已登录用户访问认证页面，重定向到首页');
        return '/';
      }

      // 允许访问引导页面（无论是否登录）
      if (isOnboardingRoute) {
        print('🔄 允许访问引导页面: ${state.matchedLocation}');
        return null;
      }

      return null;
    },
    routes: [
      // 启动页
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // 登录页面
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),

      // 注册页面
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // 修改密码页面
      GoRoute(
        path: '/change-password',
        name: 'change_password',
        builder: (context, state) => const ChangePasswordPage(),
      ),

      // 引导页面
      GoRoute(
        path: '/onboarding',
        name: 'onboarding_welcome',
        builder: (context, state) => const OnboardingWelcomePage(),
      ),

      GoRoute(
        path: '/onboarding/basic-info',
        name: 'onboarding_basic_info',
        builder: (context, state) => const OnboardingBasicInfoPage(),
      ),

      GoRoute(
        path: '/onboarding/physical-data',
        name: 'onboarding_physical_data',
        builder: (context, state) => const OnboardingPhysicalDataPage(),
      ),

      GoRoute(
        path: '/onboarding/health-goals',
        name: 'onboarding_health_goals',
        builder: (context, state) => const OnboardingHealthGoalsPage(),
      ),

      GoRoute(
        path: '/onboarding/complete',
        name: 'onboarding_complete',
        builder: (context, state) => const OnboardingCompletePage(),
      ),

      // 主页面（带底部导航）
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // 首页
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),

          // 历史页面
          GoRoute(
            path: '/history',
            name: 'history',
            builder: (context, state) => const HistoryPage(),
          ),

          // 图片预览测试页面
          GoRoute(
            path: '/history/test',
            name: 'history_test',
            builder: (context, state) => const FoodHistoryTestPage(),
          ),

          // 健康页面
          GoRoute(
            path: '/health',
            name: 'health',
            builder: (context, state) => const HealthPage(),
          ),

          // 个人资料页面
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),

          // 保存菜品页面
          GoRoute(
            path: '/saved-meals',
            name: 'saved_meals',
            builder: (context, state) => const SavedMealsPage(),
          ),

          // 提醒设置页面
          GoRoute(
            path: '/reminder-settings',
            name: 'reminder_settings',
            builder: (context, state) => const ReminderSettingsPage(),
          ),

          // 体质自测页面
          GoRoute(
            path: '/constitution-quiz',
            name: 'constitution_quiz',
            builder: (context, state) => const ConstitutionQuizPage(),
          ),
        ],
      ),

      // 相机页面（单独路由，不带底部导航）
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => const CameraPage(),
      ),
    ],

    // 错误页面
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('页面错误'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? '未知错误',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// 路由扩展方法
extension GoRouterExtension on BuildContext {
  /// 导航到首页
  void goHome() => go(AppConstants.homeRoute);

  /// 导航到登录页
  void goLogin() => go(AppConstants.loginRoute);

  /// 导航到注册页
  void goRegister() => go(AppConstants.registerRoute);

  /// 导航到拍照页
  void goCamera() => go(AppConstants.cameraRoute);

  /// 导航到历史页
  void goHistory() => go(AppConstants.historyRoute);

  /// 导航到个人资料页
  void goProfile() => go(AppConstants.profileRoute);

  /// 导航到密码修改页
  void goChangePassword() => push('/change-password');
}
