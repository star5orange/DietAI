import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 启动落地页偏好的全局状态（splash 启动时写入，profile 切换时更新），
/// 供底部导航「首页」tab 跟随偏好动态指向（对话页 ↔ 数据看板）
final landingProvider = StateProvider<String>((ref) => LandingPreference.chat);

/// 启动落地页偏好（PRD D15 扩展：默认「对话直达」，用户可改为「数据看板」自己手操功能）。
///
/// key 按用户隔离（与 last_solar_term_$userId 惯例一致），同设备多账号互不影响。
class LandingPreference {
  LandingPreference._();

  static const String chat = 'chat'; // 对话直达（默认，兼容 D15）
  static const String dashboard = 'dashboard'; // 数据看板（自己手操功能）
  static const String _prefix = 'default_landing_';

  /// 读取偏好；未设置过时返回 chat（对话直达）
  static Future<String> get(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$userId') ?? chat;
  }

  static Future<void> set(int userId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$userId', value);
  }
}
