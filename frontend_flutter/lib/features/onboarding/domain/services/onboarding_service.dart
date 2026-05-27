import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/domain/models/api_response.dart';

class OnboardingService {
  final Dio _dio;
  static const _storage = FlutterSecureStorage();

  OnboardingService() : _dio = Dio() {
    _dio.options.baseUrl = AppConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    
    // 添加请求拦截器来自动添加认证头
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 这里应该从 secure storage 获取 token
          // 暂时先用这个方式
          final token = await _getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<String?> _getAuthToken() async {
    try {
      return await _storage.read(key: AppConstants.accessTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// 检查用户引导状态
  Future<ApiResponse<Map<String, dynamic>>> checkOnboardingStatus() async {
    try {
      final token = await _getAuthToken();
      print('🔑 Token状态: ${token != null ? "已获取" : "未获取"}');
      
      if (token == null) {
        print('❌ 没有认证token');
        return ApiResponse.failure(message: '用户未登录');
      }
      
      print('📡 发送请求到: ${AppConstants.baseUrl}/api/users/onboarding/status');
      final response = await _dio.get('/api/users/onboarding/status');
      
      print('📨 响应状态码: ${response.statusCode}');
      print('📊 响应数据: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          print('✅ API调用成功');
          return ApiResponse.success(
            message: '获取引导状态成功',
            data: data['data'],
          );
        } else {
          print('❌ API返回失败: ${data['message']}');
          return ApiResponse.failure(
            message: data['message'] ?? '获取引导状态失败',
          );
        }
      } else {
        print('❌ HTTP状态码错误: ${response.statusCode}');
        return ApiResponse.failure(message: '服务器错误');
      }
    } catch (e) {
      print('❌ 网络请求异常: $e');
      return ApiResponse.failure(message: '网络错误: ${e.toString()}');
    }
  }

  /// 更新引导步骤
  Future<ApiResponse<Map<String, dynamic>>> updateOnboardingStep({
    required int step,
    Map<String, dynamic>? data,
    bool? completed,
  }) async {
    try {
      final requestData = {
        'step': step,
        if (data != null) 'data': data,
        if (completed != null) 'completed': completed,
      };

      final response = await _dio.post('/api/users/onboarding/step', data: requestData);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return ApiResponse.success(
            message: '更新引导步骤成功',
            data: responseData['data'],
          );
        } else {
          return ApiResponse.failure(
            message: responseData['message'] ?? '更新引导步骤失败',
          );
        }
      } else {
        return ApiResponse.failure(message: '服务器错误');
      }
    } catch (e) {
      return ApiResponse.failure(message: '网络错误: ${e.toString()}');
    }
  }

  /// 完成引导流程
  Future<ApiResponse<Map<String, dynamic>>> completeOnboarding({
    required Map<String, dynamic> onboardingData,
  }) async {
    try {
      final response = await _dio.post('/api/users/onboarding/complete', data: onboardingData);
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return ApiResponse.success(
            message: '完成引导成功',
            data: responseData['data'],
          );
        } else {
          return ApiResponse.failure(
            message: responseData['message'] ?? '完成引导失败',
          );
        }
      } else {
        return ApiResponse.failure(message: '服务器错误');
      }
    } catch (e) {
      return ApiResponse.failure(message: '网络错误: ${e.toString()}');
    }
  }

  /// 重置引导状态
  Future<ApiResponse<Map<String, dynamic>>> resetOnboarding() async {
    try {
      final response = await _dio.post('/api/users/onboarding/reset');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          return ApiResponse.success(
            message: '重置引导成功',
            data: responseData['data'],
          );
        } else {
          return ApiResponse.failure(
            message: responseData['message'] ?? '重置引导失败',
          );
        }
      } else {
        return ApiResponse.failure(message: '服务器错误');
      }
    } catch (e) {
      return ApiResponse.failure(message: '网络错误: ${e.toString()}');
    }
  }
}