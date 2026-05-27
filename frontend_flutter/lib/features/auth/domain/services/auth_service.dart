import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/user_model.dart';

/// 认证服务
class AuthService {
  final ApiService _apiService = ApiService();

  /// 登录
  Future<ApiResponse<AuthResponse>> login({
    required String username,
    required String password,
  }) async {
    try {
      final request = LoginRequest(
        username: username,
        password: password,
      );

      final response = await _apiService.post(
        '/auth/login',
        data: request.toJson(),
      );

      if (response.success) {
        final authResponse = AuthResponse.fromJson(response.data as Map<String, dynamic>);

        // 保存令牌
          await _apiService.saveTokens(
          accessToken: authResponse.accessToken,
          refreshToken: authResponse.refreshToken,
          );

        return ApiResponse<AuthResponse>(
          success: true,
          message: response.message,
          data: authResponse,
        );
      } else {
        return ApiResponse<AuthResponse>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<AuthResponse>(
        success: false,
        message: '网络错误，请检查网络连接',
      );
    }
  }

  /// 注册
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String username,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final request = RegisterRequest(
        username: username,
        email: email,
        password: password,
        phone: phone,
      );

      final response = await _apiService.post(
        '/auth/register',
        data: request.toJson(),
      );

      if (response.success) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data as Map<String, dynamic>,
        );
      } else {
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: '网络错误，请检查网络连接',
      );
    }
  }

  /// 获取当前用户信息
  Future<ApiResponse<User>> getCurrentUser() async {
    try {
      final response = await _apiService.get('/auth/me');

      if (response.success) {
        final user = User.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<User>(
          success: true,
          message: response.message,
          data: user,
        );
      } else {
        return ApiResponse<User>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<User>(
        success: false,
        message: '网络错误，请检查网络连接',
      );
    }
  }

  /// 退出登录
  Future<ApiResponse<void>> logout() async {
    try {
      final response = await _apiService.post('/auth/logout');

      // 不管服务端响应如何，都清除本地令牌
      await _clearLocalTokens();

      return ApiResponse<void>(
        success: true,
        message: response.success ? response.message : '已退出登录',
      );
    } catch (e) {
      // 即使网络错误，也清除本地令牌
      await _clearLocalTokens();
      return ApiResponse<void>(
        success: true,
        message: '已退出登录',
      );
    }
  }

  /// 修改密码
  Future<ApiResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final request = ChangePasswordRequest(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      final response = await _apiService.post(
        '/auth/change-password',
        data: request.toJson(),
      );

      if (response.success) {
        return ApiResponse<void>(
          success: true,
          message: response.message,
        );
      } else {
        return ApiResponse<void>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: '网络错误，请检查网络连接',
      );
    }
  }

  /// 验证令牌有效性
  Future<bool> isTokenValid() async {
    try {
      final response = await _apiService.get('/auth/verify-token');
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// 清除本地令牌
  Future<void> _clearLocalTokens() async {
    await _apiService.clearTokens();
  }
} 