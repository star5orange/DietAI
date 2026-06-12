import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class WaterIntakeRecord {
  final String id;
  final int amountMl;
  final String? notes;
  final String recordedAt;
  final String createdAt;

  WaterIntakeRecord({
    required this.id,
    required this.amountMl,
    this.notes,
    required this.recordedAt,
    required this.createdAt,
  });

  factory WaterIntakeRecord.fromJson(Map<String, dynamic> json) {
    return WaterIntakeRecord(
      id: json['id'] as String,
      amountMl: json['amount_ml'] as int,
      notes: json['notes'] as String?,
      recordedAt: json['recorded_at'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount_ml': amountMl,
      'notes': notes,
      'recorded_at': recordedAt,
      'created_at': createdAt,
    };
  }

  String get formattedAmount => '$amountMl ml';

  String get formattedAmountL => '${(amountMl / 1000).toStringAsFixed(2)} L';

  String get formattedTime {
    try {
      final date = DateTime.parse(recordedAt);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return recordedAt;
    }
  }
}

class DailyWaterSummary {
  final String date;
  final int totalMl;
  final int goalMl;
  final int recordCount;

  DailyWaterSummary({
    required this.date,
    required this.totalMl,
    this.goalMl = 2000,
    required this.recordCount,
  });

  double get progress => goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.0) : 0.0;

  bool get isGoalReached => totalMl >= goalMl;

  int get remainingMl => totalMl >= goalMl ? 0 : goalMl - totalMl;

String _fmtLiter(int ml) {
    final liters = ml / 1000;
    return liters.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  String get formattedTotal => totalMl >= 1000
      ? '${_fmtLiter(totalMl)} L'
      : '$totalMl ml';

  String get formattedGoal => '${_fmtLiter(goalMl)} L';

  String get formattedRemaining => remainingMl >= 1000
      ? '${_fmtLiter(remainingMl)} L'
      : '$remainingMl ml';
}

class WaterIntakeStorage {
  static const String _recordsKey = 'water_intake_records';
  static const String _goalKey = 'water_intake_goal_ml';

  static Future<List<WaterIntakeRecord>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_recordsKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => WaterIntakeRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAll(List<WaterIntakeRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_recordsKey, raw);
  }

  static Future<List<WaterIntakeRecord>> add(WaterIntakeRecord record) async {
    final records = await loadAll();
    records.insert(0, record);
    await saveAll(records);
    return records;
  }

  static Future<List<WaterIntakeRecord>> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await saveAll(records);
    return records;
  }

  static Future<List<WaterIntakeRecord>> getByDate(String dateStr) async {
    final records = await loadAll();
    return records.where((r) => r.recordedAt.startsWith(dateStr)).toList();
  }

  static Future<DailyWaterSummary> getDailySummary(String dateStr) async {
    final records = await getByDate(dateStr);
    final goal = await getGoal();
    return DailyWaterSummary(
      date: dateStr,
      totalMl: records.fold(0, (sum, r) => sum + r.amountMl),
      goalMl: goal,
      recordCount: records.length,
    );
  }

  static Future<int> getGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey) ?? 2000;
  }

  static Future<void> setGoal(int goalMl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey, goalMl);
  }
}
