# DietAI — UI 设计文档

> **版本**: v1.0  
> **更新日期**: 2026-04-24  
> **设计框架**: Flutter + Material Design 3

---

## 一、设计体系总览

### 1.1 设计原则

| 原则 | 说明 |
| --- | --- |
| 健康感 | 主色调绿色系传达健康活力，数据可视化配色直觉清晰 |
| 简洁高效 | 卡片式布局、圆角设计、最小化视觉噪音 |
| 渐变丰富 | 大量使用线性渐变（品牌渐变、营养素渐变、餐次渐变）增强层次感 |
| 动效友好 | 按钮压缩、卡片悬停、数据环动画、进度条动画，交互反馈自然 |
| 暗色适配 | 完整 Light/Dark 双主题，暗色模式使用 Slate 深色系 |

### 1.2 品牌标识

| 项 | 值 |
| --- | --- |
| 应用名称 | DietAI |
| 应用版本 | 1.0.0 |
| 品牌主色 | `#00C896`（现代绿） |
| 品牌字体 | Plus Jakarta Sans（标题/品牌） |
| 正文字体 | Inter |
| 数字字体 | JetBrains Mono |

---

## 二、色彩系统

### 2.1 品牌色板

| 分类 | Token | Hex | 用途 |
| --- | --- | --- | --- |
| **品牌色** | primary | `#00C896` | 主操作色、选中态、品牌标识 |
| | primaryDark | `#00A578` | 按钮 Hover 态、暗色模式主色 |
| | primaryLight | `#2DD4AA` | 渐变终点、品牌浅色变体 |
| | primaryVariant | `#7FEFDD` | 品牌色彩变体 |
| | primarySurface | `#F0FFFE` | 主色调浅底、卡片高亮背景 |
| | secondary | `#6366F1` | 辅助操作色、标签、链接 |
| | secondaryLight | `#8B5CF6` | 辅助浅色 |
| | accent | `#FF6B6B` | 强调色、操作入口 |

### 2.2 功能色板

| 分类 | Token | Hex | 用途 |
| --- | --- | --- | --- |
| **语义色** | success | `#10B981` | 成功提示、达标状态 |
| | successLight | `#6EE7B7` | 成功背景 |
| | warning | `#F59E0B` | 警告提示、注意事项 |
| | warningLight | `#FDE68A` | 警告背景 |
| | error | `#EF4444` | 错误提示、删除操作 |
| | errorLight | `#FECACA` | 错误背景 |
| | info | `#3B82F6` | 信息提示 |
| | infoLight | `#DCECFE` | 信息背景 |

### 2.3 文字色板

| Token | Hex | 用途 |
| --- | --- | --- |
| textPrimary | `#0F172A` | 正文标题、主要信息 |
| textSecondary | `#475569` | 副标题、描述文字 |
| textTertiary | `#94A3B8` | 辅助信息、时间戳 |
| textHint | `#CBD5E1` | 占位符、禁用文字 |
| textInverse | `#FFFFFF` | 反色文字（深色背景上） |

### 2.4 背景色板

| Token | Hex | 用途 |
| --- | --- | --- |
| background | `#FFFFFF` | 页面主背景 |
| backgroundSecondary | `#F8FAFC` | 输入框背景、次级背景 |
| backgroundTertiary | `#F1F5F9` | 分隔区域背景 |
| backgroundGray | `#F8F9FA` | 灰色背景 |
| backgroundCard | `#FFFFFF` | 卡片背景 |
| backgroundSurface | `#FCFCFD` | 表面背景 |

### 2.5 边框与分隔色板

| Token | Hex | 用途 |
| --- | --- | --- |
| border | `#E2E8F0` | 标准边框 |
| borderLight | `#F1F5F9` | 浅色边框 |
| borderStrong | `#CBD5E1` | 强边框 |
| divider | `#E2E8F0` | 分隔线 |

### 2.6 阴影色板

| Token | 透明度 | 用途 |
| --- | --- | --- |
| shadow | 6% (`#0F000000`) | 基础阴影 |
| shadowLight | 3% (`#08000000`) | 轻阴影 |
| shadowMedium | 8% (`#15000000`) | 中等阴影 |
| shadowStrong | 14% (`#25000000`) | 强阴影 |

### 2.7 营养素色板

| 营养素 | Token | Hex | 渐变 |
| --- | --- | --- | --- |
| 热量 | caloriesColor | `#FF6B6B` | `#FF6B6B` → `#FF8A80` |
| 蛋白质 | proteinColor | `#4ECDC4` | `#4ECDC4` → `#80E5E0` |
| 碳水化合物 | carbsColor | `#FFA726` | `#FFA726` → `#FFCC02` |
| 脂肪 | fatColor | `#AB47BC` | `#AB47BC` → `#CE93D8` |
| 膳食纤维 | fiberColor | `#66BB6A` | — |

### 2.8 餐次色板

| 餐次 | 渐变起点 | 渐变终点 |
| --- | --- | --- |
| 早餐 | `#FFB347` | `#FFCC80` |
| 午餐 | `#42A5F5` | `#90CAF9` |
| 晚餐 | `#9C27B0` | `#BA68C8` |
| 零食 | `#EC407A` | `#F48FB1` |

### 2.9 暗色模式色板

| Token | Hex | 用途 |
| --- | --- | --- |
| darkBackground | `#0F172A` | 页面背景 |
| darkSurface | `#1E293B` | 表面背景 |
| darkCard | `#334155` | 卡片背景 |
| darkBorder | `#475569` | 边框 |
| darkTextPrimary | `#F8FAFC` | 主文字 |
| darkTextSecondary | `#CBD5E1` | 次文字 |

### 2.10 渐变定义

| 名称 | 色值 | 方向 |
| --- | --- | --- |
| primaryGradient | `#00C896` → `#2DD4AA` | 左上 → 右下 |
| secondaryGradient | `#6366F1` → `#8B5CF6` | 左上 → 右下 |
| successGradient | `#10B981` → `#6EE7B7` | 左上 → 右下 |
| backgroundGradient | `#FFFFFF` → `#F8FAFC` | 上 → 下 |
| cardGradient | `#FFFFFF` → `#FBFCFD` | 左上 → 右下 |
| breakfastGradient | `#FFB347` → `#FFCC80` | 左上 → 右下 |
| lunchGradient | `#42A5F5` → `#90CAF9` | 左上 → 右下 |
| dinnerGradient | `#9C27B0` → `#BA68C8` | 左上 → 右下 |
| snackGradient | `#EC407A` → `#F48FB1` | 左上 → 右下 |

### 2.11 透明度工具方法

| 方法 | 说明 |
| --- | --- |
| `AppColors.primaryWithOpacity(0.1)` | 主色 + 透明度，用于选中背景 |
| `AppColors.secondaryWithOpacity(0.1)` | 辅色 + 透明度 |
| `AppColors.blackWithOpacity(0.08)` | 黑色透明度，用于阴影 |
| `AppColors.whiteWithOpacity(0.1)` | 白色透明度，用于毛玻璃效果 |

---

## 三、排版系统

### 3.1 字体规格

| 用途 | 字体族 | 字号(px) | 字重 | 行高 | 字间距 | 颜色 |
| --- | --- | --- | --- | --- | --- | --- |
| **Display Large** | Plus Jakarta Sans | 64 | w800 | 1.1 | -0.02 | textPrimary |
| **Display Medium** | Plus Jakarta Sans | 48 | w700 | 1.15 | -0.015 | textPrimary |
| **Display Small** | Plus Jakarta Sans | 36 | w600 | 1.2 | -0.01 | textPrimary |
| **Headline Large** | Inter | 32 | w700 | 1.25 | -0.01 | textPrimary |
| **Headline Medium** | Inter | 28 | w600 | 1.3 | -0.005 | textPrimary |
| **Headline Small** | Inter | 24 | w600 | 1.35 | — | textPrimary |
| **H1** | Inter | 32 | w800 | 1.2 | -0.01 | textPrimary |
| **H2** | Inter | 28 | w700 | 1.25 | -0.005 | textPrimary |
| **H3** | Inter | 24 | w600 | 1.3 | — | textPrimary |
| **H4** | Inter | 20 | w600 | 1.35 | — | textPrimary |
| **H5** | Inter | 18 | w500 | 1.4 | — | textPrimary |
| **H6** | Inter | 16 | w500 | 1.45 | — | textPrimary |
| **Body Large** | Inter | 16 | w400 | 1.6 | 0.01 | textPrimary |
| **Body Medium** | Inter | 14 | w400 | 1.5 | 0.005 | textPrimary |
| **Body Small** | Inter | 12 | w400 | 1.4 | — | textSecondary |
| **Body XSmall** | Inter | 10 | w400 | 1.4 | — | textTertiary |
| **Label Large** | Inter | 14 | w600 | 1.3 | 0.1 | textPrimary |
| **Label Medium** | Inter | 12 | w500 | 1.3 | 0.08 | textSecondary |
| **Label Small** | Inter | 10 | w500 | 1.3 | 0.08 | textTertiary |
| **Button Large** | Inter | 16 | w600 | 1.25 | 0.02 | textInverse |
| **Button Medium** | Inter | 14 | w500 | 1.3 | 0.01 | textInverse |
| **Button Small** | Inter | 12 | w500 | 1.3 | 0.01 | textInverse |
| **Number Large** | JetBrains Mono | 32 | w700 | 1.1 | -0.01 | primary |
| **Number Medium** | JetBrains Mono | 24 | w600 | 1.2 | — | primary |
| **Number Small** | JetBrains Mono | 18 | w500 | 1.3 | — | primary |
| **Number XSmall** | JetBrains Mono | 14 | w500 | 1.3 | — | textSecondary |
| **Caption** | Inter | 12 | w400 | 1.3 | 0.05 | textSecondary |
| **Overline** | Inter | 10 | w600 | 1.6 | 1.5 | textTertiary |
| **Brand** | Plus Jakarta Sans | 24 | w800 | 1.2 | -0.01 | primary |
| **Price** | JetBrains Mono | 20 | w600 | 1.2 | — | textPrimary |
| **Tag** | Inter | 10 | w600 | 1.2 | 0.1 | textInverse |
| **Badge** | Inter | 11 | w600 | 1.2 | 0.05 | textInverse |
| **Input Text** | Inter | 16 | w400 | 1.5 | 0.005 | textPrimary |
| **Input Hint** | Inter | 16 | w400 | 1.5 | 0.005 | textHint |
| **Input Label** | Inter | 14 | w500 | 1.3 | 0.01 | textSecondary |

### 3.2 语义文字色

| 样式 | 颜色 |
| --- | --- |
| success | `#10B981` |
| warning | `#F59E0B` |
| error | `#EF4444` |
| info | `#3B82F6` |

### 3.3 响应式字号缩放

| 屏幕宽度 | 缩放因子 |
| --- | --- |
| < 360px | ×0.9 |
| 360–600px | ×1.0 |
| > 600px | ×1.1 |

---

## 四、组件规范

### 4.1 按钮

#### AppButton

| 属性 | 说明 |
| --- | --- |
| 变体 | primary / secondary / outline / ghost |
| 尺寸 | small(12×8) / medium(16×12) / large(24×16) |
| 圆角 | small:8 / medium:12 / large:16 |
| 按压动画 | 缩放 1.0→0.95, 150ms, easeInOut |
| 主色光晕 | primary 变体按压时 0→0.3 透明度光晕 |
| 加载态 | 显示 spinner + "加载中..." |

#### ModernButton

| 属性 | 说明 |
| --- | --- |
| 变体 | primary / secondary / outline / ghost / gradient |
| 尺寸 | small(16×8) / medium(24×12) / large(32×16) / extraLarge(40×20) |
| 形状 | rounded(与尺寸匹配) / pill(50px) / square(0px) |
| 动效 | 缩放 1.0→0.95 / 微光扫过(gradient悬停) / 脉冲(1.0→1.1重复) |
| 渐变 | 默认使用 primaryGradient |
| 阴影 | showShadow=true 时展示组件阴影 |

#### ModernIconButton

| 属性 | 说明 |
| --- | --- |
| 尺寸 | small(32px) / medium(40px) / large(48px) / extraLarge(56px) |
| 徽章 | 右上角红色小圆点(badgeText) |
| 按压动画 | 缩放 1.0→0.9, 150ms |

#### 导航按钮样式

| 组件 | 背景色 | 前景色 | 圆角 | 最小尺寸 | 内边距 |
| --- | --- | --- | --- | --- | --- |
| ElevatedButton | `#00C896` | `#FFFFFF` | 16px | 120×48 | h:32, v:16 |
| TextButton | 透明 | `#00C896` | 12px | — | h:24, v:12 |
| OutlinedButton | 透明, 1.5px border | `#00C896` | 16px | 120×48 | h:32, v:16 |
| IconButton | 透明 | `#475569` | 12px | 48×48 | all:12 |
| FAB | `#00C896` | `#FFFFFF` | 圆形 | 56×56 | — |

### 4.2 卡片

#### ModernCard

| 属性 | 说明 |
| --- | --- |
| 变体 | elevated(白底+双影) / filled(微影) / outlined(描边) / glass(毛玻璃) |
| 尺寸 | small(12px内边距,4px外边距,12px圆角) / medium(16/8/16) / large(24/12/20) |
| 悬停动画 | 缩放 1.0→1.02, 200ms, easeOutCubic + 阴影提升 |
| 选中态 | outlined 变体 1px→2px 描边，颜色变 primary |
| 加载覆盖 | 白色 0.8 透明度 + spinner + "加载中..." |
| header/footer | 可选顶部标题区、底部操作区 |

#### Material Card（全局主题）

| 属性 | 值 |
| --- | --- |
| 背景色 | `#FFFFFF` (Light) / `#334155` (Dark) |
| 圆角 | 20px |
| 阴影 | 0 |
| 内边距 | 16px |
| 外边距 | h:16, v:8 |
| 裁剪 | antiAlias |

#### ModernCardHeader

| 属性 | 说明 |
| --- | --- |
| 布局 | 行：leading(图标) + 标题/副标题列 + trailing(操作) |
| 对齐 | CrossAxisAlignment.start |

#### ModernCardFooter

| 属性 | 说明 |
| --- | --- |
| 布局 | 行：actions 列表，8px 间距 |
| 对齐 | MainAxisAlignment.end（默认） |

### 4.3 输入框

#### AppInput

| 属性 | 说明 |
| --- | --- |
| 类型变体 | text / password / email / number / search |
| 焦点动画 | 缩放 1.0→1.02, 200ms easeInOut；边框变绿色 + 8px 绿色阴影 |
| 错误态 | 红色边框(1px→2px 焦点)；标签文字变红 |
| 密码类型 | 自动添加眼睛图标切换 |
| 前缀/后缀图标 | prefixIcon(左), suffixIcon(右)+onSuffixIconPressed |
| 最大行数 | maxLines（默认1，多行可设置） |
| 字数计数 | showCounter=true 显示字数 |

#### Material InputDecoration（全局主题）

| 属性 | 值 |
| --- | --- |
| filled | true |
| fillColor | `#F8FAFC` |
| 圆角 | 16px |
| 边框宽度 | enabled:1px, focused:2px, error:1px, focusedError:2px |
| 内容内边距 | h:20, v:16 |
| 浮动标签 | auto |

### 4.4 徽章 (PulseBadge)

| 属性 | 说明 |
| --- | --- |
| 类型 | filled(实底+阴影) / outline(透明底+1px描边) |
| 尺寸 | small(8×4,12px圆角,12px图标) / medium(12×6,16px圆角) / large(16×8,20px圆角) |
| 脉冲动画 | 缩放 1.0→1.2, 1500ms, 重复往返 |
| 预置变体 | `.ai()`="AI教练"绿底白字 / `.notification()`=橙色脉冲 / `.pro()`="PRO"小号绿底 |

### 4.5 进度环 (AnimatedProgressCircle)

| 属性 | 说明 |
| --- | --- |
| 参数 | progress(0-1), currentValue, targetValue, label, size, strokeWidth, color |
| 动画 | 进度弧 0→目标 1500ms / 数字递增 0→当前值 / 脉冲 1.0→1.05 2000ms 重复 |
| 默认尺寸 | 160px |
| 默认描边 | 8px |
| 中心文本 | `[数字]/[目标] [标签]` |
| 禁用脉冲 | showPulse=false |

### 4.6 底部导航栏

| 位置 | 图标 | 标签 | 路由 | 激活色 | 非激活色 |
| --- | --- | --- | --- | --- | --- |
| 1 | LucideIcons.home | 首页 | `/` | `#00C896` | `#94A3B8` |
| 2 | LucideIcons.clock | 历史 | `/history` | `#00C896` | `#94A3B8` |
| 3 | LucideIcons.plus（居中大圆按钮） | 记录 | 弹出底部模态 | — | — |
| 4 | LucideIcons.activity | 健康 | `/health` | `#00C896` | `#94A3B8` |
| 5 | LucideIcons.user | 我的 | `/profile` | `#00C896` | `#94A3B8` |

**居中按钮规格**：
- 尺寸：56×56px 圆形
- 渐变：`#00C896` → `#2DD4AA`，左上到右下
- 阴影：`primary@30%`, blurRadius:12, offset:(0,4)
- 图标：plus, 28px, 白色
- 下方文字："记录", 12px, w500, `#00C896`

**激活态**：
- 图标颜色变 primary
- 图标外围 8px 圆角 AnimatedContainer，背景 `primary@10%`, 内边距 4px
- 标签字体 12px w600

**非激活态**：
- 图标颜色 textTertiary
- 无背景装饰
- 标签字体 12px w400

**导航栏容器**：
- 背景：`#FFFFFF`
- 阴影：`Colors.black@8%`, blur 12, offset (0,-4)
- 高度：80px（含 SafeArea）

### 4.7 对话框与底部面板

#### Dialog

| 属性 | 值 |
| --- | --- |
| 背景色 | `#FFFFFF` |
| 圆角 | 24px |
| 阴影 | 0 |
| 标题样式 | h5 |
| 内容样式 | bodyMedium |
| 操作区内边距 | h:24, v:16 |

#### BottomSheet

| 属性 | 值 |
| --- | --- |
| 背景色 | `#FFFFFF` |
| 圆角 | 上方 24px |
| 拖拽指示条 | 40×4px, `#CBD5E1` |
| 显示拖拽指示 | true |

#### AlertDialog（标准确认对话框）

- 红色警告图标 + 标题 + 内容
- "取消" TextButton + "确认" 绿色 ElevatedButton
- 圆角 8px

### 4.8 其他组件主题

| 组件 | 描边 | 圆角 | 内边距 | 尺寸 |
| --- | --- | --- | --- | --- |
| ListTile | — | 12px | h:16, v:8 | — |
| Switch | — | — | — | thumb:primary/card/tertiary |
| Checkbox | 2px描边 | 4px | — | — |
| Slider | — | — | — | track:6px, thumb:12px |
| Chip | 1px描边 | 20px | h:12, v:8 | — |
| TabBar | 3px下划线 | — | h:16 inset | — |
| Tooltip | — | 8px | h:12, v:8 | — |
| Badge | — | — | h:6, v:2 | small:8, large:16 |
| SearchBar | 1px描边 | 16px | h:16, v:8 | 48px高 |
| Divider | 1px厚 | — | — | — |
| ProgressIndicator | — | — | — | 线性最小高度 6px |

### 4.9 动画工具

| 动画 | 效果 | 时长 | 曲线 |
| --- | --- | --- | --- |
| FadeIn | 透明度 0→1 | 300ms | easeOut |
| SlideIn.fromBottom | 向上滑入+淡入 | 300ms | easeOut |
| SlideIn.fromTop | 向下滑入+淡入 | 300ms | easeOut |
| SlideIn.fromLeft | 从右滑入+淡入 | 300ms | easeOut |
| SlideIn.fromRight | 从左滑入+淡入 | 300ms | easeOut |
| ScaleIn | 缩放 0→1 | 300ms | elasticOut |
| Pulse | 缩放 1.0↔1.1 | 1000ms | 重复 |
| Shake | 水平抖动 10px×3次 | 500ms | — |
| Staggered | 子项依次滑入 | 每项间隔 100ms | — |
| Press(按钮) | 缩放 1.0→0.95 | 150ms | easeInOut |
| Hover(卡片) | 缩放 1.0→1.02 + 阴影提升 | 200ms | easeOutCubic |

**页面转场**：
| 类型 | 效果 |
| --- | --- |
| slide | 从右滑入 (Offset(1,0)→zero) |
| fade | 透明度淡入 |
| scale | elasticOut 缩放进入 |

---

## 五、页面结构

### 5.1 路由与页面树

```
GoRouter (initial: /splash)
│
├── /splash → SplashPage（启动加载页）
│
├── 认证模块（无需登录）
│   ├── /login → LoginPage（登录页）
│   ├── /register → RegisterPage（注册页）
│   └── /change-password → ChangePasswordPage（修改密码页）
│
├── 新手引导（允许未登录访问）
│   ├── /onboarding → OnboardingWelcomePage（欢迎页）
│   ├── /onboarding/basic-info → OnboardingBasicInfoPage（基本信息）
│   ├── /onboarding/physical-data → OnboardingPhysicalDataPage（体测数据）
│   ├── /onboarding/health-goals → OnboardingHealthGoalsPage（健康目标）
│   └── /onboarding/complete → OnboardingCompletePage（完成页）
│
├── ShellRoute（底部导航栏包裹）
│   ├── / → HomePage（首页）
│   ├── /history → HistoryPage（历史记录）
│   ├── /history/test → FoodHistoryTestPage（测试页）
│   ├── /health → HealthPage（健康中心）
│   ├── /profile → ProfilePage（个人中心）
│   └── /saved-meals → SavedMealsPage（收藏菜品）
│
└── /camera → CameraPage（拍照识别，全屏无底部栏）
```

**认证守卫**：未登录访问受保护路由 → 重定向到 `/login`；已登录访问登录页 → 重定向到 `/`

### 5.2 首页 (HomePage)

**页面布局**：
```
┌─────────────────────────────────┐
│ 日期标签(今天/日期)  [AI教练] [🔔]  │ ← 顶部栏（无传统 AppBar）
├─────────────────────────────────┤
│ ┌─日期选择器──────────────────┐ │
│ │ [一][二][三][四][五][六][日] │ │ ← 7天水平滚动，选中日绿色圆角背景
│ └─────────────────────────────┘ │
│                                 │
│ ┌─卡路里追踪卡片──────────────┐ │
│ │ 📊 热量摄入    [✏️编辑]      │ │ ← 白色圆角卡片+阴影
│ │    ┌──────────┐             │ │
│ │    │  圆环进度  │  剩余/已摄入│ │ ← AnimatedProgressCircle
│ │    │  526/2000 │  目标值     │ │ ← 数字用 JetBrains Mono
│ │    └──────────┘             │ │
│ │ 🟢蛋白质 124g  🟠碳水 234g   │ │ ← 彩色进度条
│ │ 🟣脂肪 45g                  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─饮食记录────────────────────┐ │
│ │ ☀️ 早餐   320kcal  [记录]   │ │ ← MealCard 组件
│ │ 🌤 午餐   456kcal  [记录]   │ │
│ │ 🌙 晚餐    0kcal   [记录]   │ │
│ │ 🍫 零食    0kcal   [记录]   │ │
│ └─────────────────────────────┘ │
│                                 │
│ 刷新指示器包裹整体              │ ← RefreshIndicator
└─────────────────────────────────┘
│ [首页] [历史] [⊕记录] [健康] [我的] │ ← MainScaffold 底部导航
```

**卡路里编辑弹窗**：AlertDialog 含 TextField（800-5000 范围）

**食物记录模态底部面板**（FoodRecordModal）：
- 拖拽指示条
- 标题："记录食物"
- 3个选项：🤖 AI 扫描器 / 📝 文字描述 / 📋 已保存的菜品

**餐次记录底部面板**：
- 高度 60%
- 拖拽指示条
- 标题栏 + "添加"按钮
- 食物列表：图片缩略图(60×60) + 名称 + 热量 + 编辑/删除图标

### 5.3 认证页

#### 登录页 (LoginPage)

```
┌─────────────────────────────────┐
│         ┌────────┐              │
│         │  🍳    │              │ ← 80×80 圆形容器+emoji
│         └────────┘              │
│       欢迎回来！                 │ ← h2 标题
│     登录以继续使用              │ ← bodySmall 副标题
│                                 │
│ ┌─[👤]─────────────────────┐   │ ← AppInput, prefixIcon=user
│ │ 用户名/邮箱              │   │
│ └──────────────────────────┘   │
│                                 │
│ ┌─[🔒]─────────────────────┐   │ ← AppInput, type=password
│ │ 密码                      │   │ ← 自动添加眼睛图标
│ └──────────────────────────┘   │
│                                 │
│         忘记密码？              │ ← TextButton
│                                 │
│ ┌─────────────────────────────┐ │
│ │          登  录             │ │ ← AppButton.primary, fullWidth
│ └─────────────────────────────┘ │
│                                 │
│   还没有账户？ 立即注册          │ ← 文字+链接
└─────────────────────────────────┘
```

#### 注册页 (RegisterPage)

- 同登录页布局，表单字段为：用户名、邮箱、手机(选填)、密码(含显隐切换)、确认密码
- "注册" ElevatedButton
- "已有账户？立即登录" 底部链接

#### 修改密码页 (ChangePasswordPage)

- AppBar "修改密码"
- 黄色提示信息卡（安全说明）
- 三个 AppInput：当前密码、新密码、确认新密码
- "修改密码" AppButton + "取消" TextButton

### 5.4 新手引导

#### 欢迎页 (OnboardingWelcomePage)

```
┌─────────────────────────────────┐
│                    [跳过 →]     │ ← TextButton 右上角
│                                 │
│         ┌──────────┐            │
│         │ 🍽️       │            │ ← 280×280 圆形图标容器
│         └──────────┘            │
│                                 │
│      欢迎使用 DietAI            │ ← h2 标题
│    开始您的健康饮食之旅          │ ← bodyMedium
│                                 │
│ ┌─ 智能✨─┐┌─ 个性化🎯─┐┌─ 追踪📊─┐ │ ← 3 特性卡片
│ │ AI分析  ││ 定制建议 ││ 健康目标 │ │
│ └────────┘└──────────┘└────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │        开始设置              │ │ ← AppButton.primary, fullWidth
│ └─────────────────────────────┘ │
│                                 │
│      ● ○ ○ ○ ○ ○              │ ← 6步进度点，第1步激活
└─────────────────────────────────┘
```

#### 基本信息 (OnboardingBasicInfoPage)

- AppBar "基本信息" + 跳过按钮
- 进度点第2步激活
- 表单：真实姓名 AppInput + 性别选择(3卡片：男/女/其他) + 出生日期日期选择器 + 职业 AppInput + 地区 AppInput
- "继续" AppButton

#### 体测数据 (OnboardingPhysicalDataPage)

- 进度点第3步
- 身高(cm) + 体重(kg) 并排 AppInput
- BMI 卡片（条件显示：输入身高体重后自动计算）
  - 80×80 圆形图标 + BMI数值 + 类别标签 + 绿色边框背景
- 活动水平选择(5卡片)：久坐 / 轻度 / 中度 / 高度 / 极度（含图标+标题+描述）
- "继续" AppButton

#### 健康目标 (OnboardingHealthGoalsPage)

- 进度点第4步
- 5 目标卡片选择：减重⚖️ / 增重🏋️ / 维持⚖️ / 增肌💪 / 减脂🔥
- 条件字段：目标体重(目标1/2时) + 目标日期(目标已选时)
- "完成设置" AppButton

#### 完成 (OnboardingCompletePage)

- 120×120 绿色圆形成功图标 + 缩放动画
- "设置完成！" + "感谢您完成个人信息设置"
- 完成摘要卡片（4项勾选：基本信息✅ / 身体数据✅ / 健康目标✅ / 健康状况✅）
- 黄色提示卡片（💡信息）
- "开始使用 DietAI" AppButton

### 5.5 健康模块

#### 健康中心 (HealthPage)

```
┌─────────────────────────────────┐
│ ← 健康                    [⚙️] │ ← AppBar
├─────────────────────────────────┤
│ ┌─健康摘要卡片─────────────────┐ │
│ │ 🟢渐变背景 白色文字          │ │
│ │ 🔥 1245/2000kcal   🚶 6842步 │ │ ← LinearProgressIndicator
│ │ 💧 1.2/2.0L        😴 7.5h  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │ 🎯 健康目标│ │ ⚖️ 体重管理│      │ ← 2×2 功能网格卡片
│ └──────────┘ └──────────┘      │
│ ┌──────────┐ ┌──────────┐      │
│ │ 📊 数据分析│ │ 🤖 AI健康 │      │
│ └──────────┘ └──────────┘      │
│                                 │
│ ┌─💡健康小贴士────────────────┐ │
│ │ 💧 多喝水有助于代谢           │ │
│ │ 🥗 均衡饮食是基础             │ │ ← 3 条贴士+emoji
│ │ 🏃 每日运动30分钟             │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### 健康目标页 (HealthGoalsPage)

- AppBar "健康目标" + 添加图标
- 活跃目标概览卡片：渐变背景，最多2个 GoalProgressCard（含进度条）
- 全部目标列表：HealthGoalCard 列表
- 空状态：圆形图标 + "还没有健康目标" + 创建按钮
- FAB："新建目标" FloatingActionButton.extended
- 创建目标底部面板：目标类型5选1(emoji) + 可选目标体重 + 可选目标日期

#### 体重追踪页 (WeightTrackingPage)

- AppBar "体重记录" + 添加图标
- TabBar（2标签）：趋势分析 / 记录列表
  - **趋势分析**：WeightStatsCard + 时间范围选择(7/30/90/365天) + LineChart(fl_chart) + 趋势分析渐变卡片
  - **记录列表**：WeightRecordCard 列表 + 编辑/删除操作
- FAB："记录体重"
- 添加体重底部面板：体重(必填) + 体脂率/肌肉量(选填) + 日期时间选择 + 备注 + 保存/取消

#### 健康分析页 (HealthAnalysisPage)

- AppBar "健康分析" + 刷新按钮
- TabBar（5标签）：BMR / TDEE / 健康评分 / 营养平衡 / 体重趋势
  - **BMR**：卡片显示基础代谢率+计算公式
  - **TDEE**：卡片显示总能量消耗+活动系数
  - **健康评分**：大号数字+等级+建议列表
  - **营养平衡**：不足项(红)+过量项(橙)+建议
  - **体重趋势**：变化率+预测+趋势数据列表

#### 疾病管理页 (DiseaseManagementPage)

- 彩色 AppBar + TabBar（3标签）：疾病管理 / 过敏管理 / 饮食建议
- **疾病标签**：概览卡片(当前/历史数量) + 疾病卡片(严重程度标签) + 饮食建议按钮
- **过敏标签**：概览卡片(严重程度统计) + 过敏卡片(类型图标+严重程度) + 避免提示按钮
- **饮食建议标签**：基于疾病的建议卡 + 基于过敏的建议卡 + 一般指导准则卡
- FAB → 底部面板："添加疾病信息"/"添加过敏信息"

### 5.6 AI 对话

#### 会话列表页 (ChatSessionsPage)

```
┌─────────────────────────────────┐
│ ← AI对话          [筛选] [🔄] │ ← AppBar 筛选弹窗+刷新
├─────────────────────────────────┤
│ ┌─会话卡片────────────────────┐ │
│ │ 🟢 营养咨询                  │ │ ← 彩色头像+会话类型标签
│ │ 最近一条消息摘要...           │ │
│ │ 3条消息   2小时前            │ │
│ └─────────────────────────────┘ │
│ ┌─会话卡片────────────────────┐ │
│ │ 🔵 健康评估                  │ │
│ │ ...                          │ │
│ └─────────────────────────────┘ │
│                                 │
│ 空状态：💬 暂无对话记录 + 开始对话按钮 │
│                                 │
│                            [+]  │ ← FAB 绿色圆形新建按钮
└─────────────────────────────────┘
```

新建对话底部面板：4选项 — 营养咨询🥗 / 健康评估📊 / 食物识别🔍 / 运动建议🏃

#### 对话页 (ChatPage)

```
┌─────────────────────────────────┐
│ ← 营养咨询          [ℹ️]      │ ← AppBar + 会话信息弹窗
├─────────────────────────────────┤
│ ┌─欢迎卡片────────────────────┐ │
│ │ 🤖 你好！我是你的AI营养师    │ │ ← 会话类型图标+欢迎语
│ │ [快速建议1] [快速建议2] [3]  │ │ ← 3个快捷建议按钮
│ └─────────────────────────────┘ │
│                                 │
│          用户消息气泡 ────────── │ ← 绿色背景(#00C896), 右对齐
│              🤖 AI消息气泡      │ ← 白色背景, 左对齐
│              "正在思考中..." 🔄 │ ← 等待态
│                                 │
├─────────────────────────────────┤
│ ┌──────────────────────┐ [➤]   │ ← 输入区域
│ │ 输入消息...            │ [发送] │ ← 圆角TextField+绿色圆形发送按钮
│ └──────────────────────────────┘ │
└─────────────────────────────────┘
```

### 5.7 个人中心 (ProfilePage)

```
┌─────────────────────────────────┐
│ 个人中心               [⚙️]    │ ← AppBar
├─────────────────────────────────┤
│ ┌─用户资料卡───────────────────┐ │
│ │ 🟢渐变背景                    │ │
│ │   ┌──┐                       │ │
│ │   │👤│  真实姓名/用户名       │ │ ← 80×80 头像圆圈
│ │   └──┘                       │ │
│ │   [查看详细信息]              │ │ ← OutlinedButton
│ └─────────────────────────────┘ │
│                                 │
│ ┌───────┐ ┌───────┐ ┌───────┐ │
│ │连续7天 │ │142次记录│ │1650kcal│ │ ← 3 统计小卡片(渐变背景)
│ └───────┘ └───────┘ └───────┘ │
│                                 │
│ ┌─功能列表────────────────────┐ │
│ │ 🎯 健康目标                  │ │
│ │ ⚖️ 体重记录                  │ │
│ │ 💊 健康信息                  │ │
│ │ 🔒 修改密码                  │ │ ← ListTile 列表
│ │ 📊 数据统计                  │ │
│ │ 📥 数据导出                  │ │
│ │ ❓ 帮助中心                  │ │
│ │ ℹ️ 关于我们                  │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │          退出登录            │ │ ← 红色 OutlinedButton
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

#### 资料编辑底部面板 (ProfileEditSheet)

- 高度80%，圆角顶部
- 标题栏：关闭按钮 + "编辑个人资料" + "保存"按钮
- 基本信息：姓名 AppInput + 性别3选(男/女/其他) + 出生日期选择器
- 身体数据：身高+体重 并排 AppInput + 活动水平5选卡片
- 其他信息：职业 AppInput + 地区 AppInput

### 5.8 收藏菜品 (SavedMealsPage)

- AppBar "我的菜品" + 筛选图标 + 添加图标
- TabBar（3标签）：我的菜品 / 收藏菜品 / 全部菜品
- 搜索栏：圆角 TextField + 搜索图标 + 清除按钮
- 分类筛选底部面板：SavedMealFilterModal
- 菜品列表：SavedMealCard（80×80食物图 + 名称 + 公开标签 + 分类标签 + 营养摘要 + 使用/收藏次数 + 弹出菜单）
- 创建菜品底部面板(90%高度)：菜品名称(必填) + 描述 + 图片URL + 分类下拉 + 标签选择 + 公开开关 + 营养信息(8项)

### 5.9 历史记录 (HistoryPage)

- AppBar "饮食记录" + 搜索/筛选/测试图标
- 日期选择卡片：日历图标 + 格式化日期 + 箭头
- 按餐次分组的食物记录条目：
  - 餐次头部：彩色圆点 + 餐名 + 添加按钮
  - 食物条目：60×60 缩略图 + 名称 + 描述 + 热量标签 + 时间 + 弹出菜单(查看/编辑/保存为菜品/复制/删除)
- 食物详情底部面板(70%高度)：图片 + 基本信息 + 营养信息 + 编辑/保存按钮
- FAB：绿色 + 按钮添加记录

### 5.10 拍照识别 (CameraPage)

- 全屏相机预览 + 叠加控件
- 底部：拍照按钮 + 相册选择 + 闪光灯切换 + 前后摄像头切换
- 拍照/选图后跳转至 FoodAnalysisPage

### 5.11 食物分析 (FoodAnalysisPage)

- AI分析进度指示器（流式推送）
- 分析结果展示：食物名称 + 描述 + 营养数据卡片（16项营养素）
- 确认/拒绝按钮

---

## 六、交互规范

### 6.1 状态反馈

| 状态 | 组件 | 说明 |
| --- | --- | --- |
| 加载中 | ModernCard.isLoading | 白色0.8透明覆盖 + spinner + "加载中..." |
| 加载中 | AppButton.isLoading | 按钮内 spinner + "加载中..." 文字替换 |
| 加载中 | LoadingWidget | 独立居中 spinner + 可选消息文字 |
| 加载中 | ErrorHandler.showLoading() | 模态弹窗 spinner |
| 加载中 | FoodImagePreview | 灰色占位 + spinner |
| 空状态 | EmptyWidget | 64px 图标 + 标题 + 描述 + 可选操作按钮 |
| 错误 | CustomErrorWidget | 64px 红色图标 + 标题 + 描述 + 绿色"重试"按钮 |
| 成功 | CustomSnackBar.showSuccess() | 绿色浮动 SnackBar + ✓图标, 2s |
| 错误 | CustomSnackBar.showError() | 红色浮动 SnackBar + ⚠图标, 4s |
| 警告 | CustomSnackBar.showWarning() | 橙色浮动 SnackBar + ⚠图标, 3s |
| 信息 | CustomSnackBar.showInfo() | 蓝色浮动 SnackBar + ℹ图标, 3s |
| 确认删除 | AlertDialog | 红色警告图标 + "确定要删除吗？" + 取消/确认按钮 |

### 6.2 进度状态颜色

| 状态 | 颜色 | 用途 |
| --- | --- | --- |
| 待处理(Pending) | warning `#F59E0B` | 分析中、未完成 |
| 进行中(Analyzing) | info `#3B82F6` | 正在处理 |
| 完成(Completed) | success `#10B981` | 分析完成、目标达成 |
| 失败(Failed) | error `#EF4444` | 错误、失败 |

### 6.3 餐次类型标识

| 餐次 | 值 | 颜色 | 渐变 | 图标/Emoji |
| --- | --- | --- | --- | --- |
| 早餐 | 1 | `#FFB347` | `#FFB347→#FFCC80` | ☀️ |
| 午餐 | 2 | `#42A5F5` | `#42A5F5→#90CAF9` | 🌤️ |
| 晚餐 | 3 | `#9C27B0` | `#9C27B0→#BA68C8` | 🌙 |
| 零食 | 4 | `#EC407A` | `#EC407A→#F48FB1` | 🍫 |

### 6.4 健康目标类型标识

| 目标 | 值 | Emoji | 说明 |
| --- | --- | --- | --- |
| 减重 | 1 | ⚖️ | 目标体重低于当前 |
| 增重 | 2 | 🏋️ | 目标体重高于当前 |
| 维持 | 3 | ⚖️ | 维持当前体重 |
| 增肌 | 4 | 💪 | 增加肌肉量 |
| 减脂 | 5 | 🔥 | 减少体脂率 |

### 6.5 常量默认值

| 常量 | 值 | 说明 |
| --- | --- | --- |
| 默认热量目标 | 2000 kcal | 可编辑范围 800-5000 |
| 蛋白质比例 | 25% | 默认宏量营养素配比 |
| 碳水比例 | 50% | 默认宏量营养素配比 |
| 脂肪比例 | 25% | 默认宏量营养素配比 |
| 默认分页大小 | 20 | 列表分页 |
| 最大分页大小 | 100 | 列表分页上限 |
| 最大图片大小 | 10 MB | 图片上传限制 |
| 支持图片格式 | jpg, jpeg, png, webp | 图片上传格式 |
| 请求超时 | 120s | API 请求 |
| 连接超时 | 15s | API 连接 |
| 默认动画时长 | 300ms | 通用动画 |
| 快速动画时长 | 150ms | 按钮按压等 |
| 慢速动画时长 | 500ms | 页面转场等 |

---

## 七、数据缓存策略

### 7.1 三层缓存架构

| 层级 | 存储 | 容量 | 过期 | 用途 |
| --- | --- | --- | --- | --- |
| L1 内存(通用) | `Map<String, dynamic>` | 100条 | 24小时 | 用户资料、会话数据 |
| L1 内存(图片) | `Map<String, Uint8List>` | 50条 | 不过期 | 食物图片 base64 |
| L2 本地 | SharedPreferences | 无限 | 24小时 | JSON 序列化数据 |
| L3 文件 | 临时目录/`cache_{key}` | 无限 | 不过期 | 二进制数据（图片缓存） |

### 7.2 缓存读取流程（食物图片）

1. 检查 L1 内存缓存 → 命中则直接使用
2. 检查 L3 文件缓存 → 命中则提升至 L1 内存后使用
3. 请求 API 获取 base64 图片 → 存入 L1 内存 + L3 文件

### 7.3 后端 Redis 缓存 TTL

| 数据类型 | TTL | 键模式 |
| --- | --- | --- |
| 用户资料 | 30分钟 | `user:profile:{user_id}` |
| 用户会话 | 30分钟 | `user:session:{user_id}` |
| 每日营养汇总 | 2小时 | `nutrition:daily:{user_id}:{date}` |
| 食物分析结果 | 24小时 | `food:analysis:{record_id}` |
| 健康评分 | 1小时 | `health:score:{user_id}` |
| 对话上下文 | 30分钟 | `chat:context:{session_id}` |

---

## 八、暗色模式规范

### 8.1 色彩映射

| 亮色模式 | 暗色模式 | 用途 |
| --- | --- | --- |
| `#FFFFFF` (background) | `#0F172A` (darkBackground) | 页面背景 |
| `#FFFFFF` (card) | `#334155` (darkCard) | 卡片背景 |
| `#FFFFFF` (surface) | `#1E293B` (darkSurface) | 表面背景 |
| `#0F172A` (textPrimary) | `#F8FAFC` (darkTextPrimary) | 主文字 |
| `#475569` (textSecondary) | `#CBD5E1` (darkTextSecondary) | 次文字 |
| `#E2E8F0` (border) | `#475569` (darkBorder) | 边框 |
| `#00C896` (primary) | `#00C896` (不变) | 品牌主色 |

### 8.2 特殊处理

- AppBar 背景：亮色 `#FFFFFF` → 暗色 `#0F172A`
- AppBar 图标颜色：亮色 `#475569` → 暗色 `#F8FAFC`
- 卡片阴影色：暗色 `#25000000`
- 底部导航栏背景：亮色 `#FFFFFF` → 暗色 `#0F172A`
- 毛玻璃效果：不变（10%白色透明覆盖）

---

## 九、响应式设计

### 9.1 断点系统

| 设备 | 宽度范围 | 内边距 | 列数 | 字号缩放 | 间距缩放 |
| --- | --- | --- | --- | --- | --- |
| 手机 | < 480px | 16px | 1 | ×1.0 | ×1.0 |
| 平板 | 480–767px | 24px | 2 | ×1.1 | ×1.2 |
| 桌面 | 768–1023px | 32px | 3 | ×1.2 | ×1.4 |
| 大桌面 | ≥ 1024px | 40px | 4 | ×1.3 | ×1.6 |

### 9.2 响应式容器最大宽度

| 设备 | 最大宽度 |
| --- | --- |
| 手机 | 无限制 |
| 平板 | 800px |
| 桌面 | 1200px |
| 大桌面 | 1400px |

### 9.3 响应式组件

| 组件 | 说明 |
| --- | --- |
| ResponsiveBuilder | 根据断点返回不同 Widget |
| ResponsiveLayout | 手机/平板/桌面独立布局 |
| ResponsiveGrid | 自动列数网格布局 |
| ResponsiveContainer | 最大宽度约束容器 |
| ResponsiveSpacing | 响应式垂直/水平间距 |

---

## 十、网络与错误处理

### 10.1 API 配置

| 环境 | Base URL | MinIO URL |
| --- | --- | --- |
| 开发(模拟器) | `http://localhost:8000` | `http://localhost:9000` |
| 开发(真机) | `http://192.168.1.108:8000` | `http://192.168.1.108:9000` |
| 生产 | `https://your-production-api.com` | — |

### 10.2 认证流程

1. 登录/注册 → 获取 `accessToken` + `refreshToken`
2. 存储到 `FlutterSecureStorage`
3. 请求头自动添加 `Authorization: Bearer <accessToken>`
4. 401 响应 → 自动用 `refreshToken` 刷新 → 重试原请求
5. 刷新失败 → 清除 token → 跳转登录页

### 10.3 错误消息映射

| 错误 | 中文消息 |
| --- | --- |
| SocketException | 网络连接失败，请检查网络设置 |
| TimeoutException | 请求超时，请稍后重试 |
| 401 | 身份验证失败，请重新登录 |
| 403 | 权限不足，无法访问 |
| 404 | 请求的资源不存在 |
| 500 | 服务器内部错误，请稍后重试 |

### 10.4 SSE 流式响应

- Chat 和食物分析使用 Server-Sent Events 流式推送
- `ApiService.postStream()` 设置 `Accept: text/event-stream`
- 事件类型：session(会话创建) / status(状态更新) / content(内容增量) / complete(完成) / error(错误)

---

## 十一、组件索引

### 11.1 共享组件清单

| 组件 | 文件 | 用途 |
| --- | --- | --- |
| AppButton | `shared/presentation/widgets/app_button.dart` | 主按钮(4变体+3尺寸+加载态) |
| ModernButton | `shared/presentation/widgets/modern_button.dart` | 高级按钮(5变体+4尺寸+3形状+微光/脉冲) |
| ModernIconButton | `shared/presentation/widgets/modern_button.dart` | 图标按钮(4尺寸+徽章) |
| ModernCard | `shared/presentation/widgets/modern_card.dart` | 卡片(4变体+3尺寸+悬停+加载覆盖) |
| ModernCardHeader | `shared/presentation/widgets/modern_card.dart` | 卡片头部 |
| ModernCardFooter | `shared/presentation/widgets/modern_card.dart` | 卡片底部 |
| PulseBadge | `shared/presentation/widgets/pulse_badge.dart` | 徽章/标签(2类型+3尺寸+脉冲) |
| AppInput | `shared/presentation/widgets/app_input.dart` | 输入框(5类型+焦点动画+验证) |
| AnimatedProgressCircle | `shared/presentation/widgets/animated_progress_circle.dart` | 动画进度环(3动画层) |
| MainScaffold | `shared/presentation/widgets/main_scaffold.dart` | 底部导航壳(5Tab+中心FAB) |
| DateSelector | `features/home/presentation/widgets/date_selector.dart` | 7天日期水平选择器 |
| MealCard | `features/home/presentation/widgets/meal_card.dart` | 餐次卡片 |
| EnhancedMealCard | `features/home/presentation/widgets/enhanced_meal_card.dart` | 增强餐次卡片(含动画) |
| FoodRecordModal | `features/home/presentation/widgets/food_record_modal.dart` | 食物记录底部模态 |
| HealthGoalCard | `features/health/presentation/widgets/health_goal_card.dart` | 健康目标卡片 |
| GoalProgressCard | `features/health/presentation/widgets/goal_progress_card.dart` | 目标进度卡 |
| CreateGoalModal | `features/health/presentation/widgets/create_goal_modal.dart` | 创建目标底部面板 |
| AddWeightModal | `features/health/presentation/widgets/add_weight_modal.dart` | 添加体重底部面板 |
| WeightRecordCard | `features/health/presentation/widgets/weight_record_card.dart` | 体重记录卡片 |
| WeightStatsCard | `features/health/presentation/widgets/weight_stats_card.dart` | 体重统计卡片 |
| WeightChart | `features/health/presentation/widgets/weight_chart.dart` | 体重趋势折线图(fl_chart) |
| SavedMealCard | `features/saved_meals/presentation/widgets/saved_meal_card.dart` | 收藏菜品卡片 |
| CreateSavedMealModal | `features/saved_meals/presentation/widgets/create_saved_meal_modal.dart` | 创建菜品底部面板 |
| SavedMealFilterModal | `features/saved_meals/presentation/widgets/saved_meal_filter_modal.dart` | 筛选底部面板 |
| FoodImagePreview | `shared/presentation/widgets/food_image_preview.dart` | 食物图片预览(+全屏缩放) |
| FoodImageGridPreview | `shared/presentation/widgets/food_image_preview.dart` | 食物图片网格预览 |
| FoodRecordCard | `shared/presentation/widgets/food_record_card.dart` | 食物记录摘要卡片 |
| ErrorHandler | `shared/presentation/widgets/error_handler.dart` | 错误对话框(成功/错误/警告/加载) |
| CustomSnackBar | `shared/presentation/widgets/error_handler.dart` | 自定义浮动通知(4种语义色) |
| LoadingWidget | `shared/presentation/widgets/error_handler.dart` | 加载中组件 |
| EmptyWidget | `shared/presentation/widgets/error_handler.dart` | 空状态组件 |
| CustomErrorWidget | `shared/presentation/widgets/error_handler.dart` | 错误状态组件 |

### 11.2 动画组件清单

| 组件 | 效果 |
| --- | --- |
| FadeInAnimation | 透明度 0→1 |
| SlideInAnimation | 位置偏移+淡入（4方向） |
| ScaleInAnimation | 缩放 0→1（弹性） |
| PulseAnimation | 缩放 1.0↔1.1（循环） |
| ShakeAnimation | 水平抖动 |
| StaggeredAnimationBuilder | 子项依次动画 |
| PageTransitionBuilder | 页面转场（slide/fade/scale） |

---

## 十二、图表设计规范

### 12.1 图表库

使用 **fl_chart** (v0.66.0) 实现数据可视化。

### 12.2 体重趋势图

| 属性 | 值 |
| --- | --- |
| 类型 | LineChart |
| 线条颜色 | `#00C896` (primary) |
| 线条宽度 | 3px |
| 填充渐变 | primary → primary@0% |
| 数据点 | 圆形，5px半径，primary 色 |
| Y轴 | 体重(kg)，虚线网格 |
| X轴 | 日期标签 |
| 交互 | 点击数据点显示 Tooltip |

### 12.3 营养素进度条

| 营养素 | 进度条颜色 | 目标值标记 |
| --- | --- | --- |
| 蛋白质 | `#4ECDC4` (proteinColor) | 目标线 |
| 碳水化合物 | `#FFA726` (carbsColor) | 目标线 |
| 脂肪 | `#AB47BC` (fatColor) | 目标线 |

### 12.4 卡路里进度环

| 属性 | 值 |
| --- | --- |
| 尺寸 | 160px（默认） |
| 描边宽度 | 8px |
| 进度颜色 | `#00C896` (primary) |
| 背景颜色 | `#E2E8F0` (border) |
| 中心文字 | 数字/目标+标签 (JetBrains Mono) |
| 脉冲动画 | 缩放 1.0→1.05, 2s 重复 |

---

## 十三、图标使用规范

### 13.1 图标库

使用 **Lucide Icons** (v0.257.0) 作为主要图标库。

### 13.2 常用图标映射

| 功能 | 图标 | 大小 |
| --- | --- | --- |
| 首页 | LucideIcons.home | 24px |
| 历史 | LucideIcons.clock | 24px |
| 记录/添加 | LucideIcons.plus | 28px(中心按钮) / 24px(其他) |
| 健康 | LucideIcons.activity | 24px |
| 我的 | LucideIcons.user | 24px |
| 返回 | LucideIcons.chevronLeft | 24px |
| 搜索 | LucideIcons.search | 20px |
| 相机 | LucideIcons.camera | 24px |
| 通知 | LucideIcons.bell | 24px |
| 设置 | LucideIcons.settings | 24px |
| 刷新 | LucideIcons.refreshCw | 20px |
| 删除 | LucideIcons.trash2 | 20px |
| 编辑 | LucideIcons.edit2 | 20px |
| 关闭 | LucideIcons.x | 20px |
| 成功 | LucideIcons.check | 24px |
| 警告 | LucideIcons.alertTriangle | 24px |
| 错误 | LucideIcons.alertCircle | 24px |
| 信息 | LucideIcons.info | 24px |
| 日期 | LucideIcons.calendar | 20px |
| 体重 | LucideIcons.scale | 24px |
| 目标 | LucideIcons.target | 24px |
| AI | LucideIcons.bot | 24px |
| 发送 | LucideIcons.send | 20px |
| 密码 | LucideIcons.lock | 20px |
| 邮件 | LucideIcons.mail | 20px |
| 电话 | LucideIcons.phone | 20px |
| 过滤 | LucideIcons.filter | 20px |
| 食物 | LucideIcons.restaurant | 24px |
| 锁 | LucideIcons.lock | 20px |

---

## 十四、资产清单

### 14.1 字体

| 字体 | 来源 | 用途 |
| --- | --- | --- |
| Inter | Google Fonts (运行时加载) | 正文/标签/按钮 |
| Plus Jakarta Sans | Google Fonts (运行时加载) | 标题/品牌/Display |
| JetBrains Mono | Google Fonts (运行时加载) | 数字/代码/价格 |

### 14.2 图片与动画

| 目录 | 状态 | 说明 |
| --- | --- | --- |
| `assets/images/` | 空（.gitkeep） | 所有图片通过 API 获取 |
| `assets/icons/` | 空（.gitkeep） | 使用 Lucide Icons |
| `assets/lottie/` | 空（.gitkeep） | Lottie 依赖已包含但未使用 |

### 14.3 依赖包（与 UI 相关）

| 包名 | 版本 | 用途 |
| --- | --- | --- |
| flutter_riverpod | ^2.4.9 | 状态管理 |
| go_router | ^14.0.2 | 路由导航 |
| dio | ^5.4.0 | HTTP 客户端 |
| google_fonts | ^6.1.0 | 字体加载 |
| lucide_icons | ^0.257.0 | 图标库 |
| fl_chart | ^0.66.0 | 数据图表 |
| camera | ^0.10.5+7 | 相机功能 |
| image_picker | ^1.0.4 | 图片选择 |
| photo_view | ^0.14.0 | 图片缩放查看 |
| cached_network_image | ^3.3.0 | 网络图片缓存 |
| lottie | ^3.0.0 | Lottie 动画（预留） |
| animations | ^2.0.8 | 动画工具 |
| flutter_secure_storage | ^9.0.0 | 安全存储 |
| shared_preferences | ^2.2.2 | 本地存储 |
| permission_handler | ^11.1.0 | 权限管理 |
| intl | ^0.19.0 | 国际化/日期格式 |