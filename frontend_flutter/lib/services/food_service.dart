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
  Stream<Map<String, dynamic>> createFoodRecordStream(FoodRecordCreate foodData) async* {
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
  Future<ApiResponse<FoodRecord>> createFoodRecord(FoodRecordCreate foodData) async {
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
  Future<ApiResponse<Map<String, dynamic>>> getFoodImageData(int recordId) async {
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
        final foodRecordsResponse = FoodRecordsResponse.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<FoodRecordsResponse>(
          success: true,
          message: response.message,
          data: foodRecordsResponse,
        );
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
        final foodRecord = FoodRecord.fromJson(response.data as Map<String, dynamic>);
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
      final response = await _apiService.post(
        '/foods/records/$recordId/nutrition',
        data: nutritionData.toJson(),
      );

      if (response.success) {
        final nutritionDetail = NutritionDetail.fromJson(response.data as Map<String, dynamic>);
        return ApiResponse<NutritionDetail>(
          success: true,
          message: response.message,
          data: nutritionDetail,
        );
      } else {
        return ApiResponse<NutritionDetail>(
          success: false,
          message: response.message,
        );
      }
    } catch (e) {
      return ApiResponse<NutritionDetail>(
        success: false,
        message: '添加营养详情失败: $e',
      );
    }
  }

  /// 获取每日营养汇总
  Future<ApiResponse<DailyNutritionSummary>> getDailyNutritionSummary(String summaryDate) async {
    try {
      final response = await _apiService.get('/foods/daily-summary/$summaryDate');

      if (response.success) {
        final summary = DailyNutritionSummary.fromJson(response.data as Map<String, dynamic>);
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
        final trends = NutritionTrends.fromJson(response.data as Map<String, dynamic>);
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
  Future<ApiResponse<FileUploadResponse>> uploadFoodImage(File imageFile) async {
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
          final requiredFields = ['file_id', 'file_name', 'file_url', 'object_name', 'file_size', 'content_type', 'upload_time'];
          for (String field in requiredFields) {
            if (!dataMap.containsKey(field)) {
              print('❌ 缺少必需字段: $field');
            } else {
              print('✅ 字段 $field: ${dataMap[field]} (${dataMap[field].runtimeType})');
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
        final imageUrlResponse = ImageUrlResponse.fromJson(response.data as Map<String, dynamic>);
        
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
        'data': {'object_name': uploadResult.data!.objectName, 'message': '图片上传成功'}
      };

      // 2. 创建食物记录，包含图片URL
      final foodRecordData = FoodRecordCreate(
        recordDate: recordDate,
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
        } else if (event['type'] == 'record_created' && event['data']['record'] != null) {
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
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
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
      if (cachedData != null) {
        print('✅ 从内存缓存获取食物记录: date=$date');
        final records = (cachedData as List).map((item) => FoodRecord.fromJson(item)).toList();
        return ApiResponse<List<FoodRecord>>(
          success: true,
          message: '从缓存获取',
          data: records,
        );
      }

      // 2. 检查本地缓存
      final localCachedData = await _cacheManager.getLocalCache(cacheKey);
      if (localCachedData != null) {
        print('✅ 从本地缓存获取食物记录: date=$date');
        final records = (localCachedData as List).map((item) => FoodRecord.fromJson(item)).toList();
        // 将本地缓存数据也放入内存缓存
        _cacheManager.setMemoryCache(cacheKey, localCachedData);
        return ApiResponse<List<FoodRecord>>(
          success: true,
          message: '从缓存获取',
          data: records,
        );
      }

      print('📤 从服务器获取食物记录: date=$date');
      
      final result = await getFoodRecords(
        startDate: date,
        endDate: date,
        pageSize: 100, // 获取当天所有记录
      );

      if (result.success && result.data != null) {
        final records = result.data!.records;
        
        // 缓存数据
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
        return ApiResponse<List<FoodRecord>>(
          success: false,
          message: result.message,
        );
      }
    } catch (e) {
      return ApiResponse<List<FoodRecord>>(
        success: false,
        message: '获取指定日期食物记录失败: $e',
      );
    }
  }

  /// 获取指定日期的食物记录
  Future<ApiResponse<FoodRecordsResponse>> getFoodRecordsByDate(DateTime date) async {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return await getFoodRecords(
      startDate: dateString,
      endDate: dateString,
      pageSize: 100, // 获取当天所有记录
    );
  }

  /// 获取最近一周的营养趋势
  Future<ApiResponse<NutritionTrends>> getWeeklyNutritionTrends() async {
    final now = DateTime.now();
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = now.subtract(const Duration(days: 6));
    final startDateString = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    
    return await getNutritionTrends(
      startDate: startDateString,
      endDate: endDate,
    );
  }

  /// 获取最近一个月的营养趋势
  Future<ApiResponse<NutritionTrends>> getMonthlyNutritionTrends() async {
    final now = DateTime.now();
    final endDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startDate = now.subtract(const Duration(days: 29));
    final startDateString = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    
    return await getNutritionTrends(
      startDate: startDateString,
      endDate: endDate,
    );
  }
} 