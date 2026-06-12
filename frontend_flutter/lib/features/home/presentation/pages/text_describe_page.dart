import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';

class TextDescribePage extends StatefulWidget {
  final String mealName;
  final int mealType;
  final String recordDate;
  final String? recordTime;

  const TextDescribePage({
    super.key,
    required this.mealName,
    required this.mealType,
    required this.recordDate,
    this.recordTime,
  });

  @override
  State<TextDescribePage> createState() => _TextDescribePageState();
}

class _TextDescribePageState extends State<TextDescribePage> {
  final FoodService _foodService = FoodService();
  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _portionController =
      TextEditingController(text: '1');
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();

  String _selectedPortionUnit = '份';
  bool _isSubmitting = false;
  bool _showNutritionInput = true;
  bool _isAutoEstimate = true;

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
    _caloriesController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    super.dispose();
  }

  Future<void> _submitRecord() async {
    final foodName = _foodNameController.text.trim();
    if (foodName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入食物名称'), backgroundColor: AppColors.error),
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
        recordDate: widget.recordDate,
        recordTime: widget.recordTime ?? DateTime.now().toIso8601String(),
        mealType: widget.mealType,
        foodName: foodName,
        description: fullDescription,
        recordingMethod: 2,
      );

      final result = await _foodService.createFoodRecord(record);
      if (mounted) {
        if (result.success && result.data != null) {
          final calories = double.tryParse(_caloriesController.text);
          final protein = double.tryParse(_proteinController.text);
          final fat = double.tryParse(_fatController.text);
          final carbs = double.tryParse(_carbsController.text);

          print(
              '📝 营养数据: calories=$calories, protein=$protein, fat=$fat, carbs=$carbs');

          if (calories != null ||
              protein != null ||
              fat != null ||
              carbs != null) {
            final nutritionResult = await _foodService.addNutritionDetail(
                result.data!.id,
                NutritionDetailCreate(
                  calories: calories,
                  protein: protein,
                  fat: fat,
                  carbohydrates: carbs,
                  analysisMethod: _isAutoEstimate ? 'auto_estimate' : 'manual',
                ));

            if (!nutritionResult.success) {
              print('❌ 营养数据保存失败: ${nutritionResult.message}');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('营养信息保存失败: ${nutritionResult.message}'),
                    backgroundColor: AppColors.warning,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            } else {
              print('✅ 营养数据保存成功: recordId=${result.data!.id}');
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('$foodName 已记录到${widget.mealName}'),
                backgroundColor: AppColors.success),
          );
          await _foodService.invalidateRecordsCache(widget.recordDate);
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('记录失败: ${result.message}'),
                backgroundColor: AppColors.error),
          );
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

  void _updateAutoEstimate() {
    if (!_isAutoEstimate) return;
    final foodName = _foodNameController.text.trim();
    if (foodName.isEmpty) {
      _caloriesController.clear();
      _proteinController.clear();
      _fatController.clear();
      _carbsController.clear();
      return;
    }
    final portion = double.tryParse(_portionController.text) ?? 1.0;
    final estimate = _foodService.estimateNutrition(foodName, portion);
    _caloriesController.text = (estimate['calories'] ?? 0).toStringAsFixed(0);
    _proteinController.text = (estimate['protein'] ?? 0).toStringAsFixed(1);
    _fatController.text = (estimate['fat'] ?? 0).toStringAsFixed(1);
    _carbsController.text = (estimate['carbs'] ?? 0).toStringAsFixed(1);
  }

  Widget _buildNutritionSection() {
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
          GestureDetector(
            onTap: () {
              setState(() => _showNutritionInput = !_showNutritionInput);
              if (!_showNutritionInput && _isAutoEstimate) {
                _updateAutoEstimate();
              }
            },
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.flame,
                      color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 10),
                Text('营养信息',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(
                  _showNutritionInput
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
          if (_showNutritionInput) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text('自动估算',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
                const Spacer(),
                Flexible(
                  child: Text(
                    _isAutoEstimate ? '根据食物数据库估算' : '手动输入',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: _isAutoEstimate,
                  onChanged: (v) {
                    setState(() => _isAutoEstimate = v);
                    if (v) _updateAutoEstimate();
                  },
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildNutritionField(
                      '热量(kcal)', _caloriesController, LucideIcons.flame),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNutritionField(
                      '蛋白质(g)', _proteinController, LucideIcons.dumbbell),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildNutritionField(
                      '脂肪(g)', _fatController, LucideIcons.droplets),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNutritionField(
                      '碳水(g)', _carbsController, LucideIcons.wheat),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isAutoEstimate)
              Text(
                '💡 支持多食物估算：用"、"分隔多种食物，如"鸡排、米饭"；复合食物自动拆分，如"鸡排饭"→鸡排+米饭',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              )
            else
              Text(
                '💡 请手动输入营养数据，或切换为自动估算',
                style: TextStyle(fontSize: 12, color: AppColors.textHint),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionField(
      String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: !_isAutoEstimate,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: AppColors.textSecondary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary))
                : const Icon(LucideIcons.check,
                    size: 18, color: AppColors.primary),
            label: Text(
              _isSubmitting ? '提交中' : '提交',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary),
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
            const SizedBox(height: 16),
            _buildNutritionSection(),
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
                child:
                    Icon(LucideIcons.edit2, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('食物名称',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('必填',
                  style: TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _foodNameController,
            onChanged: (_) => _updateAutoEstimate(),
            decoration: InputDecoration(
              hintText: '例如：鸡排、米饭 或 鸡排饭...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                child: const Icon(LucideIcons.scale,
                    color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 10),
              Text('估算份量',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _portionController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _updateAutoEstimate(),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.borderLight)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.borderLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.backgroundTertiary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.textInverse
                                : AppColors.textSecondary,
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
                child: const Icon(LucideIcons.messageSquare,
                    color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Text('补充描述',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('选填',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: '例如：少油少盐、加了辣椒、配了米饭...',
              hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                child: const Icon(LucideIcons.sparkles,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              Text('快速添加',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      Text(food['name']!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textInverse))
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.send, size: 18),
                  SizedBox(width: 8),
                  Text('提交记录',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
