import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

enum AppInputType { text, password, email, number, search }

class AppInput extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final AppInputType type;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final bool showCounter;

  const AppInput({
    super.key,
    this.label,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.controller,
    this.type = AppInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.validator,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  late Animation<Color?> _borderColorAnimation;
  
  bool _obscureText = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _obscureText = widget.type == AppInputType.password;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _focusAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _borderColorAnimation = ColorTween(
      begin: AppColors.border,
      end: AppColors.primary,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case AppInputType.email:
        return TextInputType.emailAddress;
      case AppInputType.number:
        return TextInputType.number;
      case AppInputType.password:
        return TextInputType.visiblePassword;
      default:
        return TextInputType.text;
    }
  }

  Widget? _buildPrefixIcon() {
    if (widget.prefixIcon == null) return null;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Icon(
        widget.prefixIcon,
        color: _isFocused ? AppColors.primary : AppColors.textTertiary,
        size: 20,
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    IconData? iconData;
    VoidCallback? onPressed;

    if (widget.type == AppInputType.password) {
      iconData = _obscureText ? LucideIcons.eyeOff : LucideIcons.eye;
      onPressed = _togglePasswordVisibility;
    } else if (widget.suffixIcon != null) {
      iconData = widget.suffixIcon;
      onPressed = widget.onSuffixIconPressed;
    }

    if (iconData == null) return null;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        icon: Icon(
          iconData,
          color: _isFocused ? AppColors.primary : AppColors.textTertiary,
          size: 20,
        ),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _focusAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.label != null) ...[
                Text(
                  widget.label!,
                  style: AppTextStyles.inputLabel.copyWith(
                    color: hasError ? AppColors.error : null,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isFocused && !hasError
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: _obscureText,
                  enabled: widget.enabled,
                  readOnly: widget.readOnly,
                  maxLines: widget.maxLines,
                  maxLength: widget.maxLength,
                  keyboardType: _getKeyboardType(),
                  textInputAction: widget.textInputAction,
                  validator: widget.validator,
                  onChanged: widget.onChanged,
                  onEditingComplete: widget.onEditingComplete,
                  onFieldSubmitted: widget.onSubmitted,
                  style: AppTextStyles.inputText.copyWith(
                    color: widget.enabled ? null : AppColors.textTertiary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTextStyles.inputHint,
                    prefixIcon: _buildPrefixIcon(),
                    suffixIcon: _buildSuffixIcon(),
                    filled: true,
                    fillColor: widget.enabled 
                        ? (_isFocused ? AppColors.background : AppColors.backgroundSecondary)
                        : AppColors.backgroundSecondary.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.error : AppColors.border,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.error : _borderColorAnimation.value!,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    counterText: widget.showCounter ? null : '',
                  ),
                ),
              ),

              if (widget.helperText != null || widget.errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.errorText ?? widget.helperText!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: hasError ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
