import 'package:flutter/material.dart';

/// 应用颜色系统 - 现代化健康绿色主题 2.0
class AppColors {
  // 品牌色彩 - 现代化升级
  static const Color primary = Color(0xFF00C896); // 现代绿色
  static const Color primaryDark = Color(0xFF00A578); // 深绿色
  static const Color primaryLight = Color(0xFF2DD4AA); // 浅绿色
  static const Color primaryVariant = Color(0xFF7FEFDD); // 绿色变体
  static const Color primarySurface = Color(0xFFF0FFFE); // 主色表面
  
  // 次要品牌色
  static const Color secondary = Color(0xFF6366F1); // 现代紫色
  static const Color secondaryLight = Color(0xFF8B5CF6); // 浅紫色
  static const Color accent = Color(0xFFFF6B6B); // 强调色红
  
  // 背景色彩 - 现代化层级
  static const Color background = Color(0xFFFFFFFF); // 主背景
  static const Color backgroundSecondary = Color(0xFFF8FAFC); // 次要背景
  static const Color backgroundTertiary = Color(0xFFF1F5F9); // 第三背景
  static const Color backgroundGray = Color(0xFFF8F9FA); // 灰色背景
  static const Color backgroundCard = Color(0xFFFFFFFF); // 卡片背景
  static const Color backgroundSurface = Color(0xFFFCFCFD); // 表面背景
  
  // 文字色彩 - 增强对比度
  static const Color textPrimary = Color(0xFF0F172A); // 主要文字
  static const Color textSecondary = Color(0xFF475569); // 次要文字
  static const Color textTertiary = Color(0xFF94A3B8); // 第三文字
  static const Color textHint = Color(0xFFCBD5E1); // 提示文字
  static const Color textInverse = Color(0xFFFFFFFF); // 反色文字
  
  // 功能色彩 - 语义化升级
  static const Color success = Color(0xFF10B981); // 成功色
  static const Color successLight = Color(0xFF6EE7B7); // 浅成功色
  static const Color warning = Color(0xFFF59E0B); // 警告色
  static const Color warningLight = Color(0xFFFDE68A); // 浅警告色
  static const Color error = Color(0xFFEF4444); // 错误色
  static const Color errorLight = Color(0xFFFECACA); // 浅错误色
  static const Color info = Color(0xFF3B82F6); // 信息色
  static const Color infoLight = Color(0xFFDCECFE); // 浅信息色
  
  // 边框和分割线 - 精细化调节
  static const Color border = Color(0xFFE2E8F0); // 边框色
  static const Color borderLight = Color(0xFFF1F5F9); // 浅边框
  static const Color borderStrong = Color(0xFFCBD5E1); // 强边框
  static const Color divider = Color(0xFFE2E8F0); // 分割线
  
  // 阴影色彩 - 现代化阴影系统
  static const Color shadow = Color(0x0F000000); // 基础阴影
  static const Color shadowLight = Color(0x08000000); // 轻阴影
  static const Color shadowMedium = Color(0x15000000); // 中阴影
  static const Color shadowStrong = Color(0x25000000); // 强阴影
  
  // 按钮色彩 - 状态系统
  static const Color buttonPrimary = primary; // 主按钮
  static const Color buttonSecondary = Color(0xFFF1F5F9); // 次按钮
  static const Color buttonGhost = Colors.transparent; // 幽灵按钮
  static const Color buttonDisabled = Color(0xFFE2E8F0); // 禁用按钮
  static const Color buttonHover = Color(0xFF00B085); // 悬停状态
  
  // 营养素色彩 - 现代化配色
  static const Color caloriesColor = Color(0xFFFF6B6B); // 卡路里
  static const Color proteinColor = Color(0xFF4ECDC4); // 蛋白质
  static const Color carbsColor = Color(0xFFFFA726); // 碳水化合物
  static const Color fatColor = Color(0xFFAB47BC); // 脂肪
  static const Color fiberColor = Color(0xFF66BB6A); // 纤维
  
  // 餐次色彩 - 渐变升级
  static const Color breakfastStart = Color(0xFFFFB347); // 早餐渐变起
  static const Color breakfastEnd = Color(0xFFFFCC80); // 早餐渐变止
  static const Color lunchStart = Color(0xFF42A5F5); // 午餐渐变起
  static const Color lunchEnd = Color(0xFF90CAF9); // 午餐渐变止
  static const Color dinnerStart = Color(0xFF9C27B0); // 晚餐渐变起
  static const Color dinnerEnd = Color(0xFFBA68C8); // 晚餐渐变止
  static const Color snackStart = Color(0xFFEC407A); // 零食渐变起
  static const Color snackEnd = Color(0xFFF48FB1); // 零食渐变止
  
  // 渐变色系统 - 现代化升级
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, warningLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFBFCFD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // 餐次渐变
  static const LinearGradient breakfastGradient = LinearGradient(
    colors: [breakfastStart, breakfastEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient lunchGradient = LinearGradient(
    colors: [lunchStart, lunchEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient dinnerGradient = LinearGradient(
    colors: [dinnerStart, dinnerEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient snackGradient = LinearGradient(
    colors: [snackStart, snackEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // 营养素渐变
  static const LinearGradient caloriesGradient = LinearGradient(
    colors: [caloriesColor, Color(0xFFFF8A80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient proteinGradient = LinearGradient(
    colors: [proteinColor, Color(0xFF80E5E0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient carbsGradient = LinearGradient(
    colors: [carbsColor, Color(0xFFFFCC02)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient fatGradient = LinearGradient(
    colors: [fatColor, Color(0xFFCE93D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // 透明度变体 - 增强版
  static Color primaryWithOpacity(double opacity) => primary.withValues(alpha: opacity);
  static Color secondaryWithOpacity(double opacity) => secondary.withValues(alpha: opacity);
  static Color blackWithOpacity(double opacity) => Colors.black.withValues(alpha: opacity);
  static Color whiteWithOpacity(double opacity) => Colors.white.withValues(alpha: opacity);
  static Color shadowWithOpacity(double opacity) => shadow.withValues(alpha: opacity);
  
  // 状态颜色辅助方法
  static Color getStateColor(bool isActive, {Color? activeColor, Color? inactiveColor}) {
    return isActive ? (activeColor ?? primary) : (inactiveColor ?? textTertiary);
  }
  
  static Color getMealColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfastStart;
      case 'lunch':
        return lunchStart;
      case 'dinner':
        return dinnerStart;
      case 'snack':
        return snackStart;
      default:
        return primary;
    }
  }
  
  static LinearGradient getMealGradient(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return breakfastGradient;
      case 'lunch':
        return lunchGradient;
      case 'dinner':
        return dinnerGradient;
      case 'snack':
        return snackGradient;
      default:
        return primaryGradient;
    }
  }
  
  // 深色主题色彩 - 现代化升级
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  
  // 阴影预设 - 现代化分层
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: shadowLight,
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: shadowMedium,
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: shadowLight,
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get strongShadow => [
    BoxShadow(
      color: shadowStrong,
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: shadowMedium,
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
  ];
  
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: shadowLight,
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: shadow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // 特殊效果颜色
  static const Color glassmorphismOverlay = Color(0x19FFFFFF);
  static const Color neumorphismHighlight = Color(0xFFFFFFFF);
  static const Color neumorphismShadow = Color(0xFFE2E8F0);
  
  // 向后兼容的颜色别名
  static const Color cardBackground = backgroundCard;
  static List<BoxShadow> get cardShadowCompat => [
    BoxShadow(
      color: shadowLight,
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: shadow,
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  static const Color breakfastColor = breakfastStart;
  static const Color lunchColor = lunchStart;
  static const Color dinnerColor = dinnerStart;
  static const Color snackColor = snackStart;
} 