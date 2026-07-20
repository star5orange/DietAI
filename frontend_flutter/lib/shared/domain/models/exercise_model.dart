import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Note: ApiService import is intentionally avoided here since this is a pure model file.
// For API-based exercise types, use ExerciseType.fetchFromApi() which accepts an ApiService instance.

class ExerciseRecord {
  final String id;
  final String exerciseName;
  final String exerciseType;
  final int durationMinutes;
  final double caloriesBurned;
  final String? notes;
  final String recordedAt;
  final String createdAt;
  final Map<String, dynamic>? strengthDetail;

  ExerciseRecord({
    required this.id,
    required this.exerciseName,
    required this.exerciseType,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.notes,
    required this.recordedAt,
    required this.createdAt,
    this.strengthDetail,
  });

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) {
    return ExerciseRecord(
      id: (json['id'] ?? '').toString(),
      exerciseName:
          (json['exercise_name'] ?? json['exercise_type'] ?? '').toString(),
      exerciseType: (json['exercise_type'] ?? '').toString(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['calories_burned'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      recordedAt: (json['recorded_at'] ?? json['record_date'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      strengthDetail: json['strength_detail'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_name': exerciseName,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'calories_burned': caloriesBurned,
      'notes': notes,
      'recorded_at': recordedAt,
      'created_at': createdAt,
      if (strengthDetail != null) 'strength_detail': strengthDetail,
    };
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(recordedAt);
      final dateStr = '${date.month}月${date.day}日';
      // 如果是纯日期（无时间部分），只显示日期
      if (recordedAt.length <= 10) return dateStr;
      return '$dateStr ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return recordedAt;
    }
  }

  String get formattedDuration {
    if (durationMinutes >= 60) {
      final hours = durationMinutes ~/ 60;
      final mins = durationMinutes % 60;
      return mins > 0 ? '${hours}h${mins}min' : '${hours}h';
    }
    return '${durationMinutes}min';
  }

  String get formattedCalories => '${caloriesBurned.toStringAsFixed(0)} kcal';
}

class CreateExerciseRecordRequest {
  final String exerciseName;
  final String exerciseType;
  final int durationMinutes;
  final double caloriesBurned;
  final String? notes;
  final String? recordedAt;

  CreateExerciseRecordRequest({
    required this.exerciseName,
    required this.exerciseType,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.notes,
    this.recordedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'exercise_name': exerciseName,
      'exercise_type': exerciseType,
      'duration_minutes': durationMinutes,
      'calories_burned': caloriesBurned,
      'notes': notes,
      'recorded_at': recordedAt,
    };
  }
}

class DailyExerciseSummary {
  final String date;
  final double totalCaloriesBurned;
  final int totalDurationMinutes;
  final int exerciseCount;

  DailyExerciseSummary({
    required this.date,
    required this.totalCaloriesBurned,
    required this.totalDurationMinutes,
    required this.exerciseCount,
  });

  String get formattedTotalCalories =>
      '${totalCaloriesBurned.toStringAsFixed(0)} kcal';

  String get formattedTotalDuration {
    if (totalDurationMinutes >= 60) {
      final hours = totalDurationMinutes ~/ 60;
      final mins = totalDurationMinutes % 60;
      return mins > 0 ? '${hours}h${mins}min' : '${hours}h';
    }
    return '${totalDurationMinutes}min';
  }
}

class ExerciseType {
  /// 硬编码运动类型映射——作为 API 不可用时的回退数据。
  /// 主要数据源应通过 [fetchFromApi] 方法从 GET /exercises/types 获取。
  static const Map<String, String> types = {
    'running': '跑步',
    'walking': '步行',
    'cycling': '骑行',
    'swimming': '游泳',
    'yoga': '瑜伽',
    'strength': '力量训练',
    'hiit': 'HIIT',
    'dance': '舞蹈',
    'basketball': '篮球',
    'football': '足球',
    'badminton': '羽毛球',
    'tennis': '网球',
    'other': '其他',
  };

  static String getLabel(String key) => types[key] ?? key;

  static List<MapEntry<String, String>> get entries => types.entries.toList();

  /// 从后端 API 获取运动类型列表，失败时回退到 [types]。
  /// [get] 应为 ApiService().get 方法引用，以避免模型文件直接依赖 ApiService。
  static Future<Map<String, String>> fetchFromApi(
    Future<dynamic> Function(String path,
            {Map<String, dynamic>? queryParameters})
        get,
  ) async {
    try {
      final response = await get('/exercises/types');
      if (response is dynamic &&
          response.success == true &&
          response.data != null) {
        final data = response.data;
        if (data['items'] != null) {
          final items = data['items'] as List;
          final result = <String, String>{};
          for (final item in items) {
            final key = (item['type'] ?? item['id'] ?? '').toString();
            final label = (item['label'] ?? item['name'] ?? key).toString();
            if (key.isNotEmpty) result[key] = label;
          }
          if (result.isNotEmpty) return result;
        }
      }
    } catch (_) {
      // 请求失败，使用硬编码回退数据
    }
    return Map.from(types);
  }
}

class ExerciseRecordStorage {
  static const String _key = 'exercise_records';

  static Future<List<ExerciseRecord>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => ExerciseRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAll(List<ExerciseRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<List<ExerciseRecord>> add(ExerciseRecord record) async {
    final records = await loadAll();
    records.insert(0, record);
    await saveAll(records);
    return records;
  }

  static Future<List<ExerciseRecord>> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await saveAll(records);
    return records;
  }

  static Future<List<ExerciseRecord>> getByDate(String dateStr) async {
    final records = await loadAll();
    return records.where((r) => r.recordedAt.startsWith(dateStr)).toList();
  }

  static Future<DailyExerciseSummary> getDailySummary(String dateStr) async {
    final records = await getByDate(dateStr);
    return DailyExerciseSummary(
      date: dateStr,
      totalCaloriesBurned:
          records.fold(0.0, (sum, r) => sum + r.caloriesBurned),
      totalDurationMinutes:
          records.fold(0, (sum, r) => sum + r.durationMinutes),
      exerciseCount: records.length,
    );
  }
}
