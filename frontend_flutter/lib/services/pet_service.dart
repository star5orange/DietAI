import 'package:flutter/foundation.dart';
import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

/// 宠物状态数据模型
class PetStatusData {
  final String mood;
  final int level;
  final int exp;
  final int expToNext;
  final String currentSkin;
  final List<String> unlockedSkins;
  final int habitScore;
  final String? lastInteractAt;
  final int streakDays;
  final String petType;
  final String petName;
  final bool isVisible;

  const PetStatusData({
    this.mood = 'calm',
    this.level = 1,
    this.exp = 0,
    this.expToNext = 100,
    this.currentSkin = 'default',
    this.unlockedSkins = const [],
    this.habitScore = 0,
    this.lastInteractAt,
    this.streakDays = 0,
    this.petType = 'cat',
    this.petName = '桌宠一',
    this.isVisible = true,
  });

  factory PetStatusData.fromJson(Map<String, dynamic> json) {
    return PetStatusData(
      mood: json['mood'] as String? ?? 'calm',
      level: json['level'] as int? ?? 1,
      exp: json['exp'] as int? ?? 0,
      expToNext: json['exp_to_next'] as int? ?? 100,
      currentSkin: json['current_skin'] as String? ?? 'default',
      unlockedSkins: (json['unlocked_skins'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      habitScore: json['habit_score'] as int? ?? 0,
      lastInteractAt: json['last_interact_at'] as String?,
      streakDays: json['streak_days'] as int? ?? 0,
      petType: json['pet_type'] as String? ?? 'cat',
      petName: json['pet_name'] as String? ?? '桌宠一',
      isVisible: json['is_visible'] as bool? ?? true,
    );
  }
}

/// 互动结果数据
class InteractResult {
  final String mood;
  final int expGained;
  final String feedbackText;
  final List? newUnlock;

  const InteractResult({
    this.mood = 'happy',
    this.expGained = 5,
    this.feedbackText = '',
    this.newUnlock,
  });

  factory InteractResult.fromJson(Map<String, dynamic> json) {
    return InteractResult(
      mood: json['mood'] as String? ?? 'happy',
      expGained: json['exp_gained'] as int? ?? 5,
      feedbackText: json['feedback_text'] as String? ?? '',
      newUnlock: json['new_unlock'] as List?,
    );
  }
}

/// 经验值增加结果
class AddExpResult {
  final int level;
  final int exp;
  final int expToNext;
  final bool levelUp;
  final List? newUnlocks;

  const AddExpResult({
    this.level = 1,
    this.exp = 0,
    this.expToNext = 100,
    this.levelUp = false,
    this.newUnlocks,
  });

  factory AddExpResult.fromJson(Map<String, dynamic> json) {
    return AddExpResult(
      level: json['level'] as int? ?? 1,
      exp: json['exp'] as int? ?? 0,
      expToNext: json['exp_to_next'] as int? ?? 100,
      levelUp: json['level_up'] as bool? ?? false,
      newUnlocks: json['new_unlocks'] as List?,
    );
  }
}

/// 设备端宠物状态（精简版，用于硬件轮询）
class DevicePetStatus {
  final String mood;
  final int level;
  final String skin;
  final int version;
  final bool hasNewUnlock;

  const DevicePetStatus({
    this.mood = 'calm',
    this.level = 1,
    this.skin = 'default',
    this.version = 0,
    this.hasNewUnlock = false,
  });

  factory DevicePetStatus.fromJson(Map<String, dynamic> json) {
    return DevicePetStatus(
      mood: json['mood'] as String? ?? 'calm',
      level: json['level'] as int? ?? 1,
      skin: json['skin'] as String? ?? 'default',
      version: json['version'] as int? ?? 0,
      hasNewUnlock: json['has_new_unlock'] as bool? ?? false,
    );
  }
}

class PetApiService {
  final ApiService _apiService = ApiService();

  /// 获取完整宠物状态（App端）
  Future<ApiResponse<PetStatusData>> getStatus() async {
    try {
      final response = await _apiService.get('/virtual-pet/status');
      if (response.success && response.data != null) {
        final data = PetStatusData.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success(message: '获取宠物状态成功', data: data);
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '获取宠物状态失败');
    } catch (e) {
      debugPrint('PetApiService.getStatus error: $e');
      return ApiResponse.failure(message: '获取宠物状态失败: $e');
    }
  }

  /// 获取设备端精简宠物状态（硬件轮询用）
  Future<ApiResponse<DevicePetStatus>> getStatusForDevice() async {
    try {
      final response = await _apiService.get('/virtual-pet/status-for-device');
      if (response.success && response.data != null) {
        final data = DevicePetStatus.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success(message: '获取设备宠物状态成功', data: data);
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '获取设备宠物状态失败');
    } catch (e) {
      debugPrint('PetApiService.getStatusForDevice error: $e');
      return ApiResponse.failure(message: '获取设备宠物状态失败: $e');
    }
  }

  /// 互动（pet/feed/play/train）
  Future<ApiResponse<InteractResult>> interact({required String action, String? itemId}) async {
    try {
      final body = <String, dynamic>{'action': action};
      if (itemId != null) body['item_id'] = itemId;

      final response = await _apiService.post('/virtual-pet/interact', data: body);
      if (response.success && response.data != null) {
        final data = InteractResult.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success(message: '互动成功', data: data);
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '互动失败');
    } catch (e) {
      debugPrint('PetApiService.interact error: $e');
      return ApiResponse.failure(message: '互动失败: $e');
    }
  }

  /// 增加经验值（硬件按键互动）
  Future<ApiResponse<AddExpResult>> addExp({String action = 'pet'}) async {
    try {
      final response = await _apiService.post('/virtual-pet/exp/add', queryParameters: {'action': action});
      if (response.success && response.data != null) {
        final data = AddExpResult.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse.success(message: '获得经验值', data: data);
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '增加经验失败');
    } catch (e) {
      debugPrint('PetApiService.addExp error: $e');
      return ApiResponse.failure(message: '增加经验失败: $e');
    }
  }

  /// 重命名宠物
  Future<ApiResponse<Map<String, dynamic>>> rename({required String name}) async {
      final response = await _apiService.put('/virtual-pet/rename', data: {'name': name});
      if (response.success) {
        return ApiResponse.success(
          message: response.message.isNotEmpty ? response.message : '重命名成功',
          data: response.data as Map<String, dynamic>?,
        );
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '重命名失败');
    } catch (e) {
      debugPrint('PetApiService.rename error: $e');
      return ApiResponse.failure(message: '重命名失败: $e');
    }
  }

  /// 切换宠物类型
  Future<ApiResponse<Map<String, dynamic>>> changePetType({required String petType}) async {
    try {
      final response = await _apiService.put('/virtual-pet/pet-type', data: {'pet_type': petType});
      if (response.success) {
        return ApiResponse.success(
          message: response.message.isNotEmpty ? response.message : '切换成功',
          data: response.data as Map<String, dynamic>?,
        );
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '切换失败');
    } catch (e) {
      debugPrint('PetApiService.changePetType error: $e');
      return ApiResponse.failure(message: '切换失败: $e');
    }
  }

  /// 设置可见性
  Future<ApiResponse<Map<String, dynamic>>> setVisibility({required bool isVisible}) async {
    try {
      final response = await _apiService.put('/virtual-pet/visibility', data: {'is_visible': isVisible});
      if (response.success) {
        return ApiResponse.success(
          message: response.message.isNotEmpty ? response.message : '设置成功',
          data: response.data as Map<String, dynamic>?,
        );
      }
      return ApiResponse.failure(message: response.message.isNotEmpty ? response.message : '设置失败');
    } catch (e) {
      debugPrint('PetApiService.setVisibility error: $e');
      return ApiResponse.failure(message: '设置失败: $e');
    }
  }
}
