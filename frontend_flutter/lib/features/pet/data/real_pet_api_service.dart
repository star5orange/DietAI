import '../../../core/services/api_service.dart';
import '../../../shared/domain/models/api_response.dart';

/// 真实宠物 API 服务
/// 对接后端 /api/pets/* 全部端点
class RealPetApiService {
  final ApiService _api = ApiService();

  /// 将 ApiService 返回的 ApiResponse<dynamic> 安全包装为 ApiResponse<Map<String, dynamic>>
  ApiResponse<Map<String, dynamic>> _wrapMap(ApiResponse<dynamic> res) {
    return ApiResponse<Map<String, dynamic>>(
      success: res.success,
      message: res.message,
      data: res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : null,
    );
  }

  // ==================== 宠物档案 CRUD ====================

  /// 获取宠物列表
  Future<ApiResponse<Map<String, dynamic>>> getPets() async {
    try {
      final res = await _api.get('/pets');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取宠物列表失败', error: e.toString());
    }
  }

  /// 获取宠物详情
  Future<ApiResponse<Map<String, dynamic>>> getPet(int petId) async {
    try {
      final res = await _api.get('/pets/$petId');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取宠物详情失败', error: e.toString());
    }
  }

  /// 创建宠物
  Future<ApiResponse<Map<String, dynamic>>> createPet(
      Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '创建宠物失败', error: e.toString());
    }
  }

  /// 更新宠物
  Future<ApiResponse<Map<String, dynamic>>> updatePet(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/pets/$petId', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '更新宠物失败', error: e.toString());
    }
  }

  /// 删除宠物（软删除）
  Future<ApiResponse<void>> deletePet(int petId) async {
    try {
      await _api.delete('/pets/$petId');
      return ApiResponse.success(message: '宠物已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除宠物失败', error: e.toString());
    }
  }

  // ==================== 体重 ====================

  /// 添加体重记录
  Future<ApiResponse<Map<String, dynamic>>> addWeight(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets/$petId/weight-records', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '体重记录失败', error: e.toString());
    }
  }

  /// 查询体重记录
  Future<ApiResponse<Map<String, dynamic>>> getWeightRecords(int petId) async {
    try {
      final res = await _api.get('/pets/$petId/weight-records');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取体重记录失败', error: e.toString());
    }
  }

  /// 体重趋势
  Future<ApiResponse<Map<String, dynamic>>> getWeightTrend(int petId,
      {int days = 30}) async {
    try {
      final res = await _api
          .get('/pets/$petId/weight-trend', queryParameters: {'days': days});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取体重趋势失败', error: e.toString());
    }
  }

  /// 删除体重记录
  Future<ApiResponse<void>> deleteWeightRecord(int petId, int recordId) async {
    try {
      await _api.delete('/pets/$petId/weight-records/$recordId');
      return ApiResponse.success(message: '体重记录已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除体重记录失败', error: e.toString());
    }
  }

  // ==================== 疫苗 ====================

  /// 添加疫苗记录
  Future<ApiResponse<Map<String, dynamic>>> addVaccine(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets/$petId/vaccine-records', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '疫苗记录失败', error: e.toString());
    }
  }

  /// 查询疫苗记录
  Future<ApiResponse<Map<String, dynamic>>> getVaccineRecords(int petId) async {
    try {
      final res = await _api.get('/pets/$petId/vaccine-records');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取疫苗记录失败', error: e.toString());
    }
  }

  /// 更新疫苗记录
  Future<ApiResponse<Map<String, dynamic>>> updateVaccine(
      int petId, int recordId, Map<String, dynamic> data) async {
    try {
      final res =
          await _api.put('/pets/$petId/vaccine-records/$recordId', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '更新疫苗记录失败', error: e.toString());
    }
  }

  /// 删除疫苗记录
  Future<ApiResponse<void>> deleteVaccine(int petId, int recordId) async {
    try {
      await _api.delete('/pets/$petId/vaccine-records/$recordId');
      return ApiResponse.success(message: '疫苗记录已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除疫苗记录失败', error: e.toString());
    }
  }

  /// 获取所有宠物即将到期/已过期的疫苗
  Future<ApiResponse<Map<String, dynamic>>> getDueVaccines(
      {int days = 30}) async {
    try {
      final res =
          await _api.get('/pets/vaccines/due', queryParameters: {'days': days});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取疫苗提醒失败', error: e.toString());
    }
  }

  // ==================== 驱虫 ====================

  /// 添加驱虫记录
  Future<ApiResponse<Map<String, dynamic>>> addDeworming(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets/$petId/deworming-records', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '驱虫记录失败', error: e.toString());
    }
  }

  /// 查询驱虫记录
  Future<ApiResponse<Map<String, dynamic>>> getDewormingRecords(
      int petId) async {
    try {
      final res = await _api.get('/pets/$petId/deworming-records');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取驱虫记录失败', error: e.toString());
    }
  }

  /// 更新驱虫记录
  Future<ApiResponse<Map<String, dynamic>>> updateDeworming(
      int petId, int recordId, Map<String, dynamic> data) async {
    try {
      final res = await _api.put('/pets/$petId/deworming-records/$recordId',
          data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '更新驱虫记录失败', error: e.toString());
    }
  }

  /// 删除驱虫记录
  Future<ApiResponse<void>> deleteDeworming(int petId, int recordId) async {
    try {
      await _api.delete('/pets/$petId/deworming-records/$recordId');
      return ApiResponse.success(message: '驱虫记录已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除驱虫记录失败', error: e.toString());
    }
  }

  // ==================== 饮食 ====================

  /// 手动添加饮食记录
  Future<ApiResponse<Map<String, dynamic>>> addFeeding(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets/$petId/feeding-records', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '饮食记录失败', error: e.toString());
    }
  }

  /// 删除饮食记录
  Future<ApiResponse<void>> deleteFeedingRecord(int petId, int recordId) async {
    try {
      await _api.delete('/pets/$petId/feeding-records/$recordId');
      return ApiResponse.success(message: '饮食记录已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除饮食记录失败', error: e.toString());
    }
  }

  /// 查询饮食记录
  Future<ApiResponse<Map<String, dynamic>>> getFeedingRecords(int petId,
      {int skip = 0, int limit = 50}) async {
    try {
      final res = await _api.get('/pets/$petId/feeding-records',
          queryParameters: {'skip': skip, 'limit': limit});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取饮食记录失败', error: e.toString());
    }
  }

  /// 每日营养汇总
  Future<ApiResponse<Map<String, dynamic>>> getDailySummary(
      int petId, String date) async {
    try {
      final res = await _api.get('/pets/$petId/daily-summary/$date');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取每日汇总失败', error: e.toString());
    }
  }

  /// 推荐喂食计划
  Future<ApiResponse<Map<String, dynamic>>> getFeedingPlan(int petId) async {
    try {
      final res = await _api.get('/pets/$petId/feeding-plan');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取喂食计划失败', error: e.toString());
    }
  }

  // ==================== 饮水 ====================

  /// 添加饮水记录
  Future<ApiResponse<Map<String, dynamic>>> addWater(
      int petId, Map<String, dynamic> data) async {
    try {
      final res = await _api.post('/pets/$petId/water-records', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '饮水记录失败', error: e.toString());
    }
  }

  /// 查询饮水记录
  Future<ApiResponse<Map<String, dynamic>>> getWaterRecords(int petId,
      {int skip = 0, int limit = 50}) async {
    try {
      final res = await _api.get('/pets/$petId/water-records',
          queryParameters: {'skip': skip, 'limit': limit});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取饮水记录失败', error: e.toString());
    }
  }

  /// 删除饮水记录
  Future<ApiResponse<void>> deleteWaterRecord(int petId, int recordId) async {
    try {
      await _api.delete('/pets/$petId/water-records/$recordId');
      return ApiResponse.success(message: '饮水记录已删除');
    } catch (e) {
      return ApiResponse.failure(message: '删除饮水记录失败', error: e.toString());
    }
  }

  // ==================== AI 建议 ====================

  /// 获取宠物 AI 健康建议
  Future<ApiResponse<Map<String, dynamic>>> getAiAdvice(int petId) async {
    try {
      final res = await _api.post('/pets/$petId/ai-advice', data: {});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取AI建议失败', error: e.toString());
    }
  }

  // ==================== 食品库 ====================

  /// 拍照识别宠物食品包装营养成分表（OCR）
  Future<ApiResponse<Map<String, dynamic>>> ocrPetFood(
      String imageBase64) async {
    try {
      final res = await _api
          .post('/pets/food-database/ocr', data: {'image_base64': imageBase64});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: 'OCR识别失败', error: e.toString());
    }
  }

  /// 查询宠物食品库
  Future<ApiResponse<Map<String, dynamic>>> getFoodDatabase(
      {String? species, String? category}) async {
    try {
      final params = <String, dynamic>{};
      if (species != null) params['species'] = species;
      if (category != null) params['category'] = category;
      final res =
          await _api.get('/pets/food-database', queryParameters: params);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取食品库失败', error: e.toString());
    }
  }

  /// 搜索宠物食品
  Future<ApiResponse<Map<String, dynamic>>> searchFood(String keyword) async {
    try {
      final res = await _api.get('/pets/food-database/search',
          queryParameters: {'keyword': keyword});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '搜索食品失败', error: e.toString());
    }
  }

  // ==================== 换粮对比 ====================

  /// 换粮对比
  Future<ApiResponse<Map<String, dynamic>>> compareFoods(
      int petId, int currentFoodId, int newFoodId) async {
    try {
      final res = await _api.post('/pets/$petId/compare-foods', data: {
        'current_food_id': currentFoodId,
        'new_food_id': newFoodId,
      });
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '换粮对比失败', error: e.toString());
    }
  }

  // ==================== 健康评分 ====================

  /// 宠物健康评分
  Future<ApiResponse<Map<String, dynamic>>> getHealthScore(int petId) async {
    try {
      final res = await _api.get('/pets/$petId/health-score');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '获取健康评分失败', error: e.toString());
    }
  }

  // ==================== AI 形象生成 ====================

  /// 触发 AI 生成宠物形象
  Future<ApiResponse<Map<String, dynamic>>> generateAvatar(int petId,
      {String mode = 'description', String? photo, String? description}) async {
    try {
      final data = <String, dynamic>{'mode': mode};
      if (photo != null) data['photo'] = photo;
      if (description != null) data['description'] = description;
      final res = await _api.post('/pets/$petId/generate-avatar', data: data);
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '生成形象失败', error: e.toString());
    }
  }

  /// 查询生成任务状态
  Future<ApiResponse<Map<String, dynamic>>> getGenerationTask(
      String taskId) async {
    try {
      final res = await _api.get('/pets/generation-tasks/$taskId');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '查询任务失败', error: e.toString());
    }
  }

  /// 重新生成单个情绪变体
  Future<ApiResponse<Map<String, dynamic>>> regenerateEmotion(
      int petId, String emotion) async {
    try {
      final res = await _api
          .post('/pets/$petId/regenerate-emotion', data: {'emotion': emotion});
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: '重生成情绪失败', error: e.toString());
    }
  }

  /// 触发 GIF 生成
  Future<ApiResponse<Map<String, dynamic>>> upgradeToGif(int petId) async {
    try {
      final res = await _api.post('/pets/$petId/upgrade-to-gif');
      return _wrapMap(res);
    } catch (e) {
      return ApiResponse.failure(message: 'GIF生成失败', error: e.toString());
    }
  }
}
