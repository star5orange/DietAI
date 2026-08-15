import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/advisor_service.dart';
import '../widgets/advisor_style_selector.dart';

/// AI顾问风格设置页面
/// 根据 sessionType 区分人类（默认）和宠物（6）顾问风格
class AdvisorStylePage extends ConsumerStatefulWidget {
  final int sessionType; // 0=通用/人类, 6=宠物

  const AdvisorStylePage({super.key, this.sessionType = 0});

  @override
  ConsumerState<AdvisorStylePage> createState() => _AdvisorStylePageState();
}

class _AdvisorStylePageState extends ConsumerState<AdvisorStylePage> {
  String _selectedStyle = 'nutritionist';
  Set<String> _selectedFocusGoals = {}; // 改为多选
  Set<String> _selectedFocusNutrients = {}; // 改为多选
  String _selectedResponseStyle = 'friendly';
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isPet = widget.sessionType == 6;
    try {
      final service = ref.read(advisorServiceProvider);
      final settings = await service.getSettings();
      if (mounted && settings != null) {
        setState(() {
          if (isPet) {
            // 宠物模式：加载宠物专属字段
            _selectedStyle = settings.petAdvisorStyle ?? 'vet_assistant';
            _advisorStyles = List.from(_fallbackPetAdvisorStyles);
            _focusGoals = List.from(_fallbackPetFocusGoals);
            _focusNutrients = []; // 宠物不需要营养素
            if (settings.petFocusGoal != null &&
                settings.petFocusGoal!.isNotEmpty) {
              _selectedFocusGoals = {settings.petFocusGoal!};
            }
          } else {
            // 人类模式
            _selectedStyle = settings.advisorStyle ?? 'nutritionist';
            _advisorStyles = List.from(_fallbackAdvisorStyles);
            _focusGoals = List.from(_fallbackFocusGoals);
            _focusNutrients = List.from(_fallbackFocusNutrients);
            _selectedFocusGoals = _goalsFromCode(settings.focusGoal);
            _selectedFocusNutrients =
                _nutrientsFromCode(settings.focusNutrient);
          }
          _selectedResponseStyle = settings.responseStyle ?? 'friendly';
          _isInitialized = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (isPet) {
            _advisorStyles = List.from(_fallbackPetAdvisorStyles);
            _focusGoals = List.from(_fallbackPetFocusGoals);
            _focusNutrients = [];
            _selectedStyle = 'vet_assistant';
          } else {
            _advisorStyles = List.from(_fallbackAdvisorStyles);
            _focusGoals = List.from(_fallbackFocusGoals);
            _focusNutrients = List.from(_fallbackFocusNutrients);
          }
          _isInitialized = true;
        });
      }
    }
  }

  Future<void> _fetchAdvisorStyles() async {
    try {
      final response = await ApiService().get('/ai-advisor/styles');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final updated = items
            .map((item) => {
                  'id': (item['id'] ?? '').toString(),
                  'name': (item['name'] ?? '').toString(),
                  'icon': LucideIcons.apple, // 图标保持使用硬编码映射
                  'desc':
                      (item['description'] ?? item['desc'] ?? '').toString(),
                })
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _advisorStyles = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
  }

  Future<void> _fetchFocusGoals() async {
    try {
      final response = await ApiService().get('/ai-advisor/goals');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final updated = items
            .map((item) => (item['name'] ?? item['goal'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _focusGoals = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
  }

  Future<void> _fetchFocusNutrients() async {
    try {
      final response = await ApiService().get('/ai-advisor/nutrients');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final updated = items
            .map((item) => (item['name'] ?? item['nutrient'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _focusNutrients = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
  }

  Future<void> _fetchResponseStyles() async {
    try {
      final response = await ApiService().get('/ai-advisor/response-styles');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final updated = items
            .map((item) => {
                  'id': (item['id'] ?? '').toString(),
                  'name': (item['name'] ?? '').toString(),
                })
            .toList();
        if (updated.isNotEmpty && mounted) {
          setState(() => _responseStyles = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
  }

  List<Map<String, dynamic>> _advisorStyles = List.from(_fallbackAdvisorStyles);

  // AI顾问风格——优先从后端获取，硬编码数据作为回退
  static const _fallbackAdvisorStyles = [
    {
      'id': 'nutritionist',
      'name': '营养师',
      'icon': LucideIcons.apple,
      'desc': '专业营养知识，科学饮食建议'
    },
    {
      'id': 'fitness_coach',
      'name': '健身教练',
      'icon': LucideIcons.dumbbell,
      'desc': '运动营养搭配，增肌减脂指导'
    },
    {
      'id': 'tcm_healer',
      'name': '中医养生师',
      'icon': LucideIcons.heart,
      'desc': '体质辨识，食疗养生建议'
    },
    {
      'id': 'encouraging_friend',
      'name': '鼓励型伙伴',
      'icon': LucideIcons.users,
      'desc': '轻松鼓励，陪伴式健康管理'
    },
  ];

  // 宠物专属顾问风格
  static const _fallbackPetAdvisorStyles = [
    {
      'id': 'vet_assistant',
      'name': '兽医助理',
      'icon': LucideIcons.stethoscope,
      'desc': '专业严谨，强调安全边界和就医指征'
    },
    {
      'id': 'pet_nutritionist',
      'name': '宠物营养师',
      'icon': LucideIcons.fish,
      'desc': '关注饮食管理、营养配比和换粮方案'
    },
    {
      'id': 'pet_caregiver',
      'name': '贴心宠管',
      'icon': LucideIcons.heartHandshake,
      'desc': '温暖陪伴，用宠物视角关心日常健康'
    },
  ];

  List<String> _focusGoals = List.from(_fallbackFocusGoals);

  static const _fallbackFocusGoals = [
    '减脂塑形',
    '增肌增重',
    '控糖稳糖',
    '养生调理',
    '均衡健康',
  ];

  // 宠物专属关注目标
  static const _fallbackPetFocusGoals = [
    '体重管理',
    '营养均衡',
    '日常护理',
    '疫苗与驱虫',
    '换粮过渡',
  ];

  List<String> _focusNutrients = List.from(_fallbackFocusNutrients);

  static const _fallbackFocusNutrients = [
    '热量',
    '蛋白质',
    '碳水化合物',
    '脂肪',
    '微量元素',
  ];

  List<Map<String, String>> _responseStyles =
      List.from(_fallbackResponseStyles);

  static const _fallbackResponseStyles = [
    {'id': 'professional', 'name': '专业严谨'},
    {'id': 'friendly', 'name': '亲切友好'},
    {'id': 'motivating', 'name': '激励鼓舞'},
    {'id': 'detailed', 'name': '详尽细致'},
  ];

  // 英文 code -> 中文名（后端存的是英文 code，需反映射用于高亮与摘要展示）
  static const _goalCodeToName = {
    'fat_loss': '减脂塑形',
    'muscle_gain': '增肌增重',
    'sugar_control': '控糖稳糖',
    'wellness': '养生调理',
    'balanced': '均衡健康',
  };
  static const _nutrientCodeToName = {
    'calories': '热量',
    'protein': '蛋白质',
    'carb': '碳水化合物',
    'fat': '脂肪',
    'micronutrient': '微量元素',
  };
  static const _responseStyleCodeToName = {
    'professional': '专业严谨',
    'friendly': '亲切友好',
    'motivating': '激励鼓舞',
    'detailed': '详尽细致',
  };

  /// 关注目标 code 串（逗号分隔）-> 中文名集合
  Set<String> _goalsFromCode(String? code) {
    if (code == null || code.isEmpty) return {};
    return code
        .split(',')
        .map((c) => _goalCodeToName[c.trim()] ?? c.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  /// 关注营养素 code 串（逗号分隔）-> 中文名集合
  Set<String> _nutrientsFromCode(String? code) {
    if (code == null || code.isEmpty) return {};
    return code
        .split(',')
        .map((c) => _nutrientCodeToName[c.trim()] ?? c.trim())
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final isPet = widget.sessionType == 6;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPet ? '宠物AI顾问风格' : 'AI顾问风格',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('保存',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentSummary(),
            Text('选择顾问风格', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            AdvisorStyleSelector(
              selectedStyle: _selectedStyle,
              styles: _advisorStyles,
              onChanged: (style) => setState(() => _selectedStyle = style),
            ),
            const SizedBox(height: 24),
            Text('关注目标（可多选）', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _focusGoals
                  .map((goal) => _buildChip(
                        label: goal,
                        isSelected: _selectedFocusGoals.contains(goal),
                        onTap: () => setState(() {
                          if (_selectedFocusGoals.contains(goal)) {
                            _selectedFocusGoals.remove(goal);
                          } else {
                            _selectedFocusGoals.add(goal);
                          }
                        }),
                      ))
                  .toList(),
            ),
            if (!isPet) ...[
              const SizedBox(height: 24),
              Text('关注营养素（可多选）', style: AppTextStyles.h6),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _focusNutrients
                    .map((nutrient) => _buildChip(
                          label: nutrient,
                          isSelected:
                              _selectedFocusNutrients.contains(nutrient),
                          onTap: () => setState(() {
                            if (_selectedFocusNutrients.contains(nutrient)) {
                              _selectedFocusNutrients.remove(nutrient);
                            } else {
                              _selectedFocusNutrients.add(nutrient);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            Text('回复风格', style: AppTextStyles.h6),
            const SizedBox(height: 12),
            ..._responseStyles.map((style) => _buildResponseStyleRadio(style)),
          ],
        ),
      ),
    );
  }

  /// 当前顾问配置摘要卡片（顾问风格 / 关注目标 / 关注营养素 / 回复风格）
  Widget _buildCurrentSummary() {
    final isPet = widget.sessionType == 6;

    String? styleName;
    for (final s in _advisorStyles) {
      if (s['id'] == _selectedStyle) {
        styleName = s['name'] as String?;
        break;
      }
    }
    final responseName = _responseStyleCodeToName[_selectedResponseStyle] ??
        _selectedResponseStyle;

    final goalsText =
        _selectedFocusGoals.isEmpty ? '未设置' : _selectedFocusGoals.join('、');
    final nutrientsText = isPet
        ? null
        : (_selectedFocusNutrients.isEmpty
            ? '未设置'
            : _selectedFocusNutrients.join('、'));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('当前顾问配置', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 12),
          _summaryRow('顾问风格', styleName ?? _selectedStyle),
          const SizedBox(height: 6),
          _summaryRow('关注目标', goalsText),
          if (nutrientsText != null) ...[
            const SizedBox(height: 6),
            _summaryRow('关注营养素', nutrientsText),
          ],
          const SizedBox(height: 6),
          _summaryRow('回复风格', responseName),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildResponseStyleRadio(Map<String, String> style) {
    final isSelected = _selectedResponseStyle == style['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedResponseStyle = style['id']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: style['id']!,
              groupValue: _selectedResponseStyle,
              onChanged: (value) =>
                  setState(() => _selectedResponseStyle = value!),
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              style['name']!,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(advisorServiceProvider);
      final isPet = widget.sessionType == 6;

      if (isPet) {
        // 宠物模式：保存 petAdvisorStyle 和 petFocusGoal
        final petFocusGoal =
            _selectedFocusGoals.isNotEmpty ? _selectedFocusGoals.first : null;

        await service.updateSettings(AdvisorSettings(
          petAdvisorStyle: _selectedStyle,
          petFocusGoal: petFocusGoal,
          responseStyle: _selectedResponseStyle,
        ));
      } else {
        // 人类模式
        final goalMap = {
          '减脂塑形': 'fat_loss',
          '增肌增重': 'muscle_gain',
          '控糖稳糖': 'sugar_control',
          '养生调理': 'wellness',
          '均衡健康': 'balanced',
        };
        final nutrientMap = {
          '热量': 'calories',
          '蛋白质': 'protein',
          '碳水化合物': 'carb',
          '脂肪': 'fat',
          '微量元素': 'micronutrient',
        };

        final focusGoal = _selectedFocusGoals.isNotEmpty
            ? _selectedFocusGoals
                .map((g) => goalMap[g])
                .whereType<String>()
                .join(',')
            : null;
        final focusNutrient = _selectedFocusNutrients.isNotEmpty
            ? _selectedFocusNutrients
                .map((n) => nutrientMap[n])
                .whereType<String>()
                .join(',')
            : null;

        await service.updateSettings(AdvisorSettings(
          advisorStyle: _selectedStyle,
          focusGoal: focusGoal,
          focusNutrient: focusNutrient,
          responseStyle: _selectedResponseStyle,
        ));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
