import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../providers/onboarding_provider.dart';

class OnboardingPhysicalDataPage extends ConsumerStatefulWidget {
  const OnboardingPhysicalDataPage({super.key});

  @override
  ConsumerState<OnboardingPhysicalDataPage> createState() => _OnboardingPhysicalDataPageState();
}

class _OnboardingPhysicalDataPageState extends ConsumerState<OnboardingPhysicalDataPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  
  final _formKey = GlobalKey<FormState>();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  
  int _selectedActivityLevel = 2;
  double? _calculatedBMI;

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
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);
    
    if (height != null && weight != null && height > 0) {
      final heightInMeters = height / 100;
      setState(() {
        _calculatedBMI = weight / (heightInMeters * heightInMeters);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '身体数据',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/health-goals'),
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
                _buildProgressIndicator(2),
                
                const SizedBox(height: 32),
                
                // 标题
                Text(
                  '身体数据有助于精准分析',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  '我们会根据您的身体数据提供个性化建议',
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
                          // 身高体重输入
                          Row(
                            children: [
                              Expanded(
                                child: AppInput(
                                  controller: _heightController,
                                  label: '身高 (cm)',
                                  placeholder: '170',
                                  prefixIcon: LucideIcons.ruler,
                                  type: AppInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入身高';
                                    }
                                    final height = double.tryParse(value);
                                    if (height == null || height <= 0 || height > 300) {
                                      return '请输入有效身高';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) => _calculateBMI(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppInput(
                                  controller: _weightController,
                                  label: '体重 (kg)',
                                  placeholder: '65',
                                  prefixIcon: LucideIcons.scale,
                                  type: AppInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入体重';
                                    }
                                    final weight = double.tryParse(value);
                                    if (weight == null || weight <= 0 || weight > 1000) {
                                      return '请输入有效体重';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) => _calculateBMI(),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // BMI 显示
                          if (_calculatedBMI != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.activity,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'BMI: ${_calculatedBMI!.toStringAsFixed(1)}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _getBMICategory(_calculatedBMI!),
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 32),
                          
                          // 活动水平选择
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '活动水平',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...List.generate(5, (index) {
                                final level = index + 1;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildActivityLevelOption(level),
                                );
                              }),
                            ],
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
              color: i <= currentStep ? AppColors.primary : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityLevelOption(int level) {
    final isSelected = _selectedActivityLevel == level;
    final activityData = _getActivityLevelData(level);
    
    return GestureDetector(
      onTap: () => setState(() => _selectedActivityLevel = level),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              activityData['icon'],
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityData['title'],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    activityData['description'],
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
    );
  }

  Map<String, dynamic> _getActivityLevelData(int level) {
    switch (level) {
      case 1:
        return {
          'icon': LucideIcons.armchair,
          'title': '久坐',
          'description': '很少运动，主要是办公室工作',
        };
      case 2:
        return {
          'icon': LucideIcons.footprints,
          'title': '轻度活动',
          'description': '轻度运动，每周1-3次',
        };
      case 3:
        return {
          'icon': LucideIcons.bike,
          'title': '中度活动',
          'description': '中度运动，每周3-5次',
        };
      case 4:
        return {
          'icon': LucideIcons.zap,
          'title': '高度活动',
          'description': '高强度运动，每周6-7次',
        };
      case 5:
        return {
          'icon': LucideIcons.dumbbell,
          'title': '极度活动',
          'description': '专业运动员或体力劳动者',
        };
      default:
        return {};
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return '偏瘦';
    if (bmi < 25) return '正常';
    if (bmi < 30) return '超重';
    return '肥胖';
  }

  void _validateAndContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      final height = double.parse(_heightController.text);
      final weight = double.parse(_weightController.text);
      
      // 保存数据到 Provider
      ref.read(onboardingProvider.notifier).updatePhysicalData({
        'height': height,
        'weight': weight,
        'activity_level': _selectedActivityLevel,
        'bmi': _calculatedBMI,
      });
      
      // 跳转到下一页
      context.go('/onboarding/health-goals');
    }
  }
}