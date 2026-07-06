import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// 缓存管理器 - 管理图片、API数据和图片数据的缓存
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // 内存缓存
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, Uint8List> _imageCache = {};
  
  // 缓存配置
  static const int _maxMemoryCacheSize = 100; // 最大内存缓存条目数
  static const int _maxImageCacheSize = 50; // 最大图片缓存条目数
  static const Duration _cacheExpiration = Duration(hours: 24); // 缓存过期时间

  /// 获取缓存键
  String _getCacheKey(String key, String type) => '${type}_$key';

  /// 设置内存缓存
  void setMemoryCache(String key, dynamic data) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // 移除最旧的条目
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// 获取内存缓存
  dynamic getMemoryCache(String key) {
    final cached = _memoryCache[key];
    if (cached == null) return null;

    final timestamp = cached['timestamp'] as int;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    if (age > _cacheExpiration.inMilliseconds) {
      _memoryCache.remove(key);
      return null;
    }

    return cached['data'];
  }

  /// 设置图片缓存
  void setImageCache(String key, Uint8List imageData) {
    if (_imageCache.length >= _maxImageCacheSize) {
      // 移除最旧的条目
      final oldestKey = _imageCache.keys.first;
      _imageCache.remove(oldestKey);
    }
    _imageCache[key] = imageData;
  }

  /// 获取图片缓存
  Uint8List? getImageCache(String key) {
    return _imageCache[key];
  }

  /// 设置本地缓存
  Future<void> setLocalCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(key, jsonEncode(cacheData));
    } catch (e) {
      debugPrint('设置本地缓存失败: $e');
    }
  }

  /// 获取本地缓存
  Future<dynamic> getLocalCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedString = prefs.getString(key);
      if (cachedString == null) return null;

      final cached = jsonDecode(cachedString);
      final timestamp = cached['timestamp'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      
      if (age > _cacheExpiration.inMilliseconds) {
        await prefs.remove(key);
        return null;
      }

      return cached['data'];
    } catch (e) {
      debugPrint('获取本地缓存失败: $e');
      return null;
    }
  }

  /// 设置文件缓存
  Future<void> setFileCache(String key, Uint8List data) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/cache_$key');
      await file.writeAsBytes(data);
    } catch (e) {
      debugPrint('设置文件缓存失败: $e');
    }
  }

  /// 获取文件缓存
  Future<Uint8List?> getFileCache(String key) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/cache_$key');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint('获取文件缓存失败: $e');
    }
    return null;
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    _memoryCache.clear();
    _imageCache.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }
      
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      for (final file in files) {
        if (file.path.contains('cache_')) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('清除缓存失败: $e');
    }
  }

  /// 移除指定内存缓存
  void removeMemoryCache(String key) {
    _memoryCache.remove(key);
  }

  /// 移除指定本地缓存
  Future<void> removeLocalCache(String key) async {
    _memoryCache.remove(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('移除本地缓存失败: $e');
    }
  }

  /// 按前缀批量失效缓存（写操作后调用）
  /// 例如：invalidateCacheByPrefix('daily_summary') 清除所有日常汇总缓存
  Future<void> invalidateCacheByPrefix(String prefix) async {
    // 清除内存缓存
    _memoryCache.removeWhere((key, _) => key.contains(prefix));

    // 清除本地缓存
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.contains(prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('按前缀失效缓存失败: $e');
    }
  }

  /// 失效与饮食记录相关的缓存（添加/修改/删除饮食记录后调用）
  Future<void> invalidateFoodCaches() async {
    await invalidateCacheByPrefix('daily_summary');
    await invalidateCacheByPrefix('food_records');
    await invalidateCacheByPrefix('nutrition');
    removeMemoryCache('home_data');
  }

  /// 失效与运动记录相关的缓存（添加/修改/删除运动记录后调用）
  Future<void> invalidateExerciseCaches() async {
    await invalidateCacheByPrefix('exercise');
    await invalidateCacheByPrefix('daily_summary');
    removeMemoryCache('home_data');
  }

  /// 失效与饮水记录相关的缓存（添加饮水记录后调用）
  Future<void> invalidateWaterCaches() async {
    await invalidateCacheByPrefix('water');
    await invalidateCacheByPrefix('daily_summary');
    removeMemoryCache('home_data');
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'image_cache_size': _imageCache.length,
      'max_memory_cache_size': _maxMemoryCacheSize,
      'max_image_cache_size': _maxImageCacheSize,
    };
  }
} 