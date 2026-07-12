import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/services/api_service.dart';

/// 宠物状态服务
/// 提供宠物状态、成长数据、互动操作的API接口
class PetService {
  final ApiService _apiService = ApiService();

  /// 获取宠物当前状态
  Future<ApiResponse<Map<String, dynamic>>> getPetStatus() async {
    try {
      final response = await _apiService.get('/virtual-pet/status');
      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取宠物状态失败', error: e.toString());
    }
  }

  /// 获取宠物成长数据
  Future<ApiResponse<Map<String, dynamic>>> getPetGrowthData({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiService.get(
        '/virtual-pet/growth',
        queryParameters: {
          if (startDate != null) 'start_date': startDate,
          if (endDate != null) 'end_date': endDate,
        },
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取成长数据失败', error: e.toString());
    }
  }

  /// 宠物互动（统一接口）
  Future<ApiResponse<Map<String, dynamic>>> petInteract({
    required String action,
    String? itemId,
  }) async {
    try {
      final response = await _apiService.post(
        '/virtual-pet/interact',
        data: {
          'action': action,
          if (itemId != null) 'item_id': itemId,
        },
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.failure(message: '宠物互动失败', error: e.toString());
    }
  }

  /// 审物互动 - 抚摸
  Future<ApiResponse<Map<String, dynamic>>> petTouch({
    int? duration,
  }) =>
      petInteract(action: 'pet', itemId: duration?.toString());

  /// 宠物互动 - 喂食
  Future<ApiResponse<Map<String, dynamic>>> petFeed({
    String? foodType,
    int? amount,
  }) =>
      petInteract(action: 'feed', itemId: foodType);

  /// 审物互动 - 玩耍
  Future<ApiResponse<Map<String, dynamic>>> petPlay({
    String? playType,
    int? duration,
  }) =>
      petInteract(action: 'play', itemId: playType);

  /// 获取可解锁内容列表
  Future<ApiResponse<Map<String, dynamic>>> getUnlockables() async {
    try {
      final response = await _apiService.get('/virtual-pet/unlockables');
      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.failure(message: '获取可解锁内容失败', error: e.toString());
    }
  }

  /// 设置宠物可见性
  Future<ApiResponse<bool>> setPetVisible(bool visible) async {
    try {
      await _apiService.post(
        '/virtual-pet/settings',
        data: {'visible': visible},
      );
      return ApiResponse.success(message: '设置成功', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '设置可见性失败', error: e.toString());
    }
  }

  /// 设置宠物类型
  Future<ApiResponse<bool>> setPetType(String petType) async {
    try {
      await _apiService.post(
        '/virtual-pet/settings',
        data: {'pet_type': petType},
      );
      return ApiResponse.success(message: '设置成功', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '设置宠物类型失败', error: e.toString());
    }
  }

  /// 设置宠物名称
  Future<ApiResponse<bool>> setPetName(String petName) async {
    try {
      await _apiService.post(
        '/virtual-pet/settings',
        data: {'pet_name': petName},
      );
      return ApiResponse.success(message: '设置成功', data: true);
    } catch (e) {
      return ApiResponse.failure(message: '设置宠物名称失败', error: e.toString());
    }
  }

  /// 增加宠物经验值
  Future<ApiResponse<Map<String, dynamic>>> addPetExp(int amount) async {
    try {
      final response = await _apiService.post(
        '/virtual-pet/exp/add',
        data: {'amount': amount},
      );
      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse.failure(message: '增加经验值失败', error: e.toString());
    }
  }
}
