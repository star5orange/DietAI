import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// 应用主题配置 - 现代化升级 2.0
class AppTheme {
  /// 亮色主题 - 现代化设计系统
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // 颜色方案 - 现代化调色板
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.textInverse,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: AppColors.textPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textInverse,
        secondaryContainer: AppColors.backgroundSecondary,
        onSecondaryContainer: AppColors.textPrimary,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textInverse,
        surface: AppColors.backgroundCard,
        onSurface: AppColors.textPrimary,
        surfaceVariant: AppColors.backgroundSecondary,
        onSurfaceVariant: AppColors.textSecondary,
        background: AppColors.background,
        onBackground: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textInverse,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
        shadow: AppColors.shadow,
        scrim: AppColors.shadowMedium,
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.textInverse,
        inversePrimary: AppColors.primaryLight,
      ),

      // 脚手架背景色
      scaffoldBackgroundColor: AppColors.background,

      // 文字主题
      textTheme: TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.h4,
        titleMedium: AppTextStyles.h5,
        titleSmall: AppTextStyles.h6,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),

      // 应用栏主题
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.shadowLight,
        titleTextStyle: AppTextStyles.h5,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.textSecondary,
          size: 22,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        color: AppColors.backgroundCard,
        elevation: 0,
        shadowColor: AppColors.shadowLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          elevation: 0,
          shadowColor: AppColors.primaryWithOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          textStyle: AppTextStyles.buttonMedium,
          minimumSize: const Size(120, 48),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryWithOpacity(0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primaryWithOpacity(0.05);
            }
            return null;
          }),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return 2;
            }
            if (states.contains(WidgetState.hovered)) {
              return 4;
            }
            return 0;
          }),
        ),
      ),

      // 文本按钮主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.buttonMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryWithOpacity(0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primaryWithOpacity(0.05);
            }
            return null;
          }),
        ),
      ),

      // 轮廓按钮主题
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.transparent,
          textStyle: AppTextStyles.buttonMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(
            color: AppColors.border,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 16,
          ),
          minimumSize: const Size(120, 48),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return BorderSide(color: AppColors.primary, width: 2);
            }
            if (states.contains(WidgetState.focused)) {
              return BorderSide(color: AppColors.primary, width: 1.5);
            }
            return const BorderSide(color: AppColors.border, width: 1.5);
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryWithOpacity(0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primaryWithOpacity(0.05);
            }
            return null;
          }),
        ),
      ),

      // 图标按钮主题
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          minimumSize: const Size(48, 48),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppColors.primaryWithOpacity(0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppColors.primaryWithOpacity(0.05);
            }
            return null;
          }),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.borderLight,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: AppTextStyles.inputHint,
        labelStyle: AppTextStyles.inputLabel,
        errorStyle:
            AppTextStyles.withColor(AppTextStyles.bodySmall, AppColors.error),
        helperStyle: AppTextStyles.withColor(
            AppTextStyles.bodySmall, AppColors.textTertiary),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        alignLabelWithHint: true,
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: AppTextStyles.labelSmall,
        unselectedLabelStyle:
            AppTextStyles.withOpacity(AppTextStyles.labelSmall, 0.7),
        landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
      ),

      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.backgroundCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        shadowColor: AppColors.shadowMedium,
        titleTextStyle: AppTextStyles.h5,
        contentTextStyle: AppTextStyles.bodyMedium,
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.center,
      ),

      // 底部表单主题
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.backgroundCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 0,
        shadowColor: AppColors.shadowMedium,
        modalBackgroundColor: AppColors.backgroundCard,
        modalElevation: 0,
        clipBehavior: Clip.antiAlias,
        dragHandleColor: AppColors.borderStrong,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // 分割线主题
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // 浮动操作按钮主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        elevation: 0,
        highlightElevation: 2,
        disabledElevation: 0,
        shape: const CircleBorder(),
        iconSize: 24,
        sizeConstraints: const BoxConstraints(
          minWidth: 56,
          minHeight: 56,
          maxWidth: 56,
          maxHeight: 56,
        ),
      ),

      // 进度指示器主题
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.borderLight,
        circularTrackColor: AppColors.borderLight,
        linearMinHeight: 6,
        refreshBackgroundColor: AppColors.backgroundCard,
      ),

      // 列表瓦片主题
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTextStyles.bodyLarge,
        subtitleTextStyle: AppTextStyles.bodySmall,
        leadingAndTrailingTextStyle: AppTextStyles.bodyMedium,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.primaryWithOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        horizontalTitleGap: 16,
        minVerticalPadding: 8,
        enableFeedback: true,
        visualDensity: VisualDensity.standard,
      ),

      // 切换开关主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textTertiary;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.backgroundCard;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryWithOpacity(0.5);
          }
          return AppColors.border;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return AppColors.border;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),

      // 复选框主题
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textInverse),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryWithOpacity(0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primaryWithOpacity(0.05);
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: BorderSide(
          color: AppColors.border,
          width: 2,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),

      // 单选按钮主题
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.borderLight;
          }
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryWithOpacity(0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primaryWithOpacity(0.05);
          }
          return null;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
      ),

      // 滑块主题
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.borderLight,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primaryWithOpacity(0.1),
        valueIndicatorColor: AppColors.primary,
        valueIndicatorTextStyle: AppTextStyles.withColor(
            AppTextStyles.bodySmall, AppColors.textInverse),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        trackShape: const RoundedRectSliderTrackShape(),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),

      // 芯片主题
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundSecondary,
        deleteIconColor: AppColors.textTertiary,
        disabledColor: AppColors.borderLight,
        selectedColor: AppColors.primaryWithOpacity(0.1),
        secondarySelectedColor: AppColors.primaryWithOpacity(0.05),
        shadowColor: Colors.transparent,
        selectedShadowColor: Colors.transparent,
        checkmarkColor: AppColors.primary,
        labelStyle: AppTextStyles.bodySmall,
        secondaryLabelStyle: AppTextStyles.withColor(
            AppTextStyles.bodySmall, AppColors.textSecondary),
        brightness: Brightness.light,
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),

      // 标签栏主题
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: AppTextStyles.labelMedium,
        unselectedLabelStyle:
            AppTextStyles.withOpacity(AppTextStyles.labelMedium, 0.7),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.divider,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return AppColors.primaryWithOpacity(0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primaryWithOpacity(0.05);
          }
          return null;
        }),
        splashFactory: InkRipple.splashFactory,
        mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      ),

      // 工具提示主题
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTextStyles.withColor(
            AppTextStyles.bodySmall, AppColors.textInverse),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(8),
        preferBelow: true,
        verticalOffset: 24,
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 1500),
      ),

      // 徽章主题
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.error,
        textColor: AppColors.textInverse,
        smallSize: 8,
        largeSize: 16,
        textStyle: AppTextStyles.withColor(
            AppTextStyles.bodyXSmall, AppColors.textInverse),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        alignment: AlignmentDirectional.topEnd,
        offset: const Offset(-4, 4),
      ),

      // 搜索栏主题
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.all(AppColors.backgroundSecondary),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        overlayColor:
            WidgetStateProperty.all(AppColors.primaryWithOpacity(0.05)),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        side: WidgetStateProperty.all(
            BorderSide(color: AppColors.border, width: 1)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        textStyle: WidgetStateProperty.all(AppTextStyles.bodyMedium),
        hintStyle: WidgetStateProperty.all(AppTextStyles.inputHint),
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      ),

      // 搜索视图主题
      searchViewTheme: SearchViewThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        side: BorderSide(color: AppColors.border, width: 1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        headerTextStyle: AppTextStyles.bodyMedium,
        headerHintStyle: AppTextStyles.inputHint,
        dividerColor: AppColors.divider,
      ),

      // 延展配置
      extensions: <ThemeExtension<dynamic>>[
        _CustomThemeExtension(
          glassmorphismOverlay: AppColors.glassmorphismOverlay,
          neumorphismHighlight: AppColors.neumorphismHighlight,
          neumorphismShadow: AppColors.neumorphismShadow,
        ),
      ],
    );
  }

  /// 暗色主题
  static ThemeData get darkTheme {
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.textInverse,
        primaryContainer: AppColors.darkCard,
        onPrimaryContainer: AppColors.darkTextPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textInverse,
        secondaryContainer: AppColors.darkSurface,
        onSecondaryContainer: AppColors.darkTextSecondary,
        tertiary: AppColors.accent,
        onTertiary: AppColors.textInverse,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        surfaceVariant: AppColors.darkSurface,
        onSurfaceVariant: AppColors.darkTextSecondary,
        background: AppColors.darkBackground,
        onBackground: AppColors.darkTextPrimary,
        error: AppColors.error,
        onError: AppColors.textInverse,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.borderLight,
        shadow: AppColors.shadowStrong,
        scrim: AppColors.shadowStrong,
        inverseSurface: AppColors.darkTextPrimary,
        onInverseSurface: AppColors.darkBackground,
        inversePrimary: AppColors.primaryDark,
      ),

      // 更多暗色主题特定配置...
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shadowColor: AppColors.shadowStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.shadowStrong,
        titleTextStyle: AppTextStyles.withColor(
            AppTextStyles.h5, AppColors.darkTextPrimary),
        centerTitle: false,
        iconTheme: IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: AppColors.darkTextSecondary,
          size: 22,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );
  }
}

// 自定义主题扩展
@immutable
class _CustomThemeExtension extends ThemeExtension<_CustomThemeExtension> {
  const _CustomThemeExtension({
    required this.glassmorphismOverlay,
    required this.neumorphismHighlight,
    required this.neumorphismShadow,
  });

  final Color glassmorphismOverlay;
  final Color neumorphismHighlight;
  final Color neumorphismShadow;

  @override
  _CustomThemeExtension copyWith({
    Color? glassmorphismOverlay,
    Color? neumorphismHighlight,
    Color? neumorphismShadow,
  }) {
    return _CustomThemeExtension(
      glassmorphismOverlay: glassmorphismOverlay ?? this.glassmorphismOverlay,
      neumorphismHighlight: neumorphismHighlight ?? this.neumorphismHighlight,
      neumorphismShadow: neumorphismShadow ?? this.neumorphismShadow,
    );
  }

  @override
  _CustomThemeExtension lerp(
      ThemeExtension<_CustomThemeExtension>? other, double t) {
    if (other is! _CustomThemeExtension) {
      return this;
    }
    return _CustomThemeExtension(
      glassmorphismOverlay:
          Color.lerp(glassmorphismOverlay, other.glassmorphismOverlay, t)!,
      neumorphismHighlight:
          Color.lerp(neumorphismHighlight, other.neumorphismHighlight, t)!,
      neumorphismShadow:
          Color.lerp(neumorphismShadow, other.neumorphismShadow, t)!,
    );
  }
}
