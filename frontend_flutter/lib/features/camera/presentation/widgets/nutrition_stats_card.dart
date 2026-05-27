import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 营养统计卡片组件 - 增强版设计
class NutritionStatsCard extends StatelessWidget {
  final double totalCalories;
  final Map<String, double> macronutrients;
  final int servingCount;
  final Function(int) onServingChanged;

  const NutritionStatsCard({
    super.key,
    required this.totalCalories,
    required this.macronutrients,
    required this.servingCount,
    required this.onServingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和份量控制
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '营养成分',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              _buildServingController(),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 卡路里大显示
          _buildCaloriesDisplay(),
          
          const SizedBox(height: 24),
          
          // 宏营养素环形图
          _buildMacronutrientsChart(),
        ],
      ),
    );
  }

  Widget _buildServingController() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: servingCount > 1 ? () => onServingChanged(servingCount - 1) : null,
            icon: const Icon(LucideIcons.minus, size: 16),
            color: servingCount > 1 ? const Color(0xFF2BAF74) : Colors.grey,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  '$servingCount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const Text(
                  '份',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onServingChanged(servingCount + 1),
            icon: const Icon(LucideIcons.plus, size: 16),
            color: const Color(0xFF2BAF74),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesDisplay() {
    final adjustedCalories = (totalCalories * servingCount).round();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2BAF74),
            Color(0xFF3ECC7A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.flame,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$adjustedCalories',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getCalorieLevel(adjustedCalories),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCalorieLevel(int calories) {
    if (calories < 200) return '低热量';
    if (calories < 400) return '中等热量';
    if (calories < 600) return '高热量';
    return '超高热量';
  }

  Widget _buildMacronutrientsChart() {
    final protein = macronutrients['protein']! * servingCount;
    final fat = macronutrients['fat']! * servingCount;
    final carbs = macronutrients['carbohydrates']! * servingCount;
    
    final total = protein + fat + carbs;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '宏营养素分布',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: _buildNutrientItem(
                label: '蛋白质',
                value: protein.round(),
                unit: 'g',
                color: const Color(0xFF4ECDC4),
                percentage: total > 0 ? protein / total : 0,
                icon: LucideIcons.dumbbell,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNutrientItem(
                label: '碳水化合物',
                value: carbs.round(),
                unit: 'g',
                color: const Color(0xFFFFE66D),
                percentage: total > 0 ? carbs / total : 0,
                icon: LucideIcons.wheat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildNutrientItem(
                label: '脂肪',
                value: fat.round(),
                unit: 'g',
                color: const Color(0xFFFF8B94),
                percentage: total > 0 ? fat / total : 0,
                icon: LucideIcons.droplet,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNutrientItem({
    required String label,
    required int value,
    required String unit,
    required Color color,
    required double percentage,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            '$value$unit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
          const SizedBox(height: 4),
          Text(
            '${(percentage * 100).round()}%',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}