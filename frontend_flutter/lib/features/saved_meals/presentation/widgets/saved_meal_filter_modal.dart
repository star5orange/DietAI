import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';

class SavedMealFilterModal extends StatefulWidget {
  final String? selectedCategory;
  final Function(String? category) onCategoryChanged;

  const SavedMealFilterModal({
    super.key,
    this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  State<SavedMealFilterModal> createState() => _SavedMealFilterModalState();
}

class _SavedMealFilterModalState extends State<SavedMealFilterModal> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '筛选菜品',
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selectedCategory != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                      widget.onCategoryChanged(null);
                      Navigator.pop(context);
                    },
                    child: const Text('清除'),
                  ),
              ],
            ),
          ),

          // 分类选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '菜品分类',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: MealCategory.values.map((category) {
                    final isSelected = _selectedCategory == category.value;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = isSelected ? null : category.value;
                        });
                        widget.onCategoryChanged(_selectedCategory);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(20),
                          border: isSelected
                              ? null
                              : Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          category.displayName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 底部安全区域
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}