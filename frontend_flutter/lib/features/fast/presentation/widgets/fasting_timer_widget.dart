import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 断食计时器组件
/// 显示进食窗口倒计时和当前状态
class FastingTimerWidget extends ConsumerStatefulWidget {
  final DateTime windowStart;
  final DateTime windowEnd;
  final VoidCallback? onWindowEnd;

  const FastingTimerWidget({
    super.key,
    required this.windowStart,
    required this.windowEnd,
    this.onWindowEnd,
  });

  @override
  ConsumerState<FastingTimerWidget> createState() => _FastingTimerWidgetState();
}

class _FastingTimerWidgetState extends ConsumerState<FastingTimerWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _isInWindow = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 计算今天的进食窗口
    final todayWindowStart = today.add(Duration(
      hours: widget.windowStart.hour,
      minutes: widget.windowStart.minute,
    ));
    final todayWindowEnd = today.add(Duration(
      hours: widget.windowEnd.hour,
      minutes: widget.windowEnd.minute,
    ));

    if (now.isBefore(todayWindowStart)) {
      // 还没到进食窗口
      _isInWindow = false;
      _remaining = todayWindowStart.difference(now);
    } else if (now.isBefore(todayWindowEnd)) {
      // 在进食窗口内
      _isInWindow = true;
      _remaining = todayWindowEnd.difference(now);
    } else {
      // 已过进食窗口
      _isInWindow = false;
      // 计算到明天进食窗口的时间
      final tomorrowWindowStart = todayWindowStart.add(const Duration(days: 1));
      _remaining = tomorrowWindowStart.difference(now);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _calculateRemaining();
      });
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isInWindow
              ? [AppColors.success.withValues(alpha: 0.1), AppColors.success.withValues(alpha: 0.05)]
              : [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isInWindow ? AppColors.success.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // 状态标签
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInWindow ? LucideIcons.utensils : LucideIcons.moon,
                size: 16,
                color: _isInWindow ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _isInWindow ? '进食窗口' : '禁食中',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _isInWindow ? AppColors.success : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // 倒计时
          Text(
            _formatDuration(_remaining),
            style: AppTextStyles.h2.copyWith(
              color: _isInWindow ? AppColors.success : AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          // 提示文字
          Text(
            _isInWindow ? '距离进食窗口结束' : '距离进食窗口开始',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 16),

          // 进食窗口时间
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.windowStart.hour.toString().padLeft(2, '0')}:${widget.windowStart.minute.toString().padLeft(2, '0')} - ${widget.windowEnd.hour.toString().padLeft(2, '0')}:${widget.windowEnd.minute.toString().padLeft(2, '0')}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 迷你断食计时器（用于首页卡片）
class MiniFastingTimer extends ConsumerWidget {
  final DateTime windowStart;
  final DateTime windowEnd;

  const MiniFastingTimer({
    super.key,
    required this.windowStart,
    required this.windowEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final todayWindowStart = today.add(Duration(
      hours: windowStart.hour,
      minutes: windowStart.minute,
    ));
    final todayWindowEnd = today.add(Duration(
      hours: windowEnd.hour,
      minutes: windowEnd.minute,
    ));

    final isInWindow = now.isAfter(todayWindowStart) && now.isBefore(todayWindowEnd);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isInWindow ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInWindow ? LucideIcons.utensils : LucideIcons.moon,
            size: 14,
            color: isInWindow ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            isInWindow ? '进食窗口' : '禁食中',
            style: AppTextStyles.caption.copyWith(
              color: isInWindow ? AppColors.success : AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}