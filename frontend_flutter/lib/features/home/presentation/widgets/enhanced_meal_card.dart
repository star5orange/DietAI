import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/presentation/widgets/animated_progress_circle.dart';

/// 增强版主页卡片组件
class EnhancedMealCard extends StatefulWidget {
  final String mealType;
  final String title;
  final List<Map<String, dynamic>> foods;
  final int targetCalories;
  final int consumedCalories;
  final Color primaryColor;
  final IconData icon;
  final VoidCallback onAddFood;
  final VoidCallback onViewDetails;

  const EnhancedMealCard({
    super.key,
    required this.mealType,
    required this.title,
    required this.foods,
    required this.targetCalories,
    required this.consumedCalories,
    required this.primaryColor,
    required this.icon,
    required this.onAddFood,
    required this.onViewDetails,
  });

  @override
  State<EnhancedMealCard> createState() => _EnhancedMealCardState();
}

class _EnhancedMealCardState extends State<EnhancedMealCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.targetCalories > 0
        ? (widget.consumedCalories / widget.targetCalories).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onViewDetails,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildContent(progress),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.primaryColor,
            widget.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.consumedCalories} / ${widget.targetCalories} 卡路里',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          // 进度圆环
          SizedBox(
            width: 50,
            height: 50,
            child: AnimatedProgressCircle(
              progress: widget.targetCalories > 0
                  ? widget.consumedCalories / widget.targetCalories
                  : 0.0,
              size: 50,
              strokeWidth: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              progressColor: Colors.white,
              child: Text(
                '${(widget.targetCalories > 0 ? (widget.consumedCalories / widget.targetCalories * 100).round() : 0)}%',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double progress) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.foods.isEmpty) _buildEmptyState() else _buildFoodList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.plus,
            color: widget.primaryColor,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '还没有记录${widget.title}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '点击添加食物开始记录',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '已记录食物',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 12),
        ...widget.foods.take(3).map((food) => _buildFoodItem(food)).toList(),
        if (widget.foods.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '还有 ${widget.foods.length - 3} 项...',
              style: TextStyle(
                fontSize: 14,
                color: widget.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: food['image'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      food['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        LucideIcons.utensils,
                        color: widget.primaryColor,
                        size: 20,
                      ),
                    ),
                  )
                : Icon(
                    LucideIcons.utensils,
                    color: widget.primaryColor,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food['name'] ?? '未知食物',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                ),
                Text(
                  '${food['calories'] ?? 0} 卡路里',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onViewDetails,
              icon: Icon(
                LucideIcons.eye,
                size: 16,
                color: widget.primaryColor,
              ),
              label: const Text('查看详情'),
              style: OutlinedButton.styleFrom(
                foregroundColor: widget.primaryColor,
                side: BorderSide(color: widget.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onAddFood,
              icon: const Icon(
                LucideIcons.plus,
                size: 16,
                color: Colors.white,
              ),
              label: const Text('添加食物'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
