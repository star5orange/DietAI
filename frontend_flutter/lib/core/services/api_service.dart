import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../../shared/domain/models/api_response.dart';

/// API服务基础类
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  static const _storage = FlutterSecureStorage();

  /// 获取Dio实例
  Dio get dio => _dio;

  /// 初始化API服务
  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConstants.baseUrl}${AppConstants.apiPrefix}',
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.requestTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 添加日志拦截器（仅在调试模式下）
    _dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
    ));

    // 添加认证拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 只对需要认证的端点添加令牌
        if (!_isAuthEndpoint(options.path)) {
          final token = await _getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) async {
        // 只对需要认证的端点处理401错误，避免对登录/注册等端点处理
        if (error.response?.statusCode == 401 && !_isAuthEndpoint(error.requestOptions.path)) {
          // 避免递归刷新令牌
          if (error.requestOptions.path.contains('/auth/refresh-token')) {
            await _clearTokens();
            handler.next(error);
            return;
          }
          
          // 尝试刷新令牌
          final refreshed = await _refreshToken();
          if (refreshed) {
            // 重新发送原始请求
            final request = error.requestOptions;
            final token = await _getAccessToken();
            if (token != null) {
              request.headers['Authorization'] = 'Bearer $token';
            }
            
            try {
              final response = await _dio.fetch(request);
              handler.resolve(response);
              return;
            } catch (e) {
              // 刷新后仍然失败，继续原错误处理
            }
          }
          
          // 刷新失败，清除令牌
          await _clearTokens();
        }
        
        handler.next(error);
      },
    ));
  }

  /// 获取访问令牌
  Future<String?> _getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  /// 获取访问令牌（公开方法）
  Future<String?> getAccessToken() async {
    return await _getAccessToken();
  }

  /// 获取刷新令牌
  Future<String?> _getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  /// 保存令牌
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  /// 清除令牌（私有方法）
  Future<void> _clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  /// 清除令牌（公开方法）
  Future<void> clearTokens() async {
    await _clearTokens();
  }

  /// 判断是否为认证相关端点（这些端点不需要自动添加token或处理401）
  bool _isAuthEndpoint(String path) {
    final authPaths = [
      '/auth/login',
      '/auth/register', 
      '/auth/refresh-token',
    ];
    return authPaths.any((authPath) => path.contains(authPath));
  }

  /// 刷新令牌
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) return false;

      // 创建新的Dio实例避免触发拦截器
      final tempDio = Dio(BaseOptions(
        baseUrl: '${AppConstants.baseUrl}${AppConstants.apiPrefix}',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));

      final response = await tempDio.post(
        '/auth/refresh-token',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (e) {
      // 刷新失败
    }
    
    return false;
  }

  /// 通用请求方法
  Future<Response> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return await _dio.request(
      path,
      data: data,
      queryParameters: queryParameters,
      options: (options ?? Options()).copyWith(method: method),
    );
  }

  /// 通用GET请求
  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );

      return ApiResponse<dynamic>(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        data: response.data['data'],
      );
    } catch (e) {
      if (e is DioException) {
        return ApiResponse<dynamic>(
          success: false,
          message: e.response?.data?['message'] ?? e.message ?? '请求失败',
        );
      }
      return ApiResponse<dynamic>(
        success: false,
        message: '请求失败: $e',
      );
    }
  }

  /// 通用POST请求
  Future<ApiResponse<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

      return ApiResponse<dynamic>(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        data: response.data['data'],
      );
    } catch (e) {
      if (e is DioException) {
        return ApiResponse<dynamic>(
          success: false,
          message: e.response?.data?['message'] ?? e.message ?? '请求失败',
        );
      }
      return ApiResponse<dynamic>(
        success: false,
        message: '请求失败: $e',
      );
    }
  }

  /// 流式POST请求 - 用于SSE
  Stream<String> postStream(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      if (response.data != null) {
        final stream = response.data!.stream;
        
        await for (final data in stream) {
          final string = utf8.decode(data);
          final lines = string.split('\n');
          
          for (final line in lines) {
            if (line.trim().isNotEmpty) {
              yield line;
            }
          }
        }
      }
    } catch (e) {
      yield 'data: {"type": "error", "message": "连接失败: $e"}';
    }
  }

  /// 通用PUT请求
  Future<ApiResponse<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

      return ApiResponse<dynamic>(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        data: response.data['data'],
      );
    } catch (e) {
      if (e is DioException) {
        return ApiResponse<dynamic>(
          success: false,
          message: e.response?.data?['message'] ?? e.message ?? '请求失败',
        );
      }
      return ApiResponse<dynamic>(
        success: false,
        message: '请求失败: $e',
      );
    }
  }

  /// 通用DELETE请求
  Future<ApiResponse<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );

      return ApiResponse<dynamic>(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        data: response.data['data'],
      );
    } catch (e) {
      if (e is DioException) {
        return ApiResponse<dynamic>(
          success: false,
          message: e.response?.data?['message'] ?? e.message ?? '请求失败',
        );
      }
      return ApiResponse<dynamic>(
        success: false,
        message: '请求失败: $e',
      );
    }
  }

  /// 文件上传
  Future<Response<T>> upload<T>(
    String path, {
    required FormData formData,
    ProgressCallback? onSendProgress,
    Options? options,
  }) async {
    return await _dio.post<T>(
      path,
      data: formData,
      options: options,
      onSendProgress: onSendProgress,
    );
  }

  /// POST FormData请求 (文件上传的便捷方法)
  Future<ApiResponse<dynamic>> postFormData(
    String path, {
    required FormData data,
    ProgressCallback? onSendProgress,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: options,
        onSendProgress: onSendProgress,
      );

      return ApiResponse<dynamic>(
        success: response.data['success'] ?? false,
        message: response.data['message'] ?? '',
        data: response.data['data'],
      );
    } catch (e) {
      if (e is DioException) {
        return ApiResponse<dynamic>(
          success: false,
          message: e.response?.data?['message'] ?? e.message ?? '请求失败',
        );
      }
      return ApiResponse<dynamic>(
        success: false,
        message: '请求失败: $e',
      );
    }
  }
} 