import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class MealSelectionPage extends StatelessWidget {
  final String recordMethod;
  final String? initialMealName;
  final int? initialMealType;

  const MealSelectionPage({
    super.key,
    required this.recordMethod,
    this.initialMealName,
    this.initialMealType,
  });

  @override
  Widget build(BuildContext context) {
    final meals = [
      {'name': '早餐', 'icon': LucideIcons.coffee, 'color': const Color(0xFF8B4513), 'type': 1},
      {'name': '午餐', 'icon': LucideIcons.salad, 'color': const Color(0xFF3ECC7A), 'type': 2},
      {'name': '晚餐', 'icon': LucideIcons.utensils, 'color': const Color(0xFF1E90FF), 'type': 3},
      {'name': '加餐', 'icon': LucideIcons.cookie, 'color': const Color(0xFFFF9500), 'type': 4},
      {'name': '夜宵', 'icon': LucideIcons.moon, 'color': const Color(0xFF6B46C1), 'type': 5},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(_getRecordMethodTitle()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择餐次',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请选择这次要记录的餐次类型',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            
            // 餐次选项
            Expanded(
              child: ListView.builder(
                itemCount: meals.length,
                itemBuilder: (context, index) {
                  final meal = meals[index];
                  final isSelected = initialMealType == meal['type'];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: _buildMealOption(
                      context,
                      meal['name'] as String,
                      meal['icon'] as IconData,
                      meal['color'] as Color,
                      meal['type'] as int,
                      isSelected,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealOption(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
    int mealType,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => _handleMealSelection(context, name, mealType),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected 
              ? Border.all(color: color, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            
            const SizedBox(width: 20),
            
            // 餐次信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getMealDescription(mealType),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // 选中状态
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              Icon(
                LucideIcons.chevronRight,
                color: Colors.grey[400],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  String _getRecordMethodTitle() {
    switch (recordMethod) {
      case 'ai_scan':
        return 'AI扫描';
      case 'text_describe':
        return '文字描述';
      case 'voice_record':
        return '语音记录';
      case 'saved_meals':
        return '已保存菜品';
      case 'barcode_scan':
        return '条形码扫描';
      default:
        return '记录食物';
    }
  }

  String _getMealDescription(int mealType) {
    switch (mealType) {
      case 1:
        return '一天的开始，营养丰富的早餐';
      case 2:
        return '午间时光，补充能量的午餐';
      case 3:
        return '晚间用餐，均衡搭配的晚餐';
      case 4:
        return '两餐之间的小食或零食';
      case 5:
        return '夜间进食，建议清淡';
      default:
        return '';
    }
  }

  void _handleMealSelection(BuildContext context, String mealName, int mealType) {
    // 返回选择的餐次信息
    Navigator.pop(context, {
      'mealName': mealName,
      'mealType': mealType,
      'recordMethod': recordMethod,
    });
  }
}