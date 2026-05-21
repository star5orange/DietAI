# DietAI 前端部署全流程记录

> 本文档记录了 2026-04-19 将 DietAI Flutter 前端部署到 Android 手机的完整过程，包括所有遇到的问题及解决方案。

---

## 目录

1. [环境准备](#1-环境准备)
2. [Flutter SDK 安装](#2-flutter-sdk-安装)
3. [Android Studio 安装与配置](#3-android-studio-安装与配置)
4. [项目配置](#4-项目配置)
5. [Gradle 构建问题与解决](#5-gradle-构建问题与解决)
6. [手机连接与安装](#6-手机连接与安装)
7. [后端服务启动](#7-后端服务启动)
8. [端到端联调](#8-端到端联调)
9. [问题速查表](#9-问题速查表)

---

## 1. 环境准备

### 最终环境信息

| 组件 | 版本/路径 |
|------|-----------|
| 操作系统 | Windows 11 家庭中文版 23H2 |
| Flutter SDK | 3.41.7 (stable) |
| Dart SDK | 3.11.5 |
| Android SDK | API 34/35/36, Build-Tools 34/35/36.1 |
| NDK | 28.2.13676358 |
| Java/JDK | OpenJDK 21.0.10 (Android Studio 自带) |
| Android Studio | 安装路径 `E:\Android\Android Studio` |
| Android SDK 路径 | `E:\Android\SDK` |
| Flutter SDK 路径 | `E:\flutter_windows_3.41.7-stable\flutter` |
| Python | 3.12.8 |
| 测试手机 | OPPO (Android 16, API 36) |

### 系统环境变量

需添加以下系统环境变量：

```
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

Path 中添加：`E:\flutter_windows_3.41.7-stable\flutter\bin`

### Flutter Doctor 终态

```
[√] Flutter (Channel stable, 3.41.7)
[√] Windows Version
[√] Android toolchain (Android SDK version 36.1.0)
[√] Chrome
[√] Visual Studio
[√] Connected device (4 available, 含 Android 手机)
[√] Network resources
```

---

## 2. Flutter SDK 安装

1. 下载 Flutter SDK 压缩包：https://docs.flutter.dev/get-started/install/windows/desktop
2. 解压到 `E:\flutter_windows_3.41.7-stable`
3. 添加系统 PATH：`E:\flutter_windows_3.41.7-stable\flutter\bin`
4. 添加系统环境变量：
   - `PUB_HOSTED_URL=https://pub.flutter-io.cn`
   - `FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
5. 重新打开终端，运行 `flutter doctor -v` 验证

### 设置 Flutter Android SDK 路径

```bash
flutter config --android-sdk E:\Android\SDK
```

---

## 3. Android Studio 安装与配置

### 安装步骤

1. 下载 Android Studio：https://developer.android.com/studio
2. 安装到 `E:\Android\Android Studio`
3. 首次启动后进入 SDK Manager（More Actions → SDK Manager）
4. **SDK Platforms** 标签页：勾选 Android API 34
5. **SDK Tools** 标签页：勾选以下组件：
   - Android SDK Build-Tools (34, 35, 36.1)
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools (latest)
   - **NDK (Side by side)** → 勾选 **27.0.12077973** 和最新版

### 开启 Windows 开发者模式

`Win+I` → 系统 → 开发者选项 → 开启"开发人员模式"

### 接受 Android Licenses

```bash
flutter doctor --android-licenses
```

一路按 `y` 接受。

---

## 4. 项目配置

### 4.1 合并上游代码

```bash
git fetch upstream
git merge upstream/main
```

本次合入了 `upstream/main` (60a5ba8) 的更新，主要包括 `frontend_flutter/lib/` 所有 Flutter 源代码。合并过程中解决了以下冲突：

- `frontend_flutter/pubspec.yaml` — 保留 upstream 版本（新增 `photo_view` 依赖）
- `frontend_flutter/pubspec.lock` — 采用 upstream 版本
- `frontend_flutter/.metadata` — 合并平台列表
- 后端 `agent/` → `agents/` 目录重构 — 接受 upstream 的 `agents/` 结构，更新了所有 Python import 路径和 `langgraph.json`

### 4.2 创建 local.properties

文件路径：`frontend_flutter/android/local.properties`

```properties
sdk.dir=E:\\Android\\SDK
flutter.sdk=E:\\flutter_windows_3.41.7-stable\\flutter
flutter.buildMode=debug
flutter.versionName=1.0.0
flutter.versionCode=1
```

### 4.3 配置 API 地址

文件路径：`frontend_flutter/lib/core/constants/api_config.dart`

将 `devLocalNetworkUrl` 和 `devLocalNetworkMinioUrl` 修改为电脑局域网 IP：

```dart
static const String devLocalNetworkUrl = 'http://192.168.1.108:8000';
static const String devLocalNetworkMinioUrl = 'http://192.168.1.108:9090';
```

> 查看电脑 IP：`ipconfig` → 找 WLAN 的 IPv4 地址

### 4.4 代理配置

文件：`frontend_flutter/android/gradle.properties`

如果**不使用代理**，注释掉 6 行 systemProp 配置。本项目当前使用代理（端口 7890），故保持原样。

### 4.5 创建 assets 目录

```bash
mkdir frontend_flutter\assets\images
mkdir frontend_flutter\assets\icons
mkdir frontend_flutter\assets\lottie
```

在每个目录中添加 `.gitkeep` 占位文件。

### 4.6 AGP 版本升级

文件：`frontend_flutter/android/settings.gradle.kts`

AGP 版本从 8.7.3 升级到 **8.9.1**（因 androidx 依赖要求 >= 8.9.1）：

```kotlin
id("com.android.application") version "8.9.1" apply false
```

### 4.7 NDK 版本更新

文件：`frontend_flutter/android/app/build.gradle.kts`

NDK 版本从 27.0.12077973 更新为 **28.2.13676358**（因 jni 插件要求更新版本）：

```kotlin
ndkVersion = "28.2.13676358"
```

### 4.7 环境配置文件

创建 `.env.dev`（settings.py 从此文件读取配置）：

```
DIETAI_OPENAI_API_KEY=sk-xxx
DIETAI_DASHSCOPE_API_KEY=sk-xxx
DIETAI_DASHSCOPE_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1
DIETAI_REDIS_PASSWORD=123456
DIETAI_VECTOR_STORE_PATH=agents/VectorStore
DIETAI_VECTOR_COLLECTION_NAME=nutrition_collection
```

修复 `.env` 中 `VECTOR_STORE_PATH=agent/VectorStore` → `agents/VectorStore`。

---

## 5. Gradle 构建问题与解决

### 5.1 kotlin-dsl 插件找不到

**错误：** `Plugin 'org.gradle.kotlin.kotlin-dsl' version '5.1.2' was not found`

**原因：** `settings.gradle.kts` 中的 `pluginManagement.repositories` 缺少国内镜像。

**解决：** 在 `settings.gradle.kts` 中添加阿里云镜像：

```kotlin
pluginManagement {
    // ... flutterSdkPath ...
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin/") }
        maven { url = uri("https://maven.aliyun.com/repository/google/") }
        maven { url = uri("https://maven.aliyun.com/repository/public/") }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
```

### 5.2 AGP 版本过低

**错误：** `Dependency 'androidx.activity:activity-ktx:1.12.4' requires Android Gradle plugin 8.9.1 or higher`

**解决：** `settings.gradle.kts` 中 AGP 从 8.7.3 → 8.9.1

### 5.3 NDK 版本不匹配

**错误：** `Your project is configured with Android NDK 27.0.12077973, but the following plugin(s) depend on a different Android NDK version: jni requires Android NDK 28.2.13676358`

**解决：** `app/build.gradle.kts` 中 NDK 从 27.0.12077973 → 28.2.13676358

### 5.4 Kotlin Daemon 编译错误

**错误：** `Daemon compilation failed: null` + `this and base files have different roots`

**解决：** `flutter clean` 清除缓存后重新构建

### 5.5 不使用代理时构建卡住

**原因：** `gradle.properties` 中配置了 `systemProp.http.proxyHost=127.0.0.1:7890`，但代理未运行。

**解决：** 注释掉 `systemProp.*` 的 6 行代理配置，或确保代理软件运行在 7890 端口。

---

## 6. 手机连接与安装

### 6.1 手机设置

1. 设置 → 关于手机 → 连点7次版本号 → 开启开发者模式
2. 设置 → 开发者选项 → 开启 USB 调试
3. USB 连接电脑 → 选择"传输文件"模式
4. 手机弹窗 → 允许 USB 调试

### 6.2 小米手机特殊问题

小米手机开启"USB 安装"需要 SIM 卡。**解决方案：** 换用 OPPO 手机。

### 6.3 OPPO 手机安装失败

**错误：** `INSTALL_FAILED_USER_RESTRICTED`

**解决：** 设置 → 密码与安全 → 系统安全 → 允许安装未知来源应用 → 开启

### 6.4 构建与运行命令

```bash
cd E:\DietAI\frontend_flutter
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

---

## 7. 后端服务启动

### 7.1 服务清单

| 服务 | 默认端口 | 状态 |
|------|---------|------|
| PostgreSQL | 5432 | ✅ 已运行（本地安装） |
| Redis | 6379 | ✅ 已运行（密码 123456） |
| MinIO | 9090 (API) / 9000 (Console) | ✅ 手动启动 |
| FastAPI (uvicorn) | 8000 | ✅ 手动启动 |
| LangGraph | 2024 | ⏳ 暂未启动 |

### 7.2 启动 MinIO

```bash
E:\minio\bin\minio.exe server E:\minio\data --console-address "127.0.0.1:9000" --address "127.0.0.1:9090"
```

### 7.3 启动 FastAPI 后端

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 7.4 遇到的 Python 依赖问题

启动时缺少以下 Python 包，需手动安装：

```bash
pip install minio psycopg2-binary "pydantic[email]" passlib python-jose python-multipart aiofiles pillow httpx
```

### 7.5 合并导致的代码问题

`routers/deep_router.py` 第 206-208 行 import 语句被嵌入 try 块内，导致 `IndentationError`。修复为正确的函数体缩进。

### 7.6 防火墙放行

```powershell
# 管理员 PowerShell
netsh advfirewall firewall add rule name="DietAI-Backend" dir=in action=allow protocol=TCP localport=8000
netsh advfirewall firewall add rule name="DietAI-MinIO" dir=in action=allow protocol=TCP localport=9090
```

---

## 8. 端到端联调

### 8.1 手机访问后端

确保手机和电脑在同一 WiFi 下。App 中 `api_config.dart` 已配置电脑局域网 IP `192.168.1.108`。

### 8.2 注册接口测试

- 请求：`POST http://192.168.1.108:8000/api/auth/register`
- 密码需 ≥ 8 个字符
- 注册成功返回：`{"success": true, "data": {"user_id": 2, "username": "zzz"}}`

---

## 9. 问题速查表

| 问题 | 原因 | 解决 |
|------|------|------|
| kotlin-dsl 插件找不到 | 缺少国内 Maven 镜像 | settings.gradle.kts 添加阿里云镜像 |
| AGP 版本过低 | androidx 依赖要求 >= 8.9.1 | AGP 8.7.3 → 8.9.1 |
| NDK 版本不匹配 | jni 插件要求 28.x | NDK 27.x → 28.2.13676358 |
| Kotlin Daemon 编译失败 | 缓存跨盘符冲突 | flutter clean |
| Gradle 构建卡住 | 代理配置但代理未运行 | 注释或删除 gradle.properties 代理配置 |
| 手机安装失败 (MIUI) | USB 安装需 SIM 卡 | 换 OPPO 手机 |
| 手机安装失败 (OPPO) | 禁止未知来源应用 | 开启允许安装未知来源应用 |
| App 连接后端超时 | Windows 防火墙阻挡 | 放行 8000/9090 端口 |
| 注册 422 错误 | 密码少于 8 位 | 密码输入 ≥ 8 位 |
| ModuleNotFoundError: minio | Python 缺少 minio 包 | pip install minio |
| ModuleNotFoundError: psycopg2 | Python 缺少 psycopg2 | pip install psycopg2-binary |
| ModuleNotFoundError: email_validator | Python 缺少 email-validator | pip install "pydantic[email]" |
| ModuleNotFoundError: passlib | Python 缺少 passlib | pip install passlib python-jose |
| deep_router.py IndentationError | 合并冲突导致 import 嵌入 try 块 | 修复缩进 |
| VECTOR_STORE_PATH 错误 | .env 中路径为旧的 agent/ | 改为 agents/VectorStore |

---

*文档创建日期: 2026-04-19*