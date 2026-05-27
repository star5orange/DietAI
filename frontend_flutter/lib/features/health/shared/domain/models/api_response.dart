/// 通用API响应模型
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final DateTime timestamp;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 成功响应
  factory ApiResponse.success(T data, [String message = '成功']) {
    return ApiResponse(
      success: true,
      message: message,
      data: data,
    );
  }

  /// 错误响应
  factory ApiResponse.error(String message, [T? data]) {
    return ApiResponse(
      success: false,
      message: message,
      data: data,
    );
  }

  /// 从JSON创建
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson(dynamic Function(T) toJsonT) {
    return {
      'success': success,
      'message': message,
      'data': data != null ? toJsonT(data as T) : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}