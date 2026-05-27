import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

enum ModernButtonVariant { primary, secondary, outline, ghost, gradient }
enum ModernButtonSize { small, medium, large, extraLarge }
enum ModernButtonShape { rounded, pill, square }

/// 现代化按钮组件 - 支持渐变、动画和高级交互
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ModernButtonVariant variant;
  final ModernButtonSize size;
  final ModernButtonShape shape;
  final IconData? icon;
  final bool iconRight;
  final bool isLoading;
  final bool fullWidth;
  final Widget? child;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool showShadow;
  final bool pulse;
  final Duration? animationDuration;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = ModernButtonVariant.primary,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = true,
    this.pulse = false,
    this.animationDuration,
  });

  // 便捷构造函数
  const ModernButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = true,
    this.pulse = false,
    this.animationDuration,
  }) : variant = ModernButtonVariant.primary;

  const ModernButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = true,
    this.pulse = false,
    this.animationDuration,
  }) : variant = ModernButtonVariant.secondary;

  const ModernButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = false,
    this.pulse = false,
    this.animationDuration,
  }) : variant = ModernButtonVariant.outline;

  const ModernButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = false,
    this.pulse = false,
    this.animationDuration,
  }) : variant = ModernButtonVariant.ghost;

  const ModernButton.gradient({
    super.key,
    required this.text,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.shape = ModernButtonShape.rounded,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
    this.gradient,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.showShadow = true,
    this.pulse = false,
    this.animationDuration,
  }) : variant = ModernButtonVariant.gradient;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    final duration = widget.animationDuration ?? const Duration(milliseconds: 150);
    
    _scaleController = AnimationController(duration: duration, vsync: this);
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.ease,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _scaleController.reverse();
    }
  }

  void _handleHover(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered && widget.variant == ModernButtonVariant.gradient) {
      _shimmerController.forward();
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ModernButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case ModernButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
      case ModernButtonSize.extraLarge:
        return const EdgeInsets.symmetric(horizontal: 40, vertical: 20);
    }
  }

  double _getBorderRadius() {
    switch (widget.shape) {
      case ModernButtonShape.rounded:
        switch (widget.size) {
          case ModernButtonSize.small:
            return 8;
          case ModernButtonSize.medium:
            return 12;
          case ModernButtonSize.large:
            return 16;
          case ModernButtonSize.extraLarge:
            return 20;
        }
      case ModernButtonShape.pill:
        return 50;
      case ModernButtonShape.square:
        return 0;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return 16;
      case ModernButtonSize.medium:
        return 20;
      case ModernButtonSize.large:
        return 24;
      case ModernButtonSize.extraLarge:
        return 28;
    }
  }

  Color _getBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    if (widget.onPressed == null) return AppColors.buttonDisabled;

    switch (widget.variant) {
      case ModernButtonVariant.primary:
      case ModernButtonVariant.gradient:
        return AppColors.primary;
      case ModernButtonVariant.secondary:
        return AppColors.backgroundSecondary;
      case ModernButtonVariant.outline:
      case ModernButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _getForegroundColor() {
    if (widget.foregroundColor != null) return widget.foregroundColor!;
    if (widget.onPressed == null) return AppColors.textTertiary;

    switch (widget.variant) {
      case ModernButtonVariant.primary:
      case ModernButtonVariant.gradient:
        return AppColors.textInverse;
      case ModernButtonVariant.secondary:
      case ModernButtonVariant.outline:
      case ModernButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  Gradient? _getGradient() {
    if (widget.gradient != null) return widget.gradient;
    if (widget.variant == ModernButtonVariant.gradient) {
      return AppColors.primaryGradient;
    }
    return null;
  }

  Border? _getBorder() {
    if (widget.variant == ModernButtonVariant.outline) {
      return Border.all(
        color: widget.onPressed == null ? AppColors.border : AppColors.primary,
        width: 1.5,
      );
    }
    return null;
  }

  List<BoxShadow>? _getBoxShadow() {
    if (!widget.showShadow || widget.onPressed == null) return null;
    
    switch (widget.variant) {
      case ModernButtonVariant.primary:
      case ModernButtonVariant.gradient:
        return [
          BoxShadow(
            color: AppColors.primaryWithOpacity(0.3),
            blurRadius: _isPressed ? 4 : 8,
            offset: Offset(0, _isPressed ? 2 : 4),
          ),
        ];
      case ModernButtonVariant.secondary:
        return AppColors.lightShadow;
      case ModernButtonVariant.outline:
      case ModernButtonVariant.ghost:
        return null;
    }
  }

  TextStyle _getTextStyle() {
    TextStyle baseStyle;
    switch (widget.size) {
      case ModernButtonSize.small:
        baseStyle = AppTextStyles.buttonSmall;
        break;
      case ModernButtonSize.medium:
        baseStyle = AppTextStyles.buttonMedium;
        break;
      case ModernButtonSize.large:
        baseStyle = AppTextStyles.buttonLarge;
        break;
      case ModernButtonSize.extraLarge:
        baseStyle = AppTextStyles.buttonLarge.copyWith(fontSize: 18);
        break;
    }

    return baseStyle.copyWith(
      color: _getForegroundColor(),
      fontWeight: FontWeight.w600,
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getForegroundColor()),
            ),
          ),
          const SizedBox(width: 12),
          Text('加载中...', style: _getTextStyle()),
        ],
      );
    }

    if (widget.child != null) {
      return DefaultTextStyle(
        style: _getTextStyle(),
        child: widget.child!,
      );
    }

    final iconWidget = widget.icon != null
        ? Icon(
            widget.icon,
            size: _getIconSize(),
            color: _getForegroundColor(),
          )
        : null;

    if (iconWidget == null) {
      return Text(widget.text, style: _getTextStyle());
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.iconRight
          ? [
              Text(widget.text, style: _getTextStyle()),
              const SizedBox(width: 8),
              iconWidget,
            ]
          : [
              iconWidget,
              const SizedBox(width: 8),
              Text(widget.text, style: _getTextStyle()),
            ],
    );
  }

  Widget _buildShimmerEffect(Widget child) {
    if (widget.variant != ModernButtonVariant.gradient || !_isHovered) {
      return child;
    }

    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        return Stack(
          children: [
            child,
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_getBorderRadius()),
                child: Transform.translate(
                  offset: Offset(_shimmerAnimation.value * 200, 0),
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          AppColors.whiteWithOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _pulseController]),
      builder: (context, child) {
        double scale = _scaleAnimation.value;
        if (widget.pulse) {
          scale *= _pulseAnimation.value;
        }

        Widget button = Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onPressed,
            child: MouseRegion(
              onEnter: (_) => _handleHover(true),
              onExit: (_) => _handleHover(false),
              child: Container(
                width: widget.fullWidth ? double.infinity : null,
                padding: _getPadding(),
                decoration: BoxDecoration(
                  color: _getGradient() == null ? _getBackgroundColor() : null,
                  gradient: _getGradient(),
                  borderRadius: BorderRadius.circular(_getBorderRadius()),
                  border: _getBorder(),
                  boxShadow: _getBoxShadow(),
                ),
                child: Center(child: _buildContent()),
              ),
            ),
          ),
        );

        return _buildShimmerEffect(button);
      },
    );
  }
}

/// 现代化图标按钮
class ModernIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final ModernButtonSize size;
  final ModernButtonVariant variant;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? tooltip;
  final bool showBadge;
  final String? badgeText;

  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = ModernButtonSize.medium,
    this.variant = ModernButtonVariant.ghost,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.showBadge = false,
    this.badgeText,
  });

  @override
  State<ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<ModernIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _getSize() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return 32;
      case ModernButtonSize.medium:
        return 40;
      case ModernButtonSize.large:
        return 48;
      case ModernButtonSize.extraLarge:
        return 56;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case ModernButtonSize.small:
        return 16;
      case ModernButtonSize.medium:
        return 20;
      case ModernButtonSize.large:
        return 24;
      case ModernButtonSize.extraLarge:
        return 28;
    }
  }

  Color _getBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    if (widget.onPressed == null) return AppColors.buttonDisabled;

    switch (widget.variant) {
      case ModernButtonVariant.primary:
        return AppColors.primary;
      case ModernButtonVariant.secondary:
        return AppColors.backgroundSecondary;
      case ModernButtonVariant.outline:
      case ModernButtonVariant.ghost:
        return Colors.transparent;
      case ModernButtonVariant.gradient:
        return AppColors.primary;
    }
  }

  Color _getForegroundColor() {
    if (widget.foregroundColor != null) return widget.foregroundColor!;
    if (widget.onPressed == null) return AppColors.textTertiary;

    switch (widget.variant) {
      case ModernButtonVariant.primary:
      case ModernButtonVariant.gradient:
        return AppColors.textInverse;
      case ModernButtonVariant.secondary:
      case ModernButtonVariant.outline:
      case ModernButtonVariant.ghost:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onTap: widget.onPressed,
            child: Container(
              width: _getSize(),
              height: _getSize(),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(_getSize() / 2),
                border: widget.variant == ModernButtonVariant.outline
                    ? Border.all(color: AppColors.border)
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: _getIconSize(),
                color: _getForegroundColor(),
              ),
            ),
          ),
        );
      },
    );

    if (widget.showBadge) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: widget.badgeText != null
                  ? Text(
                      widget.badgeText!,
                      style: AppTextStyles.withColor(
                        AppTextStyles.bodyXSmall,
                        AppColors.textInverse,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : null,
            ),
          ),
        ],
      );
    }

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}