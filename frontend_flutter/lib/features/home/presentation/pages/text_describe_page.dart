import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';

class TextDescribePage extends StatefulWidget {
  final String mealName;
  final int mealType;

  const TextDescribePage({
    super.key,
    required this.mealName,
    required this.mealType,
  });

  @override
  State<TextDescribePage> createState() => _TextDescribePageState();
}

class _TextDescribePageState extends State<TextDescribePage> {
  final FoodService _foodService = FoodService();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _portionController = TextEditingController(text: '1');

  String _selectedPortionUnit = '份';
  bool _isSubmitting = false;

  final List<String> _portionUnits = ['份', '碗', '盘', '个', '片', '杯', '克'];

  final List<Map<String, String>> _commonFoods = [
    {'name': '米饭', 'icon': '🍚'},
    {'name': '面条', 'icon': '🍜'},
    {'name': '馒头', 'icon': '🍞'},
    {'name': '鸡蛋', 'icon': '🥚'},
    {'name': '牛奶', 'icon': '🥛'},
    {'name': '苹果', 'icon': '🍎'},
    {'name': '鸡胸肉', 'icon': '🍗'},
    {'name': '西兰花', 'icon': '🥦'},
    {'name': '豆腐', 'icon': '🧈'},
    {'name': '酸奶', 'icon': '🥣'},
    {'name': '香蕉', 'icon': '🍌'},
    {'name': '全麦面包', 'icon': '🍞'},
  ];

  @override
  void dispose() {
    _foodNameController.dispose();
    _descriptionController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  Future<void> _submitRecord() async {
    final foodName = _foodNameController.text.trim();
    if (foodName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入食物名称'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final portion = double.tryParse(_portionController.text) ?? 1.0;
      final description = _descriptionController.text.trim();
      final fullDescription = description.isNotEmpty
          ? '$foodName ${portion}${_selectedPortionUnit} - $description'
          : '$foodName ${portion}${_selectedPortionUnit}';

      final record = FoodRecordCreate(
        recordDate: DateTime.now().toIso8601String().substring(0, 10),
        mealType: widget.mealType,
        foodName: foodName,
        description: fullDescription,
        recordingMethod: 2,
      );

      await for (final event in _foodService.createFoodRecordStream(record)) {
        if (event['type'] == 'complete' || event['type'] == 'final') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$foodName 已记录到${widget.mealName}'), backgroundColor: AppColors.success),
            );
            Navigator.pop(context, true);
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('记录失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _quickAddFood(String name) {
    if (_foodNameController.text.isEmpty) {
      _foodNameController.text = name;
    } else {
      _foodNameController.text = '${_foodNameController.text}、$name';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text('文字描述 - ${widget.mealName}'),
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _submitRecord,
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(LucideIcons.check, size: 18, color: AppColors.primary),
            label: Text(
              _isSubmitting ? '提交中' : '提交',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFoodNameInput(),
            const SizedBox(height: 16),
            _buildPortionSection(),
            const SizedBox(height: 16),
            _buildDescriptionInput(),
            const SizedBox(height: 20),
            _buildCommonFoodsSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodNameInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.edit2, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('食物名称', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('必填', style: TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _foodNameController,
            decoration: InputDecoration(
              hintText: '例如：红烧排骨、番茄炒蛋...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderLight)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderLight)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            maxLines: 2,
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }

  Widget _buildPortionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.scale, color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 10),
              Text('估算份量', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _portionController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderLight)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.borderLight)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _portionUnits.map((unit) {
                    final isSelected = unit == _selectedPortionUnit;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPortionUnit = unit),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.messageSquare, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Text('补充描述', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('选填', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: '例如：少油少盐、加了辣椒、配了米饭...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderLight)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderLight)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            maxLines: 3,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildCommonFoodsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.sparkles, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              Text('快速添加', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonFoods.map((food) {
              return GestureDetector(
                onTap: () => _quickAddFood(food['name']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundTertiary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(food['icon']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(food['name']!, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRecord,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textInverse,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.send, size: 18),
                  SizedBox(width: 8),
                  Text('提交记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
