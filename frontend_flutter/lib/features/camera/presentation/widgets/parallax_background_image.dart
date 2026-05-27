import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

/// 视差背景图片组件 - 实现食物图片作为背景的效果
class ParallaxBackgroundImage extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final ScrollController scrollController;
  final double opacity;

  const ParallaxBackgroundImage({
    super.key,
    this.imageFile,
    this.imageUrl,
    required this.scrollController,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final scrollOffset = scrollController.hasClients 
          ? scrollController.offset 
          : 0.0;
        
        // 计算视差偏移量
        final parallaxOffset = scrollOffset * 0.5;
        
        return Transform.translate(
          offset: Offset(0, -parallaxOffset),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图片
                _buildBackgroundImage(),
                
                // 渐变遮罩
                _buildGradientOverlay(),
                
                // 模糊遮罩（随滚动变化）
                _buildBlurOverlay(scrollOffset),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundImage() {
    if (imageFile != null) {
      return Image.file(
        imageFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    
    if (imageUrl != null) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2BAF74),
            Color(0xFF259960),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 100,
          color: Colors.white30,
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.black.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildBlurOverlay(double scrollOffset) {
    // 计算模糊强度，随滚动增加
    final blurIntensity = (scrollOffset / 200).clamp(0.0, 10.0);
    
    if (blurIntensity > 0) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurIntensity,
          sigmaY: blurIntensity,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.1 * (blurIntensity / 10)),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}