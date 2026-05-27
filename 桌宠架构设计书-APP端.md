# DietAI 桌宠架构设计书（APP 端 - Flutter）

> 基于三花小猫形象，为 DietAI Flutter APP 设计营养主题桌宠系统
> 
> 技术路线：预生成 GIF 动画 + Flutter 动画特效叠加，GIF 随饮食数据切换

## 一、设计目标

将三花小猫作为桌宠形象，通过 7 个预生成 GIF 动画覆盖全部状态，根据用户每日饮食数据自动切换 GIF 和对话文案，提升用户粘性和饮食管理趣味性。

---

## 二、形象设计

### 2.1 形象来源

参考 `三花小猫.jpg`，经 AI 视频生成工具制作各状态动画，再转为 GIF。

### 2.2 形象要素（Q版无爪圆猫）

```
├── 身体：圆形白底 + 橙色斑块（左侧）+ 黑色斑块（右侧）
│   ├── 肥胖：圆球膨胀，横向撑开
│   ├── 自然：标准圆形
│   └── 饥饿：椭圆干瘪
├── 姿态：站立 / 倒下
├── 耳朵：三角耳 × 2（左橙右黑，内耳粉色）
│   ├── 竖起 / 飞机耳 / 耷拉
├── 尾巴：橙+黑+白三段
│   ├── 上翘 / 下垂 / 摇摆 / 蓬起 / 瘫软
├── 面部：蓝色大眼 + 粉色三角鼻 + W形嘴 + 6根胡须
└── 无四肢：纯圆形身体
```

### 2.3 GIF 素材

#### 素材列表

| 文件名 | 状态 | 建议尺寸 | 建议大小 |
|--------|------|---------|---------|
| calm.gif | 自然/平静 | 200×200px | ≤150KB |
| happy.gif | 自然/开心 | 200×200px | ≤150KB |
| satisfied.gif | 肥胖/满足 | 200×200px | ≤150KB |
| anxious.gif | 肥胖/焦虑 | 200×200px | ≤150KB |
| expect.gif | 饥饿/期待 | 200×200px | ≤150KB |
| weak.gif | 饥饿/虚弱 | 200×200px | ≤150KB |
| hungry.gif | 饥饿/饥饿 | 200×200px | ≤150KB |

> **APP 端优势**：Flutter APP 无 2MB 包体积限制，GIF 可使用更高分辨率（200px）和更多颜色，画质优于小程序端。

#### 存放路径

```
frontend_flutter/
└── assets/
    └── pet/
        ├── calm.gif
        ├── happy.gif
        ├── satisfied.gif
        ├── anxious.gif
        ├── expect.gif
        ├── weak.gif
        └── hungry.gif
```

#### pubspec.yaml 注册

```yaml
flutter:
  assets:
    - assets/pet/
```

---

## 三、状态系统设计

### 3.1 状态 → GIF 映射（7 状态）

每个 GIF 已包含该状态的全部视觉元素（体型 + 姿态 + 耳朵 + 尾巴 + 表情 + 特效），切换 GIF 即可切换完整状态。

#### 状态判断条件（完整逻辑）

核心公式：`R = consumed / target`（已摄入卡路里 / 目标卡路里）

| 优先级 | 条件 | 区间 | 状态 | GIF | 对话文案基调 |
|--------|------|------|------|-----|------------|
| 1 | R > 1.5 | 肥胖 | anxious（焦虑） | anxious.gif | 担心吃多 |
| 2 | R > 1.2 且刚记录饮食 | 肥胖 | satisfied（满足） | satisfied.gif | 吃饱满足 |
| 3 | R > 1.2（其他） | 肥胖 | satisfied（满足） | satisfied.gif | 吃饱满足 |
| 4 | 0.8 ≤ R ≤ 1.0 | 自然 | happy（开心） | happy.gif | 心情愉悦 |
| 5 | 0.5 ≤ R < 0.8 或 1.0 < R ≤ 1.2 | 自然 | calm（平静） | calm.gif | 日常提醒 |
| 6 | R < 0.5 且当天无任何记录 | 饥饿 | weak（虚弱） | weak.gif | 虚弱无力 |
| 7 | R < 0.5 且在饭点(11-13/17-19点) | 饥饿 | expect（期待） | expect.gif | 想吃东西 |
| 8 | R < 0.5（其他） | 饥饿 | hungry（饥饿） | hungry.gif | 肚子饿 |

**参数说明**：
- `justRecorded`：30 分钟内刚完成饮食记录（时效窗口，通过 `SharedPreferences` 存储时间戳判断）
- `noRecordToday`：当天 `consumed == 0`
- "饭点"：11:00-13:00 或 17:00-19:00
- 状态切换防抖：同状态 5 分钟内不重复计算

#### 状态切换伪代码

```dart
// lib/features/pet/domain/pet_state_calculator.dart

enum PetExpression { satisfied, anxious, happy, calm, expect, weak, hungry }

class PetStateResult {
  final PetExpression expression;
  final String gifPath;
  final String dialogue;
  
  PetStateResult({required this.expression, required this.gifPath, required this.dialogue});
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
    if (justRecorded)      expression = PetExpression.satisfied;
    else if (ratio > 1.5)  expression = PetExpression.anxious;
    else                   expression = PetExpression.satisfied;
  } else if (ratio >= 0.5) {
    if (ratio >= 0.8 && ratio <= 1.0) expression = PetExpression.happy;
    else                               expression = PetExpression.calm;
  } else {
    if (noRecordToday)      expression = PetExpression.weak;
    else if ((hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19))
                             expression = PetExpression.expect;
    else                     expression = PetExpression.hungry;
  }

  return PetStateResult(
    expression: expression,
    gifPath: 'assets/pet/${expression.name}.gif',
    dialogue: pickDialogue(expression),
  );
}
```

### 3.2 状态计算流程

```
FoodService.getDailySummary()
HealthGoalsService.getHealthGoals()
              │
              ▼
┌──────────────┐
│ R = consumed / target │
└──────┬───────┘
       │
  ┌────┼────┐
  ▼    ▼    ▼
R>1.2  0.5≤R≤1.2  R<0.5
肥胖    自然      饥饿
  │      │        │
  ├─刚记录? → satisfied    ├─0.8≤R≤1.0? → happy   ├─整天未记录? → weak
  ├─R>1.5?  → anxious      └─其他       → calm     ├─饭点前后?   → expect
  └─其他    → satisfied                              └─其他        → hungry
       │                    │                          │
       ▼                    ▼                          ▼
  satisfied.gif        calm.gif/happy.gif       weak.gif/expect.gif/hungry.gif
```

### 3.3 跨天重置

每天 0 点后首次进入页面时，状态自动重置为 calm，清除 `justRecorded` 标记。

---

## 四、组件架构

### 4.1 文件结构

```
frontend_flutter/
├── assets/
│   └── pet/                                    # 桌宠 GIF 素材（7 个）
├── lib/
│   ├── features/
│   │   └── pet/
│   │       ├── domain/
│   │       │   ├── pet_state_calculator.dart   # 状态计算（纯函数）
│   │       │   └── pet_dialogues.dart          # 对话文案库
│   │       ├── presentation/
│   │       │   ├── widgets/
│   │       │   │   ├── pet_widget.dart         # 桌宠主组件
│   │       │   │   └── pet_bubble.dart         # 对话气泡组件
│   │       │   └── providers/
│   │       │       └── pet_provider.dart        # Riverpod 状态管理
│   │       └── data/
│   │           └── pet_storage.dart             # 本地存储（SharedPreferences）
│   ├── features/
│   │   └── home/
│   │       └── presentation/
│   │           └── pages/
│   │               └── home_page.dart           # 首页集成
```

### 4.2 桌宠组件接口

```dart
// lib/features/pet/presentation/widgets/pet_widget.dart

class PetWidget extends ConsumerStatefulWidget {
  final double consumed;
  final double target;
  final bool justRecorded;
  final int hour;
  final double size;          // 宽高（px），默认 128
  final bool draggable;       // 是否可拖拽，默认 true
  final bool showBubble;      // 是否显示对话气泡，默认 true

  const PetWidget({
    super.key,
    required this.consumed,
    required this.target,
    this.justRecorded = false,
    this.hour = 12,
    this.size = 128,
    this.draggable = true,
    this.showBubble = true,
  });

  @override
  ConsumerState<PetWidget> createState() => _PetWidgetState();
}
```

### 4.3 状态管理（Riverpod）

```dart
// lib/features/pet/presentation/providers/pet_provider.dart

@riverpod
class PetState extends _$PetState {
  @override
  PetStateResult build() => PetStateResult(
    expression: PetExpression.calm,
    gifPath: 'assets/pet/calm.gif',
    dialogue: '喵~',
  );

  void updateState({
    required double consumed,
    required double target,
    required bool justRecorded,
    required bool noRecordToday,
    required int hour,
  }) {
    state = computePetState(
      consumed: consumed,
      target: target,
      justRecorded: justRecorded,
      noRecordToday: noRecordToday,
      hour: hour,
    );
  }
}
```

### 4.4 对话文案库

```dart
// lib/features/pet/domain/pet_dialogues.dart

const Map<PetExpression, List<String>> kDialogues = {
  PetExpression.satisfied: ['吃得好饱~摸摸肚子~', '今天的饭真好吃！', '喵~好满足~'],
  PetExpression.anxious:   ['好像吃太多了...', '我感觉自己变圆了...', '要不要出去运动一下？'],
  PetExpression.happy:     ['今天吃得很棒哦！', '营养均衡，继续保持~', '喵~完美的一天！'],
  PetExpression.calm:      ['今天也要好好吃饭哦', '记得记录饮食~', '喵~'],
  PetExpression.expect:    ['快到饭点了吗？', '好香的味道...', '喵...想吃东西'],
  PetExpression.weak:      ['好饿...还没吃东西...', '记得按时吃饭哦...', '喵...'],
  PetExpression.hungry:    ['肚子饿了...', '该吃饭啦！', '喵~想吃东西'],
};

String pickDialogue(PetExpression expression) {
  final pool = kDialogues[expression] ?? ['喵~'];
  return pool[DateTime.now().millisecond % pool.length];
}
```

---

## 五、UI 层动画（Flutter）

以下动画作用于 GIF 之外的 UI 层——GIF 本身不参与 transform（体型变化已在 GIF 内容中固定）。

### 5.1 GIF 切换过渡

```dart
// AnimatedSwitcher 实现淡入淡出
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Image.asset(
    currentGif,
    key: ValueKey(currentGif),
    width: widget.size,
    height: widget.size,
  ),
)
```

### 5.2 点击反馈

```dart
// 弹跳动画
void _onTapPet() {
  _bounceController.forward().then((_) => _bounceController.reverse());
}

// 使用 ScaleTransition
ScaleTransition(
  scale: Tween<double>(begin: 1.0, end: 1.1).animate(
    CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
  ),
  child: Image.asset(currentGif),
)
```

### 5.3 对话气泡

```dart
// FadeTransition + SlideTransition
AnimatedOpacity(
  opacity: _bubbleVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: SlideTransition(
    position: _slideAnimation,
    child: PetBubble(text: _bubbleText),
  ),
)
```

气泡显示 3 秒后自动消失。每 2.5 分钟随机弹出一次（仅 calm/happy 状态）。

---

## 六、数据流设计

### 6.1 整体数据流

```
后端 /api/goals/daily-status  →  { daily_targets, today_consumed }
后端 /api/foods/daily-summary  →  { total_calories, ... }
              │
        Dio HTTP
              │
              ▼
FoodService / HealthGoalsService
  │ getDailySummary() / getHealthGoals()
  │ 计算 justRecorded（30min 时效窗口）
  │ 计算 noRecordToday
  │
  ▼ 传入组件
PetWidget(
  consumed: currentCalories,
  target: targetCalories,
  justRecorded: justRecorded,
  hour: currentHour,
)
  │
  ▼
PetProvider.updateState()
  │ computePetState()
  │
  ▼ 渲染
Image.asset(currentGif) + PetBubble
```

### 6.2 数据刷新时机

| 时机 | 方式 | 说明 |
|------|------|------|
| 页面显示 | `WidgetsBindingObserver.didChangeAppLifecycleState` | 从后台切回前台时刷新 |
| 记录饮食后 | 回调 `onRecordComplete` | camera 页返回时触发 |
| 定时轮询 | `Timer.periodic` 5min | 后台保持数据同步 |
| 0 点重置 | 检测日期变化 | 清除标记，状态回 calm |

### 6.3 justRecorded 时效管理

```dart
// 记录饮食时
await SharedPreferences.getInstance().then((prefs) {
  prefs.setInt('petJustRecordedAt', DateTime.now().millisecondsSinceEpoch);
});

// 计算状态时
bool checkJustRecorded() {
  final recordTime = prefs.getInt('petJustRecordedAt') ?? 0;
  return DateTime.now().millisecondsSinceEpoch - recordTime < 30 * 60 * 1000;
}
```

---

## 七、页面集成方案

### 7.1 首页集成

在 `home_page.dart` 的卡路里卡片下方插入桌宠组件：

```dart
// 在 _buildCalorieCard 之后
PetWidget(
  consumed: currentCalories,
  target: _targetCalories,
  justRecorded: _justRecorded,
  hour: DateTime.now().hour,
  size: 128,
  draggable: true,
),
```

### 7.2 健康页集成

```dart
PetWidget(
  consumed: consumedCalories,
  target: targetCalories,
  size: 80,
  draggable: false,
  showBubble: false,
),
```

### 7.3 悬浮定位

桌宠使用 `Positioned` + `Stack` 实现全局悬浮，初始位置左下角：

```dart
Stack(
  children: [
    // 原有页面内容
    OriginalContent(),
    
    // 悬浮桌宠
    if (showPet)
      Positioned(
        left: petLeft,
        top: petTop,
        child: GestureDetector(
          onPanUpdate: _onDragUpdate,
          onPanEnd: _onDragEnd,
          onTap: _onTapPet,
          child: PetWidget(...),
        ),
      ),
  ],
)
```

---

## 八、成长系统设计

### 8.1 等级体系

| 等级 | 所需经验 | 称号 |
|------|---------|------|
| 1 | 0 | 小奶猫 |
| 2 | 50 | 贪吃猫 |
| 3 | 150 | 营养学徒 |
| 4 | 300 | 饮食达人 |
| 5 | 500 | 营养专家 |
| 6 | 750 | 健康卫士 |
| 7 | 1050 | 营养大师 |
| 8 | 1400 | 饮食贤者 |
| 9 | 1800 | 健康守护者 |
| 10 | 2300 | 营养之神 |

> GIF 路线下，等级外观变化通过 GIF 上层叠加装饰图标实现（项圈/铃铛/披风/皇冠等），而非修改 GIF 本身。

### 8.2 经验获取

| 行为 | 经验 | 限制 |
|------|------|------|
| 每日首次记录饮食 | +5 | 每天 1 次 |
| 达标（80%-100%） | +10 | 每天 1 次 |
| 连续达标 7 天 | +30 | 周奖励 |
| 连续达标 30 天 | +100 | 月奖励 |
| 点击互动 | +1 | 每天最多 3 次 |

### 8.3 存储结构

```dart
// lib/features/pet/data/pet_storage.dart

class PetStorage {
  static const _keyLevel = 'pet_level';
  static const _keyExp = 'pet_exp';
  static const _keyCurrentStreak = 'pet_current_streak';
  static const _keyLongestStreak = 'pet_longest_streak';
  static const _keyLastInteractDate = 'pet_last_interact_date';
  static const _keyTodayInteractCount = 'pet_today_interact_count';
  static const _keyPetPositionX = 'pet_position_x';
  static const _keyPetPositionY = 'pet_position_y';

  // 使用 SharedPreferences 存储
  final SharedPreferences _prefs;
  
  // ... get/set 方法
}
```

---

## 九、开发流程

### 第一阶段：GIF 素材 + 基础状态联动

```
步骤 1: GIF 素材准备
  └── 将 7 个 GIF 放到 assets/pet/
  └── 在 pubspec.yaml 注册 assets

步骤 2: 创建状态计算模块
  └── pet_state_calculator.dart（computePetState 函数）
  └── pet_dialogues.dart（对话文案库）

步骤 3: 创建桌宠组件
  └── PetWidget（GIF 显示 + AnimatedSwitcher + 对话气泡）
  └── PetBubble（气泡组件）

步骤 4: 首页集成
  └── home_page.dart 插入 PetWidget
  └── 传入 consumed / target / justRecorded / hour
```

### 第二阶段：交互

```
步骤 5: 点击互动 + 对话气泡
步骤 6: 记录饮食后触发状态更新（justRecorded 标记）
步骤 7: 拖拽移动（GestureDetector + Positioned）
步骤 8: 定时弹出对话气泡（Timer.periodic）
```

### 第三阶段：成长系统

```
步骤 9: 经验/等级数据管理（PetStorage + SharedPreferences）
步骤 10: 升级动画 + 外观装饰叠加（Stack + Positioned 装饰图标）
步骤 11: 桌宠详情页
```

---

## 十、文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新增 | `assets/pet/*.gif` | 7 个 GIF 素材 |
| 修改 | `pubspec.yaml` | 注册 assets/pet/ 目录 |
| 新增 | `lib/features/pet/domain/pet_state_calculator.dart` | 状态计算 |
| 新增 | `lib/features/pet/domain/pet_dialogues.dart` | 对话文案 |
| 新增 | `lib/features/pet/presentation/widgets/pet_widget.dart` | 桌宠主组件 |
| 新增 | `lib/features/pet/presentation/widgets/pet_bubble.dart` | 气泡组件 |
| 新增 | `lib/features/pet/presentation/providers/pet_provider.dart` | Riverpod 状态 |
| 新增 | `lib/features/pet/data/pet_storage.dart` | 本地存储 |
| 修改 | `lib/features/home/presentation/pages/home_page.dart` | 集成桌宠 |

---

## 十一、APP 端特有优势

1. **无包体积限制**：GIF 可使用 200px 分辨率、256 色，画质远优于小程序端
2. **Lottie 支持**：项目已集成 `lottie: ^3.0.0`，未来可将 GIF 替换为 Lottie 动画，实现更精细的交互控制
3. **更丰富的动画**：Flutter 的 AnimationController 支持更复杂的动画效果（弹性、弹簧等）
4. **全屏悬浮**：APP 端可轻松实现全局悬浮桌宠（Overlay），不局限于单个页面
5. **本地存储更灵活**：SharedPreferences + FlutterSecureStorage，无需担心小程序 10MB 限制

---

## 十二、风险与注意事项

1. **GIF 透明度**：白色边缘在非白背景下会显白边。建议使用透明底 GIF 或统一页面背景色。
2. **GIF 是固定循环**：无法参数化体型。如需细分，后续可增加更多 GIF 或迁移到 Lottie。
3. **状态防抖**：同状态 5 分钟内不重复计算，避免饮食记录瞬间频繁切换。
4. **跨天重置**：0 点后首次显示强制重置状态。
5. **性能**：GIF 播放使用 Flutter 内置解码器，在低端设备上可能占用较多 CPU。如遇性能问题，考虑使用 Lottie 替代。
