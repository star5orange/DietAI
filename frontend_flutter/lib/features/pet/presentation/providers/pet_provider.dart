import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/pet_state_calculator.dart';
import '../../data/pet_storage.dart';
import '../../domain/services/pet_service.dart';

class PetState {
  final PetExpression expression;
  final String gifPath;
  final String dialogue;
  final int level;
  final int exp;
  final int maxExp;
  final String levelName;
  final bool visible;
  final String petType;
  final String petName;
  final int currentStreak;
  final int longestStreak;
  final double foodProgress;
  final double waterProgress;

  const PetState({
    this.expression = PetExpression.calm,
    this.gifPath = 'assets/pet/calm.gif',
    this.dialogue = '嗯~',
    this.level = 1,
    this.exp = 0,
    this.maxExp = 50,
    this.levelName = '初来乍到',
    this.visible = true,
    this.petType = 'cat',
    this.petName = '桌宠一',
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.foodProgress = 0.0,
    this.waterProgress = 0.0,
  });

  PetState copyWith({
    PetExpression? expression,
    String? gifPath,
    String? dialogue,
    int? level,
    int? exp,
    int? maxExp,
    String? levelName,
    bool? visible,
    String? petType,
    String? petName,
    int? currentStreak,
    int? longestStreak,
    double? foodProgress,
    double? waterProgress,
  }) {
    return PetState(
      expression: expression ?? this.expression,
      gifPath: gifPath ?? this.gifPath,
      dialogue: dialogue ?? this.dialogue,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      maxExp: maxExp ?? this.maxExp,
      levelName: levelName ?? this.levelName,
      visible: visible ?? this.visible,
      petType: petType ?? this.petType,
      petName: petName ?? this.petName,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      foodProgress: foodProgress ?? this.foodProgress,
      waterProgress: waterProgress ?? this.waterProgress,
    );
  }
}

class PetNotifier extends StateNotifier<PetState> {
  PetStorage? _storage;
  final PetService _petService = PetService();

  PetNotifier() : super(const PetState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _storage = PetStorage(prefs);

    if (_storage!.needsDailyReset()) {
      state = state.copyWith(
        expression: PetExpression.calm,
        gifPath: 'assets/pet/calm.gif',
        dialogue: '嗯~',
      );
    }

    _syncFromStorage();

    // 从后端同步宠物状态
    _syncFromBackend();
  }

  /// 从后端获取宠物状态并合并到本地
  Future<void> _syncFromBackend() async {
    try {
      final response = await _petService.getPetStatus();
      if (response.success && response.data != null) {
        final data = response.data!;
        state = state.copyWith(
          level: (data['level'] as int?) ?? state.level,
          exp: (data['exp'] as int?) ?? state.exp,
          currentStreak:
              (data['current_streak'] as int?) ?? state.currentStreak,
          longestStreak:
              (data['longest_streak'] as int?) ?? state.longestStreak,
          petType: data['current_skin'] as String? ?? state.petType,
          petName: data['pet_name'] as String? ?? state.petName,
        );
        // 同步到本地存储（levelName 自动由 level 计算）
        _storage?.level = state.level;
        _storage?.exp = state.exp;
        _storage?.currentStreak = state.currentStreak;
        _storage?.longestStreak = state.longestStreak;
      }
    } catch (_) {
      // 后端不可用时继续使用本地数据
    }
  }

  void _syncFromStorage() {
    if (_storage == null) return;
    final currentLevel = _storage!.level;
    state = state.copyWith(
      level: currentLevel,
      exp: _storage!.exp,
      maxExp: _calcMaxExp(currentLevel),
      levelName: _storage!.levelName,
      visible: _storage!.petVisible,
      petType: _storage!.petType,
      petName: _storage!.petName,
      currentStreak: _storage!.currentStreak,
      longestStreak: _storage!.longestStreak,
    );
  }

  /// 计算当前等级所需的最大经验值
  static int _calcMaxExp(int level) {
    const thresholds = [0, 50, 150, 300, 500, 750, 1050, 1400, 1800, 2300];
    if (level >= thresholds.length) return thresholds.last;
    return thresholds[level]; // thresholds[lv] = next level's required exp
  }

  void updateState({
    required double consumed,
    required double target,
    required bool noRecordToday,
  }) {
    if (_storage == null) return;

    final result = computePetState(
      consumed: consumed,
      target: target,
      justRecorded: _storage!.checkJustRecorded(),
      noRecordToday: noRecordToday,
      hour: DateTime.now().hour,
    );

    state = state.copyWith(
      expression: result.expression,
      gifPath: result.gifPath,
      dialogue: result.dialogue,
    );
  }

  void onFoodRecorded() {
    _storage?.markJustRecorded();
  }

  void onTap() {
    if (_storage?.tryInteract() == true) {
      _syncFromStorage();
      state = state.copyWith(
        dialogue: pickDialogue(state.expression),
      );
    }
  }

  void addExp(int amount) {
    _storage?.addExp(amount);
    _syncFromStorage();
    // 同步到后端
    _petService.addPetExp(amount);
  }

  void setPetVisible(bool visible) {
    _storage?.petVisible = visible;
    if (visible) {
      _storage?.positionX = -1;
      _storage?.positionY = -1;
    }
    state = state.copyWith(visible: visible);
    _petService.setPetVisible(visible);
  }

  void setPetType(String petType) {
    _storage?.petType = petType;
    state = state.copyWith(petType: petType);
    _petService.setPetType(petType);
  }

  void setPetName(String petName) {
    _storage?.petName = petName;
    state = state.copyWith(petName: petName);
    _petService.setPetName(petName);
  }

  void updateFoodProgress(double progress) {
    state = state.copyWith(foodProgress: progress);
  }

  void updateWaterProgress(double progress) {
    state = state.copyWith(waterProgress: progress);
  }

  PetStorage? get storage => _storage;
}

final petProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  final notifier = PetNotifier();
  notifier.init();
  return notifier;
});
