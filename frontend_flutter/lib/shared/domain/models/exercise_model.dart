import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExerciseRecord {
  final String id;
  final String exerciseName;
  final String exerciseType;
  final int durationMinutes;
  final double caloriesBurned;
  final String? notes;
  final String recordedAt;
  final String createdAt;

  ExerciseRecord({
    required this.id,
    required this.exerciseName,
    required this.exerciseType,
    required this.durationMinutes,
    required this.caloriesBurned,
    this.notes,
    required this.recordedAt,
    required this.createdAt,
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
