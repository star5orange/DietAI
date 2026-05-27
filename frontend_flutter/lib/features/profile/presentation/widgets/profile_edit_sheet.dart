import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../domain/services/user_service.dart';
import '../providers/profile_provider.dart';

class ProfileEditSheet extends ConsumerStatefulWidget {
  final UserProfile? userProfile;

  const ProfileEditSheet({
    super.key,
    this.userProfile,
  });

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _realNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _occupationController = TextEditingController();
  final _regionController = TextEditingController();
  
  int? _selectedGender;
  String? _selectedBirthDate;
  int? _selectedActivityLevel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.userProfile != null) {
      final profile = widget.userProfile!;
      _realNameController.text = profile.realName ?? '';
      _heightController.text = profile.height?.toString() ?? '';
      _weightController.text = profile.weight?.toString() ?? '';
      _occupationController.text = profile.occupation ?? '';
      _regionController.text = profile.region ?? '';
      _selectedGender = profile.gender;
      _selectedBirthDate = profile.birthDate;
      _selectedActivityLevel = profile.activityLevel;
    }
  }

  @override
  void dispose() {
    _realNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _occupationController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 头部
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
                Expanded(
                  child: Text(
                    '编辑个人资料',
                    style: AppTextStyles.h5,
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            ),
          ),
          
          // 表单内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 真实姓名
                    _buildSectionTitle('基本信息'),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _realNameController,
                      label: '真实姓名',
                      prefixIcon: LucideIcons.user,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '请输入真实姓名';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 性别选择
                    _buildGenderSelector(),
                    const SizedBox(height: 16),
                    
                    // 生日选择
                    _buildBirthDateSelector(),
                    const SizedBox(height: 24),
                    
                    // 身体数据
                    _buildSectionTitle('身体数据'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            controller: _heightController,
                            label: '身高 (cm)',
                            prefixIcon: LucideIcons.ruler,
                            type: AppInputType.number,
                            validator: (value) {
                              if (value?.isNotEmpty ?? false) {
                                final height = double.tryParse(value!);
                                if (height == null || height <= 0 || height > 300) {
                                  return '请输入有效的身高';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: AppInput(
                            controller: _weightController,
                            label: '体重 (kg)',
                            prefixIcon: LucideIcons.scale,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 活动级别
                    _buildActivityLevelSelector(),
                    const SizedBox(height: 24),
                    
                    // 其他信息
                    _buildSectionTitle('其他信息'),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _occupationController,
                      label: '职业',
                      prefixIcon: LucideIcons.briefcase,
                    ),
                    const SizedBox(height: 16),
                    AppInput(
                      controller: _regionController,
                      label: '地区',
                      prefixIcon: LucideIcons.mapPin,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('性别', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildGenderOption(1, '男', LucideIcons.user),
            const SizedBox(width: 16),
            _buildGenderOption(2, '女', LucideIcons.user),
            const SizedBox(width: 16),
            _buildGenderOption(3, '其他', LucideIcons.user),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(int value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirthDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('出生日期', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectBirthDate,
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
                    _selectedBirthDate?.split('T')[0] ?? '选择出生日期',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedBirthDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('活动级别', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Column(
          children: [
            _buildActivityLevelOption(1, '久坐不动', '很少运动'),
            const SizedBox(height: 8),
            _buildActivityLevelOption(2, '轻度活动', '每周运动1-3次'),
            const SizedBox(height: 8),
            _buildActivityLevelOption(3, '中度活动', '每周运动3-5次'),
            const SizedBox(height: 8),
            _buildActivityLevelOption(4, '重度活动', '每周运动6-7次'),
            const SizedBox(height: 8),
            _buildActivityLevelOption(5, '超重度活动', '每天2次运动'),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityLevelOption(int value, String title, String subtitle) {
    final isSelected = _selectedActivityLevel == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedActivityLevel = value;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate != null 
          ? DateTime.parse(_selectedBirthDate!)
          : DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (selectedDate != null) {
      setState(() {
        _selectedBirthDate = selectedDate.toIso8601String();
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = UserProfileUpdateRequest(
        realName: _realNameController.text.trim().isEmpty ? null : _realNameController.text.trim(),
        gender: _selectedGender,
        birthDate: _selectedBirthDate,
        height: _heightController.text.trim().isEmpty ? null : double.tryParse(_heightController.text),
        weight: _weightController.text.trim().isEmpty ? null : double.tryParse(_weightController.text),
        activityLevel: _selectedActivityLevel,
        occupation: _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
        region: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
      );

      final success = await ref.read(userProfileProvider.notifier).updateUserProfile(request);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('个人资料更新成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新失败，请重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
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