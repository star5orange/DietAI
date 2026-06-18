import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/themes/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/api_config.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'services/notification_response_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 从环境变量初始化 API 配置
  await ApiConfig.initFromEnv();

  ApiService().initialize();

  await NotificationService().initialize();

  // 设置通知点击回调：记录提醒响应
  NotificationService.onNotificationTapped = _handleNotificationTap;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: DietAIApp(),
    ),
  );
}

class DietAIApp extends ConsumerWidget {
  const DietAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
  }
}

/// 处理通知点击：记录提醒响应
/// payload格式: reminder_{idHash}_{type} 或 reminder_{idHash}_{type}_day{day}
void _handleNotificationTap(int notificationId, String? payload) {
  if (payload == null || !payload.startsWith('reminder_')) return;

  try {
    // 解析payload: reminder_{idHash}_{type}[_day{day}]
    final parts = payload.split('_');
    if (parts.length < 3) return;

    final idHash = int.tryParse(parts[1]) ?? 0;
    final reminderType = parts[2];

    // 根据提醒类型确定响应动作
    String actionType;
    switch (reminderType) {
      case 'water':
        actionType = 'drank';
        break;
      case 'meal':
        actionType = 'ate';
        break;
      default:
        actionType = 'ate';
        break;
    }

    // 异步记录响应到后端
    final service = NotificationResponseService();
    service.createResponse(
      reminderId: idHash,
      actionType: actionType,
    ).then((_) {
      debugPrint('提醒响应记录成功');
    }).catchError((e) {
      debugPrint('记录提醒响应失败: $e');
    }, test: (e) => e is Exception);
  } catch (e) {
    debugPrint('处理通知点击失败: $e');
  }
}
