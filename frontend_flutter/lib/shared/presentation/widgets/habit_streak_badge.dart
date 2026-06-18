import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';

/// 习惯连续打卡徽章组件
class HabitStreakBadge extends StatelessWidget {
  final int streakDays;
  final String? habitName;
  final bool isMini;

  const HabitStreakBadge({
    super.key,
    required this.streakDays,
    this.habitName,
    this.isMini = false,
  });

  @override
  Widget build(BuildContext context) {
    if (streakDays <= 0) return const SizedBox.shrink();

    final level = _getStreakLevel();
    final size = isMini ? 36.0 : 48.0;
    final iconSize = isMini ? 16.0 : 22.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMini ? 8 : 12,
        vertical: isMini ? 4 : 8,
      ),
      decoration: BoxDecoration(
        gradient: level.gradient,
        borderRadius: BorderRadius.circular(isMini ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: level.color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, color: AppColors.textInverse, size: iconSize),
          SizedBox(width: isMini ? 4 : 6),
          Text(
            '$streakDays天',
            style: (isMini ? AppTextStyles.labelSmall : AppTextStyles.labelMedium)
                .copyWith(
              color: AppColors.textInverse,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (habitName != null && !isMini) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                habitName!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.whiteWithOpacity(0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StreakLevel get _streakLevel => _getStreakLevel();

  _StreakLevel _getStreakLevel() {
    if (streakDays >= 30) {
      return _StreakLevel(
        icon: LucideIcons.flame,
        color: const Color(0xFFFF5722),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
        ),
      );
    } else if (streakDays >= 14) {
      return _StreakLevel(
        icon: LucideIcons.award,
        color: const Color(0xFFFF9800),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
        ),
      );
    } else if (streakDays >= 7) {
      return _StreakLevel(
        icon: LucideIcons.star,
        color: const Color(0xFF4CAF50),
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
        ),
      );
    } else {
      return _StreakLevel(
        icon: LucideIcons.zap,
        color: AppColors.info,
        gradient: LinearGradient(
          colors: [AppColors.info, AppColors.infoLight],
        ),
      );
    }
  }
}

class _StreakLevel {
  final IconData icon;
  final Color color;
  final Gradient gradient;

  _StreakLevel({
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
