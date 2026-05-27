import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/pet_state_calculator.dart';
import '../../data/pet_storage.dart';

class PetState {
  final PetExpression expression;
  final String gifPath;
  final String dialogue;
  final int level;
  final int exp;
  final String levelName;

  const PetState({
    this.expression = PetExpression.calm,
    this.gifPath = 'assets/pet/calm.gif',
    this.dialogue = '喵~',
    this.level = 1,
    this.exp = 0,
    this.levelName = '小奶猫',
  });

  PetState copyWith({
    PetExpression? expression,
    String? gifPath,
    String? dialogue,
    int? level,
    int? exp,
    String? levelName,
  }) {
    return PetState(
      expression: expression ?? this.expression,
      gifPath: gifPath ?? this.gifPath,
      dialogue: dialogue ?? this.dialogue,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      levelName: levelName ?? this.levelName,
    );
  }
}

class PetNotifier extends StateNotifier<PetState> {
  PetStorage? _storage;

  PetNotifier() : super(const PetState());

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _storage = PetStorage(prefs);

    if (_storage!.needsDailyReset()) {
      state = state.copyWith(
        expression: PetExpression.calm,
        gifPath: 'assets/pet/calm.gif',
        dialogue: '喵~',
      );
    }

    _syncFromStorage();
  }

  void _syncFromStorage() {
    if (_storage == null) return;
    state = state.copyWith(
      level: _storage!.level,
      exp: _storage!.exp,
      levelName: _storage!.levelName,
    );
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
  }

  PetStorage? get storage => _storage;
}

final petProvider = StateNotifierProvider<PetNotifier, PetState>((ref) {
  final notifier = PetNotifier();
  notifier.init();
  return notifier;
});
