import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../shared/utils/species_utils.dart';

/// 宠物形象展示组件
/// P1：真实 GIF 帧动画 + 降级伪动画（呼吸/眨眼/微旋转）
class PetAvatarDisplay extends StatefulWidget {
  final String emotion;
  final double size;
  final bool enableAnimation;
  final String? customImageUrl;
  final Map<String, String>? emotionUrls; // AI 情绪变体 URL 映射
  final String? breed;
  final String? species;

  const PetAvatarDisplay({
    super.key,
    this.emotion = 'normal',
    this.size = 100,
    this.enableAnimation = true,
    this.customImageUrl,
    this.emotionUrls,
    this.breed,
    this.species,
  });

  @override
  State<PetAvatarDisplay> createState() => _PetAvatarDisplayState();
}

class _PetAvatarDisplayState extends State<PetAvatarDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _breathAnimation;
  Timer? _blinkTimer;
  bool _isBlinking = false;
  bool _hasGifError = false;

  // 情绪切换：AnimatedCrossFade 状态
  String? _previousImageUrl;
  bool _showNewEmotion = true;

  // 情绪 → GIF 资源映射
  static const _emotionGifs = {
    'happy': 'assets/pet/christine/happy.gif',
    'normal': 'assets/pet/christine/normal.gif',
    'calm': 'assets/pet/christine/normal.gif',
    'hungry': 'assets/pet/christine/hungry.gif',
    'weak': 'assets/pet/christine/weak.gif',
    'expect': 'assets/pet/christine/expect.gif',
    'anxious': 'assets/pet/christine/anxious.gif',
    'satisfied': 'assets/pet/christine/happy.gif',
  };

  // 情绪颜色
  static const _emotionColors = {
    'happy': Color(0xFF4CAF50),
    'normal': Color(0xFF2196F3),
    'calm': Color(0xFF2196F3),
    'hungry': Color(0xFFFF9800),
    'weak': Color(0xFF9E9E9E),
    'expect': Color(0xFF00BCD4),
    'anxious': Color(0xFFF44336),
    'satisfied': Color(0xFF4CAF50),
  };

  static const _emotionIcons = {
    'happy': Icons.sentiment_satisfied,
    'normal': Icons.pets,
    'calm': Icons.pets,
    'hungry': Icons.sentiment_dissatisfied,
    'weak': Icons.sentiment_very_dissatisfied,
    'expect': Icons.sentiment_satisfied,
    'anxious': Icons.sentiment_dissatisfied,
    'satisfied': Icons.sentiment_satisfied,
  };

  static const _breedColors = {
    '橘猫': Color(0xFFFF9800),
    '英短（英国短毛猫）': Color(0xFF607D8B),
    '布偶猫': Color(0xFFF5E6D3),
    '暹罗猫': Color(0xFFD7CCC8),
    '中华田园猫': Color(0xFF9E9E9E),
    '泰迪（贵宾犬）': Color(0xFF795548),
    '柯基': Color(0xFFFFC107),
    '金毛': Color(0xFFFFB74D),
    '哈士奇': Color(0xFF78909C),
  };

  bool get _canUseGif =>
      _emotionGifs.containsKey(widget.emotion) && !_hasGifError;

  @override
  void initState() {
    super.initState();
    _hasGifError = false;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.enableAnimation) {
      _startBlinkTimer();
    }
  }

  void _startBlinkTimer() {
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _isBlinking = true);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _isBlinking = false);
      });
    });
  }

  @override
  void didUpdateWidget(PetAvatarDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEffectiveUrl =
        oldWidget.emotionUrls?[oldWidget.emotion] ?? oldWidget.customImageUrl;
    final newEffectiveUrl =
        widget.emotionUrls?[widget.emotion] ?? widget.customImageUrl;
    if (oldEffectiveUrl != newEffectiveUrl) {
      // 情绪切换：记录旧图 URL，触发 AnimatedCrossFade
      _previousImageUrl = oldEffectiveUrl;
      _showNewEmotion = false;
      // 下一帧切换到新图，触发淡入淡出
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showNewEmotion = true);
      });
    }
    if (oldWidget.emotion != widget.emotion) {
      _hasGifError = false;
    }
    if (oldWidget.enableAnimation != widget.enableAnimation) {
      if (widget.enableAnimation) {
        _controller.repeat(reverse: true);
        _startBlinkTimer();
      } else {
        _controller.stop();
        _blinkTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breedColor = _breedColors[widget.breed] ?? AppColors.primary;
    final emotionColor = _emotionColors[widget.emotion] ?? AppColors.primary;

    return AnimatedBuilder(
      animation: _breathAnimation,
      builder: (context, child) {
        final breatheScale =
            widget.enableAnimation ? _breathAnimation.value : 1.0;
        final rotateAngle = widget.enableAnimation
            ? sin(_controller.value * 2 * pi) * 0.03
            : 0.0;

        return Transform.rotate(
          angle: rotateAngle,
          child: Transform.scale(
            scale: breatheScale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 主图片
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        breedColor.withValues(alpha: 0.3),
                        breedColor.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(widget.size * 0.24),
                    boxShadow: [
                      BoxShadow(
                        color: breedColor.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.size * 0.24),
                    child: _buildAvatarContent(breedColor, emotionColor),
                  ),
                ),

                // 眨眼遮罩（仅伪动画模式）
                if (_isBlinking && widget.enableAnimation && !_canUseGif)
                  Positioned(
                    top: widget.size * 0.35,
                    child: Container(
                      width: widget.size * 0.5,
                      height: widget.size * 0.06,
                      decoration: BoxDecoration(
                        color: breedColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建形象内容：emotionUrls → customImageUrl → GIF → 降级预设
  Widget _buildAvatarContent(Color breedColor, Color emotionColor) {
    // AI 情绪变体：根据当前 emotion 选择对应图片
    final emotionUrl = widget.emotionUrls?[widget.emotion];
    final effectiveUrl = emotionUrl ?? widget.customImageUrl;

    // 自定义网络图片（AI 生成结果）
    if (effectiveUrl != null && effectiveUrl.isNotEmpty) {
      final newImage =
          _buildNetworkImage(effectiveUrl, breedColor, emotionColor);

      // 情绪切换时的交叉淡入淡出
      if (_previousImageUrl != null && _previousImageUrl != effectiveUrl) {
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _showNewEmotion
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild:
              _buildNetworkImage(_previousImageUrl!, breedColor, emotionColor),
          secondChild: newImage,
        );
      }
      return newImage;
    }

    // GIF 真动画（P1）
    if (_canUseGif) {
      return Image.asset(
        _emotionGifs[widget.emotion]!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          _hasGifError = true;
          return _buildPresetAvatar(breedColor, emotionColor);
        },
      );
    }

    // 降级：伪动画 + 图标
    return _buildPresetAvatar(breedColor, emotionColor);
  }

  Widget _buildNetworkImage(String url, Color breedColor, Color emotionColor) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          _buildPresetAvatar(breedColor, emotionColor),
    );
  }

  Widget _buildPresetAvatar(Color breedColor, Color emotionColor) {
    final icon = _emotionIcons[widget.emotion] ?? Icons.pets;
    final speciesIcon = getSpeciesIcon(widget.species);

    return Container(
      decoration: BoxDecoration(
        color: breedColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(widget.size * 0.24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            speciesIcon,
            size: widget.size * 0.45,
            color: breedColor,
          ),
          const SizedBox(height: 2),
          Icon(
            icon,
            size: widget.size * 0.2,
            color: emotionColor,
          ),
        ],
      ),
    );
  }
}

/// 情绪选择器组件
class EmotionSelector extends StatelessWidget {
  final String selectedEmotion;
  final Function(String) onEmotionSelected;

  const EmotionSelector(
      {super.key,
      required this.selectedEmotion,
      required this.onEmotionSelected});

  static const _emotions = [
    {'key': 'happy', 'label': '开心'},
    {'key': 'normal', 'label': '正常'},
    {'key': 'hungry', 'label': '饿了'},
    {'key': 'weak', 'label': '虚弱'},
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _emotions.map((emotion) {
        final isSelected = selectedEmotion == emotion['key'];
        return GestureDetector(
          onTap: () => onEmotionSelected(emotion['key'] as String? ?? ''),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
              ),
            ),
            child: Text(
              emotion['label']!,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
