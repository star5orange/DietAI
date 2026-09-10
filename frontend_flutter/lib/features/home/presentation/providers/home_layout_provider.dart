import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_manager.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/home_layout_service.dart';
import '../../domain/home_layout.dart';

/// 首页布局状态
///
/// 策略：先用本地缓存渲染（首屏不闪），再以后端结果为准并回写缓存。
/// 后端不可用时保留兜底布局（全部可见），不会让模块缺席。
class HomeLayoutNotifier extends StateNotifier<HomeLayout> {
  HomeLayoutNotifier() : super(HomeLayout.fallback()) {
    reload();
  }

  static const String _cacheKey = 'cache_home_layout';

  final HomeLayoutService _service = HomeLayoutService();
  final CacheManager _cache = CacheManager();

  Future<void> reload() async {
    // 1. 本地缓存先行
    try {
      final cached = await _cache.getLocalCache(_cacheKey);
      if (cached is Map) {
        state = HomeLayout.fromJson(Map<String, dynamic>.from(cached));
      }
    } catch (_) {
      // 缓存损坏时忽略，继续走网络
    }

    // 2. 后端为准
    try {
      final res = await _service.fetchLayout();
      final data = res.data;
      if (res.success && data is Map) {
        final layout = HomeLayout.fromJson(Map<String, dynamic>.from(data));
        state = layout;
        await _cache.setLocalCache(_cacheKey, layout.toJson());
      }
    } catch (_) {
      // 网络异常：保持缓存/兜底布局
    }
  }

  /// 保存引导问卷答案（由后端推导 focus / interests），成功返回 true
  Future<bool> saveAnswers(Map<String, String> answers) async {
    return save(preferences: {'answers': answers});
  }

  /// 保存定制；成功返回 true
  Future<bool> save({
    List<String>? hiddenModules,
    List<String>? moduleOrder,
    Map<String, dynamic>? preferences,
    bool reset = false,
  }) async {
    try {
      final res = await _service.saveLayout(
        hiddenModules: hiddenModules,
        moduleOrder: moduleOrder,
        preferences: preferences,
        reset: reset,
      );
      final data = res.data;
      if (res.success && data is Map) {
        final layout = HomeLayout.fromJson(Map<String, dynamic>.from(data));
        state = layout;
        await _cache.setLocalCache(_cacheKey, layout.toJson());
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutNotifier, HomeLayout>((ref) {
  final notifier = HomeLayoutNotifier();
  // 切换账号时重新拉取（各账号布局不同）
  ref.listen(currentUserProvider, (prev, next) {
    if (prev?.id != next?.id) {
      notifier.reload();
    }
  });
  return notifier;
});
