import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';

/// 形象生成进度组件
/// 显示进度动画 + 完成回调
class AvatarGenerationProgress extends StatefulWidget {
  final String petName;
  final String description;
  final int regenCount;
  final Function(Map<String, dynamic> result) onComplete;
  final double progressValue;
  final String progressMessage;

  const AvatarGenerationProgress({
    super.key,
    required this.petName,
    required this.description,
    this.regenCount = 0,
    required this.onComplete,
    this.progressValue = 0.0,
    this.progressMessage = '',
  });

  @override
  State<AvatarGenerationProgress> createState() =>
      _AvatarGenerationProgressState();
}

class _AvatarGenerationProgressState extends State<AvatarGenerationProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 进度动画，由外部 progressValue 驱动，保留动画控制器用于平滑过渡
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _updateProgress();
  }

  @override
  void didUpdateWidget(AvatarGenerationProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressValue != widget.progressValue) {
      _updateProgress();
    }
  }

  void _updateProgress() {
    _controller.animateTo(widget.progressValue,
        duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动画圆环
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 背景圆
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 8,
                          color: AppColors.borderLight.withValues(alpha: 0.3),
                        ),
                      ),
                      // 进度圆
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: CircularProgressIndicator(
                          value: _animation.value,
                          strokeWidth: 8,
                          color: AppColors.primary,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      // 中心图标（旋转）
                      Transform.rotate(
                        angle: _controller.value * 2 * pi,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
                            size: 36,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // 宠物名称
            Text(
              '正在为 ${widget.petName} 生成形象',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 当前步骤消息
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.progressMessage.isNotEmpty
                    ? widget.progressMessage
                    : '正在生成中...',
                key: ValueKey(widget.progressMessage),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 进度条
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: LinearProgressIndicator(
                value: _animation.value,
                backgroundColor: AppColors.borderLight,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),

            // 百分比
            Text(
              '${(_animation.value * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),

            // 描述信息
            if (widget.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.feather,
                          size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
