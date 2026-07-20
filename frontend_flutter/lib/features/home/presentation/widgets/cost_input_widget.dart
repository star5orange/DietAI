import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';

/// 消费输入组件
/// 用于在记录食物时输入消费金额和来源
class CostInputWidget extends StatefulWidget {
  final double? initialAmount;
  final String? initialSource;
  final Function(double? amount, String? source) onChanged;

  const CostInputWidget({
    super.key,
    this.initialAmount,
    this.initialSource,
    required this.onChanged,
  });

  @override
  State<CostInputWidget> createState() => _CostInputWidgetState();
}

class _CostInputWidgetState extends State<CostInputWidget> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _showCostInput = false;

  List<String> _commonSources = ['外卖', '食堂', '餐厅', '自制', '便利店', '其他'];

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount.toString();
      _showCostInput = true;
    }
    if (widget.initialSource != null) {
      _sourceController.text = widget.initialSource!;
    }
    _fetchSources();
  }

  Future<void> _fetchSources() async {
    try {
      final response = await _apiService.get('/foods/source-tags');
      if (response.success && response.data != null) {
        final items = response.data['items'] as List<dynamic>?;
        if (items != null && mounted) {
          setState(() {
            _commonSources = items
                .map((item) => (item['label'] ?? item['value']).toString())
                .toList();
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
    _sourceController.dispose();
    super.dispose();
  }

  void _updateCost() {
    final amount = double.tryParse(_amountController.text);
    final source = _sourceController.text.trim();
    widget.onChanged(amount, source.isEmpty ? null : source);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 展开/收起按钮
          GestureDetector(
            onTap: () {
              setState(() {
                _showCostInput = !_showCostInput;
                if (!_showCostInput) {
                  _amountController.clear();
                  _sourceController.clear();
                  widget.onChanged(null, null);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showCostInput
                      ? AppColors.primary
                      : AppColors.borderLight,
                  width: _showCostInput ? 2 : 1,
                ),
                boxShadow: AppColors.lightShadow,
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    color: _showCostInput
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _showCostInput ? '记录消费 (可选)' : '添加消费记录 (可选)',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: _showCostInput
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight:
                            _showCostInput ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Icon(
                    _showCostInput
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    color: _showCostInput
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 输入区域
          if (_showCostInput)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.lightShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消费金额
                  Text('消费金额', style: AppTextStyles.bodyLarge),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: '请输入消费金额',
                        prefixText: '¥ ',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (_) => _updateCost(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 消费来源
                  Text('消费来源', style: AppTextStyles.bodyLarge),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _sourceController,
                      decoration: const InputDecoration(
                        hintText: '请输入消费来源',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (_) => _updateCost(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 快捷选择
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _commonSources.map((source) {
                      final isSelected = _sourceController.text == source;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _sourceController.text = source;
                          });
                          _updateCost();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: Text(
                            source,
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
