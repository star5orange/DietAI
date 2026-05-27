# DietAI 桌宠功能计划书（APP 端 - Flutter）

## 一、功能概述

在 DietAI Flutter APP 中实现一个营养主题的桌宠（虚拟宠物），它以拟人化的方式陪伴用户完成每日饮食管理。桌宠会根据用户的饮食数据、目标完成情况展现不同状态和互动，提升用户粘性和使用趣味性。

## 二、核心设计

### 2.1 桌宠形象

- 采用预生成 GIF 动画方案，7 个状态对应 7 个 GIF 文件
- 基础形象：Q版无爪三花小猫（圆形身体 + 三色斑块 + 尾巴 + 耳朵 + 表情）
- **核心特色：不同状态对应完全不同的 GIF 动画**，包含体型、姿态、表情、尾巴、耳朵的整体变化
- GIF 切换时使用 AnimatedSwitcher 实现淡入淡出过渡

### 2.2 桌宠状态系统（7 状态 GIF 驱动）

桌宠有 7 种状态，每种状态对应一个独立的 GIF 动画，直观反映用户当天的饮食情况：

#### 状态判断条件

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
- `justRecorded`：30 分钟内刚完成饮食记录（通过 SharedPreferences 存储时间戳判断）
- `noRecordToday`：当天 `consumed == 0`
- "饭点"：11:00-13:00 或 17:00-19:00
- 状态切换防抖：同状态 5 分钟内不重复计算

#### GIF 素材规格

| 状态 | GIF 文件名 | 建议尺寸 | 建议大小 |
|------|-----------|---------|---------|
| 平静 | calm.gif | 200×200px | ≤150KB |
| 开心 | happy.gif | 200×200px | ≤150KB |
| 满足 | satisfied.gif | 200×200px | ≤150KB |
| 焦虑 | anxious.gif | 200×200px | ≤150KB |
| 期待 | expect.gif | 200×200px | ≤150KB |
| 虚弱 | weak.gif | 200×200px | ≤150KB |
| 饥饿 | hungry.gif | 200×200px | ≤150KB |

> APP 端无 2MB 包体积限制，GIF 可使用更高分辨率和更多颜色。

### 2.3 互动功能

1. **点击互动**：点击桌宠弹出对话气泡，显示营养小贴士或鼓励语，同时触发弹跳动画
2. **拖拽移动**：长按拖拽桌宠到屏幕任意位置，松手后记忆位置（SharedPreferences）
3. **对话气泡**：每 2.5 分钟自动弹出一次（仅 calm/happy 状态），3 秒后自动消失
4. **成长等级**：根据互动和达标情况获取经验值，桌宠升级（外观叠加装饰）

## 三、技术方案

### 3.1 项目结构

```
lib/features/pet/
  ├── domain/
  │   ├── pet_state_calculator.dart    # 状态计算（纯函数）
  │   └── pet_dialogues.dart           # 对话文案库
  ├── presentation/
  │   ├── widgets/
  │   │   ├── pet_widget.dart          # 桌宠主组件
  │   │   └── pet_bubble.dart          # 对话气泡组件
  │   └── providers/
  │       └── pet_provider.dart         # Riverpod 状态管理
  └── data/
      └── pet_storage.dart              # 本地存储

assets/pet/
  ├── calm.gif
  ├── happy.gif
  ├── satisfied.gif
  ├── anxious.gif
  ├── expect.gif
  ├── weak.gif
  └── hungry.gif
```

### 3.2 关键技术选型

| 技术点 | 方案 |
|--------|------|
| 状态管理 | Riverpod（项目已使用 flutter_riverpod） |
| GIF 播放 | Flutter 内置 Image.asset（原生支持 GIF） |
| 切换过渡 | AnimatedSwitcher（淡入淡出） |
| 点击反馈 | AnimationController + ScaleTransition（弹跳） |
| 对话气泡 | AnimatedOpacity + SlideTransition |
| 拖拽定位 | GestureDetector + Positioned（全局悬浮） |
| 状态计算 | 纯函数 computePetState() |
| 本地存储 | SharedPreferences（项目已使用 shared_preferences） |
| 定时弹出 | Timer.periodic |
| 路由 | go_router（项目已使用） |

### 3.3 数据流

```
用户饮食数据 → FoodService.getDailySummary()
                    ↓
            前端计算桌宠状态（computePetState）
                    ↓
         PetProvider 更新状态 → PetWidget 渲染
                    ↓
         Image.asset(currentGif) + PetBubble
```

### 3.4 对话文案库

```dart
const Map<PetExpression, List<String>> kDialogues = {
  PetExpression.satisfied: ['吃得好饱~摸摸肚子~', '今天的饭真好吃！', '喵~好满足~'],
  PetExpression.anxious:   ['好像吃太多了...', '我感觉自己变圆了...', '要不要出去运动一下？'],
  PetExpression.happy:     ['今天吃得很棒哦！', '营养均衡，继续保持~', '喵~完美的一天！'],
  PetExpression.calm:      ['今天也要好好吃饭哦', '记得记录饮食~', '喵~'],
  PetExpression.expect:    ['快到饭点了吗？', '好香的味道...', '喵...想吃东西'],
  PetExpression.weak:      ['好饿...还没吃东西...', '记得按时吃饭哦...', '喵...'],
  PetExpression.hungry:    ['肚子饿了...', '该吃饭啦！', '喵~想吃东西'],
};
```

## 四、开发阶段

### 第一阶段：GIF 素材 + 基础状态联动

- [ ] 将 7 个 GIF 放入 `assets/pet/` 目录
- [ ] 在 `pubspec.yaml` 注册 assets
- [ ] 创建 `pet_state_calculator.dart`（computePetState 函数 + PetExpression 枚举）
- [ ] 创建 `pet_dialogues.dart`（对话文案库）
- [ ] 创建 `PetWidget` 组件（GIF 显示 + AnimatedSwitcher 切换）
- [ ] 创建 `PetBubble` 组件（对话气泡）
- [ ] 在首页 `home_page.dart` 集成桌宠组件
- [ ] 传入 consumed / target / justRecorded / hour 参数

### 第二阶段：交互

- [ ] 点击互动 + 弹跳动画（AnimationController + ScaleTransition）
- [ ] 对话气泡显示/隐藏（AnimatedOpacity + SlideTransition）
- [ ] 记录饮食后触发状态更新（justRecorded 标记 + SharedPreferences 时间戳）
- [ ] 拖拽移动（GestureDetector.onPanUpdate + Positioned）
- [ ] 拖拽边界限制（不超出屏幕）
- [ ] 位置记忆（SharedPreferences 存储 pet_position_x/y）
- [ ] 定时弹出对话气泡（Timer.periodic 2.5 分钟）
- [ ] 初始位置设为左下角

### 第三阶段：成长系统

- [ ] 经验/等级数据管理（PetStorage + SharedPreferences）
- [ ] 等级体系（1-10 级，经验表）
- [ ] 互动经验（点击 +1，每天最多 3 次）
- [ ] 饮食记录经验（首次记录 +5，达标 +10）
- [ ] 升级动画（SnackBar 或自定义弹窗）
- [ ] 等级外观装饰叠加（Stack + Positioned 装饰图标）
- [ ] 桌宠详情页（pet_detail_page.dart）

## 五、文件变更预估

| 操作 | 文件 | 说明 |
|------|------|------|
| 新增 | `assets/pet/*.gif` | 7 个 GIF 素材 |
| 修改 | `pubspec.yaml` | 注册 assets/pet/ |
| 新增 | `lib/features/pet/domain/pet_state_calculator.dart` | 状态计算 |
| 新增 | `lib/features/pet/domain/pet_dialogues.dart` | 对话文案 |
| 新增 | `lib/features/pet/presentation/widgets/pet_widget.dart` | 桌宠主组件 |
| 新增 | `lib/features/pet/presentation/widgets/pet_bubble.dart` | 气泡组件 |
| 新增 | `lib/features/pet/presentation/providers/pet_provider.dart` | Riverpod 状态 |
| 新增 | `lib/features/pet/data/pet_storage.dart` | 本地存储 |
| 修改 | `lib/features/home/presentation/pages/home_page.dart` | 集成桌宠 |
| 新增 | `lib/features/pet/presentation/pages/pet_detail_page.dart` | 详情页（第三阶段） |

## 六、APP 端 vs 小程序端差异

| 对比项 | 小程序端 | APP 端（Flutter） |
|--------|---------|------------------|
| 包体积限制 | 2MB | 无硬性限制 |
| GIF 分辨率 | 128-160px | 200px+ |
| GIF 颜色 | 64-128 色 | 256 色 |
| 状态管理 | 组件 data + observers | Riverpod |
| 动画方案 | CSS @keyframes | AnimationController + Transition |
| 拖拽实现 | touch 事件 + transform | GestureDetector + Positioned |
| 本地存储 | wx.setStorageSync | SharedPreferences |
| GIF 播放 | `<image>` 原生支持 | Image.asset 原生支持 |
| 全局悬浮 | position: fixed | Stack + Positioned / Overlay |
| 未来扩展 | 受限 | 可迁移到 Lottie 动画 |

## 七、注意事项

1. **性能**：GIF 播放在低端设备可能占用较多 CPU，如遇性能问题考虑迁移到 Lottie（项目已集成 lottie 依赖）
2. **GIF 透明度**：建议使用透明底 GIF，避免白边问题
3. **状态防抖**：同状态 5 分钟内不重复计算
4. **跨天重置**：0 点后首次显示强制重置状态
5. **拖拽边界**：桌宠不能拖出屏幕边界
6. **初始位置**：左下角，留出底部导航栏空间
