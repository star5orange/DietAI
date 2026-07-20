import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/real_pet_api_service.dart';

/// 添加宠物饮食记录弹窗
class AddFeedingRecordModal extends StatefulWidget {
  final int petId;

  const AddFeedingRecordModal({super.key, required this.petId});

  @override
  State<AddFeedingRecordModal> createState() => _AddFeedingRecordModalState();
}

class _AddFeedingRecordModalState extends State<AddFeedingRecordModal> {
  final _foodController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedMealType = '干粮';
  String _selectedTime = '08:00';
  bool _isCustomTime = false;
  bool _showFoodPicker = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _foodOptions = [];
  bool _isLoadingFoods = true;

  static const _mealTypes = ['干粮', '湿粮', '鲜食', '零食'];
  static const _timeOptions = [
    '06:00',
    '07:00',
    '08:00',
    '09:00',
    '12:00',
    '13:00',
    '14:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadFoodDatabase();
  }

  Future<void> _loadFoodDatabase() async {
    try {
      final api = RealPetApiService();
      final result = await api.getFoodDatabase();
      if (result.isSuccess && result.data != null) {
        final foods = result.data!['foods'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _foodOptions =
                foods.map((f) => Map<String, dynamic>.from(f as Map)).toList();
            _isLoadingFoods = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFoods = false);
    }
  }

  @override
  void dispose() {
    _foodController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示条
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            const Text(
              '添加饮食记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            // 食品选择
            const Text('食品',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showFoodPicker = !_showFoodPicker),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.search,
                        size: 18, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _foodController.text.isEmpty
                            ? '搜索或选择食品'
                            : _foodController.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: _foodController.text.isEmpty
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      _showFoodPicker
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

            // 食品下拉选择
            if (_showFoodPicker)
              Container(
                margin: const EdgeInsets.only(top: 4),
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: _isLoadingFoods
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount:
                            _foodOptions.length + 1, // +1 for custom input
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color:
                                AppColors.borderLight.withValues(alpha: 0.5)),
                        itemBuilder: (ctx, index) {
                          if (index == _foodOptions.length) {
                            return _buildCustomFoodItem();
                          }
                          return _buildFoodOptionItem(_foodOptions[index]);
                        },
                      ),
              ),

            const SizedBox(height: 16),

            // 克数
            const Text('数量',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '请输入克数',
                      hintStyle: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('g',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 类型
            const Text('类型',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: _mealTypes.map((type) {
                final isSelected = _selectedMealType == type;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: type != _mealTypes.last ? 8.0 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMealType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySurface
                              : AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // 时间
            const Text('时间',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._timeOptions.map((time) {
                  final isSelected = _selectedTime == time;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedTime = time;
                      _isCustomTime = false;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySurface
                            : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        time,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }),
                // 自定义时间
                GestureDetector(
                  onTap: _pickCustomTime,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isCustomTime
                          ? AppColors.primarySurface
                          : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCustomTime
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.clock,
                          size: 14,
                          color: _isCustomTime
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isCustomTime ? _selectedTime : '自定义',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isCustomTime
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: _isCustomTime
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('保存',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodOptionItem(Map<String, dynamic> food) {
    return InkWell(
      onTap: () {
        _foodController.text = food['name'] as String? ?? '';
        setState(() => _showFoodPicker = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(LucideIcons.fish,
                size: 16, color: AppColors.caloriesColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(food['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 14)),
            ),
            Text(
              '${food['calories'] ?? '-'} kcal/100g',
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomFoodItem() {
    return InkWell(
      onTap: () {
        _foodController.clear();
        setState(() => _showFoodPicker = false);
        // 清空输入框，方便用户手动输入
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(LucideIcons.edit3, size: 16, color: AppColors.primary),
            SizedBox(width: 10),
            Text('自定义输入...',
                style: TextStyle(fontSize: 14, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }

  void _handleSave() async {
    final foodName = _foodController.text.trim();
    if (foodName.isEmpty) {
      _showError('请输入食品名称');
      return;
    }
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      _showError('请输入数量（克）');
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      _showError('请输入有效的克数');
      return;
    }

    // 查找匹配的食品营养数据
    Map<String, dynamic>? matchedFood;
    for (final food in _foodOptions) {
      if (food['name'] == foodName) {
        matchedFood = food;
        break;
      }
    }

    setState(() => _isSaving = true);

    // 计算营养值（绝对值，非 per-100g）
    final ratio = amount / 100;
    final caloriesPer100g = (matchedFood?['calories'] as num?)?.toDouble() ?? 0;
    final proteinPer100g = (matchedFood?['protein'] as num?)?.toDouble() ?? 0;
    final fatPer100g = (matchedFood?['fat'] as num?)?.toDouble() ?? 0;

    final api = RealPetApiService();
    final now = DateTime.now();
    final apiData = <String, dynamic>{
      'food_name': foodName,
      'amount_grams': amount,
      'calories': caloriesPer100g * ratio,
      'protein': proteinPer100g * ratio,
      'fat': fatPer100g * ratio,
      'record_time':
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} $_selectedTime:00',
      'from_source': 'manual',
    };

    final result = await api.addFeeding(widget.petId, apiData);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      Navigator.pop(context, {
        'food': foodName,
        'amount_g': amount,
        'calories': (caloriesPer100g * ratio).round(),
        'protein': double.parse((proteinPer100g * ratio).toStringAsFixed(1)),
        'fat': double.parse((fatPer100g * ratio).toStringAsFixed(1)),
        'time': _selectedTime,
        'meal_type': _selectedMealType,
        'source': '手动',
      });
    } else {
      _showError(result.message);
      return;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickCustomTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(_selectedTime.split(':')[0]) ?? now.hour,
        minute: int.tryParse(_selectedTime.split(':')[1]) ?? now.minute,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        _isCustomTime = true;
      });
    }
  }
}
