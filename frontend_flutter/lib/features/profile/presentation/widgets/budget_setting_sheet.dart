import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../cost/data/services/cost_service.dart';

/// 月度预算设置弹窗
class BudgetSettingSheet extends ConsumerStatefulWidget {
  const BudgetSettingSheet({super.key});

  @override
  ConsumerState<BudgetSettingSheet> createState() => _BudgetSettingSheetState();
}

class _BudgetSettingSheetState extends ConsumerState<BudgetSettingSheet> {
  final TextEditingController _budgetController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  double _currentBudget = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCurrentBudget();
  }

  Future<void> _loadCurrentBudget() async {
    try {
      final service = ref.read(costServiceProvider);
      final stats = await service.getCostStats(period: 'month');
      setState(() {
        _currentBudget = stats.budget ?? 0.0;
        _budgetController.text =
            _currentBudget > 0 ? _currentBudget.toStringAsFixed(0) : '';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBudget() async {
    final budgetText = _budgetController.text.trim();
    if (budgetText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入预算金额')),
      );
      return;
    }

    final budget = double.tryParse(budgetText);
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的预算金额')),
      );
      return;
    }

    if (budget > 99999) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('预算金额不能超过99999元')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final service = ref.read(costServiceProvider);
      await service.setMonthlyBudget(budget);
      setState(() {
        _currentBudget = budget;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('月度预算已设置为 ¥${budget.toStringAsFixed(0)}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
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
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 标题
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.wallet,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('月度饮食预算', style: AppTextStyles.h5),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // 说明
            Text(
              '设置每月饮食消费的上限，帮助控制开支',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            // 当前预算（如果有）
            if (_currentBudget > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      '当前预算: ¥${_currentBudget.toStringAsFixed(0)}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            if (_currentBudget > 0) const SizedBox(height: 20),

            // 输入框
            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '预算金额',
                hintText: '例如: 1500',
                suffixText: '元/月',
                prefixIcon: Icon(LucideIcons.coins),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
              ),
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),

            // 建议范围
            Text(
              '建议范围: 500-5000 元/月',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),

            // 快捷选择
            Text('快捷选择',
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickButton('500', 500),
                const SizedBox(width: 8),
                _buildQuickButton('1000', 1000),
                const SizedBox(width: 8),
                _buildQuickButton('1500', 1500),
                const SizedBox(width: 8),
                _buildQuickButton('2000', 2000),
              ],
            ),
            const SizedBox(height: 24),

            // 保存按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('保存设置', style: AppTextStyles.buttonMedium),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickButton(String label, double value) {
    final isSelected = _budgetController.text == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _budgetController.text = label;
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
