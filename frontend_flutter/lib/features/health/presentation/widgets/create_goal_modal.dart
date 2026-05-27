import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/health_goals_model.dart';
import '../providers/health_goals_provider.dart';

class CreateGoalModal extends ConsumerStatefulWidget {
  final HealthGoal? existingGoal;
  final VoidCallback? onGoalCreated;

  const CreateGoalModal({
    super.key,
    this.existingGoal,
    this.onGoalCreated,
  });

  @override
  ConsumerState<CreateGoalModal> createState() => _CreateGoalModalState();
}

class _CreateGoalModalState extends ConsumerState<CreateGoalModal> {
  final _formKey = GlobalKey<FormState>();
  final _targetWeightController = TextEditingController();

  int _selectedGoalType = 1;
  DateTime? _targetDate;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _goalTypes = [
    {'id': 1, 'name': '减重', 'icon': '⬇️', 'description': '减少体重，塑造完美身材'},
    {'id': 2, 'name': '增重', 'icon': '⬆️', 'description': '健康增重，改善体质'},
    {'id': 3, 'name': '维持体重', 'icon': '⚖️', 'description': '保持当前体重，维持健康状态'},
    {'id': 4, 'name': '增肌', 'icon': '💪', 'description': '增加肌肉量，提升身体素质'},
    {'id': 5, 'name': '减脂', 'icon': '🔥', 'description': '减少体脂率，塑造线条'},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingGoal != null) {
      _selectedGoalType = widget.existingGoal!.goalType;
      if (widget.existingGoal!.targetWeight != null) {
        _targetWeightController.text =
            widget.existingGoal!.targetWeight!.toString();
      }
      if (widget.existingGoal!.targetDate != null) {
        _targetDate = DateTime.parse(widget.existingGoal!.targetDate!);
      }
    }
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingGoal != null;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isEditing),
                  const SizedBox(height: 24),
                  _buildGoalTypeSection(),
                  const SizedBox(height: 24),
                  _buildTargetWeightSection(),
                  const SizedBox(height: 24),
                  _buildTargetDateSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(isEditing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            LucideIcons.target,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? '编辑健康目标' : '创建健康目标',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEditing ? '修改您的健康目标' : '设定一个明确的健康目标',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }

  Widget _buildGoalTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目标类型',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...(_goalTypes.map((goalType) => _buildGoalTypeOption(goalType))),
      ],
    );
  }

  Widget _buildGoalTypeOption(Map<String, dynamic> goalType) {
    final isSelected = _selectedGoalType == goalType['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedGoalType = goalType['id']),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.divider.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  goalType['icon'],
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalType['name'],
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        goalType['description'],
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    LucideIcons.check,
                    color: AppColors.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目标体重（可选）',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _targetWeightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '输入目标体重',
            suffixText: 'kg',
            prefixIcon: const Icon(LucideIcons.scale),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0 || weight > 500) {
                return '请输入有效的体重（1-500kg）';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTargetDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目标日期（可选）',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectTargetDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendar,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _targetDate != null
                        ? '${_targetDate!.year}年${_targetDate!.month}月${_targetDate!.day}日'
                        : '选择目标日期',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _targetDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(isEditing ? '更新目标' : '创建目标'),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTargetDate() async {
    final now = DateTime.now();
    final firstDate = now;
    final lastDate = DateTime(now.year + 5);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate != null) {
      setState(() {
        _targetDate = selectedDate;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final targetWeight = _targetWeightController.text.isNotEmpty
          ? double.parse(_targetWeightController.text)
          : null;

      final targetDateString = _targetDate?.toIso8601String().split('T')[0];

      if (widget.existingGoal != null) {
        // 更新目标
        final request = UpdateHealthGoalRequest(
          goalType: _selectedGoalType,
          targetWeight: targetWeight,
          targetDate: targetDateString,
        );

        final result = await ref
            .read(healthGoalsProvider.notifier)
            .updateHealthGoal(widget.existingGoal!.id, request);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor:
                  result.success ? AppColors.success : AppColors.error,
            ),
          );

          if (result.success) {
            Navigator.pop(context);
            widget.onGoalCreated?.call();
          }
        }
      } else {
        // 创建目标
        final request = CreateHealthGoalRequest(
          goalType: _selectedGoalType,
          targetWeight: targetWeight,
          targetDate: targetDateString,
        );

        final result = await ref
            .read(healthGoalsProvider.notifier)
            .createHealthGoal(request);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor:
                  result.success ? AppColors.success : AppColors.error,
            ),
          );

          if (result.success) {
            Navigator.pop(context);
            widget.onGoalCreated?.call();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
