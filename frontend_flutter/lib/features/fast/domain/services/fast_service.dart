import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/services/api_service.dart';

/// 轻断食服务
/// 用于管理轻断食计划、打卡记录和复食指导
class FastService {
  final ApiService _apiService = ApiService();

  /// 获取计划列表（可筛选状态）
  Future<ApiResponse<List<Map<String, dynamic>>>> getPlans({
    String? status,
  }) async {
    try {
      final response = await _apiService.get(
        '/fasting/plans',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );

      if (response.isSuccess && response.data != null) {
        // 后端返回 {"plans": [...]}，需取 plans 字段
        final data = response.data as Map<String, dynamic>;
        final plansList = data['plans'] as List? ?? [];
        final list = plansList
            .map((e) => (e as Map<String, dynamic>).cast<String, dynamic>())
            .toList();
        return ApiResponse.success(message: response.message, data: list);
      }
      return ApiResponse.success(
        message: response.message,
        data: [],
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取计划列表失败', error: e.toString());
    }
  }

  /// 获取当前活动计划
  Future<ApiResponse<Map<String, dynamic>>> getActivePlan() async {
    try {
      final result = await getPlans(status: 'active');
      if (result.isSuccess && result.data != null && result.data!.isNotEmpty) {
        return ApiResponse.success(
          message: '获取活动计划成功',
          data: result.data!.first,
        );
      }
      return ApiResponse.success(message: '无活动计划', data: null);
    } catch (e) {
      return ApiResponse.failure(message: '获取活动计划失败', error: e.toString());
    }
  }

  /// 获取历史计划列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getHistoryPlans({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final result = await getPlans();
      if (result.isSuccess && result.data != null) {
        final history =
            result.data!.where((p) => p['status'] != 'active').toList();
        return ApiResponse.success(
          message: '获取历史计划成功',
          data: history,
        );
      }
      return ApiResponse.success(message: '无历史计划', data: []);
    } catch (e) {
      return ApiResponse.failure(message: '获取历史计划失败', error: e.toString());
    }
  }

  /// 创建轻断食计划
  Future<ApiResponse<Map<String, dynamic>>> createPlan({
    required String planType,
    required String startDate,
    String eatingWindowStart = '08:00',
    String eatingWindowEnd = '16:00',
    double? targetWeight,
    Map<String, dynamic>? healthAssessment,
    bool disclaimerAccepted = true,
  }) async {
    try {
      final response = await _apiService.post(
        '/fasting/plans',
        data: {
          'plan_type': planType,
          'start_date': startDate,
          'eating_window_start': eatingWindowStart,
          'eating_window_end': eatingWindowEnd,
          if (targetWeight != null) 'target_weight': targetWeight,
          if (healthAssessment != null) 'health_assessment': healthAssessment,
          'disclaimer_accepted': disclaimerAccepted,
        },
      );

      if (response.isSuccess) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '创建计划失败', error: e.toString());
    }
  }

  /// 结束计划
  Future<ApiResponse<bool>> stopPlan(int planId) async {
    try {
      await _apiService.put('/fasting/plans/$planId/stop');
      return ApiResponse.success(message: '计划已停止', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '结束计划失败', error: e.toString());
    }
  }

  /// 删除计划
  Future<ApiResponse<bool>> deletePlan(int planId) async {
    try {
      await _apiService.delete('/fasting/plans/$planId');
      return ApiResponse.success(message: '计划已删除', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '删除计划失败', error: e.toString());
    }
  }

  /// 更新计划
  Future<ApiResponse<Map<String, dynamic>>> updatePlan({
    required int planId,
    double? targetWeight,
    String? eatingWindowStart,
    String? eatingWindowEnd,
    String? endDate,
  }) async {
    try {
      final response = await _apiService.put(
        '/fasting/plans/$planId',
        data: {
          if (targetWeight != null) 'target_weight': targetWeight,
          if (eatingWindowStart != null)
            'eating_window_start': eatingWindowStart,
          if (eatingWindowEnd != null) 'eating_window_end': eatingWindowEnd,
          if (endDate != null) 'end_date': endDate,
        },
      );

      if (response.isSuccess) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新计划失败', error: e.toString());
    }
  }

  /// 提交打卡记录
  Future<ApiResponse<Map<String, dynamic>>> submitCheckin({
    required int planId,
    required String checkinDate,
    double? weight,
    String feeling = 'normal',
    bool completed = true,
    Map<String, bool>? discomfort,
    String? notes,
  }) async {
    try {
      final response = await _apiService.post(
        '/fasting/checkins',
        data: {
          'plan_id': planId,
          'checkin_date': checkinDate,
          if (weight != null) 'weight': weight,
          'feeling': feeling,
          'completed': completed,
          if (discomfort != null) 'discomfort': discomfort,
          if (notes != null) 'notes': notes,
        },
      );

      if (response.isSuccess) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '打卡失败', error: e.toString());
    }
  }

  /// 获取打卡记录列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getCheckinRecords({
    required int planId,
  }) async {
    try {
      final response = await _apiService.get(
        '/fasting/checkins',
        queryParameters: {'plan_id': planId},
      );

      if (response.isSuccess && response.data != null) {
        // 后端返回 {"plan_id": ..., "checkins": [...], "total": ...}
        final data = response.data as Map<String, dynamic>;
        final checkinsList = data['checkins'] as List? ?? [];
        final list = checkinsList
            .map((e) => (e as Map<String, dynamic>).cast<String, dynamic>())
            .toList();
        return ApiResponse.success(message: response.message, data: list);
      }
      return ApiResponse.success(message: response.message, data: []);
    } catch (e) {
      return ApiResponse.failure(message: '获取打卡记录失败', error: e.toString());
    }
  }

  /// 获取计划进度
  Future<ApiResponse<Map<String, dynamic>>> getProgress({
    required int planId,
  }) async {
    try {
      final response = await _apiService.get(
        '/fasting/progress',
        queryParameters: {'plan_id': planId},
      );

      if (response.isSuccess) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取进度失败', error: e.toString());
    }
  }

  /// 获取复食指导
  Future<ApiResponse<Map<String, dynamic>>> getRefeedGuidance({
    required int planId,
  }) async {
    try {
      final response = await _apiService.get(
        '/fasting/refeed-guide',
        queryParameters: {'plan_id': planId},
      );

      if (response.isSuccess) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : null,
        );
      }
      return ApiResponse.failure(message: response.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取复食指导失败', error: e.toString());
    }
  }
}
