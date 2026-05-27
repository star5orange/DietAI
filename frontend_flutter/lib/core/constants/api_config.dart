/// API 配置
///
/// 在这里配置不同环境的API基础URL
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

  static String get effectiveBaseUrl {
    return _customBaseUrl ?? baseUrl;
  }

  static String get effectiveMinioUrl {
    return _customMinioUrl ?? minioUrl;
  }
}

/// 环境枚举
enum Environment {
  development,
  production,
}

/// 使用方法：
/// 1. 修改 devLocalNetworkUrl 为您后端服务器的实际IP地址
/// 2. 确保后端服务器在对应端口上运行（默认8000）
/// 3. 如果需要切换到生产环境，修改 currentEnvironment
/// 4. 运行时可以通过 ApiConfig.setCustomBaseUrl() 动态设置API地址
