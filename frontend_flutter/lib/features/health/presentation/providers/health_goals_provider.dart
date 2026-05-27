import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/health_goals_service.dart';
import '../../../../shared/domain/models/health_goals_model.dart';
import '../../../../shared/domain/models/api_response.dart';

/// Health Goals Service Provider
final healthGoalsServiceProvider = Provider<HealthGoalsService>((ref) {
  return HealthGoalsService();
});

/// Health Goals State Provider
final healthGoalsProvider = StateNotifierProvider<HealthGoalsNotifier, AsyncValue<List<HealthGoal>>>((ref) {
  final service = ref.watch(healthGoalsServiceProvider);
  return HealthGoalsNotifier(service);
});

/// Health Goals Notifier
class HealthGoalsNotifier extends StateNotifier<AsyncValue<List<HealthGoal>>> {
  final HealthGoalsService _service;

  HealthGoalsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadHealthGoals();
  }

  /// 加载健康目标列表
  Future<void> loadHealthGoals() async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _service.getHealthGoals();
      
      if (result.success) {
        state = AsyncValue.data(result.data ?? []);
      } else {
        state = AsyncValue.error(result.message, StackTrace.current);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// 创建健康目标
  Future<ApiResponse<HealthGoal>> createHealthGoal(CreateHealthGoalRequest request) async {
    try {
      final result = await _service.createHealthGoal(request);
      
      if (result.success && result.data != null) {
        // 更新本地状态
        state.whenData((goals) {
          state = AsyncValue.data([...goals, result.data!]);
        });
      }
      
      return result;
    } catch (e) {
      return ApiResponse<HealthGoal>.failure(
        message: '创建健康目标失败: $e',
      );
    }
  }

  /// 更新健康目标
  Future<ApiResponse<HealthGoal>> updateHealthGoal(int goalId, UpdateHealthGoalRequest request) async {
    try {
      final result = await _service.updateHealthGoal(goalId, request);
      
      if (result.success && result.data != null) {
        // 更新本地状态
        state.whenData((goals) {
          final updatedGoals = goals.map((goal) {
            return goal.id == goalId ? result.data! : goal;
          }).toList();
          state = AsyncValue.data(updatedGoals);
        });
      }
      
      return result;
    } catch (e) {
      return ApiResponse<HealthGoal>.failure(
        message: '更新健康目标失败: $e',
      );
    }
  }

  /// 删除健康目标
  Future<ApiResponse<void>> deleteHealthGoal(int goalId) async {
    try {
      final result = await _service.deleteHealthGoal(goalId);
      
      if (result.success) {
        // 更新本地状态
        state.whenData((goals) {
          final updatedGoals = goals.where((goal) => goal.id != goalId).toList();
          state = AsyncValue.data(updatedGoals);
        });
      }
      
      return result;
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除健康目标失败: $e',
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await loadHealthGoals();
  }
}

/// 健康目标进度Provider - 为特定目标提供进度信息
final healthGoalProgressProvider = FutureProvider.family<HealthGoalProgress?, int>((ref, goalId) async {
  final service = ref.watch(healthGoalsServiceProvider);
  final result = await service.getHealthGoalProgress(goalId);
  
  return result.success ? result.data : null;
});

/// 当前活跃健康目标Provider - 获取状态为进行中的目标
final activeHealthGoalsProvider = Provider<AsyncValue<List<HealthGoal>>>((ref) {
  final healthGoalsAsync = ref.watch(healthGoalsProvider);
  
  return healthGoalsAsync.when(
    data: (goals) {
      final activeGoals = goals.where((goal) => goal.currentStatus == 1).toList();
      return AsyncValue.data(activeGoals);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stackTrace) => AsyncValue.error(error, stackTrace),
  );
});