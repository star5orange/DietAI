import 'api_config.dart';

class AppConstants {
  // 应用信息
  static const String appName = 'DietAI';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI智能饮食健康管理';

  // API配置
  static String get baseUrl => ApiConfig.effectiveBaseUrl; // 使用更灵活的API配置
  static const String apiPrefix = '/api';

  // 存储键
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userInfoKey = 'user_info';
  static const String themeKey = 'theme_mode';

  // 路由路径
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/';
  static const String cameraRoute = '/camera';
  static const String historyRoute = '/history';
  static const String healthRoute = '/health';
  static const String profileRoute = '/profile';
  static const String savedMealsRoute = '/saved-meals';

  // 时间配置
  static const int requestTimeout = 120000; // 120秒 (AI分析需要更长时间)
  static const int connectTimeout = 15000; // 15秒

  // 分页配置
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // 文件上传配置
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const List<String> supportedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'webp'
  ];

  // 营养目标配置
  static const double defaultCalorieGoal = 2000;
  static const double defaultProteinRatio = 0.25;
  static const double defaultCarbRatio = 0.5;
  static const double defaultFatRatio = 0.25;

  // 动画配置
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // 餐次类型
  static const Map<int, String> mealTypes = {
    1: '早餐',
    2: '午餐',
    3: '晚餐',
    4: '零食',
  };

  // 记录方式
  static const Map<int, String> recordingMethods = {
    1: 'AI扫描',
    2: '文字描述',
    3: '语音输入',
    4: '已保存菜品',
    5: '手动输入',
  };
}
