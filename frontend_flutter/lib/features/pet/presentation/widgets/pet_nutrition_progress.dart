import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

/// 宠物营养进度环组件
/// 展示热量/蛋白质/脂肪的环形进度
class PetNutritionProgress extends StatelessWidget {
  final num currentCalories;
  final num targetCalories;
  final num currentProtein;
  final num targetProtein;
  final num currentFat;
  final num targetFat;

  const PetNutritionProgress({
    super.key,
    required this.currentCalories,
    required this.targetCalories,
    required this.currentProtein,
    required this.targetProtein,
    required this.currentFat,
    required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '今日营养摄入',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNutrientRing(
                '热量',
                currentCalories,
                targetCalories,
                AppColors.caloriesColor,
                'kcal',
              ),
              _buildNutrientRing(
                '蛋白质',
                currentProtein,
                targetProtein,
                AppColors.primary,
                'g',
              ),
              _buildNutrientRing(
                '脂肪',
                currentFat,
                targetFat,
                AppColors.warning,
                'g',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRing(
    String label,
    num current,
    num target,
    Color color,
    String unit,
  ) {
    final ratio = target > 0 ? (current / target).clamp(0.0, 1.5) : 0.0;

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 背景圆
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 6,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
              // 进度圆
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: ratio > 1 ? 1 : ratio,
                  strokeWidth: 6,
                  color: ratio > 1 ? AppColors.error : color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // 中心文字
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    current.toStringAsFixed(current % 1 == 0 ? 0 : 1),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color:
                          ratio > 1 ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '目标 ${target.toStringAsFixed(target % 1 == 0 ? 0 : 0)}$unit',
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
        if (ratio > 1)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '已超标',
              style: TextStyle(fontSize: 10, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}
