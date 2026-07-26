import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingCrowdTagPage extends ConsumerStatefulWidget {
  const OnboardingCrowdTagPage({super.key});

  @override
  ConsumerState<OnboardingCrowdTagPage> createState() =>
      _OnboardingCrowdTagPageState();
}

class _OnboardingCrowdTagPageState extends ConsumerState<OnboardingCrowdTagPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  String? _selectedTag;

  // 人群标签数据——优先从后端获取，硬编码数据作为回退
  static const List<Map<String, dynamic>> _fallbackCrowdTags = [
    {
      'tag': '减脂',
      'icon': LucideIcons.flame,
      'color': Color(0xFFFF6B6B),
      'description': '减少体脂率，塑造身材',
    },
    {
      'tag': '健身',
      'icon': LucideIcons.dumbbell,
      'color': Color(0xFF4ECDC4),
      'description': '增肌塑形，提升体能',
    },
    {
      'tag': '均衡维持',
      'icon': LucideIcons.scale,
      'color': Color(0xFF2BAF74),
      'description': '均衡饮食，维持健康体重',
    },
  ];

  // 可被API更新的人群标签列表
  List<Map<String, dynamic>> _crowdTags = List.from(_fallbackCrowdTags);

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
    _fetchCrowdTags();
  }

  Future<void> _fetchCrowdTags() async {
    try {
      final response = await ApiService().get('/users/crowd-tags');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final tagIcons = {
          '减脂': LucideIcons.flame,
          '健身': LucideIcons.dumbbell,
          '均衡维持': LucideIcons.scale,
        };
        final tagColors = {
          '减脂': const Color(0xFFFF6B6B),
          '健身': const Color(0xFF4ECDC4),
          '均衡维持': const Color(0xFF2BAF74),
        };
        final updated = items.map((item) {
          final tag = (item['tag'] ?? item['name'] ?? '').toString();
          final colorHex = item['color'] as String?;
          return {
            'tag': tag,
            'icon': tagIcons[tag] ?? LucideIcons.users,
            'color': colorHex != null
                ? Color(int.parse(colorHex.replaceFirst('#', '0xFF')))
                : (tagColors[tag] ?? const Color(0xFF2BAF74)),
            'description': (item['description'] ?? '').toString(),
          };
        }).toList();

        if (updated.isNotEmpty && mounted) {
          setState(() => _crowdTags = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
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
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '人群标签',
          style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/onboarding/constitution'),
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
                _buildProgressIndicator(4),
                const SizedBox(height: 24),
                Text(
                  '选择您的人群标签',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '帮助我们为您提供更精准的饮食建议',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _crowdTags.length,
                    itemBuilder: (context, index) {
                      final tag = _crowdTags[index];
                      final isSelected = _selectedTag == tag['tag'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTag = tag['tag'] as String;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (tag['color'] as Color).withValues(alpha: 0.1)
                                : AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? (tag['color'] as Color)
                                  : AppColors.textTertiary
                                      .withValues(alpha: 0.2),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (tag['color'] as Color)
                                          .withValues(alpha: 0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : AppColors.lightShadow,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: (tag['color'] as Color)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  tag['icon'] as IconData,
                                  color: tag['color'] as Color,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                tag['tag'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? (tag['color'] as Color)
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tag['description'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  text: '下一步',
                  onPressed: _selectedTag != null ? _nextStep : null,
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
              color: step <= currentStep
                  ? AppColors.primary
                  : AppColors.textTertiary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  void _nextStep() {
    ref.read(onboardingProvider.notifier).updateBasicInfo({
      'crowd_tag': _selectedTag,
    });
    context.go('/onboarding/constitution');
  }
}
