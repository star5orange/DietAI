import 'package:shared_preferences/shared_preferences.dart';

class PetStorage {
  static const _keyLevel = 'pet_level';
  static const _keyExp = 'pet_exp';
  static const _keyCurrentStreak = 'pet_current_streak';
  static const _keyLongestStreak = 'pet_longest_streak';
  static const _keyLastInteractDate = 'pet_last_interact_date';
  static const _keyTodayInteractCount = 'pet_today_interact_count';
  static const _keyPetPositionX = 'pet_position_x';
  static const _keyPetPositionY = 'pet_position_y';
  static const _keyJustRecordedAt = 'pet_just_recorded_at';
  static const _keyLastStateDate = 'pet_last_state_date';
  static const _keyPetVisible = 'pet_visible';
  static const _keyPetType = 'pet_type';
  static const _keyPetName = 'pet_name';
  static const _keySkipHideConfirm = 'pet_skip_hide_confirm';

  final SharedPreferences _prefs;

  PetStorage(this._prefs);

  int get level => _prefs.getInt(_keyLevel) ?? 1;
  set level(int v) => _prefs.setInt(_keyLevel, v);

  int get exp => _prefs.getInt(_keyExp) ?? 0;
  set exp(int v) => _prefs.setInt(_keyExp, v);

  int get currentStreak => _prefs.getInt(_keyCurrentStreak) ?? 0;
  set currentStreak(int v) => _prefs.setInt(_keyCurrentStreak, v);

  int get longestStreak => _prefs.getInt(_keyLongestStreak) ?? 0;
  set longestStreak(int v) => _prefs.setInt(_keyLongestStreak, v);

  String? get lastInteractDate => _prefs.getString(_keyLastInteractDate);
  set lastInteractDate(String? v) {
    if (v != null) _prefs.setString(_keyLastInteractDate, v);
  }

  int get todayInteractCount => _prefs.getInt(_keyTodayInteractCount) ?? 0;
  set todayInteractCount(int v) => _prefs.setInt(_keyTodayInteractCount, v);

  double get positionX => _prefs.getDouble(_keyPetPositionX) ?? -1;
  set positionX(double v) => _prefs.setDouble(_keyPetPositionX, v);

  double get positionY => _prefs.getDouble(_keyPetPositionY) ?? -1;
  set positionY(double v) => _prefs.setDouble(_keyPetPositionY, v);

  bool checkJustRecorded() {
    final recordTime = _prefs.getInt(_keyJustRecordedAt) ?? 0;
    return DateTime.now().millisecondsSinceEpoch - recordTime < 30 * 60 * 1000;
  }

  void markJustRecorded() {
    _prefs.setInt(_keyJustRecordedAt, DateTime.now().millisecondsSinceEpoch);
  }

  String? get lastStateDate => _prefs.getString(_keyLastStateDate);
  set lastStateDate(String? v) {
    if (v != null) _prefs.setString(_keyLastStateDate, v);
  }

  bool needsDailyReset() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final saved = lastStateDate;
    if (saved == null || saved != today) {
      lastStateDate = today;
      return true;
    }
    return false;
  }

  bool get petVisible => _prefs.getBool(_keyPetVisible) ?? true;
  set petVisible(bool v) => _prefs.setBool(_keyPetVisible, v);

  String get petType => _prefs.getString(_keyPetType) ?? 'cat';
  set petType(String v) => _prefs.setString(_keyPetType, v);

  String get petName => _prefs.getString(_keyPetName) ?? '桌宠一';
  set petName(String v) => _prefs.setString(_keyPetName, v);

  bool get skipHideConfirm => _prefs.getBool(_keySkipHideConfirm) ?? false;
  set skipHideConfirm(bool v) => _prefs.setBool(_keySkipHideConfirm, v);

  void addExp(int amount) {
    final newExp = exp + amount;
    final currentLevel = level;
    final newLevel = _calcLevel(newExp);
    exp = newExp;
    if (newLevel > currentLevel) {
      level = newLevel;
    }
  }

  static int _calcLevel(int totalExp) {
    const thresholds = [0, 50, 150, 300, 500, 750, 1050, 1400, 1800, 2300];
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (totalExp >= thresholds[i]) return i + 1;
    }
    return 1;
  }

  static int expForLevel(int lv) {
    const thresholds = [0, 50, 150, 300, 500, 750, 1050, 1400, 1800, 2300];
    if (lv < 1 || lv > thresholds.length) return 0;
    return thresholds[lv - 1];
  }

  static const levelNames = [
    '初来乍到',
    '渐入佳境',
    '营养学徒',
    '饮食达人',
    '营养专家',
    '健康卫士',
    '营养大师',
    '饮食贤者',
    '健康守护者',
    '营养之神',
  ];

  String get levelName {
    final lv = level;
    if (lv < 1 || lv > levelNames.length) return '初来乍到';
    return levelNames[lv - 1];
  }

  bool tryInteract() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastInteractDate != today) {
      lastInteractDate = today;
      todayInteractCount = 0;
    }
    if (todayInteractCount >= 3) return false;
    todayInteractCount = todayInteractCount + 1;
    addExp(1);
    return true;
  }
}
