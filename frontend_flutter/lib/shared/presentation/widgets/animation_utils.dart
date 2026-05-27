import 'package:flutter/material.dart';

/// 动画时长常量
class AnimationDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 800);
}

/// 动画曲线常量
class AnimationCurves {
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve bounceIn = Curves.bounceIn;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve elasticOut = Curves.elasticOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
}

/// 淡入动画组件
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final VoidCallback? onComplete;

  const FadeInAnimation({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.onComplete,
  });

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    // 延迟启动动画
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }
}

/// 滑入动画组件
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final Offset beginOffset;
  final VoidCallback? onComplete;

  const SlideInAnimation({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.3),
    this.onComplete,
  });

  const SlideInAnimation.fromBottom({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.onComplete,
  }) : beginOffset = const Offset(0, 0.3);

  const SlideInAnimation.fromTop({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.onComplete,
  }) : beginOffset = const Offset(0, -0.3);

  const SlideInAnimation.fromLeft({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.onComplete,
  }) : beginOffset = const Offset(0.3, 0);

  const SlideInAnimation.fromRight({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.easeOut,
    this.delay = Duration.zero,
    this.onComplete,
  }) : beginOffset = const Offset(-0.3, 0);

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 缩放动画组件
class ScaleInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Duration delay;
  final double beginScale;
  final VoidCallback? onComplete;

  const ScaleInAnimation({
    super.key,
    required this.child,
    this.duration = AnimationDurations.medium,
    this.curve = AnimationCurves.elasticOut,
    this.delay = Duration.zero,
    this.beginScale = 0.0,
    this.onComplete,
  });

  @override
  State<ScaleInAnimation> createState() => _ScaleInAnimationState();
}

class _ScaleInAnimationState extends State<ScaleInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.beginScale,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// 交错动画构建器
class StaggeredAnimationBuilder extends StatefulWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration staggerDelay;
  final Curve curve;
  final Axis direction;

  const StaggeredAnimationBuilder({
    super.key,
    required this.children,
    this.duration = AnimationDurations.medium,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.curve = AnimationCurves.easeOut,
    this.direction = Axis.vertical,
  });

  @override
  State<StaggeredAnimationBuilder> createState() => _StaggeredAnimationBuilderState();
}

class _StaggeredAnimationBuilderState extends State<StaggeredAnimationBuilder> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        final delay = widget.staggerDelay * index;

        return SlideInAnimation(
          delay: delay,
          duration: widget.duration,
          curve: widget.curve,
          beginOffset: widget.direction == Axis.vertical 
              ? const Offset(0, 0.3) 
              : const Offset(0.3, 0),
          child: child,
        );
      }).toList(),
    );
  }
}

/// 脉冲动画组件
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  final bool infinite;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 1.0,
    this.maxScale = 1.1,
    this.infinite = true,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.infinite) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// 摇摆动画组件
class ShakeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double displacement;
  final int count;

  const ShakeAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.displacement = 10.0,
    this.count = 3,
  });

  @override
  State<ShakeAnimation> createState() => _ShakeAnimationState();
}

class _ShakeAnimationState extends State<ShakeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final progress = _shakeAnimation.value;
        final offset = widget.displacement * 
            (1 - progress) * 
            (0.5 - (progress * widget.count % 1 - 0.5).abs()) * 2;
        
        return Transform.translate(
          offset: Offset(offset, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// 页面转场动画
class PageTransitionBuilder {
  static Widget slideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.ease;

    var tween = Tween(begin: begin, end: end).chain(
      CurveTween(curve: curve),
    );

    return SlideTransition(
      position: animation.drive(tween),
      child: child,
    );
  }

  static Widget fadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  }

  static Widget scaleTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: animation,
        curve: Curves.elasticOut,
      ),
      child: child,
    );
  }
}

/// 自定义页面路由
class ModernPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final String transitionType;

  ModernPageRoute({
    required this.child,
    this.transitionType = 'slide',
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: AnimationDurations.medium,
          reverseTransitionDuration: AnimationDurations.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transitionType) {
              case 'fade':
                return PageTransitionBuilder.fadeTransition(
                  context, animation, secondaryAnimation, child,
                );
              case 'scale':
                return PageTransitionBuilder.scaleTransition(
                  context, animation, secondaryAnimation, child,
                );
              default:
                return PageTransitionBuilder.slideTransition(
                  context, animation, secondaryAnimation, child,
                );
            }
          },
        );
}