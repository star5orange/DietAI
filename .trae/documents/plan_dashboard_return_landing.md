# 计划：看板右上角切回对话入口 + 启动落地页可配置

## Context

用户需求：
1. 启动应用默认进入对话页（现状已如此，保持为默认值）
2. 切换到「数据看板」后，在页面右上方提供切回对话页的入口
3. 让用户自选默认落地：「对话直达」（启动进 AI 对话页）或「自己手操功能」（启动进数据看板）

用户已拍板：选择入口放「我的」页菜单（新增设置项）；看板右上角按钮只负责快速切回。

现状核实（已探索）：
- `/` 即对话页 ChatPage（app_router.dart:242-253）；`/dashboard` → HomePage（:256-263）
- 冷启动 `initialLocation: '/splash'`，SplashPage 已登录 → `context.go('/')`（splash_page.dart:84）；登录成功 → `context.go('/')`（login_page.dart:80）
- 看板页 home_page.dart 非 Scaffold+AppBar，自绘头部 `_buildAppBar()`（:1502-1581）：左侧日期选择，`Spacer()`（:1538）右侧为打卡徽章（:1539）+「编辑首页模块」按钮（:1565-1577）；目前无切回对话入口，只能靠底部导航「首页」tab
- 无现成落地页偏好；偏好存取惯例：SharedPreferences 按 userId 隔离 key（如 `last_solar_term_$userId`，home_page.dart:144-173）
- PRD D15（PRD .md:337）定「对话页为首页主入口」——本改动默认值仍是对话页，与 D15 兼容；"可配置"为新增需求

## 改动方案

### 1. 新增偏好读写工具 `lib/core/utils/landing_preference.dart`

```dart
/// 启动落地页偏好（'chat' | 'dashboard'，缺省 'chat'）
/// key 按用户隔离：default_landing_$userId（与项目 last_solar_term_$userId 惯例一致）
class LandingPreference {
  static const String _prefix = 'default_landing_';
  static const String defaultValue = 'chat';

  static Future<String> get(int userId) async { ... }   // SharedPreferences.getString
  static Future<void> set(int userId, String value) async { ... }
}
```

### 2. 启动/登录落地按偏好跳转

- `splash_page.dart:84`：已登录分支 `context.go('/')` 改为读偏好——userId 取自当前登录用户（splash 已有登录态判断，从 auth provider / 已缓存的 user 取 id）；`dashboard` → `context.go('/dashboard')`，否则 `context.go('/')`
- `login_page.dart:80`：登录成功处同样调用（响应里有 user.id）
- app_router 的已登录访问认证页 redirect（:96-141）保持 `go('/')` 不动（边缘路径，落对话页无害，且 redirect 同步函数不宜读异步偏好）

### 3. 看板右上角切回按钮 `home_page.dart`

在 `_buildAppBar()` Row 的 `Spacer()` 之后、「编辑首页模块」按钮左侧追加：

```dart
IconButton(
  icon: const Icon(Icons.chat_bubble_rounded),
  tooltip: '回对话',
  onPressed: () => context.go('/'),   // go 而非 push：/ 是 tab 根，避免堆栈
),
```

### 4. 「我的」页新增设置项 `profile_page.dart`

在「首页个性化」（:446）附近插入菜单项（复用 `_buildMenuItem`）：
- 标题「启动默认页」，副标题显示当前值（对话直达 / 数据看板）
- 点击弹二选一弹窗（AlertDialog + RadioListTile 或 SimpleDialog）：
  - **对话直达**：启动进 AI 对话页（默认）
  - **数据看板**：启动进数据看板，自己手操功能
- 选择后 `LandingPreference.set(userId, ...)` 并 setState 刷新副标题

## 文件清单

| 文件 | 动作 |
|---|---|
| `lib/core/utils/landing_preference.dart` | 新增 |
| `lib/features/auth/presentation/pages/splash_page.dart` | 改落地分支 |
| `lib/features/auth/presentation/pages/login_page.dart` | 改登录成功跳转 |
| `lib/features/home/presentation/pages/home_page.dart` | `_buildAppBar` 加按钮 |
| `lib/features/profile/presentation/pages/profile_page.dart` | 加设置项 + 弹窗 |

## 验证

1. `cd frontend_flutter && flutter analyze`（注意项目既有 lint 问题与本次无关，只看新增文件 0 issue）
2. 手测（SharedPreferences 不随 hot restart 清空，需冷启动/杀进程重开验证）：
   - 新账号（未设置过）：冷启动 → 对话页（默认不变）
   - 「我的」→ 启动默认页 → 选「数据看板」→ 杀 App 重启 → 落地数据看板
   - 看板右上角聊天按钮 → 切回对话页（底部 tab 同步高亮首页）
   - 改回「对话直达」→ 冷启动 → 对话页
