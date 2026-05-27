import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

enum ModernCardVariant { elevated, filled, outlined, glass }

enum ModernCardSize { small, medium, large }

/// 现代化卡片组件 - 支持多种视觉效果
class ModernCard extends StatefulWidget {
  final Widget child;
  final ModernCardVariant variant;
  final ModernCardSize size;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isSelected;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Widget? header;
  final Widget? footer;
  final CrossAxisAlignment alignment;
  final bool showRipple;

  const ModernCard({
    super.key,
    required this.child,
    this.variant = ModernCardVariant.elevated,
    this.size = ModernCardSize.medium,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.isLoading = false,
    this.isSelected = false,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.header,
    this.footer,
    this.alignment = CrossAxisAlignment.start,
    this.showRipple = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (widget.onTap != null) {
      if (isHovered) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  EdgeInsetsGeometry _getPadding() {
    if (widget.padding != null) return widget.padding!;

    switch (widget.size) {
      case ModernCardSize.small:
        return const EdgeInsets.all(12);
      case ModernCardSize.medium:
        return const EdgeInsets.all(16);
      case ModernCardSize.large:
        return const EdgeInsets.all(24);
    }
  }

  EdgeInsetsGeometry _getMargin() {
    if (widget.margin != null) return widget.margin!;

    switch (widget.size) {
      case ModernCardSize.small:
        return const EdgeInsets.all(4);
      case ModernCardSize.medium:
        return const EdgeInsets.all(8);
      case ModernCardSize.large:
        return const EdgeInsets.all(12);
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case ModernCardSize.small:
        return 12;
      case ModernCardSize.medium:
        return 16;
      case ModernCardSize.large:
        return 20;
    }
  }

  Color _getBackgroundColor() {
    if (widget.backgroundColor != null) return widget.backgroundColor!;

    switch (widget.variant) {
      case ModernCardVariant.elevated:
      case ModernCardVariant.filled:
        return widget.isSelected
            ? AppColors.primaryWithOpacity(0.1)
            : AppColors.backgroundCard;
      case ModernCardVariant.outlined:
        return widget.isSelected
            ? AppColors.primaryWithOpacity(0.05)
            : Colors.transparent;
      case ModernCardVariant.glass:
        return AppColors.glassmorphismOverlay;
    }
  }

  List<BoxShadow> _getBoxShadow() {
    switch (widget.variant) {
      case ModernCardVariant.elevated:
        return [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ];
      case ModernCardVariant.filled:
        return AppColors.lightShadow;
      case ModernCardVariant.outlined:
      case ModernCardVariant.glass:
        return [];
    }
  }

  Border? _getBorder() {
    Color borderColor = widget.borderColor ?? AppColors.border;

    switch (widget.variant) {
      case ModernCardVariant.outlined:
        return Border.all(
          color: widget.isSelected ? AppColors.primary : borderColor,
          width: widget.isSelected ? 2 : 1,
        );
      case ModernCardVariant.glass:
        return Border.all(
          color: AppColors.whiteWithOpacity(0.2),
          width: 1,
        );
      case ModernCardVariant.elevated:
      case ModernCardVariant.filled:
        return null;
    }
  }

  Widget _buildContent() {
    List<Widget> children = [];

    if (widget.header != null) {
      children.add(widget.header!);
      children.add(const SizedBox(height: 12));
    }

    children.add(widget.child);

    if (widget.footer != null) {
      children.add(const SizedBox(height: 12));
      children.add(widget.footer!);
    }

    return Column(
      crossAxisAlignment: widget.alignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(_getBorderRadius()),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '加载中...',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        Widget card = Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            margin: _getMargin(),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(_getBorderRadius()),
              border: _getBorder(),
              boxShadow: _getBoxShadow(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_getBorderRadius()),
              child: Stack(
                children: [
                  // 玻璃态效果背景
                  if (widget.variant == ModernCardVariant.glass)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.whiteWithOpacity(0.1),
                              AppColors.whiteWithOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 主要内容
                  Padding(
                    padding: _getPadding(),
                    child: _buildContent(),
                  ),

                  // 加载状态覆盖层
                  if (widget.isLoading) _buildLoadingOverlay(),

                  // 交互覆盖层
                  if (widget.onTap != null)
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.isLoading ? null : widget.onTap,
                          onHover: _handleHover,
                          borderRadius:
                              BorderRadius.circular(_getBorderRadius()),
                          splashColor: widget.showRipple
                              ? AppColors.primaryWithOpacity(0.1)
                              : Colors.transparent,
                          highlightColor: widget.showRipple
                              ? AppColors.primaryWithOpacity(0.05)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        // 为悬停效果添加额外的阴影
        if (_isHovered && widget.onTap != null) {
          return Container(
            decoration: BoxDecoration(
              boxShadow: AppColors.mediumShadow,
              borderRadius: BorderRadius.circular(_getBorderRadius()),
            ),
            child: card,
          );
        }

        return card;
      },
    );
  }
}

/// 现代化卡片头部组件
class ModernCardHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final CrossAxisAlignment alignment;

  const ModernCardHeader({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: alignment,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: AppTextStyles.h6,
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// 现代化卡片底部组件
class ModernCardFooter extends StatelessWidget {
  final List<Widget> actions;
  final MainAxisAlignment alignment;

  const ModernCardFooter({
    super.key,
    required this.actions,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: actions
          .expand((action) => [action, const SizedBox(width: 8)])
          .take(actions.length * 2 - 1)
          .toList(),
    );
  }
}
