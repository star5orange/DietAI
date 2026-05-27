import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../providers/onboarding_provider.dart';

class OnboardingBasicInfoPage extends ConsumerStatefulWidget {
  const OnboardingBasicInfoPage({super.key});

  @override
  ConsumerState<OnboardingBasicInfoPage> createState() =>
      _OnboardingBasicInfoPageState();
}

class _OnboardingBasicInfoPageState
    extends ConsumerState<OnboardingBasicInfoPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _occupationController = TextEditingController();
  final _regionController = TextEditingController();

  int _selectedGender = 0;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _birthdateController.dispose();
    _occupationController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '基本信息',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/physical-data'),
            child: const Text('跳过'),
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // 进度指示器
                _buildProgressIndicator(1),

                const SizedBox(height: 32),

                // 标题
                Text(
                  '告诉我们一些关于您的基本信息',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  '这将帮助我们为您提供更个性化的建议',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // 姓名输入
                          AppInput(
                            controller: _nameController,
                            label: '真实姓名',
                            placeholder: '请输入您的真实姓名',
                            prefixIcon: LucideIcons.user,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入您的真实姓名';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // 性别选择
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '性别',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGenderOption(
                                        1, '男性', LucideIcons.user),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildGenderOption(
                                        2, '女性', LucideIcons.user),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildGenderOption(
                                        3, '其他', LucideIcons.user),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 出生日期
                          GestureDetector(
                            onTap: _selectBirthDate,
                            child: AppInput(
                              controller: _birthdateController,
                              label: '出生日期',
                              placeholder: '请选择出生日期',
                              prefixIcon: LucideIcons.calendar,
                              enabled: false,
                              suffixIcon: LucideIcons.chevronDown,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 职业
                          AppInput(
                            controller: _occupationController,
                            label: '职业',
                            placeholder: '请输入您的职业',
                            prefixIcon: LucideIcons.briefcase,
                          ),

                          const SizedBox(height: 20),

                          // 地区
                          AppInput(
                            controller: _regionController,
                            label: '所在地区',
                            placeholder: '请输入您的所在地区',
                            prefixIcon: LucideIcons.mapPin,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 继续按钮
                AppButton(
                  text: '继续',
                  onPressed: _validateAndContinue,
                  variant: AppButtonVariant.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentStep ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= currentStep
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _buildGenderOption(int value, String label, IconData icon) {
    final isSelected = _selectedGender == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _birthdateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _validateAndContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedGender == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择性别')),
        );
        return;
      }

      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择出生日期')),
        );
        return;
      }

      // 保存数据到 Provider
      ref.read(onboardingProvider.notifier).updateBasicInfo({
        'real_name': _nameController.text,
        'gender': _selectedGender,
        'birth_date': _birthdateController.text,
        'occupation': _occupationController.text,
        'region': _regionController.text,
      });

      // 跳转到下一页
      context.go('/onboarding/physical-data');
    }
  }
}
