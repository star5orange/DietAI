import 'package:flutter/material.dart';

import '../../domain/models/food_model.dart';
import 'food_image_preview.dart';

/// 食物记录卡片组件
class FoodRecordCard extends StatelessWidget {
  final FoodRecord foodRecord;
  final VoidCallback? onTap;
  final bool showImage;
  final bool showNutrition;

  const FoodRecordCard({
    super.key,
    required this.foodRecord,
    this.onTap,
    this.showImage = true,
    this.showNutrition = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (foodRecord.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _buildDescription(),
              ],
              if (showImage && foodRecord.imageUrl != null) ...[
                const SizedBox(height: 12),
                _buildImageSection(),
              ],
              if (showNutrition && foodRecord.nutritionDetail != null) ...[
                const SizedBox(height: 12),
                _buildNutritionSection(),
              ],
              const SizedBox(height: 8),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                foodRecord.foodName?.isNotEmpty == true ? foodRecord.foodName! : '未命名食物',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getMealTypeColor(foodRecord.mealType),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      foodRecord.mealTypeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(foodRecord.analysisStatus ?? 0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      foodRecord.analysisStatusName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (foodRecord.imageUrl != null)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FoodImagePreview(
                foodRecord: foodRecord,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                showFullScreen: false,
                showLoadingIndicator: false,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      foodRecord.description!,
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '食物图片',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: FoodImagePreview(
            foodRecord: foodRecord,
            fit: BoxFit.cover,
            showFullScreen: true,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionSection() {
    final nutrition = foodRecord.nutritionDetail!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '营养成分',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNutritionItem('热量', '${nutrition.calories.toStringAsFixed(0)} kcal'),
              ),
              Expanded(
                child: _buildNutritionItem('蛋白质', '${nutrition.protein.toStringAsFixed(1)}g'),
              ),
              Expanded(
                child: _buildNutritionItem('脂肪', '${nutrition.fat.toStringAsFixed(1)}g'),
              ),
              Expanded(
                child: _buildNutritionItem('碳水', '${nutrition.carbohydrates.toStringAsFixed(1)}g'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 14,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          _formatDateTime(foodRecord.createdAt),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        const Spacer(),
        if (foodRecord.nutritionDetail != null)
          Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 14,
                color: Colors.green[600],
              ),
              const SizedBox(width: 4),
              Text(
                '已分析',
                style: TextStyle(
                  color: Colors.green[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  Color _getMealTypeColor(int mealType) {
    switch (mealType) {
      case 1: // 早餐
        return Colors.orange;
      case 2: // 午餐
        return Colors.red;
      case 3: // 晚餐
        return Colors.purple;
      case 4: // 加餐
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1: // 待分析
        return Colors.orange;
      case 2: // 分析中
        return Colors.blue;
      case 3: // 已完成
        return Colors.green;
      case 4: // 分析失败
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 