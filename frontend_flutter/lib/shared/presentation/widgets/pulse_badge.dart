import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

enum PulseBadgeType { filled, outline }
enum PulseBadgeSize { small, medium, large }

class PulseBadge extends StatefulWidget {
  final String text;
  final PulseBadgeType type;
  final PulseBadgeSize size;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool showPulse;
  final VoidCallback? onTap;

  const PulseBadge({
    super.key,
    required this.text,
    this.type = PulseBadgeType.filled,
    this.size = PulseBadgeSize.medium,
    this.color,
    this.textColor,
    this.icon,
    this.showPulse = false,
    this.onTap,
  });

  // 便捷构造函数
  const PulseBadge.ai({
    super.key,
    this.text = 'AI教练',
    this.type = PulseBadgeType.filled,
    this.size = PulseBadgeSize.medium,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
    this.icon = LucideIcons.bot,
    this.showPulse = false,
    this.onTap,
  });

  const PulseBadge.notification({
    super.key,
    required this.text,
    this.type = PulseBadgeType.filled,
    this.size = PulseBadgeSize.small,
    this.color = const Color(0xFFFF9800),
    this.textColor = Colors.white,
    this.icon,
    this.showPulse = true,
    this.onTap,
  });

  const PulseBadge.pro({
    super.key,
    this.text = 'PRO',
    this.type = PulseBadgeType.filled,
    this.size = PulseBadgeSize.small,
    this.color = AppColors.primary,
    this.textColor = Colors.white,
    this.icon,
    this.showPulse = false,
    this.onTap,
  });

  @override
  State<PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<PulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.showPulse != widget.showPulse) {
      if (widget.showPulse) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case PulseBadgeSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case PulseBadgeSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case PulseBadgeSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case PulseBadgeSize.small:
        return 12;
      case PulseBadgeSize.medium:
        return 16;
      case PulseBadgeSize.large:
        return 20;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case PulseBadgeSize.small:
        return 12;
      case PulseBadgeSize.medium:
        return 16;
      case PulseBadgeSize.large:
        return 20;
    }
  }

  TextStyle _getTextStyle() {
    TextStyle baseStyle;
    switch (widget.size) {
      case PulseBadgeSize.small:
        baseStyle = AppTextStyles.bodyXSmall;
        break;
      case PulseBadgeSize.medium:
        baseStyle = AppTextStyles.bodySmall;
        break;
      case PulseBadgeSize.large:
        baseStyle = AppTextStyles.bodyMedium;
        break;
    }

    return baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: _getTextColor(),
    );
  }

  Color _getBackgroundColor() {
    final color = widget.color ?? AppColors.primary;
    
    switch (widget.type) {
      case PulseBadgeType.filled:
        return color;
      case PulseBadgeType.outline:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    if (widget.textColor != null) {
      return widget.textColor!;
    }

    final color = widget.color ?? AppColors.primary;
    
    switch (widget.type) {
      case PulseBadgeType.filled:
        return Colors.white;
      case PulseBadgeType.outline:
        return color;
    }
  }

  Border? _getBorder() {
    if (widget.type == PulseBadgeType.outline) {
      final color = widget.color ?? AppColors.primary;
      return Border.all(
        color: color,
        width: 1,
      );
    }
    return null;
  }

  Widget _buildContent() {
    final children = <Widget>[];

    if (widget.icon != null) {
      children.add(Icon(
        widget.icon,
        size: _getIconSize(),
        color: _getTextColor(),
      ));

      if (widget.text.isNotEmpty) {
        children.add(const SizedBox(width: 4));
      }
    }

    if (widget.text.isNotEmpty) {
      children.add(Text(
        widget.text,
        style: _getTextStyle(),
      ));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: _getPadding(),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        border: _getBorder(),
        boxShadow: widget.type == PulseBadgeType.filled
            ? [
                BoxShadow(
                  color: (widget.color ?? AppColors.primary).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: _buildContent(),
    );

    // 添加脉冲动画
    if (widget.showPulse) {
      badge = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: badge,
          );
        },
      );
    }

    // 添加点击事件
    if (widget.onTap != null) {
      badge = GestureDetector(
        onTap: widget.onTap,
        child: badge,
      );
    }

    return badge;
  }
} 