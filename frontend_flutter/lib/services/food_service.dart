import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/services/api_service.dart';
import '../core/cache/cache_manager.dart';
import '../shared/domain/models/api_response.dart';
import '../shared/domain/models/food_model.dart';

/// 食物服务类
class FoodService {
  final ApiService _apiService = ApiService();
  final CacheManager _cacheManager = CacheManager();

  /// 创建食物记录（流式输出）
  Stream<Map<String, dynamic>> createFoodRecordStream(
      FoodRecordCreate foodData) async* {
    try {
      print('📤 创建食物记录SSE请求: ${foodData.toJson()}');

      // 构建请求URL
      final baseUrl = _apiService.dio.options.baseUrl;
      final url = '$baseUrl/foods/records';

      // 获取认证token
      final token = await _apiService.getAccessToken();

      // 创建HTTP客户端
      final client = HttpClient();

      try {
        // 创建请求
        final request = await client.postUrl(Uri.parse(url));

        // 设置请求头
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        if (token != null) {
          request.headers.set('Authorization', 'Bearer $token');
        }

        // 发送请求体
        final jsonData = json.encode(foodData.toJson());
        request.add(utf8.encode(jsonData));

        // 获取响应
        final response = await request.close();

        if (response.statusCode == 200) {
          // 处理SSE流
          yield* response
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .where((line) => line.startsWith('data: '))
              .map((line) => line.substring(6)) // 移除 'data: ' 前缀
              .where((data) => data.isNotEmpty)
              .map((data) {
            try {
              return json.decode(data) as Map<String, dynamic>;
            } catch (e) {
              print('❌ 解析SSE数据失败: $e, 数据: $data');
              return <String, dynamic>{
                'type': 'error',
                'success': false,
                'data': {'error': '数据解析失败'}
              };
            }
          });
        } else {
          yield {
            'type': 'error',
            'success': false,
            'data': {'error': '请求失败，状态码: ${response.statusCode}'}
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ 创建食物记录SSE异常: $e');
      yield {
        'type': 'error',
        'success': false,
        'data': {'error': '创建食物记录失败: $e'}
      };
    }
  }

  /// 确认食物记录创建
  Future<ApiResponse<FoodRecord>> confirmFoodRecord(int recordId) async {
    try {
      print('📤 确认食物记录请求: recordId=$recordId');

      final response = await _apiService.post(
        '/foods/records/confirm/$recordId',
      );

      print('📥 确认食物记录响应: success=${response.success}, data=${response.data}');

      if (response.success) {
        try {
          final dataMap = response.data as Map<String, dynamic>;
          final foodRecord = FoodRecord.fromJson(dataMap);
          print('✅ 食物记录确认成功: ${foodRecord.id}');
          return ApiResponse<FoodRecord>(
            success: true,
            message: response.message,
            data: foodRecord,
          );
        } catch (parseError, stackTrace) {
          print('❌ JSON解析错误: $parseError');
          print('📄 错误堆栈: $stackTrace');
          print('📄 原始数据: ${response.data}');
          return ApiResponse<FoodRecord>(
            success: false,
            message: 'JSON解析失败: $parseError',
          );
        }
      } else {
        print('❌ 确认食物记录失败: ${response.message}');
        return ApiResponse<FoodRecord>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('❌ 确认食物记录异常: $e');
      return ApiResponse<FoodRecord>(
        success: false,
        message: '确认食物记录失败: $e',
      );
    }
  }

  /// 创建食物记录（传统方法）
  Future<ApiResponse<FoodRecord>> createFoodRecord(
      FoodRecordCreate foodData) async {
    try {
      print('📤 创建食物记录请求: ${foodData.toJson()}');

      final response = await _apiService.post(
        '/foods/records/traditional',
        data: foodData.toJson(),
      );

      print('📥 创建食物记录响应: success=${response.success}, data=${response.data}');

      if (response.success) {
        try {
          final dataMap = response.data as Map<String, dynamic>;
          final foodRecord = FoodRecord.fromJson(dataMap);
          print('✅ 食物记录解析成功: ${foodRecord.id}');
          return ApiResponse<FoodRecord>(
            success: true,
            message: response.message,
            data: foodRecord,
          );
        } catch (parseError, stackTrace) {
          print('❌ JSON解析错误: $parseError');
          print('📄 错误堆栈: $stackTrace');
          print('📄 原始数据: ${response.data}');
          return ApiResponse<FoodRecord>(
            success: false,
            message: 'JSON解析失败: $parseError',
          );
        }
      } else {
        print('❌ 创建食物记录失败: ${response.message}');
        return ApiResponse<FoodRecord>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('❌ 创建食物记录异常: $e');
      return ApiResponse<FoodRecord>(
        success: false,
        message: '创建食物记录失败: $e',
      );
    }
  }

  /// 获取食物记录图片数据（带缓存）
  Future<ApiResponse<Map<String, dynamic>>> getFoodImageData(
      int recordId) async {
    final cacheKey = 'food_image_$recordId';

    try {
      // 1. 检查内存缓存
      final cachedData = _cacheManager.getMemoryCache(cacheKey);
      if (cachedData != null) {
        print('✅ 从内存缓存获取图片数据: recordId=$recordId');
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: '从缓存获取',
          data: cachedData,
        );
      }

      // 2. 检查本地缓存
      final localCachedData = await _cacheManager.getLocalCache(cacheKey);
      if (localCachedData != null) {
        print('✅ 从本地缓存获取图片数据: recordId=$recordId');
        // 将本地缓存数据也放入内存缓存
        _cacheManager.setMemoryCache(cacheKey, localCachedData);
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: '从缓存获取',
          data: localCachedData,
        );
      }

      print('📤 从服务器获取食物记录图片数据: recordId=$recordId');

      final response = await _apiService.get(
        '/foods/images/data/$recordId',
      );

      print('📥 获取食物记录图片数据响应: success=${response.success}');

      if (response.success) {
        final dataMap = response.data as Map<String, dynamic>;
        print('✅ 获取食物记录图片数据成功: recordId=$recordId');

        // 缓存数据
        _cacheManager.setMemoryCache(cacheKey, dataMap);
        await _cacheManager.setLocalCache(cacheKey, dataMap);

        // 如果图片数据是base64格式，也缓存图片字节数据
        final imageBase64 = dataMap['image_base64'] as String?;
        if (imageBase64 != null) {
          try {
            final imageBytes = base64Decode(imageBase64);
            _cacheManager.setImageCache(cacheKey, imageBytes);
            await _cacheManager.setFileCache(cacheKey, imageBytes);
          } catch (e) {
            print('⚠️ 缓存图片字节数据失败: $e');
          }
        }

        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: response.message,
          data: dataMap,
        );
      } else {
        print('❌ 获取食物记录图片数据失败: ${response.message}');
        return ApiResponse<Map<String, dynamic>>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('❌ 获取食物记录图片数据异常: $e');
      return ApiResponse<Map<String, dynamic>>(
        success: false,
        message: '获取食物记录图片数据失败: $e',
      );
    }
  }

  /// 获取食物记录列表
  Future<ApiResponse<FoodRecordsResponse>> getFoodRecords({
    String? startDate,
    String? endDate,
    int? mealType,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (mealType != null) queryParams['meal_type'] = mealType;

      final response = await _apiService.get(
        '/foods/records',
        queryParameters: queryParams,
      );

      if (response.success) {
        try {
          final foodRecordsResponse = FoodRecordsResponse.fromJson(
              response.data as Map<String, dynamic>);
          return ApiResponse<FoodRecordsResponse>(
            success: true,
            message: response.message,
            data: foodRecordsResponse,
          );
        } catch (parseError, stackTrace) {
          print('❌ FoodRecordsResponse解析失败: $parseError');
          print('❌ 堆栈: $stackTrace');
          print('❌ 原始数据: ${response.data}');
          return ApiResponse<FoodRecordsResponse>(
            success: false,
            message: '解析食物记录失败: $parseError',
          );
        }
      } else {
        return ApiResponse<FoodRecordsResponse>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<FoodRecordsResponse>(
        success: false,
        message: '获取食物记录列表失败: $e',
      );
    }
  }

  /// 获取单个食物记录详情
  Future<ApiResponse<FoodRecord>> getFoodRecord(int recordId) async {
    try {
      final response = await _apiService.get('/foods/records/$recordId');

      if (response.success) {
        final foodRecord =
            FoodRecord.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<FoodRecord>(
          success: true,
          message: response.message,
          data: foodRecord,
        );
      } else {
        return ApiResponse<FoodRecord>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<FoodRecord>(
        success: false,
        message: '获取食物记录详情失败: $e',
      );
    }
  }

  /// 添加营养详情
  Future<ApiResponse<NutritionDetail>> addNutritionDetail(
    int recordId,
    NutritionDetailCreate nutritionData,
  ) async {
    try {
      final requestBody = nutritionData.toJson();
      print('📤 添加营养详情请求: recordId=$recordId, body=$requestBody');

      final response = await _apiService.post(
        '/foods/records/$recordId/nutrition',
        data: requestBody,
      );

      print(
          '📥 添加营养详情响应: success=${response.success}, message=${response.message}');

      if (response.success) {
        try {
          final nutritionDetail =
              NutritionDetail.fromJson(response.data as Map<String, dynamic>);
          print('✅ 营养详情解析成功: id=${nutritionDetail.id}');
          return ApiResponse<NutritionDetail>(
            success: true,
            message: response.message,
            data: nutritionDetail,
          );
        } catch (parseError) {
          print('❌ 营养详情解析失败: $parseError, 原始数据: ${response.data}');
          return ApiResponse<NutritionDetail>(
            success: false,
            message: '营养详情解析失败: $parseError',
          );
        }
      } else {
        print('❌ 添加营养详情API失败: ${response.message}');
        return ApiResponse<NutritionDetail>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('❌ 添加营养详情异常: $e');
      return ApiResponse<NutritionDetail>(
        success: false,
        message: '添加营养详情失败: $e',
      );
    }
  }

  /// 获取每日营养汇总
  Future<ApiResponse<DailyNutritionSummary>> getDailyNutritionSummary(
      String summaryDate) async {
    try {
      final response =
          await _apiService.get('/foods/daily-summary/$summaryDate');

      if (response.success) {
        final summary = DailyNutritionSummary.fromJson(
            response.data as Map<String, dynamic>);
        return ApiResponse<DailyNutritionSummary>(
          success: true,
          message: response.message,
          data: summary,
        );
      } else {
        return ApiResponse<DailyNutritionSummary>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<DailyNutritionSummary>(
        success: false,
        message: '获取每日营养汇总失败: $e',
      );
    }
  }

  /// 获取营养趋势
  Future<ApiResponse<NutritionTrends>> getNutritionTrends({
    String? startDate,
    String? endDate,
    String metrics = 'calories,protein,fat,carbohydrates',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'metrics': metrics,
      };

      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;

      final response = await _apiService.get(
        '/foods/nutrition-trends',
        queryParameters: queryParams,
      );

      if (response.success) {
        final trends =
            NutritionTrends.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<NutritionTrends>(
          success: true,
          message: response.message,
          data: trends,
        );
      } else {
        return ApiResponse<NutritionTrends>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<NutritionTrends>(
        success: false,
        message: '获取营养趋势失败: $e',
      );
    }
  }

  /// 上传食物图片
  Future<ApiResponse<FileUploadResponse>> uploadFoodImage(
      File imageFile) async {
    try {
      print('📤 开始上传图片: ${imageFile.path}');

      // 获取文件名和扩展名
      final fileName = imageFile.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      print('📄 文件信息: name=$fileName, ext=$extension');

      // 确定MIME类型
      MediaType mediaType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mediaType = MediaType('image', 'jpeg');
          break;
        case 'png':
          mediaType = MediaType('image', 'png');
          break;
        case 'gif':
          mediaType = MediaType('image', 'gif');
          break;
        default:
          mediaType = MediaType('image', 'jpeg');
      }

      // 创建MultipartFile
      final multipartFile = await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
        contentType: mediaType,
      );

      // 创建FormData
      final formData = FormData.fromMap({
        'file': multipartFile,
      });

      print('📤 发送上传请求...');
      final response = await _apiService.postFormData(
        '/foods/upload-image',
        data: formData,
      );

      print('📥 上传响应: success=${response.success}, data=${response.data}');

      if (response.success) {
        try {
          print('📄 尝试解析响应数据...');
          print('📄 数据类型: ${response.data.runtimeType}');
          print('📄 数据内容: ${response.data}');

          final dataMap = response.data as Map<String, dynamic>;
          print('📄 转换后的Map: $dataMap');

          // 验证必需字段
          final requiredFields = [
            'file_id',
            'file_name',
            'file_url',
            'object_name',
            'file_size',
            'content_type',
            'upload_time'
          ];
          for (String field in requiredFields) {
            if (!dataMap.containsKey(field)) {
              print('❌ 缺少必需字段: $field');
            } else {
              print(
                  '✅ 字段 $field: ${dataMap[field]} (${dataMap[field].runtimeType})');
            }
          }

          final uploadResponse = FileUploadResponse.fromJson(dataMap);
          print('✅ 图片上传成功: ${uploadResponse.objectName}');
          return ApiResponse<FileUploadResponse>(
            success: true,
            message: response.message,
            data: uploadResponse,
          );
        } catch (parseError, stackTrace) {
          print('❌ 上传响应解析错误: $parseError');
          print('📄 错误堆栈: $stackTrace');
          print('📄 原始数据: ${response.data}');
          return ApiResponse<FileUploadResponse>(
            success: false,
            message: '响应解析失败: $parseError',
          );
        }
      } else {
        print('❌ 图片上传失败: ${response.message}');
        return ApiResponse<FileUploadResponse>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      print('❌ 图片上传异常: $e');
      return ApiResponse<FileUploadResponse>(
        success: false,
        message: '上传图片失败: $e',
      );
    }
  }

  /// 获取图片访问URL
  Future<ApiResponse<ImageUrlResponse>> getImageUrl(
    String objectName, {
    int expiresMinutes = 60,
  }) async {
    try {
      final response = await _apiService.get(
        '/foods/images/url',
        queryParameters: {
          'object_name': objectName,
          'expires_minutes': expiresMinutes,
        },
      );

      if (response.success) {
        final imageUrlResponse =
            ImageUrlResponse.fromJson(response.data as Map<String, dynamic>);

        // 修复localhost URL问题 - 替换为实际的服务器IP
        String fixedUrl = imageUrlResponse.fileUrl;
        if (fixedUrl.contains('localhost:9000')) {
          // 从API服务的baseUrl中提取IP地址
          final apiBaseUrl = _apiService.dio.options.baseUrl;
          final uri = Uri.parse(apiBaseUrl);
          final serverIp = uri.host;

          // 将localhost替换为实际的服务器IP
          fixedUrl = fixedUrl.replaceAll('localhost:9000', '$serverIp:9000');
          print('🔧 图片URL修复: localhost -> $serverIp');
          print('📷 修复后URL: $fixedUrl');
        }

        // 创建修复后的响应对象
        final fixedResponse = ImageUrlResponse(
          objectName: imageUrlResponse.objectName,
          fileUrl: fixedUrl,
          expiresIn: imageUrlResponse.expiresIn,
          expiresAt: imageUrlResponse.expiresAt,
        );

        return ApiResponse<ImageUrlResponse>(
          success: true,
          message: response.message,
          data: fixedResponse,
        );
      } else {
        return ApiResponse<ImageUrlResponse>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<ImageUrlResponse>(
        success: false,
        message: '获取图片URL失败: $e',
      );
    }
  }

  /// 创建带图片分析的食物记录（流式输出）
  Stream<Map<String, dynamic>> createFoodRecordWithImageStream({
    required File imageFile,
    required String recordDate,
    required int mealType,
    required String foodName,
    String? description,
    String? recordTime,
  }) async* {
    try {
      print('🚀 开始创建带图片的食物记录（流式）');
      print('📋 请求参数: date=$recordDate, meal=$mealType, food=$foodName');

      // 1. 首先上传图片
      print('📤 步骤1: 上传图片');
      yield {
        'type': 'upload_started',
        'success': true,
        'data': {'status': 'uploading', 'message': '正在上传图片...'}
      };

      final uploadResult = await uploadFoodImage(imageFile);
      if (!uploadResult.success || uploadResult.data == null) {
        print('❌ 图片上传失败: ${uploadResult.message}');
        yield {
          'type': 'upload_failed',
          'success': false,
          'data': {'error': uploadResult.message}
        };
        return;
      }

      print('✅ 图片上传成功: ${uploadResult.data!.objectName}');
      yield {
        'type': 'upload_complete',
        'success': true,
        'data': {
          'object_name': uploadResult.data!.objectName,
          'message': '图片上传成功'
        }
      };

      // 2. 创建食物记录，包含图片URL
      final foodRecordData = FoodRecordCreate(
        recordDate: recordDate,
        recordTime: recordTime ?? DateTime.now().toIso8601String(),
        mealType: mealType,
        foodName: foodName,
        description: description,
        imageUrl: uploadResult.data!.objectName, // 使用object_name而不是URL
        recordingMethod: 1, // AI扫描
      );

      print('📤 步骤2: 创建食物记录（流式）');
      // 3. 创建食物记录（流式输出）
      yield* createFoodRecordStream(foodRecordData);
    } catch (e) {
      print('❌ 创建带图片的食物记录异常: $e');
      yield {
        'type': 'error',
        'success': false,
        'data': {'error': '创建食物记录失败: $e'}
      };
    }
  }

  /// 创建带图片分析的食物记录（向后兼容方法）
  Future<ApiResponse<FoodRecord>> createFoodRecordWithImage({
    required File imageFile,
    required String recordDate,
    required int mealType,
    required String foodName,
    String? description,
    String? recordTime,
  }) async {
    try {
      print('🚀 开始创建带图片的食物记录');
      print('📋 请求参数: date=$recordDate, meal=$mealType, food=$foodName');

      // 1. 首先上传图片
      print('📤 步骤1: 上传图片');
      final uploadResult = await uploadFoodImage(imageFile);
      if (!uploadResult.success || uploadResult.data == null) {
        print('❌ 图片上传失败: ${uploadResult.message}');
        return ApiResponse<FoodRecord>(
          success: false,
          message: '图片上传失败: ${uploadResult.message}',
        );
      }

      print('✅ 图片上传成功: ${uploadResult.data!.objectName}');

      // 2. 创建食物记录，包含图片URL
      final foodRecordData = FoodRecordCreate(
        recordDate: recordDate,
        recordTime: recordTime ?? DateTime.now().toIso8601String(),
        mealType: mealType,
        foodName: foodName,
        description: description,
        imageUrl: uploadResult.data!.objectName, // 使用object_name而不是URL
        recordingMethod: 1, // AI扫描
      );

      print('📤 步骤2: 创建食物记录');

      // 这里使用原有的创建方法等待分析完成
      FoodRecord? finalRecord;
      await for (final event in createFoodRecordStream(foodRecordData)) {
        if (event['type'] == 'stream_complete' && event['success'] == true) {
          break; // 流程完成
        } else if (event['type'] == 'record_created' &&
            event['data']['record'] != null) {
          finalRecord = FoodRecord.fromJson(event['data']['record']);
        }
      }

      if (finalRecord != null) {
        // 等待分析完成或超时
        int attempts = 0;
        const maxAttempts = 60; // 最多等待60秒

        while (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 1));

          final result = await getFoodRecord(finalRecord.id);
          if (result.success && result.data != null) {
            final updatedRecord = result.data!;
            if (updatedRecord.analysisStatus == 3) {
              // 分析完成
              print('✅ 完整流程成功: 记录ID=${updatedRecord.id}');
              return ApiResponse<FoodRecord>(
                success: true,
                message: '食物记录创建成功，图片分析已完成',
                data: updatedRecord,
              );
            } else if (updatedRecord.analysisStatus == 1) {
              // 分析失败，但记录创建成功
              print('⚠️ 记录创建成功但分析失败: 记录ID=${updatedRecord.id}');
              return ApiResponse<FoodRecord>(
                success: true,
                message: '食物记录创建成功，图片分析失败',
                data: updatedRecord,
              );
            }
          }
          attempts++;
        }

        // 超时但记录已创建
        print('⚠️ 分析超时但记录已创建: 记录ID=${finalRecord.id}');
        return ApiResponse<FoodRecord>(
          success: true,
          message: '食物记录创建成功，分析可能需要更多时间',
          data: finalRecord,
        );
      } else {
        return ApiResponse<FoodRecord>(
          success: false,
          message: '创建食物记录失败',
        );
      }
    } catch (e) {
      print('❌ 创建带图片的食物记录异常: $e');
      return ApiResponse<FoodRecord>(
        success: false,
        message: '创建食物记录失败: $e',
      );
    }
  }

  /// 获取今日营养汇总
  Future<ApiResponse<DailyNutritionSummary>> getTodayNutritionSummary() async {
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return await getDailyNutritionSummary(todayString);
  }

  /// 获取每日汇总（别名方法，兼容前端）
  Future<ApiResponse<DailySummary>> getDailySummary(String summaryDate) async {
    return await getDailyNutritionSummary(summaryDate);
  }

  /// 获取指定日期的食物记录列表（带缓存）
  Future<ApiResponse<List<FoodRecord>>> getFoodRecordsByDay(String date) async {
    final cacheKey = 'food_records_$date';

    try {
      // 1. 检查内存缓存
      final cachedData = _cacheManager.getMemoryCache(cacheKey);
      if (cachedData != null && (cachedData as List).isNotEmpty) {
        print('✅ 从内存缓存获取食物记录: date=$date');
        try {
          final records = (cachedData as List)
              .map((item) => FoodRecord.fromJson(item as Map<String, dynamic>))
              .toList();
          if (records.isNotEmpty) {
            return ApiResponse<List<FoodRecord>>(
              success: true,
              message: '从缓存获取',
              data: records,
            );
          }
        } catch (e) {
          print('⚠️ 内存缓存解析失败，跳过缓存: $e');
        }
      }

      // 2. 检查本地缓存
      final localCachedData = await _cacheManager.getLocalCache(cacheKey);
      if (localCachedData != null && (localCachedData as List).isNotEmpty) {
        print('✅ 从本地缓存获取食物记录: date=$date');
        try {
          final records = (localCachedData as List)
              .map((item) => FoodRecord.fromJson(item as Map<String, dynamic>))
              .toList();
          if (records.isNotEmpty) {
            _cacheManager.setMemoryCache(cacheKey, localCachedData);
            return ApiResponse<List<FoodRecord>>(
              success: true,
              message: '从缓存获取',
              data: records,
            );
          }
        } catch (e) {
          print('⚠️ 本地缓存解析失败，跳过缓存: $e');
        }
      }

      print('📤 从服务器获取食物记录: date=$date');

      final result = await getFoodRecords(
        startDate: date,
        endDate: date,
        pageSize: 100,
      );

      print('📤 服务器响应: success=${result.success}, message=${result.message}');

      if (result.success && result.data != null) {
        final records = result.data!.records;
        print('📤 服务器返回记录数: ${records.length}');

        final recordsJson = records.map((record) => record.toJson()).toList();
        _cacheManager.setMemoryCache(cacheKey, recordsJson);
        await _cacheManager.setLocalCache(cacheKey, recordsJson);

        print('✅ 食物记录获取成功并已缓存: date=$date, count=${records.length}');

        return ApiResponse<List<FoodRecord>>(
          success: true,
          message: result.message,
          data: records,
        );
      } else {
        print('❌ 服务器返回失败: ${result.message}');
        return ApiResponse<List<FoodRecord>>(
          success: false,
          message: result.message,
        );
      }
    } catch (e, stackTrace) {
      print('❌ getFoodRecordsByDay异常: $e');
      print('❌ 堆栈: $stackTrace');
      return ApiResponse<List<FoodRecord>>(
        success: false,
        message: '获取指定日期食物记录失败: $e',
      );
    }
  }

  /// 获取指定日期的食物记录
  Future<ApiResponse<FoodRecordsResponse>> getFoodRecordsByDate(
      DateTime date) async {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return await getFoodRecords(
      startDate: dateString,
      endDate: dateString,
      pageSize: 100, // 获取当天所有记录
    );
  }

  /// 获取最近一周的营养趋势
  Future<ApiResponse<NutritionTrends>> getWeeklyNutritionTrends() async {
    final now = DateTime.now();
    final endDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = now.subtract(const Duration(days: 6));
    final startDateString =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    return await getNutritionTrends(
      startDate: startDateString,
      endDate: endDate,
    );
  }

  /// 获取最近一个月的营养趋势
  Future<ApiResponse<NutritionTrends>> getMonthlyNutritionTrends() async {
    final now = DateTime.now();
    final endDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = now.subtract(const Duration(days: 29));
    final startDateString =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    return await getNutritionTrends(
      startDate: startDateString,
      endDate: endDate,
    );
  }

  Future<ApiResponse<FoodRecord>> updateFoodRecord(
      int recordId, FoodRecordCreate foodData) async {
    try {
      final response = await _apiService.put(
        '/foods/records/$recordId',
        data: foodData.toJson(),
      );

      if (response.success && response.data != null) {
        final foodRecord =
            FoodRecord.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<FoodRecord>(
          success: true,
          message: response.message.isNotEmpty ? response.message : '更新成功',
          data: foodRecord,
        );
      }
      return ApiResponse<FoodRecord>(
        success: false,
        message: response.message.isNotEmpty ? response.message : '更新失败',
      );
    } catch (e) {
      return ApiResponse<FoodRecord>(
        success: false,
        message: '更新食物记录失败: $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteFoodRecord(int recordId) async {
    try {
      final response = await _apiService.delete('/foods/records/$recordId');

      if (response.success) {
        return ApiResponse<void>(
          success: true,
          message: response.message.isNotEmpty ? response.message : '删除成功',
        );
      }
      return ApiResponse<void>(
        success: false,
        message: response.message.isNotEmpty ? response.message : '删除失败',
        notFound: response.notFound,
      );
    } catch (e) {
      return ApiResponse<void>(
        success: false,
        message: '删除食物记录失败: $e',
      );
    }
  }

  Future<void> invalidateRecordsCache(String date) async {
    final cacheKey = 'food_records_$date';
    _cacheManager.removeMemoryCache(cacheKey);
    await _cacheManager.removeLocalCache(cacheKey);
    print('🗑️ 已清除食物记录缓存: date=$date');
  }

  static const Map<String, Map<String, double>> _foodNutritionDB = {
    '米饭': {'calories': 116, 'protein': 2.6, 'fat': 0.3, 'carbs': 25.9},
    '白米饭': {'calories': 116, 'protein': 2.6, 'fat': 0.3, 'carbs': 25.9},
    '馒头': {'calories': 221, 'protein': 7.0, 'fat': 1.1, 'carbs': 47.0},
    '面条': {'calories': 110, 'protein': 3.5, 'fat': 0.5, 'carbs': 23.0},
    '面包': {'calories': 312, 'protein': 8.3, 'fat': 5.1, 'carbs': 58.6},
    '饺子': {'calories': 196, 'protein': 7.8, 'fat': 6.5, 'carbs': 26.0},
    '包子': {'calories': 174, 'protein': 6.4, 'fat': 4.5, 'carbs': 27.0},
    '粥': {'calories': 46, 'protein': 1.1, 'fat': 0.3, 'carbs': 9.8},
    '白粥': {'calories': 46, 'protein': 1.1, 'fat': 0.3, 'carbs': 9.8},
    '鸡蛋': {'calories': 144, 'protein': 13.3, 'fat': 8.8, 'carbs': 2.8},
    '煮鸡蛋': {'calories': 144, 'protein': 13.3, 'fat': 8.8, 'carbs': 2.8},
    '煎蛋': {'calories': 199, 'protein': 14.1, 'fat': 15.2, 'carbs': 1.2},
    '牛奶': {'calories': 54, 'protein': 3.0, 'fat': 3.2, 'carbs': 3.4},
    '豆浆': {'calories': 31, 'protein': 3.0, 'fat': 1.6, 'carbs': 1.2},
    '酸奶': {'calories': 72, 'protein': 2.5, 'fat': 2.7, 'carbs': 9.3},
    '鸡胸肉': {'calories': 133, 'protein': 19.4, 'fat': 5.0, 'carbs': 2.5},
    '鸡腿': {'calories': 181, 'protein': 16.0, 'fat': 13.0, 'carbs': 0},
    '鸡翅': {'calories': 194, 'protein': 17.4, 'fat': 13.6, 'carbs': 0},
    '红烧肉': {'calories': 337, 'protein': 13.2, 'fat': 30.5, 'carbs': 4.2},
    '排骨': {'calories': 264, 'protein': 16.7, 'fat': 20.4, 'carbs': 3.5},
    '牛肉': {'calories': 125, 'protein': 19.9, 'fat': 4.2, 'carbs': 2.0},
    '猪肉': {'calories': 143, 'protein': 20.3, 'fat': 6.2, 'carbs': 1.5},
    '羊肉': {'calories': 118, 'protein': 20.5, 'fat': 3.9, 'carbs': 0},
    '鱼': {'calories': 104, 'protein': 17.6, 'fat': 3.3, 'carbs': 0},
    '三文鱼': {'calories': 139, 'protein': 17.2, 'fat': 7.8, 'carbs': 0},
    '虾': {'calories': 87, 'protein': 16.4, 'fat': 2.4, 'carbs': 0},
    '豆腐': {'calories': 81, 'protein': 8.1, 'fat': 3.7, 'carbs': 4.2},
    '蔬菜': {'calories': 23, 'protein': 1.5, 'fat': 0.3, 'carbs': 3.5},
    '白菜': {'calories': 18, 'protein': 1.5, 'fat': 0.2, 'carbs': 2.8},
    '西兰花': {'calories': 36, 'protein': 4.1, 'fat': 0.6, 'carbs': 4.3},
    '番茄': {'calories': 15, 'protein': 0.9, 'fat': 0.2, 'carbs': 2.5},
    '西红柿': {'calories': 15, 'protein': 0.9, 'fat': 0.2, 'carbs': 2.5},
    '土豆': {'calories': 76, 'protein': 2.0, 'fat': 0.2, 'carbs': 16.5},
    '黄瓜': {'calories': 15, 'protein': 0.7, 'fat': 0.2, 'carbs': 2.4},
    '胡萝卜': {'calories': 37, 'protein': 1.0, 'fat': 0.2, 'carbs': 7.7},
    '苹果': {'calories': 53, 'protein': 0.2, 'fat': 0.2, 'carbs': 13.5},
    '香蕉': {'calories': 93, 'protein': 1.4, 'fat': 0.2, 'carbs': 22.0},
    '橙子': {'calories': 48, 'protein': 0.8, 'fat': 0.2, 'carbs': 11.1},
    '葡萄': {'calories': 44, 'protein': 0.5, 'fat': 0.2, 'carbs': 10.3},
    '西瓜': {'calories': 25, 'protein': 0.5, 'fat': 0.1, 'carbs': 5.8},
    '草莓': {'calories': 30, 'protein': 1.0, 'fat': 0.2, 'carbs': 6.2},
    '沙拉': {'calories': 35, 'protein': 1.5, 'fat': 1.0, 'carbs': 5.5},
    '汉堡': {'calories': 295, 'protein': 14.0, 'fat': 14.5, 'carbs': 28.0},
    '披萨': {'calories': 266, 'protein': 11.0, 'fat': 10.0, 'carbs': 33.0},
    '炸鸡': {'calories': 279, 'protein': 18.5, 'fat': 18.0, 'carbs': 10.5},
    '薯条': {'calories': 298, 'protein': 3.3, 'fat': 15.0, 'carbs': 36.0},
    '可乐': {'calories': 43, 'protein': 0, 'fat': 0, 'carbs': 10.6},
    '咖啡': {'calories': 2, 'protein': 0.3, 'fat': 0, 'carbs': 0},
    '奶茶': {'calories': 52, 'protein': 0.8, 'fat': 1.5, 'carbs': 9.2},
    '绿茶': {'calories': 1, 'protein': 0, 'fat': 0, 'carbs': 0},
    '火锅': {'calories': 150, 'protein': 8.0, 'fat': 8.5, 'carbs': 10.0},
    '炒饭': {'calories': 174, 'protein': 4.5, 'fat': 6.5, 'carbs': 25.0},
    '炒面': {'calories': 160, 'protein': 4.0, 'fat': 5.5, 'carbs': 24.0},
    '拉面': {'calories': 130, 'protein': 5.0, 'fat': 3.0, 'carbs': 21.0},
    '方便面': {'calories': 472, 'protein': 9.5, 'fat': 21.1, 'carbs': 61.6},
    '饼干': {'calories': 433, 'protein': 7.5, 'fat': 14.8, 'carbs': 70.3},
    '蛋糕': {'calories': 348, 'protein': 7.0, 'fat': 15.0, 'carbs': 46.0},
    '巧克力': {'calories': 544, 'protein': 5.3, 'fat': 31.0, 'carbs': 60.0},
    '冰淇淋': {'calories': 127, 'protein': 2.4, 'fat': 5.3, 'carbs': 17.7},
    '花生': {'calories': 563, 'protein': 24.8, 'fat': 44.3, 'carbs': 21.7},
    '核桃': {'calories': 627, 'protein': 14.9, 'fat': 58.8, 'carbs': 19.1},
    '红枣': {'calories': 276, 'protein': 3.2, 'fat': 0.5, 'carbs': 67.8},
    '燕麦': {'calories': 367, 'protein': 15.0, 'fat': 6.7, 'carbs': 61.6},
    '玉米': {'calories': 112, 'protein': 4.0, 'fat': 1.2, 'carbs': 22.8},
    '紫薯': {'calories': 82, 'protein': 1.5, 'fat': 0.2, 'carbs': 18.0},
    '红薯': {'calories': 86, 'protein': 1.1, 'fat': 0.2, 'carbs': 20.1},
    '茄子': {'calories': 23, 'protein': 1.1, 'fat': 0.2, 'carbs': 3.6},
    '青椒': {'calories': 22, 'protein': 1.0, 'fat': 0.2, 'carbs': 3.7},
    '蘑菇': {'calories': 24, 'protein': 2.7, 'fat': 0.1, 'carbs': 4.1},
    '海带': {'calories': 16, 'protein': 1.2, 'fat': 0.1, 'carbs': 2.1},
    '紫菜': {'calories': 207, 'protein': 26.7, 'fat': 1.1, 'carbs': 22.5},
    '鸡蛋灌饼': {'calories': 248, 'protein': 8.0, 'fat': 11.0, 'carbs': 30.0},
    '油条': {'calories': 386, 'protein': 6.9, 'fat': 17.6, 'carbs': 51.0},
    '烧饼': {'calories': 326, 'protein': 8.0, 'fat': 10.5, 'carbs': 50.0},
    '煎饼果子': {'calories': 235, 'protein': 7.5, 'fat': 8.5, 'carbs': 32.0},
    '小笼包': {'calories': 204, 'protein': 8.0, 'fat': 7.5, 'carbs': 26.0},
    '馄饨': {'calories': 110, 'protein': 5.5, 'fat': 3.0, 'carbs': 14.0},
    '粽子': {'calories': 195, 'protein': 4.5, 'fat': 3.5, 'carbs': 37.0},
    '汤圆': {'calories': 311, 'protein': 5.0, 'fat': 6.0, 'carbs': 60.0},
    '月饼': {'calories': 421, 'protein': 8.0, 'fat': 19.0, 'carbs': 55.0},
  };

  Map<String, double?> estimateNutrition(String foodName, double portion) {
    final key = foodName.trim();
    if (key.isEmpty) {
      return {'calories': 0, 'protein': 0, 'fat': 0, 'carbs': 0};
    }

    final exactMatch = _foodNutritionDB[key];
    if (exactMatch != null) {
      return {
        'calories': (exactMatch['calories'] ?? 0) * portion,
        'protein': (exactMatch['protein'] ?? 0) * portion,
        'fat': (exactMatch['fat'] ?? 0) * portion,
        'carbs': (exactMatch['carbs'] ?? 0) * portion,
      };
    }

    final tokens = _splitFoodName(key);
    if (tokens.length > 1) {
      return _estimateMultipleFoods(tokens, portion);
    }

    return _estimateSingleFood(key, portion);
  }

  List<String> _splitFoodName(String foodName) {
    final delimiters = ['、', '，', ',', '和', '加', '配', '搭', '跟', '与'];
    for (final d in delimiters) {
      if (foodName.contains(d)) {
        return foodName
            .split(d)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return [foodName];
  }

  Map<String, double?> _estimateMultipleFoods(
      List<String> tokens, double portion) {
    double totalCalories = 0, totalProtein = 0, totalFat = 0, totalCarbs = 0;
    for (final token in tokens) {
      final est = _estimateSingleFood(token, 1.0);
      totalCalories += est['calories'] ?? 0;
      totalProtein += est['protein'] ?? 0;
      totalFat += est['fat'] ?? 0;
      totalCarbs += est['carbs'] ?? 0;
    }
    return {
      'calories': totalCalories * portion,
      'protein': totalProtein * portion,
      'fat': totalFat * portion,
      'carbs': totalCarbs * portion,
    };
  }

  Map<String, double?> _estimateSingleFood(String foodName, double portion) {
    final exactMatch = _foodNutritionDB[foodName];
    if (exactMatch != null) {
      return {
        'calories': (exactMatch['calories'] ?? 0) * portion,
        'protein': (exactMatch['protein'] ?? 0) * portion,
        'fat': (exactMatch['fat'] ?? 0) * portion,
        'carbs': (exactMatch['carbs'] ?? 0) * portion,
      };
    }

    final decomposed = _decomposeCompoundFood(foodName);
    if (decomposed.length > 1) {
      return _estimateMultipleFoods(decomposed, portion);
    }

    String? fuzzyKey;
    int fuzzyKeyLen = 0;
    for (final k in _foodNutritionDB.keys) {
      if (foodName.contains(k) && k.length > fuzzyKeyLen) {
        fuzzyKey = k;
        fuzzyKeyLen = k.length;
      }
    }
    if (fuzzyKey != null) {
      final data = _foodNutritionDB[fuzzyKey]!;
      return {
        'calories': (data['calories'] ?? 0) * portion,
        'protein': (data['protein'] ?? 0) * portion,
        'fat': (data['fat'] ?? 0) * portion,
        'carbs': (data['carbs'] ?? 0) * portion,
      };
    }

    for (final entry in _foodNutritionDB.entries) {
      if (entry.key.contains(foodName)) {
        return {
          'calories': (entry.value['calories'] ?? 0) * portion,
          'protein': (entry.value['protein'] ?? 0) * portion,
          'fat': (entry.value['fat'] ?? 0) * portion,
          'carbs': (entry.value['carbs'] ?? 0) * portion,
        };
      }
    }

    return {
      'calories': 100 * portion,
      'protein': 5 * portion,
      'fat': 3 * portion,
      'carbs': 15 * portion,
    };
  }

  List<String> _decomposeCompoundFood(String foodName) {
    final sortedKeys = _foodNutritionDB.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    List<String> result = [];
    String remaining = foodName;

    while (remaining.isNotEmpty) {
      bool found = false;
      for (final key in sortedKeys) {
        if (remaining.contains(key)) {
          result.add(key);
          remaining = remaining.replaceAll(key, '');
          found = true;
          break;
        }
      }
      if (!found) break;
    }

    remaining = remaining.replaceAll(RegExp(r'[饭面米汤饼粥粉皮卷丝粒丁块条片碎末沫]'), '');
    if (remaining.isNotEmpty && result.isNotEmpty) {
      for (final key in sortedKeys) {
        if (key.length == 1 && remaining.contains(key)) {
          result.add(key);
          remaining = remaining.replaceAll(key, '');
        }
      }
    }

    if (result.length <= 1) return [foodName];

    return result;
  }
}
