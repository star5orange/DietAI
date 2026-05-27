import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pet_state_calculator.dart';
import '../providers/pet_provider.dart';
import 'pet_bubble.dart';

class PetWidget extends ConsumerStatefulWidget {
  final double size;
  final bool draggable;
  final bool showBubble;

  const PetWidget({
    super.key,
    this.size = 128,
    this.draggable = true,
    this.showBubble = true,
  });

  @override
  ConsumerState<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends ConsumerState<PetWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _bubbleController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _bubbleOpacity;
  late Animation<Offset> _bubbleSlide;

  bool _bubbleVisible = false;
  String _bubbleText = '';
  Timer? _autoBubbleTimer;
  Timer? _bubbleHideTimer;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bubbleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );
    _bubbleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bubbleController, curve: Curves.easeOut),
    );

    _startAutoBubble();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _bubbleController.dispose();
    _autoBubbleTimer?.cancel();
    _bubbleHideTimer?.cancel();
    super.dispose();
  }

  void _startAutoBubble() {
    _autoBubbleTimer?.cancel();
    _autoBubbleTimer = Timer.periodic(
      const Duration(minutes: 2, seconds: 30),
      (_) {
        final petState = ref.read(petProvider);
        if (petState.expression == PetExpression.calm ||
            petState.expression == PetExpression.happy) {
          _showBubble(petState.dialogue);
        }
      },
    );
  }

  void _showBubble(String text) {
    if (!widget.showBubble) return;
    if (!mounted) return;

    setState(() {
      _bubbleText = text;
      _bubbleVisible = true;
    });
    _bubbleController.forward();

    _bubbleHideTimer?.cancel();
    _bubbleHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _bubbleController.reverse().then((_) {
        if (mounted) {
          setState(() => _bubbleVisible = false);
        }
      });
    });
  }

  void _onTapPet() {
    _bounceController.forward().then((_) => _bounceController.reverse());
    ref.read(petProvider.notifier).onTap();
    final petState = ref.read(petProvider);
    _showBubble(petState.dialogue);
  }

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_bubbleVisible)
          FadeTransition(
            opacity: _bubbleOpacity,
            child: SlideTransition(
              position: _bubbleSlide,
              child: PetBubble(text: _bubbleText),
            ),
          ),
        if (_bubbleVisible) const SizedBox(height: 6),
        GestureDetector(
          onTap: _onTapPet,
          child: ScaleTransition(
            scale: _bounceAnimation,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.asset(
                petState.gifPath,
                key: ValueKey(petState.gifPath),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                    ),
                    child: const Icon(Icons.pets, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class FloatingPetOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const FloatingPetOverlay({super.key, required this.child});

  @override
  ConsumerState<FloatingPetOverlay> createState() => _FloatingPetOverlayState();
}

class _FloatingPetOverlayState extends ConsumerState<FloatingPetOverlay> {
  double _petLeft = -1;
  double _petTop = -1;
  bool _positionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final storage = ref.read(petProvider.notifier).storage;
    if (storage != null) {
      setState(() {
        _petLeft = storage.positionX;
        _petTop = storage.positionY;
        _positionLoaded = true;
      });
    } else {
      _positionLoaded = true;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    setState(() {
      _petLeft = (_petLeft + details.delta.dx).clamp(0, screenSize.width - 80);
      _petTop = (_petTop + details.delta.dy).clamp(0, screenSize.height - 200);
    });
  }

  void _onPanEnd() {
    final storage = ref.read(petProvider.notifier).storage;
    if (storage != null) {
      storage.positionX = _petLeft;
      storage.positionY = _petTop;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    if (!_positionLoaded) {
      return widget.child;
    }

    if (_petLeft < 0) {
      _petLeft = 16;
      _petTop = screenSize.height - 260;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: _petLeft,
          top: _petTop,
          child: GestureDetector(
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: (_) => _onPanEnd(),
            child: const PetWidget(
              size: 96,
              draggable: true,
              showBubble: true,
            ),
          ),
        ),
      ],
    );
  }
}
