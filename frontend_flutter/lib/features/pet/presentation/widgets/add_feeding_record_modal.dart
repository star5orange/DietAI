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
  bool _isSaving = false;
  List<Map<String, dynamic>> _foodOptions = [];

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
          });
        }
      }
    } catch (_) {}
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

            // 食品选择（可输入 + 模糊匹配数据库）
            const Text('食品',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (ctx, constraints) => RawAutocomplete<String>(
                focusNode: FocusNode(),
                textEditingController: _foodController,
                optionsBuilder: (value) {
                  final query = value.text.trim();
                  if (query.isEmpty) return const [];
                  return _foodOptions
                      .where((f) {
                        final name = (f['name'] as String? ?? '');
                        return name.contains(query);
                      })
                      .map((f) => f['name'] as String)
                      .take(8);
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  if (options.isEmpty) return const SizedBox.shrink();
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (ctx, index) {
                            final option = options.elementAt(index);
                            final food = _foodOptions.firstWhere(
                              (f) => f['name'] == option,
                              orElse: () => <String, dynamic>{},
                            );
                            return ListTile(
                              dense: true,
                              leading: const Icon(LucideIcons.fish,
                                  size: 16, color: AppColors.caloriesColor),
                              title: Text(option,
                                  style: const TextStyle(fontSize: 14)),
                              subtitle: Text(
                                '${food['calories'] ?? '-'} kcal/100g',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary),
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder: (ctx, controller, focusNode, onSubmit) =>
                    TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: '输入食品名称搜索',
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textTertiary),
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 18, color: AppColors.textTertiary),
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
      'record_time': now.toIso8601String(),
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
        'time': now.toIso8601String(),
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
}
