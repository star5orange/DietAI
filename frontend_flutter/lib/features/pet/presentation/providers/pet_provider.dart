import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/pet_state_calculator.dart';
import '../../data/pet_storage.dart';
import '../../domain/services/pet_service.dart';
import '../../domain/pet_skin_config.dart'; // 导入桌宠皮肤配置

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
  final Map<String, String> petNames; // 新增：每个桌宠皮肤的独立命名
  final int currentStreak;
  final int longestStreak;
  final double foodProgress;
  final double waterProgress;
  final PetSkin currentSkin; // 新增：当前桌宠皮肤

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
    this.petNames = const {'default': '桌宠一', 'christine': '桌宠二'}, // 默认名称映射
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.foodProgress = 0.0,
    this.waterProgress = 0.0,
    this.currentSkin = PetSkin.defaultPet, // 默认桌宠
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
    Map<String, String>? petNames, // 新增参数
    int? currentStreak,
    int? longestStreak,
    double? foodProgress,
    double? waterProgress,
    PetSkin? currentSkin, // 新增参数
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
      petNames: petNames ?? this.petNames,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      foodProgress: foodProgress ?? this.foodProgress,
      waterProgress: waterProgress ?? this.waterProgress,
      currentSkin: currentSkin ?? this.currentSkin,
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
        final skinKey = data['current_skin'] as String? ?? 'default';

        // 解析 pet_names
        Map<String, String> petNames = {'default': '桌宠一', 'christine': '桌宠二'};
        if (data['pet_names'] != null && data['pet_names'] is Map) {
          final namesMap = data['pet_names'] as Map;
          petNames = namesMap
              .map((key, value) => MapEntry(key.toString(), value.toString()));
        }

        // 获取当前皮肤的名称
        final currentSkin = PetSkin.fromKey(skinKey);
        final currentPetName = petNames[skinKey] ?? currentSkin.defaultName;

        state = state.copyWith(
          level: (data['level'] as int?) ?? state.level,
          exp: (data['exp'] as int?) ?? state.exp,
          currentStreak:
              (data['current_streak'] as int?) ?? state.currentStreak,
          longestStreak:
              (data['longest_streak'] as int?) ?? state.longestStreak,
          petType: skinKey,
          petName: currentPetName,
          petNames: petNames,
          currentSkin: currentSkin,
        );
        // 同步到本地存储（levelName 自动由 level 计算）
        _storage?.level = state.level;
        _storage?.exp = state.exp;
        _storage?.currentStreak = state.currentStreak;
        _storage?.longestStreak = state.longestStreak;
        _storage?.petNames = petNames; // 保存各皮肤命名到本地
      }
    } catch (_) {
      // 后端不可用时继续使用本地数据
    }
  }

  void _syncFromStorage() {
    if (_storage == null) return;
    final currentLevel = _storage!.level;
    final petType = _storage!.petType;
    final currentSkin = PetSkin.fromKey(petType);

    // 从本地存储获取各皮肤命名，并获取当前皮肤的名称
    final petNames = _storage!.petNames;
    final currentPetName = petNames[petType] ?? currentSkin.defaultName;

    state = state.copyWith(
      level: currentLevel,
      exp: _storage!.exp,
      maxExp: _calcMaxExp(currentLevel),
      levelName: _storage!.levelName,
      visible: _storage!.petVisible,
      petType: petType,
      petName: currentPetName,
      petNames: petNames,
      currentSkin: currentSkin, // 从本地存储恢复当前皮肤
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
    final skin = PetSkin.fromKey(petType);
    state = state.copyWith(petType: petType, currentSkin: skin);
    _petService.setPetType(petType);
  }

  /// 设置桌宠皮肤
  void setPetSkin(PetSkin skin) {
    _storage?.petType = skin.key;
    // 切换皮肤时，更新 petName 为对应皮肤的名称
    final newPetName = state.petNames[skin.key] ?? skin.defaultName;
    state = state.copyWith(
      petType: skin.key,
      currentSkin: skin,
      petName: newPetName,
    );
    _petService.setPetType(skin.key);
  }

  /// 设置指定皮肤的名称
  void setPetName(String petName, {PetSkin? skin}) {
    final targetSkin = skin ?? state.currentSkin;
    final newPetNames = Map<String, String>.from(state.petNames);
    newPetNames[targetSkin.key] = petName;

    // 如果是当前皮肤，同时更新 petName
    if (targetSkin == state.currentSkin) {
      state = state.copyWith(
        petName: petName,
        petNames: newPetNames,
      );
    } else {
      state = state.copyWith(petNames: newPetNames);
    }

    // 保存到本地存储
    _storage?.petNames = newPetNames;
    if (targetSkin == state.currentSkin) {
      _storage?.petName = petName;
    }

    // 保存到后端
    _petService.setPetName(petName, skinKey: targetSkin.key);
  }

  /// 获取指定皮肤的名称
  String getPetName(PetSkin skin) {
    return state.petNames[skin.key] ?? skin.defaultName;
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
