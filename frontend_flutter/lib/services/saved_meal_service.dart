import 'package:dio/dio.dart';

import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';
import '../shared/domain/models/saved_meal_model.dart';

class SavedMealService {
  final ApiService _apiService = ApiService();

  /// 获取保存的菜品列表
  Future<ApiResponse<List<SavedMeal>>> getSavedMeals({
    String? category,
    bool? isPublic,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (category != null) queryParams['category'] = category;
      if (isPublic != null) queryParams['is_public'] = isPublic;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _apiService.get('/saved-meals', queryParameters: queryParams);

      if (response.success && response.data != null) {
        final List<dynamic> data = response.data;
        final savedMeals = data.map((json) => SavedMeal.fromJson(json)).toList();
        return ApiResponse(
          success: true,
          data: savedMeals,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('获取保存菜品列表失败: $e');
      return ApiResponse(
        success: false,
        message: '获取菜品列表失败: $e',
      );
    }
  }

  /// 获取单个保存的菜品
  Future<ApiResponse<SavedMeal>> getSavedMeal(int mealId) async {
    try {
      final response = await _apiService.get('/saved-meals/$mealId');

      if (response.success && response.data != null) {
        final savedMeal = SavedMeal.fromJson(response.data);
        return ApiResponse(
          success: true,
          data: savedMeal,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('获取保存菜品详情失败: $e');
      return ApiResponse(
        success: false,
        message: '获取菜品详情失败: $e',
      );
    }
  }

  /// 创建保存的菜品
  Future<ApiResponse<SavedMeal>> createSavedMeal(SavedMealCreate mealData) async {
    try {
      final response = await _apiService.post('/saved-meals', data: mealData.toJson());

      if (response.success && response.data != null) {
        final savedMeal = SavedMeal.fromJson(response.data);
        return ApiResponse(
          success: true,
          data: savedMeal,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('创建保存菜品失败: $e');
      return ApiResponse(
        success: false,
        message: '创建菜品失败: $e',
      );
    }
  }

  /// 从食物记录创建保存的菜品
  Future<ApiResponse<SavedMeal>> createSavedMealFromRecord({
    required int foodRecordId,
    required String mealName,
    String? description,
    String? category,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    try {
      final data = {
        'meal_name': mealName,
        'description': description,
        'category': category,
        'tags': tags,
        'is_public': isPublic,
      };

      final response = await _apiService.post(
        '/saved-meals/from-food-record/$foodRecordId',
        data: data,
      );

      if (response.success && response.data != null) {
        final savedMeal = SavedMeal.fromJson(response.data);
        return ApiResponse(
          success: true,
          data: savedMeal,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('从食物记录创建保存菜品失败: $e');
      return ApiResponse(
        success: false,
        message: '创建菜品失败: $e',
      );
    }
  }

  /// 更新保存的菜品
  Future<ApiResponse<SavedMeal>> updateSavedMeal(int mealId, SavedMealUpdate mealData) async {
    try {
      final response = await _apiService.put('/saved-meals/$mealId', data: mealData.toJson());

      if (response.success) {
        return ApiResponse(
          success: true,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('更新保存菜品失败: $e');
      return ApiResponse(
        success: false,
        message: '更新菜品失败: $e',
      );
    }
  }

  /// 删除保存的菜品
  Future<ApiResponse<void>> deleteSavedMeal(int mealId) async {
    try {
      final response = await _apiService.delete('/saved-meals/$mealId');

      if (response.success) {
        return ApiResponse(
          success: true,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('删除保存菜品失败: $e');
      return ApiResponse(
        success: false,
        message: '删除菜品失败: $e',
      );
    }
  }

  /// 收藏/取消收藏菜品
  Future<ApiResponse<void>> toggleFavoriteMeal(int mealId) async {
    try {
      final response = await _apiService.post('/saved-meals/$mealId/favorite');

      if (response.success) {
        return ApiResponse(
          success: true,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('收藏菜品操作失败: $e');
      return ApiResponse(
        success: false,
        message: '操作失败: $e',
      );
    }
  }

  /// 使用保存的菜品
  Future<ApiResponse<void>> useSavedMeal(int mealId) async {
    try {
      final response = await _apiService.post('/saved-meals/$mealId/use');

      if (response.success) {
        return ApiResponse(
          success: true,
          message: response.message,
        );
      } else {
        return ApiResponse(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('使用保存菜品失败: $e');
      return ApiResponse(
        success: false,
        message: '操作失败: $e',
      );
    }
  }

  /// 获取推荐标签
  List<String> getRecommendedTags() {
    return [
      '早餐',
      '午餐',
      '晚餐',
      '零食',
      '健康',
      '低卡',
      '高蛋白',
      '素食',
      '快手菜',
      '家常菜',
      '减脂',
      '增肌',
      '营养',
      '美味',
      '简单',
    ];
  }
}