import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';

/// 饮食推荐状态
class DietRecommendationState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> recommendations;

  DietRecommendationState({
    this.isLoading = false,
    this.error,
    this.recommendations = const [],
  });

  DietRecommendationState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? recommendations,
  }) {
    return DietRecommendationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      recommendations: recommendations ?? this.recommendations,
    );
  }
}

/// 饮食推荐 Notifier
class DietRecommendationNotifier
    extends StateNotifier<DietRecommendationState> {
  final ApiService _apiService;

  DietRecommendationNotifier(this._apiService)
      : super(DietRecommendationState());

  /// 加载饮食推荐
  /// 后端: POST /family/diet-recommendation?target_user_id=xxx
  Future<void> loadRecommendations(int userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post(
        '/family/diet-recommendation',
        queryParameters: {'target_user_id': userId},
      );

      if (response.success) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final recommendations = List<Map<String, dynamic>>.from(
            data['recommendations'] ?? [],
          );
          state = DietRecommendationState(recommendations: recommendations);
        } else if (data is List) {
          final recommendations = data
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          state = DietRecommendationState(recommendations: recommendations);
        } else {
          state = DietRecommendationState(recommendations: []);
        }
      } else {
        state = DietRecommendationState(error: response.message);
      }
    } catch (e) {
      state = DietRecommendationState(error: e.toString());
    }
  }
}

/// 饮食推荐 Provider
final dietRecommendationProvider =
    StateNotifierProvider<DietRecommendationNotifier, DietRecommendationState>(
        (ref) {
  return DietRecommendationNotifier(ref.watch(apiServiceProvider));
});

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
