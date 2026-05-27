import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderRecord {
  final String id;
  final String type;
  final String title;
  final int hour;
  final int minute;
  final List<int> repeatDays;
  final bool isEnabled;
  final String? message;
  final String createdAt;

  ReminderRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.hour,
    required this.minute,
    this.repeatDays = const [],
    this.isEnabled = true,
    this.message,
    required this.createdAt,
  });

  factory ReminderRecord.fromJson(Map<String, dynamic> json) {
    return ReminderRecord(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      repeatDays: (json['repeat_days'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      isEnabled: json['is_enabled'] as bool? ?? true,
      message: json['message'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'hour': hour,
      'minute': minute,
      'repeat_days': repeatDays,
      'is_enabled': isEnabled,
      'message': message,
      'created_at': createdAt,
    };
  }

  ReminderRecord copyWith({
    String? id,
    String? type,
    String? title,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    bool? isEnabled,
    String? message,
    String? createdAt,
  }) {
    return ReminderRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeatDaysText {
    if (repeatDays.isEmpty) return '仅一次';
    if (repeatDays.length == 7) return '每天';
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final sorted = List<int>.from(repeatDays)..sort();
    return sorted.map((d) => '周${dayLabels[d - 1]}').join('、');
  }
}

class ReminderType {
  static const String meal = 'meal';
  static const String water = 'water';
  static const String exercise = 'exercise';
  static const String weigh = 'weigh';
  static const String medicine = 'medicine';
  static const String custom = 'custom';

  static const Map<String, String> labels = {
    meal: '用餐提醒',
    water: '饮水提醒',
    exercise: '运动提醒',
    weigh: '称重提醒',
    medicine: '用药提醒',
    custom: '自定义提醒',
  };

  static const Map<String, String> icons = {
    meal: '🍽️',
    water: '💧',
    exercise: '🏃',
    weigh: '⚖️',
    medicine: '💊',
    custom: '🔔',
  };

  static String getLabel(String key) => labels[key] ?? key;
  static String getIcon(String key) => icons[key] ?? '🔔';

  static List<MapEntry<String, String>> get entries => labels.entries.toList();
}

class ReminderStorage {
  static const String _key = 'reminder_records';

  static Future<List<ReminderRecord>> loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .map((e) => ReminderRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveAll(List<ReminderRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(records.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<List<ReminderRecord>> add(ReminderRecord record) async {
    final records = await loadAll();
    records.add(record);
    await saveAll(records);
    return records;
  }

  static Future<List<ReminderRecord>> update(ReminderRecord updated) async {
    final records = await loadAll();
    final index = records.indexWhere((r) => r.id == updated.id);
    if (index >= 0) {
      records[index] = updated;
    }
    await saveAll(records);
    return records;
  }

  static Future<List<ReminderRecord>> delete(String id) async {
    final records = await loadAll();
    records.removeWhere((r) => r.id == id);
    await saveAll(records);
    return records;
  }

  static Future<void> toggleEnabled(String id, bool enabled) async {
    final records = await loadAll();
    final index = records.indexWhere((r) => r.id == id);
    if (index >= 0) {
      records[index] = records[index].copyWith(isEnabled: enabled);
      await saveAll(records);
    }
  }
}
