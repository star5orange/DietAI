import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';
import '../shared/domain/models/weight_record_model.dart';

class WeightRecordsService {
  final ApiService _apiService = ApiService();

  /// 获取用户的体重记录列表
  Future<ApiResponse<List<WeightRecord>>> getWeightRecords({
    int? limit,
    int? offset,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/users/weight-records',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data is List 
          ? response.data 
          : (response.data['items'] ?? []);
        final records = dataList.map((json) => WeightRecord.fromJson(json)).toList();
        
        return ApiResponse<List<WeightRecord>>.success(
          message: response.message.isNotEmpty ? response.message : '获取体重记录成功',
          data: records,
        );
      } else {
        return ApiResponse<List<WeightRecord>>.failure(
          message: response.message.isNotEmpty ? response.message : '获取体重记录失败',
        );
      }
    } catch (e) {
      return ApiResponse<List<WeightRecord>>.failure(
        message: '获取体重记录失败: $e',
      );
    }
  }

  /// 创建新的体重记录
  Future<ApiResponse<WeightRecord>> createWeightRecord(CreateWeightRecordRequest request) async {
    try {
      final response = await _apiService.post(
        '/users/weight-records',
        data: request.toJson(),
      );
      
      if (response.success && response.data != null) {
        final record = WeightRecord.fromJson(response.data);
        
        return ApiResponse<WeightRecord>.success(
          message: response.message.isNotEmpty ? response.message : '添加体重记录成功',
          data: record,
        );
      } else {
        return ApiResponse<WeightRecord>.failure(
          message: response.message.isNotEmpty ? response.message : '添加体重记录失败',
        );
      }
    } catch (e) {
      return ApiResponse<WeightRecord>.failure(
        message: '添加体重记录失败: $e',
      );
    }
  }

  /// 更新体重记录
  Future<ApiResponse<WeightRecord>> updateWeightRecord(int recordId, UpdateWeightRecordRequest request) async {
    try {
      final response = await _apiService.put(
        '/users/weight-records/$recordId',
        data: request.toJson(),
      );
      
      if (response.success && response.data != null) {
        final record = WeightRecord.fromJson(response.data);
        
        return ApiResponse<WeightRecord>.success(
          message: response.message.isNotEmpty ? response.message : '更新体重记录成功',
          data: record,
        );
      } else {
        return ApiResponse<WeightRecord>.failure(
          message: response.message.isNotEmpty ? response.message : '更新体重记录失败',
        );
      }
    } catch (e) {
      return ApiResponse<WeightRecord>.failure(
        message: '更新体重记录失败: $e',
      );
    }
  }

  /// 删除体重记录
  Future<ApiResponse<void>> deleteWeightRecord(int recordId) async {
    try {
      final response = await _apiService.delete('/users/weight-records/$recordId');
      
      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '删除体重记录成功',
        );
      } else {
        return ApiResponse<void>.failure(
          message: response.message.isNotEmpty ? response.message : '删除体重记录失败',
        );
      }
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除体重记录失败: $e',
      );
    }
  }

  /// 获取体重趋势分析
  Future<ApiResponse<WeightTrend>> getWeightTrend({int? days}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (days != null) queryParams['days'] = days;

      final response = await _apiService.get(
        '/health/weight-trend',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final trend = WeightTrend.fromJson(response.data);
        
        return ApiResponse<WeightTrend>.success(
          message: response.message.isNotEmpty ? response.message : '获取体重趋势成功',
          data: trend,
        );
      } else {
        return ApiResponse<WeightTrend>.failure(
          message: response.message.isNotEmpty ? response.message : '获取体重趋势失败',
        );
      }
    } catch (e) {
      return ApiResponse<WeightTrend>.failure(
        message: '获取体重趋势失败: $e',
      );
    }
  }

  /// 获取最新的体重记录
  Future<ApiResponse<WeightRecord>> getLatestWeightRecord() async {
    try {
      final response = await _apiService.get('/users/weight-records', queryParameters: {'limit': 1});
      
      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data is List 
          ? response.data 
          : (response.data['items'] ?? []);
        if (dataList.isEmpty) {
          return ApiResponse<WeightRecord>.failure(
            message: '暂无体重记录',
          );
        }
        final record = WeightRecord.fromJson(dataList[0] as Map<String, dynamic>);
        
        return ApiResponse<WeightRecord>.success(
          message: response.message.isNotEmpty ? response.message : '获取最新体重记录成功',
          data: record,
        );
      } else {
        return ApiResponse<WeightRecord>.failure(
          message: response.message.isNotEmpty ? response.message : '获取最新体重记录失败',
        );
      }
    } catch (e) {
      return ApiResponse<WeightRecord>.failure(
        message: '获取最新体重记录失败: $e',
      );
    }
  }
}