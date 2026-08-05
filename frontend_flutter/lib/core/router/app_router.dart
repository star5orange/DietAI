import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../services/modal_tracker.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/change_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/camera/presentation/pages/camera_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/pages/food_history_test_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/my_pet_page.dart';
import '../../features/health/presentation/pages/main_health_page.dart';
import '../../features/health/presentation/pages/reminder_settings_page.dart';
import '../../features/health/presentation/pages/constitution_quiz_page.dart';
import '../../features/health/presentation/pages/wellness_page.dart';
import '../../features/cost/presentation/pages/cost_statistics_page.dart';
import '../../features/advisor/presentation/pages/advisor_style_page.dart';
import '../../features/pet/presentation/pages/pet_home_page.dart';
import '../../features/pet/presentation/pages/real_pet_detail_page.dart';
import '../../features/pet/presentation/pages/add_pet_page.dart';
import '../../features/pet/presentation/pages/pet_feeding_page.dart';
import '../../features/pet/presentation/pages/pet_food_library_page.dart';
import '../../features/pet/presentation/pages/generate_pet_avatar_page.dart';
import '../../features/pet/presentation/pages/pet_weekly_report_page.dart';
import '../../features/fast/presentation/pages/fasting_plan_page.dart';
import '../../features/fast/presentation/pages/fasting_assessment_page.dart';
import '../../features/fast/presentation/pages/fasting_checkin_page.dart';
import '../../features/fast/presentation/pages/fasting_checkin_history_page.dart';
import '../../features/fast/presentation/pages/fasting_refeed_page.dart';
import '../../features/fast/presentation/pages/fasting_progress_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_welcome_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_basic_info_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_physical_data_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_health_goals_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_crowd_tag_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_constitution_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_complete_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../../shared/domain/models/user_model.dart';
import '../../shared/presentation/widgets/main_scaffold.dart';
import '../../shared/presentation/pages/splash_page.dart';
// Milestone 4: 社交与家庭
import '../../features/social/presentation/pages/social_page.dart';
import '../../features/social/presentation/pages/search_user_page.dart';
import '../../features/social/presentation/pages/friend_requests_page.dart';
import '../../features/social/presentation/pages/chat_page.dart';
import '../../features/social/presentation/pages/family_health_page.dart';
import '../../features/social/presentation/pages/leaderboard_page.dart';
import '../../features/social/presentation/pages/permission_page.dart';
import '../../features/social/presentation/pages/invite_code_page.dart';
import '../../features/family/presentation/pages/family_dashboard_page.dart';
import '../../features/family/presentation/pages/weekly_report_page.dart';
import '../../features/family/presentation/pages/diet_recommendation_page.dart';
import '../../features/family/presentation/pages/proxy_record_page.dart';
import '../../features/exam/presentation/pages/exam_reports_page.dart';
import '../../features/exam/presentation/pages/exam_detail_page.dart';
import '../../features/exam/presentation/pages/exam_upload_page.dart';
import '../../features/exam/presentation/pages/exam_trend_page.dart';

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
    observers: [ModalTrackerObserver()],
    refreshListenable: ref.watch(authNotifierProvider),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.whenOrNull(
            data: (user) => user != null,
          ) ??
          false;

      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';

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

      // 如果已登录且在认证页面，检查引导状态后重定向
      if (isLoggedIn && isAuthRoute) {
        final onboardingState = ref.read(onboardingProvider);
        if (!onboardingState.isCompleted) {
          print('🔄 已登录用户未完成引导，重定向到引导页');
          return '/onboarding';
        }
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

      // 忘记密码页面
      GoRoute(
        path: '/forgot-password',
        name: 'forgot_password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // 重置密码页面
      GoRoute(
        path: '/reset-password',
        name: 'reset_password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ResetPasswordPage(
            phone: extra['phone'] as String,
            code: extra['code'] as String, // 接收验证码参数
          );
        },
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
        path: '/onboarding/crowd-tag',
        name: 'onboarding_crowd_tag',
        builder: (context, state) => const OnboardingCrowdTagPage(),
      ),

      GoRoute(
        path: '/onboarding/constitution',
        name: 'onboarding_constitution',
        builder: (context, state) => const OnboardingConstitutionPage(),
      ),

      GoRoute(
        path: '/onboarding/complete',
        name: 'onboarding_complete',
        builder: (context, state) => const OnboardingCompletePage(),
      ),

      // 主页面（带底部导航）- 使用用户 ID 作为 key，切换账号时强制重建
      ShellRoute(
        builder: (context, state, child) {
          final userId = ref.watch(currentUserProvider)?.id ?? 0;
          return MainScaffold(key: ValueKey('scaffold_$userId'), child: child);
        },
        routes: [
          // 首页
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) {
              final userId = ref.watch(currentUserProvider)?.id ?? 0;
              return HomePage(key: ValueKey('home_$userId'));
            },
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

          // 提醒设置页面
          GoRoute(
            path: '/reminder-settings',
            name: 'reminder_settings',
            builder: (context, state) => const ReminderSettingsPage(),
          ),

          // 真实宠物详情页（从首页宠物健康跳转）
          GoRoute(
            path: '/real-pet-detail/:petId',
            name: 'real_pet_detail',
            builder: (context, state) {
              final pet = state.extra as Map<String, dynamic>;
              return RealPetDetailPage(pet: pet);
            },
          ),

          // 宠物添加页面
          GoRoute(
            path: '/add-pet',
            name: 'add_pet',
            builder: (context, state) => const AddPetPage(),
          ),

          // 宠物饮食日报（完整报告）
          GoRoute(
            path: '/pet-feeding',
            name: 'pet_feeding',
            builder: (context, state) {
              final pet = state.extra as Map<String, dynamic>;
              return PetFeedingPage(pet: pet);
            },
          ),

          // 宠物食品库
          GoRoute(
            path: '/pet-food-library',
            name: 'pet_food_library',
            builder: (context, state) => const PetFoodLibraryPage(),
          ),

          // 宠物AI形象生成
          GoRoute(
            path: '/generate-pet-avatar',
            name: 'generate_pet_avatar',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return GeneratePetAvatarPage(
                petId: (extra['petId'] as num?)?.toInt() ?? 0,
                petName: extra['petName'] as String? ?? '未命名',
                species: extra['species'] as String? ?? '猫',
              );
            },
          ),

          // 宠物饮食周报
          GoRoute(
            path: '/pet-weekly-report',
            name: 'pet_weekly_report',
            builder: (context, state) {
              final pet = state.extra as Map<String, dynamic>;
              return PetWeeklyReportPage(pet: pet);
            },
          ),

          // 体质自测页面
          GoRoute(
            path: '/constitution-quiz',
            name: 'constitution_quiz',
            builder: (context, state) => const ConstitutionQuizPage(),
          ),

          // 养生推荐页面
          GoRoute(
            path: '/wellness',
            name: 'wellness',
            builder: (context, state) => const WellnessPage(),
          ),

          // M2: 消费统计页
          GoRoute(
            path: '/cost-statistics',
            name: 'cost_statistics',
            builder: (context, state) => const CostStatisticsPage(),
          ),

          // M2: AI顾问风格设置页
          GoRoute(
            path: '/advisor-style',
            name: 'advisor_style',
            builder: (context, state) => const AdvisorStylePage(),
          ),

          // 我的精灵页（从"我的"页面进入）
          GoRoute(
            path: '/my-pet',
            name: 'my_pet',
            builder: (context, state) => const MyPetPage(),
          ),

          // M2: 轻断食 — 健康评估
          GoRoute(
            path: '/fasting-assessment',
            name: 'fasting_assessment',
            builder: (context, state) => const FastingAssessmentPage(),
          ),

          // M2: 轻断食 — 计划主页
          GoRoute(
            path: '/fasting-plan',
            name: 'fasting_plan',
            builder: (context, state) => const FastingPlanPage(),
          ),

          // M2: 轻断食 — 每日打卡
          GoRoute(
            path: '/fasting-checkin',
            name: 'fasting_checkin',
            builder: (context, state) => const FastingCheckinPage(),
          ),

          // M2: 轻断食 — 打卡记录历史
          GoRoute(
            path: '/fasting-checkin-history',
            name: 'fasting_checkin_history',
            builder: (context, state) => const FastingCheckinHistoryPage(),
          ),

          // M2: 轻断食 — 复食指导
          GoRoute(
            path: '/fasting-refeed',
            name: 'fasting_refeed',
            builder: (context, state) => const FastingRefeedPage(),
          ),

          // M2: 轻断食 — 进度追踪
          GoRoute(
            path: '/fasting-progress',
            name: 'fasting_progress',
            builder: (context, state) => const FastingProgressPage(),
          ),

          // M4: 社交 — 家人与好友主页
          GoRoute(
            path: '/social',
            name: 'social',
            builder: (context, state) => const SocialPage(),
          ),

          // M4: 社交 — 搜索用户
          GoRoute(
            path: '/social/search',
            name: 'social_search',
            builder: (context, state) => const SearchUserPage(),
          ),

          // M4: 社交 — 好友申请
          GoRoute(
            path: '/social/requests',
            name: 'social_requests',
            builder: (context, state) => const FriendRequestsPage(),
          ),

          // M4: 社交 — 好友饮食排行榜
          GoRoute(
            path: '/social/leaderboard',
            name: 'social_leaderboard',
            builder: (context, state) => const LeaderboardPage(),
          ),

          // M4: 社交 — 聊天页面
          GoRoute(
            path: '/social/chat/:userId',
            name: 'social_chat',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return ChatPage(
                targetUserId: userId,
                targetUserName: extra?['name'] as String?,
                targetUserAvatar: extra?['avatarUrl'] as String?,
              );
            },
          ),

          // M4: 社交 — 家人健康详情
          GoRoute(
            path: '/social/family-health/:userId',
            name: 'family_health',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return FamilyHealthPage(
                userId: userId,
                userName: extra?['name'] as String?,
              );
            },
          ),

          // M4: 家庭健康看板
          GoRoute(
            path: '/family-dashboard',
            name: 'family_dashboard',
            builder: (context, state) => const FamilyDashboardPage(),
          ),

          // M4: 家庭周报
          GoRoute(
            path: '/family/weekly-report',
            name: 'family_weekly_report',
            builder: (context, state) => const WeeklyReportPage(),
          ),

          // M4: 饮食推荐
          GoRoute(
            path: '/family/diet-recommendation/:userId',
            name: 'diet_recommendation',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return DietRecommendationPage(
                userId: userId,
                userName: extra?['name'] as String? ?? '家人',
              );
            },
          ),

          // M4: 代记录饮食
          GoRoute(
            path: '/family/proxy-record/:userId',
            name: 'proxy_record',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return ProxyRecordPage(
                targetUserId: userId,
                targetUserName: extra?['name'] as String? ?? '家人',
              );
            },
          ),

          // M4: 数据权限管理
          GoRoute(
            path: '/social/permission/:userId',
            name: 'social_permission',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return PermissionPage(
                targetUserId: userId,
                targetUserName: extra?['name'] as String? ?? '好友',
              );
            },
          ),

          // M4: 邀请码
          GoRoute(
            path: '/social/invite-code',
            name: 'invite_code',
            builder: (context, state) => const InviteCodePage(),
          ),

          // M4: 体检报告列表
          GoRoute(
            path: '/exam/reports',
            name: 'exam_reports',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ExamReportsPage(userId: extra?['userId'] as int?);
            },
          ),

          // M4: 体检报告详情
          GoRoute(
            path: '/exam/detail/:reportId',
            name: 'exam_detail',
            builder: (context, state) {
              final reportId = int.parse(state.pathParameters['reportId']!);
              final extra = state.extra as Map<String, dynamic>?;
              return ExamDetailPage(
                reportId: reportId,
                userId: extra?['userId'] as int?,
              );
            },
          ),

          // M4: 体检指标趋势
          GoRoute(
            path: '/exam/trend/:userId/:metricName',
            name: 'exam_trend',
            builder: (context, state) {
              final userId = int.parse(state.pathParameters['userId']!);
              final metricName =
                  Uri.decodeComponent(state.pathParameters['metricName']!);
              return ExamTrendPage(userId: userId, metricName: metricName);
            },
          ),

          // M4: 上传体检报告
          GoRoute(
            path: '/exam/upload',
            name: 'exam_upload',
            builder: (context, state) => const ExamUploadPage(),
          ),
        ],
      ),

      // 相机页面（单独路由，不带底部导航）
      GoRoute(
        path: '/camera',
        name: 'camera',
        builder: (context, state) => CameraPage(
          recordDate: DateTime.now().toIso8601String().substring(0, 10),
        ),
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
