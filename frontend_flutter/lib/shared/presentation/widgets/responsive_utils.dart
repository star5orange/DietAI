import 'package:flutter/material.dart';

/// 响应式断点定义
class ResponsiveBreakpoints {
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;
  static const double largeDesktop = 1440;
}

/// 设备类型枚举
enum DeviceType { mobile, tablet, desktop, largeDesktop }

/// 响应式工具类
class ResponsiveUtils {
  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < ResponsiveBreakpoints.mobile) {
      return DeviceType.mobile;
    } else if (width < ResponsiveBreakpoints.tablet) {
      return DeviceType.mobile;
    } else if (width < ResponsiveBreakpoints.desktop) {
      return DeviceType.tablet;
    } else if (width < ResponsiveBreakpoints.largeDesktop) {
      return DeviceType.desktop;
    } else {
      return DeviceType.largeDesktop;
    }
  }

  /// 判断是否为移动设备
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }

  /// 判断是否为平板设备
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }

  /// 判断是否为桌面设备
  static bool isDesktop(BuildContext context) {
    final type = getDeviceType(context);
    return type == DeviceType.desktop || type == DeviceType.largeDesktop;
  }

  /// 获取响应式值
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    final deviceType = getDeviceType(context);

    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
    }
  }

  /// 获取响应式边距
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context) {
    return getValue(
      context,
      mobile: const EdgeInsets.all(16),
      tablet: const EdgeInsets.all(24),
      desktop: const EdgeInsets.all(32),
      largeDesktop: const EdgeInsets.all(40),
    );
  }

  /// 获取响应式列数
  static int getResponsiveColumns(BuildContext context) {
    return getValue(
      context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      largeDesktop: 4,
    );
  }

  /// 获取响应式字体大小
  static double getResponsiveFontSize(
      BuildContext context, double baseFontSize) {
    final factor = getValue(
      context,
      mobile: 1.0,
      tablet: 1.1,
      desktop: 1.2,
      largeDesktop: 1.3,
    );
    return baseFontSize * factor;
  }

  /// 获取响应式间距
  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final factor = getValue(
      context,
      mobile: 1.0,
      tablet: 1.2,
      desktop: 1.4,
      largeDesktop: 1.6,
    );
    return baseSpacing * factor;
  }
}

/// 响应式构建器组件
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    return builder(context, deviceType);
  }
}

/// 响应式布局组件
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, deviceType) {
        switch (deviceType) {
          case DeviceType.mobile:
            return mobile;
          case DeviceType.tablet:
            return tablet ?? mobile;
          case DeviceType.desktop:
            return desktop ?? tablet ?? mobile;
          case DeviceType.largeDesktop:
            return largeDesktop ?? desktop ?? tablet ?? mobile;
        }
      },
    );
  }
}

/// 响应式网格组件
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? largeDesktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.largeDesktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveUtils.getValue(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
      largeDesktop: largeDesktopColumns ?? 4,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// 响应式容器组件
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool centerContent;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final double effectiveMaxWidth = maxWidth ??
        ResponsiveUtils.getValue(
          context,
          mobile: double.infinity,
          tablet: 800,
          desktop: 1200,
          largeDesktop: 1400,
        );

    final effectivePadding =
        padding ?? ResponsiveUtils.getResponsivePadding(context);

    Widget container = Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      padding: effectivePadding,
      child: child,
    );

    if (centerContent) {
      container = Center(child: container);
    }

    return container;
  }
}

/// 响应式间距组件
class ResponsiveSpacing extends StatelessWidget {
  final double height;
  final double? width;

  const ResponsiveSpacing({
    super.key,
    required this.height,
    this.width,
  });

  const ResponsiveSpacing.horizontal({
    super.key,
    required double width,
  })  : height = 0,
        width = width;

  const ResponsiveSpacing.vertical({
    super.key,
    required this.height,
  }) : width = null;

  @override
  Widget build(BuildContext context) {
    final responsiveHeight =
        ResponsiveUtils.getResponsiveSpacing(context, height);
    final responsiveWidth = width != null
        ? ResponsiveUtils.getResponsiveSpacing(context, width!)
        : null;

    return SizedBox(
      height: responsiveHeight,
      width: responsiveWidth,
    );
  }
}

/// 响应式文字大小扩展
extension ResponsiveTextStyle on TextStyle {
  TextStyle responsive(BuildContext context) {
    final responsiveFontSize = ResponsiveUtils.getResponsiveFontSize(
      context,
      fontSize ?? 14,
    );
    return copyWith(fontSize: responsiveFontSize);
  }
}
