import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, ghost }
enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool iconRight;
  final bool isLoading;
  final bool fullWidth;
  final Widget? child;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
  });

  const AppButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.iconRight = false,
    this.isLoading = false,
    this.fullWidth = false,
    this.child,
  }) : variant = AppButtonVariant.ghost;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 0.3,
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

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 8;
      case AppButtonSize.medium:
        return 12;
      case AppButtonSize.large:
        return 16;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  Color _getBackgroundColor() {
    if (widget.onPressed == null) {
      return AppColors.buttonDisabled;
    }

    switch (widget.variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.backgroundSecondary;
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    if (widget.onPressed == null) {
      return AppColors.textTertiary;
    }

    switch (widget.variant) {
      case AppButtonVariant.primary:
        return Colors.white;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return AppColors.primary;
    }
  }

  Border? _getBorder() {
    if (widget.variant == AppButtonVariant.outline) {
      return Border.all(
        color: widget.onPressed == null ? AppColors.border : AppColors.primary,
        width: 1.5,
      );
    }
    return null;
  }

  List<BoxShadow>? _getBoxShadow() {
    if (widget.variant == AppButtonVariant.primary && widget.onPressed != null) {
      return [
        BoxShadow(
          color: AppColors.primaryWithOpacity(0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return null;
  }

  TextStyle _getTextStyle() {
    TextStyle baseStyle;
    switch (widget.size) {
      case AppButtonSize.small:
        baseStyle = AppTextStyles.buttonSmall;
        break;
      case AppButtonSize.medium:
        baseStyle = AppTextStyles.buttonMedium;
        break;
      case AppButtonSize.large:
        baseStyle = AppTextStyles.buttonLarge;
        break;
    }

    return baseStyle.copyWith(
      fontWeight: FontWeight.w600,
      color: _getTextColor(),
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
              valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
            ),
          ),
          const SizedBox(width: 8),
          Text('加载中...', style: _getTextStyle()),
        ],
      );
    }

    if (widget.child != null) {
      return widget.child!;
    }

    final iconWidget = widget.icon != null
        ? Icon(
            widget.icon,
            size: _getIconSize(),
            color: _getTextColor(),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onPressed,
            child: Container(
              width: widget.fullWidth ? double.infinity : null,
              padding: _getPadding(),
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(_getBorderRadius()),
                border: _getBorder(),
                boxShadow: _getBoxShadow(),
              ),
              child: Stack(
                children: [
                  if (widget.variant == AppButtonVariant.primary)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: _glowAnimation.value),
                          borderRadius: BorderRadius.circular(_getBorderRadius()),
                        ),
                      ),
                    ),
                  Center(child: _buildContent()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
