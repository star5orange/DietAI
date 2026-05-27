import 'package:json_annotation/json_annotation.dart';

part 'api_response.g.dart';

/// 通用API响应模型
@JsonSerializable(genericArgumentFactories: true)
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final String? error;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiResponseFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$ApiResponseToJson(this, toJsonT);

  /// 成功响应
  factory ApiResponse.success({
    required String message,
    T? data,
  }) =>
      ApiResponse(
        success: true,
        message: message,
        data: data,
      );

  /// 失败响应
  factory ApiResponse.failure({
    required String message,
    String? error,
  }) =>
      ApiResponse(
        success: false,
        message: message,
        error: error,
      );

  /// 检查是否成功
  bool get isSuccess => success;

  /// 检查是否失败
  bool get isFailure => !success;
}

/// 分页数据模型
@JsonSerializable(genericArgumentFactories: true)
class PaginatedData<T> {
  final List<T> items;
  final int total;
  final int page;
  @JsonKey(name: 'page_size')
  final int pageSize;
  @JsonKey(name: 'total_pages')
  final int totalPages;
  @JsonKey(name: 'has_next')
  final bool hasNext;
  @JsonKey(name: 'has_prev')
  final bool hasPrev;

  const PaginatedData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory PaginatedData.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$PaginatedDataFromJson(json, fromJsonT);

  Map<String, dynamic> toJson(Object? Function(T value) toJsonT) =>
      _$PaginatedDataToJson(this, toJsonT);
} 