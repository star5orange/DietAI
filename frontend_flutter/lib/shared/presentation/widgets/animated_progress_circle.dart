import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

class AnimatedProgressCircle extends StatefulWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final int? currentValue;
  final int? targetValue;
  final String? label;
  final Color? color;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPulse;
  final Duration animationDuration;
  final Widget? child;

  const AnimatedProgressCircle({
    super.key,
    required this.progress,
    this.currentValue,
    this.targetValue,
    this.label,
    this.size = 160,
    this.strokeWidth = 8,
    this.color,
    this.progressColor,
    this.backgroundColor,
    this.showPulse = true,
    this.animationDuration = const Duration(milliseconds: 1500),
    this.child,
  });

  @override
  State<AnimatedProgressCircle> createState() => _AnimatedProgressCircleState();
}

class _AnimatedProgressCircleState extends State<AnimatedProgressCircle>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _numberController;
  late AnimationController _pulseController;

  late Animation<double> _progressAnimation;
  late Animation<double> _numberAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _numberController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _numberAnimation = Tween<double>(
      begin: 0.0,
      end: (widget.currentValue ?? 0).toDouble(),
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    _progressController.forward();
    _numberController.forward();

    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedProgressCircle oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.progress != widget.progress ||
        oldWidget.currentValue != widget.currentValue) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _numberAnimation = Tween<double>(
      begin: _numberAnimation.value,
      end: (widget.currentValue ?? 0).toDouble(),
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeInOut,
    ));

    _progressController.reset();
    _numberController.reset();
    _progressController.forward();
    _numberController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _numberController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.progressColor ?? widget.color ?? AppColors.primary;
    final backgroundColor = widget.backgroundColor ?? AppColors.border;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _progressController,
        _numberController,
        _pulseController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: widget.showPulse ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: CircularProgressPainter(
                    progress: _progressAnimation.value,
                    strokeWidth: widget.strokeWidth,
                    color: effectiveColor,
                    backgroundColor: backgroundColor,
                  ),
                ),
                if (widget.child != null)
                  widget.child!
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _numberAnimation,
                        builder: (context, child) {
                          return Text(
                            _numberAnimation.value.round().toString(),
                            style: AppTextStyles.displaySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                      if (widget.label != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.label!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (widget.targetValue != null &&
                          widget.targetValue != widget.currentValue)
                        Text(
                          '/ ${widget.targetValue}',
                          style: AppTextStyles.bodyXSmall.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;

  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
