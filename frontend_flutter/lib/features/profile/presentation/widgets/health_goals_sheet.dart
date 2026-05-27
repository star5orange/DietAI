import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../../domain/services/user_service.dart';
import '../providers/profile_provider.dart';

class HealthGoalsSheet extends ConsumerStatefulWidget {
  const HealthGoalsSheet({super.key});

  @override
  ConsumerState<HealthGoalsSheet> createState() => _HealthGoalsSheetState();
}

class _HealthGoalsSheetState extends ConsumerState<HealthGoalsSheet> {
  bool _isAddingGoal = false;

  @override
  void initState() {
    super.initState();
    // 加载健康目标数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthGoalsProvider.notifier).loadHealthGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final healthGoalsAsync = ref.watch(healthGoalsProvider);
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 头部
          _buildHeader(),
          
          // 内容
          Expanded(
            child: _isAddingGoal 
                ? _buildAddGoalForm()
                : _buildGoalsList(healthGoalsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_isAddingGoal) {
                setState(() {
                  _isAddingGoal = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(_isAddingGoal ? LucideIcons.arrowLeft : LucideIcons.x),
          ),
          Expanded(
            child: Text(
              _isAddingGoal ? '添加健康目标' : '健康目标',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
          ),
          if (!_isAddingGoal)
            IconButton(
              onPressed: () {
                setState(() {
                  _isAddingGoal = true;
                });
              },
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsList(AsyncValue<List<HealthGoal>> healthGoalsAsync) {
    return healthGoalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('加载失败: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(healthGoalsProvider.notifier).loadHealthGoals(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (goals) {
        if (goals.isEmpty) {
          return _buildEmptyState();
        }
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进行中的目标
              if (ref.read(healthGoalsProvider.notifier).activeGoals.isNotEmpty) ...[
                _buildSectionTitle('进行中的目标'),
                const SizedBox(height: 12),
                ...ref.read(healthGoalsProvider.notifier).activeGoals
                    .map((goal) => _buildGoalCard(goal))
                    .toList(),
                const SizedBox(height: 24),
              ],
              
              // 已完成的目标
              if (ref.read(healthGoalsProvider.notifier).completedGoals.isNotEmpty) ...[
                _buildSectionTitle('已完成的目标'),
                const SizedBox(height: 12),
                ...ref.read(healthGoalsProvider.notifier).completedGoals
                    .map((goal) => _buildGoalCard(goal))
                    .toList(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.target, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            '暂无健康目标',
            style: AppTextStyles.h6.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '设置健康目标，开始您的健康之旅',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _isAddingGoal = true;
              });
            },
            icon: const Icon(LucideIcons.plus),
            label: const Text('添加目标'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.h6.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildGoalCard(HealthGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                goal.goalTypeText,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildStatusChip(goal.currentStatus),
            ],
          ),
          if (goal.targetWeight != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.target, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '目标体重: ${goal.targetWeight}kg',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (goal.targetDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '目标日期: ${goal.targetDate!.split('T')[0]}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: 编辑目标
                  },
                  icon: const Icon(LucideIcons.edit2, size: 16),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: goal.currentStatus == 1 ? () {
                    // TODO: 更新目标状态
                  } : null,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('完成'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int status) {
    Color color;
    String text;
    
    switch (status) {
      case 1:
        color = AppColors.primary;
        text = '进行中';
        break;
      case 2:
        color = AppColors.success;
        text = '已完成';
        break;
      case 3:
        color = AppColors.warning;
        text = '已暂停';
        break;
      case 4:
        color = AppColors.error;
        text = '已取消';
        break;
      default:
        color = AppColors.textSecondary;
        text = '未知';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAddGoalForm() {
    return const _AddGoalForm();
  }
}

class _AddGoalForm extends ConsumerStatefulWidget {
  const _AddGoalForm();

  @override
  ConsumerState<_AddGoalForm> createState() => _AddGoalFormState();
}

class _AddGoalFormState extends ConsumerState<_AddGoalForm> {
  final _formKey = GlobalKey<FormState>();
  final _targetWeightController = TextEditingController();
  
  int _selectedGoalType = 1;
  String? _selectedTargetDate;
  bool _isLoading = false;
  
  final List<Map<String, dynamic>> _goalTypes = [
    {'value': 1, 'label': '减重', 'icon': LucideIcons.trendingDown},
    {'value': 2, 'label': '增重', 'icon': LucideIcons.trendingUp},
    {'value': 3, 'label': '维持', 'icon': LucideIcons.minus},
    {'value': 4, 'label': '增肌', 'icon': LucideIcons.dumbbell},
    {'value': 5, 'label': '减脂', 'icon': LucideIcons.flame},
  ];

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 目标类型选择
            _buildSectionTitle('目标类型'),
            const SizedBox(height: 12),
            _buildGoalTypeSelector(),
            const SizedBox(height: 24),
            
            // 目标体重
            _buildSectionTitle('目标体重'),
            const SizedBox(height: 12),
            AppInput(
              controller: _targetWeightController,
              label: '目标体重 (kg)',
              prefixIcon: LucideIcons.target,
              type: AppInputType.number,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  final weight = double.tryParse(value!);
                  if (weight == null || weight <= 0 || weight > 1000) {
                    return '请输入有效的体重';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // 目标日期
            _buildSectionTitle('目标日期'),
            const SizedBox(height: 12),
            _buildTargetDateSelector(),
            const SizedBox(height: 32),
            
            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitGoal,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('创建目标'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.h6.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildGoalTypeSelector() {
    return Column(
      children: _goalTypes.map((goalType) {
        return _buildGoalTypeOption(
          goalType['value'],
          goalType['label'],
          goalType['icon'],
        );
      }).toList(),
    );
  }

  Widget _buildGoalTypeOption(int value, String label, IconData icon) {
    final isSelected = _selectedGoalType == value;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGoalType = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? LucideIcons.checkCircle : LucideIcons.circle,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetDateSelector() {
    return GestureDetector(
      onTap: _selectTargetDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedTargetDate?.split('T')[0] ?? '选择目标日期（可选）',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedTargetDate != null 
                      ? AppColors.textPrimary 
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTargetDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (selectedDate != null) {
      setState(() {
        _selectedTargetDate = selectedDate.toIso8601String();
      });
    }
  }

  Future<void> _submitGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = HealthGoalCreateRequest(
        goalType: _selectedGoalType,
        targetWeight: _targetWeightController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_targetWeightController.text),
        targetDate: _selectedTargetDate,
      );

      final success = await ref.read(healthGoalsProvider.notifier).createHealthGoal(request);
      
      if (success) {
        if (mounted) {
          // 返回到目标列表
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('健康目标创建成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('创建失败，请重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}