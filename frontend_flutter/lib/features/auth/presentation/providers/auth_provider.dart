import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../domain/services/auth_service.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

/// 认证服务提供者
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// 认证状态提供者
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AsyncValue<User?>>((ref) {
  return AuthStateNotifier(ref.read(authServiceProvider), ref);
});

/// 认证状态管理器
class AuthStateNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final Ref _ref;
  static const _storage = FlutterSecureStorage();

  AuthStateNotifier(this._authService, this._ref) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  /// 初始化认证状态
  Future<void> _initializeAuth() async {
    try {
      print('🔄 开始初始化认证状态...');
      
      // 检查是否有存储的令牌
      final accessToken = await _storage.read(key: AppConstants.accessTokenKey);
      
      if (accessToken != null) {
        print('🔑 发现存储的token，验证有效性...');
        
        // 验证令牌有效性
        final isValid = await _authService.isTokenValid();
        
        if (isValid) {
          print('✅ Token有效，获取用户信息...');
          // 获取用户信息
          final userResponse = await _authService.getCurrentUser();
          
          if (userResponse.isSuccess && userResponse.data != null) {
            print('✅ 用户信息获取成功，设置已登录状态');
            state = AsyncValue.data(userResponse.data);
            return;
          } else {
            print('❌ 用户信息获取失败，清除token');
            await _storage.delete(key: AppConstants.accessTokenKey);
            await _storage.delete(key: AppConstants.refreshTokenKey);
          }
        } else {
          print('❌ Token无效，清除token');
          await _storage.delete(key: AppConstants.accessTokenKey);
          await _storage.delete(key: AppConstants.refreshTokenKey);
        }
      } else {
        print('ℹ️ 未发现存储的token');
      }
      
      // 令牌无效或不存在，设置为未登录状态
      print('✅ 设置为未登录状态');
      state = const AsyncValue.data(null);
    } catch (e) {
      print('❌ 认证状态初始化失败: $e');
      // 发生错误时也设置为未登录状态，而不是error状态
      state = const AsyncValue.data(null);
    }
  }

  /// 登录
  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      print('🔐 开始登录流程...');
      final response = await _authService.login(
        username: username,
        password: password,
      );

      if (response.isSuccess) {
        print('✅ 登录成功，准备获取用户信息...');
        
        // 登录成功，获取用户信息
        final userResponse = await _authService.getCurrentUser();
        
        if (userResponse.isSuccess && userResponse.data != null) {
          print('✅ 用户信息获取成功');
          state = AsyncValue.data(userResponse.data);
          
          // 登录成功后检查引导状态
          await _checkOnboardingStatus();
        } else {
          print('❌ 用户信息获取失败: ${userResponse.message}');
          // 即使获取用户信息失败，登录仍然成功，设置空用户状态
          state = const AsyncValue.data(null);
        }
      } else {
        print('❌ 登录失败: ${response.message}');
        state = AsyncValue.error(
          response.message,
          StackTrace.current,
        );
      }
    } catch (e) {
      print('❌ 登录过程发生异常: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// 检查引导状态
  Future<void> _checkOnboardingStatus() async {
    try {
      print('🔍 开始检查用户引导状态...');
      await _ref.read(onboardingProvider.notifier).checkOnboardingStatus();
      print('✅ 引导状态检查完成');
    } catch (e) {
      print('❌ 检查引导状态失败: $e');
    }
  }

  /// 注册并自动登录
  Future<bool> registerAndLogin({
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      print('📝 开始注册流程...');
      
      // 先注册
      final registerResponse = await _authService.register(
        username: username,
        email: email,
        password: password,
        phone: phone,
      );

      if (!registerResponse.isSuccess) {
        print('❌ 注册失败: ${registerResponse.message}');
        return false;
      }
      
      print('✅ 注册成功，开始自动登录...');
      
      // 注册成功后自动登录
      await login(username: username, password: password);
      
      // 检查登录是否成功
      final currentUser = state.value;
      if (currentUser != null) {
        print('✅ 注册和登录流程完成');
        return true;
      } else {
        print('❌ 自动登录失败');
        return false;
      }
    } catch (e) {
      print('❌ 注册流程失败: $e');
      return false;
    }
  }

  /// 注册
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final response = await _authService.register(
        username: username,
        email: email,
        password: password,
        phone: phone,
      );

      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _authService.logout();
      state = const AsyncValue.data(null);
    } catch (e) {
      // 即使退出失败，也清除本地状态
      state = const AsyncValue.data(null);
    }
  }

  /// 刷新用户信息
  Future<void> refreshUser() async {
    if (state.value == null) return;
    
    try {
      final userResponse = await _authService.getCurrentUser();
      
      if (userResponse.isSuccess && userResponse.data != null) {
        state = AsyncValue.data(userResponse.data);
      }
    } catch (e) {
      // 刷新失败时保持当前状态
    }
  }

  /// 修改密码
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
}

/// 当前用户提供者
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// 登录状态提供者
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// 用户信息加载状态提供者
final userLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isLoading;
});

/// 认证错误提供者
final authErrorProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    error: (error, _) => error.toString(),
  );
}); 