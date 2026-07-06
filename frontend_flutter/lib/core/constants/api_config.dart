/// API 配置
///
/// 支持三种配置方式（优先级从高到低）：
/// 1. 运行时通过 setCustomBaseUrl() 动态设置
/// 2. 环境变量 DIETAI_API_URL / DIETAI_MINIO_URL
/// 3. 编译时常量 devBaseUrl / prodBaseUrl
class ApiConfig {
  // 开发环境配置
  static const String devBaseUrl = 'http://localhost:8000';
  static const String devLocalNetworkUrl =
      'http://192.168.1.108:8000'; // 请修改为您的局域网IP

  // MinIO配置
  static const String devMinioUrl = 'http://localhost:9000';
  static const String devLocalNetworkMinioUrl =
      'http://192.168.1.108:9000'; // 请修改为您的局域网IP

  // 生产环境配置
  static const String prodBaseUrl = 'https://your-production-api.com';
  static const String prodMinioUrl = 'https://your-production-minio.com';

  // 当前使用的环境
  static const Environment currentEnvironment = Environment.development;

  /// 获取当前环境的基础URL
  static String get baseUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return _getDevBaseUrl();
      case Environment.production:
        return prodBaseUrl;
    }
  }

  /// 获取当前环境的MinIO URL
  static String get minioUrl {
    switch (currentEnvironment) {
      case Environment.development:
        return _getDevMinioUrl();
      case Environment.production:
        return prodMinioUrl;
    }
  }

  /// 智能选择开发环境URL
  static String _getDevBaseUrl() {
    return devBaseUrl;
  }

  /// 智能选择开发环境MinIO URL
  static String _getDevMinioUrl() {
    return devMinioUrl;
  }

  /// 动态设置API基础URL（用于运行时配置）
  static String? _customBaseUrl;
  static String? _customMinioUrl;

  static void setCustomBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static void setCustomMinioUrl(String url) {
    _customMinioUrl = url;
  }

  /// 从环境变量初始化配置
  /// 在 main.dart 中调用：await ApiConfig.initFromEnv();
  static Future<void> initFromEnv() async {
    // 尝试从环境变量读取（适用于 CI/CD 或 docker 部署）
    const envApiUrl = String.fromEnvironment('DIETAI_API_URL');
    const envMinioUrl = String.fromEnvironment('DIETAI_MINIO_URL');

    if (envApiUrl.isNotEmpty) {
      _customBaseUrl = envApiUrl;
    }
    if (envMinioUrl.isNotEmpty) {
      _customMinioUrl = envMinioUrl;
    }
  }

  static String get effectiveBaseUrl {
    final url = _customBaseUrl ?? baseUrl;
    assert(
      currentEnvironment == Environment.development || url.startsWith('https://'),
      '生产环境必须使用 HTTPS！当前 URL: $url',
    );
    return url;
  }

  static String get effectiveMinioUrl {
    final url = _customMinioUrl ?? minioUrl;
    assert(
      currentEnvironment == Environment.development || url.startsWith('https://'),
      '生产环境 MinIO 必须使用 HTTPS！当前 URL: $url',
    );
    return url;
  }
}

/// 环境枚举
enum Environment {
  development,
  production,
}

/// 使用方法：
/// 1. 编译时传入环境变量：flutter run --dart-define=DIETAI_API_URL=http://192.168.1.100:8000
/// 2. 运行时动态设置：ApiConfig.setCustomBaseUrl('http://192.168.1.100:8000')
/// 3. 默认使用 devBaseUrl（开发环境）或 prodBaseUrl（生产环境）
/// 4. 修改 devLocalNetworkUrl 为您后端服务器的实际IP地址
