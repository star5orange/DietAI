import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingConstitutionPage extends ConsumerStatefulWidget {
  const OnboardingConstitutionPage({super.key});

  @override
  ConsumerState<OnboardingConstitutionPage> createState() => _OnboardingConstitutionPageState();
}

class _OnboardingConstitutionPageState extends ConsumerState<OnboardingConstitutionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  String? _selectedConstitution;

  static const List<Map<String, dynamic>> _constitutions = [
    {
      'type': '平和质',
      'icon': LucideIcons.smile,
      'color': Color(0xFF2BAF74),
      'description': '阴阳气血调和，体态适中，面色润泽',
      'advice': '保持均衡饮食和规律作息',
    },
    {
      'type': '气虚质',
      'icon': LucideIcons.wind,
      'color': Color(0xFFFFB74D),
      'description': '元气不足，疲乏气短，易感冒',
      'advice': '宜食益气健脾食物，如山药、黄芪',
    },
    {
      'type': '阳虚质',
      'icon': LucideIcons.snowflake,
      'color': Color(0xFF64B5F6),
      'description': '阳气不足，手足不温，畏寒怕冷',
      'advice': '宜食温热食物，如羊肉、生姜',
    },
    {
      'type': '阴虚质',
      'icon': LucideIcons.thermometer,
      'color': Color(0xFFEF5350),
      'description': '阴液亏少，口燥咽干，手足心热',
      'advice': '宜食滋阴润燥食物，如百合、银耳',
    },
    {
      'type': '痰湿质',
      'icon': LucideIcons.cloud,
      'color': Color(0xFF78909C),
      'description': '痰湿凝聚，形体肥胖，腹部肥满松软',
      'advice': '宜食健脾利湿食物，如薏米、冬瓜',
    },
    {
      'type': '湿热质',
      'icon': LucideIcons.sun,
      'color': Color(0xFFFFA726),
      'description': '湿热内蕴，面垢油光，口苦口干',
      'advice': '宜食清热利湿食物，如绿豆、苦瓜',
    },
    {
      'type': '血瘀质',
      'icon': LucideIcons.droplet,
      'color': Color(0xFFAB47BC),
      'description': '血行不畅，肤色晦暗，易有瘀斑',
      'advice': '宜食活血化瘀食物，如山楂、黑豆',
    },
    {
      'type': '气郁质',
      'icon': LucideIcons.cloudRain,
      'color': Color(0xFF7E57C2),
      'description': '气机郁滞，情绪低落，胸胁胀痛',
      'advice': '宜食行气解郁食物，如玫瑰花、柑橘',
    },
    {
      'type': '特禀质',
      'icon': LucideIcons.shieldAlert,
      'color': Color(0xFFEC407A),
      'description': '先天禀赋不足或过敏体质',
      'advice': '避免过敏原，饮食宜清淡均衡',
    },
  ];

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
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '体质辨识',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/complete'),
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
                _buildProgressIndicator(5),
                const SizedBox(height: 20),
                Text(
                  '选择您的体质类型',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '基于中医九种体质分类，为您提供个性化养生建议',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _constitutions.length,
                    itemBuilder: (context, index) {
                      final item = _constitutions[index];
                      final isSelected = _selectedConstitution == item['type'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedConstitution = item['type'] as String;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (item['color'] as Color).withValues(alpha: 0.08)
                                  : AppColors.backgroundCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? (item['color'] as Color)
                                    : AppColors.textTertiary.withValues(alpha: 0.15),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    color: item['color'] as Color,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['type'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? (item['color'] as Color)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item['description'] as String,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle, color: item['color'] as Color, size: 22),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedConstitution != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.lightbulb, color: AppColors.info, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _constitutions.firstWhere((c) => c['type'] == _selectedConstitution)['advice'] as String,
                            style: const TextStyle(fontSize: 13, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                AppButton(
                  text: '完成设置',
                  onPressed: _selectedConstitution != null ? _completeSetup : null,
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
      children: List.generate(6, (index) {
        final step = index + 1;
        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: step <= currentStep ? AppColors.primary : AppColors.textTertiary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  void _completeSetup() {
    ref.read(onboardingProvider.notifier).updateBasicInfo({
      'constitution_type': _selectedConstitution,
    });
    context.go('/onboarding/complete');
  }
}
