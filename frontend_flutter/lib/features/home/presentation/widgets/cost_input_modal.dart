import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';

/// 消费信息输入模态框
/// 用于记录食物消费的金额和来源信息
class CostInputModal extends StatefulWidget {
  final String foodName;
  final Function(double amount, String source) onSave;

  const CostInputModal({
    super.key,
    required this.foodName,
    required this.onSave,
  });

  @override
  State<CostInputModal> createState() => _CostInputModalState();
}

class _CostInputModalState extends State<CostInputModal> {
  final _amountController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedSource = 'canteen';
  bool _isSaving = false;

  static const Map<String, IconData> _sourceIcons = {
    'canteen': LucideIcons.utensils,
    'delivery': LucideIcons.package,
    'home': LucideIcons.home,
    'restaurant': LucideIcons.store,
    'snack': LucideIcons.cookie,
    'other': LucideIcons.moreHorizontal,
  };

  static const Map<String, Color> _sourceColors = {
    'canteen': AppColors.breakfastStart,
    'delivery': AppColors.accent,
    'home': AppColors.primary,
    'restaurant': AppColors.lunchStart,
    'snack': AppColors.snackStart,
    'other': AppColors.dinnerStart,
  };

  List<Map<String, dynamic>> _sourceOptions = [
    {
      'value': 'canteen',
      'label': '食堂',
      'icon': LucideIcons.utensils,
      'color': AppColors.breakfastStart
    },
    {
      'value': 'delivery',
      'label': '外卖',
      'icon': LucideIcons.package,
      'color': AppColors.accent
    },
    {
      'value': 'home',
      'label': '家里',
      'icon': LucideIcons.home,
      'color': AppColors.primary
    },
    {
      'value': 'restaurant',
      'label': '餐厅',
      'icon': LucideIcons.store,
      'color': AppColors.lunchStart
    },
    {
      'value': 'snack',
      'label': '零食',
      'icon': LucideIcons.cookie,
      'color': AppColors.snackStart
    },
    {
      'value': 'other',
      'label': '其他',
      'icon': LucideIcons.moreHorizontal,
      'color': AppColors.dinnerStart
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchSourceOptions();
  }

  Future<void> _fetchSourceOptions() async {
    try {
      final response = await _apiService.get('/foods/source-tags');
      if (response.success && response.data != null) {
        final items = response.data['items'] as List<dynamic>?;
        if (items != null && mounted) {
          setState(() {
            _sourceOptions = items.map((item) {
              final value = item['value'] as String;
              final label = item['label'] as String;
              return {
                'value': value,
                'label': label,
                'icon': _sourceIcons[value] ?? LucideIcons.moreHorizontal,
                'color': _sourceColors[value] ?? AppColors.dinnerStart,
              };
            }).toList();
          });
        }
      }
    } catch (_) {
      // Silently fallback to hardcoded data
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部指示器
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 标题
              Row(
                children: [
                  Icon(LucideIcons.receipt, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '记录消费信息',
                    style:
                        AppTextStyles.h4.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 食物名称
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.utensilsCrossed,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.foodName,
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 金额输入
              Text('消费金额', style: AppTextStyles.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  hintText: '请输入金额',
                  suffixText: '元',
                  prefixIcon: Icon(LucideIcons.coins,
                      color: AppColors.textTertiary, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: AppTextStyles.inputText,
              ),

              const SizedBox(height: 24),

              // 来源选择
              Text('消费来源', style: AppTextStyles.labelLarge),
              const SizedBox(height: 12),
              _buildSourceSelector(),

              const SizedBox(height: 24),

              // 快速金额选择
              Text('快速选择金额', style: AppTextStyles.labelLarge),
              const SizedBox(height: 12),
              _buildQuickAmountSelector(),

              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.textInverse,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.check, size: 18),
                            const SizedBox(width: 8),
                            Text('保存消费记录', style: AppTextStyles.buttonMedium),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // 跳过按钮
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '暂不记录消费',
                    style: AppTextStyles.linkSmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _sourceOptions.map((option) {
        final isSelected = _selectedSource == option['value'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedSource = option['value'] as String;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (option['color'] as Color).withValues(alpha: 0.15)
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? (option['color'] as Color) : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  option['icon'] as IconData,
                  size: 16,
                  color: isSelected
                      ? (option['color'] as Color)
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  option['label'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (option['color'] as Color)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAmountSelector() {
    final quickAmounts = [5.0, 10.0, 15.0, 20.0, 30.0, 50.0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickAmounts.map((amount) {
        final isSelected = _amountController.text == amount.toStringAsFixed(1);
        return GestureDetector(
          onTap: () {
            setState(() {
              _amountController.text = amount.toStringAsFixed(1);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '¥${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _handleSave() async {
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('请输入消费金额'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text('请输入有效的金额'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // 模拟保存延迟
    await Future.delayed(const Duration(milliseconds: 500));

    widget.onSave(amount, _selectedSource);

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(LucideIcons.checkCircle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('消费记录已保存：¥${amount.toStringAsFixed(2)} - $_selectedSource'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
