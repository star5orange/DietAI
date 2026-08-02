import 'package:lucide_icons/lucide_icons.dart';

/// 统一的图标常量管理
///
/// 所有页面/组件应从此处引用图标，而非直接使用 LucideIcons.xxx。
/// 好处：
///   1. 语义化命名：改图标只需改一处
///   2. 全局一致性：相同语义的图标保证统一
///   3. 便于维护：要换图标库时只改这一个文件
///
/// 使用示例：
///   ```dart
///   import 'package:frontend_flutter/core/constants/icon_constants.dart';
///   Icon(AppIcons.calories),
///   ```
class AppIcons {
  AppIcons._();

  // ============================================================
  // 底部导航栏
  // ============================================================
  static const home = LucideIcons.home;
  static const history = LucideIcons.clock;
  static const health = LucideIcons.activity;
  static const profile = LucideIcons.user;

  // ============================================================
  // 导航操作
  // ============================================================
  static const back = LucideIcons.chevronLeft;
  static const forward = LucideIcons.chevronRight;
  static const backArrow = LucideIcons.arrowLeft;
  static const forwardArrow = LucideIcons.arrowRight;
  static const close = LucideIcons.x;
  static const more = LucideIcons.moreVertical;
  static const expand = LucideIcons.chevronDown;

  // ============================================================
  // 通用操作
  // ============================================================
  static const add = LucideIcons.plus;
  static const edit = LucideIcons.pencil;
  static const edit2 = LucideIcons.edit2;
  static const delete = LucideIcons.trash2;
  static const confirm = LucideIcons.check;
  static const search = LucideIcons.search;
  static const filter = LucideIcons.filter;
  static const filterActive = LucideIcons.filterX;
  static const settings = LucideIcons.settings;
  static const notification = LucideIcons.bell;

  // ============================================================
  // 功能入口
  // ============================================================
  static const camera = LucideIcons.camera;
  static const gallery = LucideIcons.image;
  static const aiSparkle = LucideIcons.sparkles;
  static const aiQuick = LucideIcons.zap;
  static const voice = LucideIcons.mic;
  static const chat = LucideIcons.messageCircle;
  static const scan = LucideIcons.scanLine;

  // ============================================================
  // 营养/健康数据
  // ============================================================
  static const calories = LucideIcons.flame;
  static const weight = LucideIcons.scale;
  static const water = LucideIcons.droplets;
  static const protein = LucideIcons.dumbbell;
  static const carbs = LucideIcons.wheat;
  static const fat = LucideIcons.droplet;
  static const meal = LucideIcons.utensils;
  static const exercise = LucideIcons.dumbbell;
  static const activityLevel = LucideIcons.activity;

  // ============================================================
  // 健康/身体
  // ============================================================
  static const heart = LucideIcons.heart;
  static const height = LucideIcons.ruler;
  static const goal = LucideIcons.target;
  static const shield = LucideIcons.shield;
  static const apple = LucideIcons.apple;
  static const leaf = LucideIcons.leaf;

  // ============================================================
  // 状态反馈
  // ============================================================
  static const success = LucideIcons.checkCircle;
  static const warning = LucideIcons.alertCircle;
  static const error = LucideIcons.alertTriangle;
  static const tip = LucideIcons.lightbulb;
  static const trendUp = LucideIcons.trendingUp;
  static const trendDown = LucideIcons.trendingDown;

  // ============================================================
  // 时间/日期
  // ============================================================
  static const calendar = LucideIcons.calendar;
  static const clock = LucideIcons.clock;
  static const sun = LucideIcons.sun;
  static const moon = LucideIcons.moon;

  // ============================================================
  // 表单输入
  // ============================================================
  static const password = LucideIcons.lock;
  static const eye = LucideIcons.eye;
  static const eyeOff = LucideIcons.eyeOff;
  static const person = LucideIcons.user;
  static const location = LucideIcons.mapPin;
  static const job = LucideIcons.briefcase;
  static const note = LucideIcons.fileText;
  static const tag = LucideIcons.tag;
  static const budget = LucideIcons.coins;
  static const wallet = LucideIcons.wallet;

  // ============================================================
  // 其他
  // ============================================================
  static const bookmark = LucideIcons.bookmark;
  static const chart = LucideIcons.barChart3;
  static const smile = LucideIcons.smile;
  static const circle = LucideIcons.circle;
}
