enum PetExpression { satisfied, anxious, happy, calm, expect, weak, hungry }

class PetStateResult {
  final PetExpression expression;
  final String gifPath;
  final String dialogue;

  PetStateResult({
    required this.expression,
    required this.gifPath,
    required this.dialogue,
  });
}

PetStateResult computePetState({
  required double consumed,
  required double target,
  required bool justRecorded,
  required bool noRecordToday,
  required int hour,
}) {
  final ratio = target > 0 ? consumed / target : 0.0;
  PetExpression expression;

  if (ratio > 1.2) {
    if (justRecorded) {
      expression = PetExpression.satisfied;
    } else if (ratio > 1.5) {
      expression = PetExpression.anxious;
    } else {
      expression = PetExpression.satisfied;
    }
  } else if (ratio >= 0.5) {
    if (ratio >= 0.8 && ratio <= 1.0) {
      expression = PetExpression.happy;
    } else {
      expression = PetExpression.calm;
    }
  } else {
    if (noRecordToday) {
      expression = PetExpression.weak;
    } else if ((hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19)) {
      expression = PetExpression.expect;
    } else {
      expression = PetExpression.hungry;
    }
  }

  return PetStateResult(
    expression: expression,
    gifPath: 'assets/pet/${expression.name}.gif',
    dialogue: pickDialogue(expression),
  );
}

String pickDialogue(PetExpression expression) {
  final pool = kDialogues[expression] ?? ['嗯~'];
  return pool[DateTime.now().millisecond % pool.length];
}

const Map<PetExpression, List<String>> kDialogues = {
  PetExpression.satisfied: ['吃得好饱~摸摸肚子~', '今天的饭真好吃！', '好满足~'],
  PetExpression.anxious: ['好像吃太多了...', '我感觉自己变圆了...', '要不要出去运动一下？'],
  PetExpression.happy: ['今天吃得很棒哦！', '营养均衡，继续保持~', '完美的一天！'],
  PetExpression.calm: ['今天也要好好吃饭哦', '记得记录饮食~', '嗯~'],
  PetExpression.expect: ['快到饭点了吗？', '好香的味道...', '想吃东西...'],
  PetExpression.weak: ['好饿...还没吃东西...', '记得按时吃饭哦...', '...'],
  PetExpression.hungry: ['肚子饿了...', '该吃饭啦！', '想吃东西~'],
};
