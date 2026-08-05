import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';

/// 家庭周报数据模型
class FamilyWeeklyReport {
  final String weekStart;
  final String weekEnd;
  final List<FamilyMemberWeeklyData> members;

  FamilyWeeklyReport({
    required this.weekStart,
    required this.weekEnd,
    required this.members,
  });

  factory FamilyWeeklyReport.fromJson(Map<String, dynamic> json) {
    return FamilyWeeklyReport(
      weekStart: json['week_start'] ?? '',
      weekEnd: json['week_end'] ?? '',
      members: (json['members'] as List)
          .map((m) => FamilyMemberWeeklyData.fromJson(m))
          .toList(),
    );
  }
}

class FamilyMemberWeeklyData {
  final int userId;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final double avgCalories;
  final double avgWater;
  final int healthScore;
  final List<String> achievements;
  final Map<String, dynamic>? examSummary;

  FamilyMemberWeeklyData({
    required this.userId,
    required this.username,
    this.realName,
    this.avatarUrl,
    required this.avgCalories,
    required this.avgWater,
    required this.healthScore,
    required this.achievements,
    this.examSummary,
  });

  factory FamilyMemberWeeklyData.fromJson(Map<String, dynamic> json) {
    return FamilyMemberWeeklyData(
      userId: json['user_id'],
      username: json['username'] ?? '',
      realName: json['real_name'],
      avatarUrl: json['avatar_url'],
      avgCalories: (json['avg_calories'] ?? 0).toDouble(),
      avgWater: (json['avg_water'] ?? 0).toDouble(),
      healthScore: json['health_score'] ?? 0,
      achievements: List<String>.from(json['achievements'] ?? []),
      examSummary: json['exam_summary'] as Map<String, dynamic>?,
    );
  }
}

/// 家庭周报状态
class WeeklyReportState {
  final FamilyWeeklyReport? report;
  final bool isLoading;
  final String? error;

  WeeklyReportState({
    this.report,
    this.isLoading = false,
    this.error,
  });

  WeeklyReportState copyWith({
    FamilyWeeklyReport? report,
    bool? isLoading,
    String? error,
  }) {
    return WeeklyReportState(
      report: report ?? this.report,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 家庭周报 Notifier
class WeeklyReportNotifier extends StateNotifier<WeeklyReportState> {
  final ApiService _apiService;

  WeeklyReportNotifier(this._apiService) : super(WeeklyReportState());

  Future<void> loadWeeklyReport() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.get('/family/weekly-report');
      if (response.success) {
        final report = FamilyWeeklyReport.fromJson(response.data);
        state = WeeklyReportState(report: report);
      } else {
        state = WeeklyReportState(error: response.message);
      }
    } catch (e) {
      state = WeeklyReportState(error: e.toString());
    }
  }
}

final weeklyReportProvider =
    StateNotifierProvider<WeeklyReportNotifier, WeeklyReportState>((ref) {
  return WeeklyReportNotifier(ref.watch(apiServiceProvider));
});

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
