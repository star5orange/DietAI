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

class HealthInfoSheet extends ConsumerStatefulWidget {
  const HealthInfoSheet({super.key});

  @override
  ConsumerState<HealthInfoSheet> createState() => _HealthInfoSheetState();
}

class _HealthInfoSheetState extends ConsumerState<HealthInfoSheet> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAddingDisease = false;
  bool _isAddingAllergy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diseasesProvider.notifier).loadDiseases();
      ref.read(allergiesProvider.notifier).loadAllergies();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          _buildHeader(),
          
          // 标签栏
          if (!_isAddingDisease && !_isAddingAllergy) _buildTabBar(),
          
          // 内容
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    String title = '健康信息';
    if (_isAddingDisease) {
      title = '添加疾病信息';
    } else if (_isAddingAllergy) {
      title = '添加过敏信息';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_isAddingDisease || _isAddingAllergy) {
                setState(() {
                  _isAddingDisease = false;
                  _isAddingAllergy = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon((_isAddingDisease || _isAddingAllergy) 
                ? LucideIcons.arrowLeft 
                : LucideIcons.x),
          ),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
          ),
          if (!_isAddingDisease && !_isAddingAllergy)
            IconButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  setState(() {
                    _isAddingDisease = true;
                  });
                } else {
                  setState(() {
                    _isAddingAllergy = true;
                  });
                }
              },
              icon: const Icon(LucideIcons.plus),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '疾病信息'),
          Tab(text: '过敏信息'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),
    );
  }

  Widget _buildContent() {
    if (_isAddingDisease) {
      return _buildAddDiseaseForm();
    } else if (_isAddingAllergy) {
      return _buildAddAllergyForm();
    } else {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildDiseasesTab(),
          _buildAllergiesTab(),
        ],
      );
    }
  }

  Widget _buildDiseasesTab() {
    final diseasesAsync = ref.watch(diseasesProvider);
    
    return diseasesAsync.when(
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
              onPressed: () => ref.read(diseasesProvider.notifier).loadDiseases(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (diseases) {
        final currentDiseases = ref.read(diseasesProvider.notifier).currentDiseases;
        final historicalDiseases = ref.read(diseasesProvider.notifier).historicalDiseases;
        
        if (diseases.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.heart,
            title: '暂无疾病信息',
            subtitle: '管理您的健康状况',
            onAdd: () => setState(() => _isAddingDisease = true),
          );
        }
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前疾病
              if (currentDiseases.isNotEmpty) ...[
                _buildSectionTitle('当前疾病'),
                const SizedBox(height: 12),
                ...currentDiseases.map((disease) => _buildDiseaseCard(disease)),
                const SizedBox(height: 24),
              ],
              
              // 历史疾病
              if (historicalDiseases.isNotEmpty) ...[
                _buildSectionTitle('历史疾病'),
                const SizedBox(height: 12),
                ...historicalDiseases.map((disease) => _buildDiseaseCard(disease)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllergiesTab() {
    final allergiesAsync = ref.watch(allergiesProvider);
    
    return allergiesAsync.when(
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
              onPressed: () => ref.read(allergiesProvider.notifier).loadAllergies(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (allergies) {
        final foodAllergies = ref.read(allergiesProvider.notifier).foodAllergies;
        final medicineAllergies = ref.read(allergiesProvider.notifier).medicineAllergies;
        final environmentAllergies = ref.read(allergiesProvider.notifier).environmentAllergies;
        
        if (allergies.isEmpty) {
          return _buildEmptyState(
            icon: LucideIcons.shield,
            title: '暂无过敏信息',
            subtitle: '记录您的过敏原信息',
            onAdd: () => setState(() => _isAddingAllergy = true),
          );
        }
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 食物过敏
              if (foodAllergies.isNotEmpty) ...[
                _buildSectionTitle('食物过敏'),
                const SizedBox(height: 12),
                ...foodAllergies.map((allergy) => _buildAllergyCard(allergy)),
                const SizedBox(height: 24),
              ],
              
              // 药物过敏
              if (medicineAllergies.isNotEmpty) ...[
                _buildSectionTitle('药物过敏'),
                const SizedBox(height: 12),
                ...medicineAllergies.map((allergy) => _buildAllergyCard(allergy)),
                const SizedBox(height: 24),
              ],
              
              // 环境过敏
              if (environmentAllergies.isNotEmpty) ...[
                _buildSectionTitle('环境过敏'),
                const SizedBox(height: 12),
                ...environmentAllergies.map((allergy) => _buildAllergyCard(allergy)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAdd,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.h6.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(LucideIcons.plus),
            label: const Text('添加'),
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

  Widget _buildDiseaseCard(Disease disease) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: disease.isCurrent 
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.heart,
                  size: 16,
                  color: disease.isCurrent ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.diseaseName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (disease.severityLevel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '严重程度: ${disease.severityText}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: disease.isCurrent 
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  disease.isCurrent ? '当前' : '历史',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: disease.isCurrent ? AppColors.error : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical,
                    size: 18, color: AppColors.textTertiary),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(LucideIcons.pencil,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        const Text('编辑')
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(LucideIcons.trash2,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: AppColors.error))
                      ])),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditDiseaseDialog(disease);
                  } else if (value == 'delete') {
                    _showDeleteDiseaseConfirmation(disease);
                  }
                },
              ),
            ],
          ),
          if (disease.diagnosedDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '诊断日期: ${disease.diagnosedDate!.split('T')[0]}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (disease.notes != null) ...[
            const SizedBox(height: 8),
            Text(
              disease.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllergyCard(Allergy allergy) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.shield,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allergy.allergenName,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '类型: ${allergy.allergenTypeText}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (allergy.severityLevel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '严重程度: ${allergy.severityText}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.moreVertical,
                    size: 18, color: AppColors.textTertiary),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(LucideIcons.pencil,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        const Text('编辑')
                      ])),
                  PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(LucideIcons.trash2,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text('删除', style: TextStyle(color: AppColors.error))
                      ])),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditAllergyDialog(allergy);
                  } else if (value == 'delete') {
                    _showDeleteAllergyConfirmation(allergy);
                  }
                },
              ),
            ],
          ),
          if (allergy.reactionDescription != null) ...[
            const SizedBox(height: 8),
            Text(
              '反应描述: ${allergy.reactionDescription}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddDiseaseForm() {
    return const _AddDiseaseForm();
  }

  Widget _buildAddAllergyForm() {
    return const _AddAllergyForm();
  }

  void _showEditDiseaseDialog(Disease disease) {
    final nameController = TextEditingController(text: disease.diseaseName);
    final codeController = TextEditingController(text: disease.diseaseCode ?? '');
    final notesController = TextEditingController(text: disease.notes ?? '');
    int severityLevel = disease.severityLevel ?? 1;
    bool isCurrent = disease.isCurrent;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑疾病信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '疾病名称 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '疾病编码',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: severityLevel,
                  decoration: const InputDecoration(
                    labelText: '严重程度',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('轻度')),
                    DropdownMenuItem(value: 2, child: Text('中度')),
                    DropdownMenuItem(value: 3, child: Text('重度')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => severityLevel = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('当前患病'),
                  value: isCurrent,
                  onChanged: (value) {
                    setDialogState(() => isCurrent = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入疾病名称')),
                  );
                  return;
                }
                Navigator.pop(context);
                final success = await ref.read(diseasesProvider.notifier).updateDisease(
                  disease.id,
                  DiseaseCreateRequest(
                    diseaseName: nameController.text.trim(),
                    diseaseCode: codeController.text.trim().isEmpty
                        ? null
                        : codeController.text.trim(),
                    severityLevel: severityLevel,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  ),
                );
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('疾病信息更新成功')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('更新失败')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDiseaseConfirmation(Disease disease) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${disease.diseaseName}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(diseasesProvider.notifier).deleteDisease(disease.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('疾病信息已删除')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除失败')),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditAllergyDialog(Allergy allergy) {
    final nameController = TextEditingController(text: allergy.allergenName);
    final reactionController = TextEditingController(text: allergy.reactionDescription ?? '');
    int allergenType = allergy.allergenType;
    int severityLevel = allergy.severityLevel ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑过敏信息'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: allergenType,
                  decoration: const InputDecoration(
                    labelText: '过敏原类型',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('食物')),
                    DropdownMenuItem(value: 2, child: Text('药物')),
                    DropdownMenuItem(value: 3, child: Text('环境')),
                    DropdownMenuItem(value: 4, child: Text('其他')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => allergenType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '过敏原名称 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: severityLevel,
                  decoration: const InputDecoration(
                    labelText: '严重程度',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('轻度')),
                    DropdownMenuItem(value: 2, child: Text('中度')),
                    DropdownMenuItem(value: 3, child: Text('重度')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => severityLevel = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reactionController,
                  decoration: const InputDecoration(
                    labelText: '过敏反应描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入过敏原名称')),
                  );
                  return;
                }
                Navigator.pop(context);
                final success = await ref.read(allergiesProvider.notifier).updateAllergy(
                  allergy.id,
                  AllergyCreateRequest(
                    allergenType: allergenType,
                    allergenName: nameController.text.trim(),
                    severityLevel: severityLevel,
                    reactionDescription: reactionController.text.trim().isEmpty
                        ? null
                        : reactionController.text.trim(),
                  ),
                );
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('过敏信息更新成功')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('更新失败')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllergyConfirmation(Allergy allergy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${allergy.allergenName}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(allergiesProvider.notifier).deleteAllergy(allergy.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('过敏信息已删除')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除失败')),
                );
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _AddDiseaseForm extends ConsumerStatefulWidget {
  const _AddDiseaseForm();

  @override
  ConsumerState<_AddDiseaseForm> createState() => _AddDiseaseFormState();
}

class _AddDiseaseFormState extends ConsumerState<_AddDiseaseForm> {
  final _formKey = GlobalKey<FormState>();
  final _diseaseNameController = TextEditingController();
  final _diseaseCodeController = TextEditingController();
  final _notesController = TextEditingController();
  
  int? _selectedSeverity;
  String? _selectedDiagnosedDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _diseaseNameController.dispose();
    _diseaseCodeController.dispose();
    _notesController.dispose();
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
            AppInput(
              controller: _diseaseNameController,
              label: '疾病名称',
              prefixIcon: LucideIcons.heart,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入疾病名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _diseaseCodeController,
              label: '疾病代码（可选）',
              prefixIcon: LucideIcons.tag,
            ),
            const SizedBox(height: 16),
            _buildSeveritySelector(),
            const SizedBox(height: 16),
            _buildDiagnosedDateSelector(),
            const SizedBox(height: 16),
            AppInput(
              controller: _notesController,
              label: '备注',
              prefixIcon: LucideIcons.fileText,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitDisease,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加疾病'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeveritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('严重程度', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSeverityOption(1, '轻度'),
            const SizedBox(width: 12),
            _buildSeverityOption(2, '中度'),
            const SizedBox(width: 12),
            _buildSeverityOption(3, '重度'),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityOption(int value, String label) {
    final isSelected = _selectedSeverity == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSeverity = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosedDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('诊断日期', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDiagnosedDate,
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
                    _selectedDiagnosedDate?.split('T')[0] ?? '选择诊断日期（可选）',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedDiagnosedDate != null 
                          ? AppColors.textPrimary 
                          : AppColors.textSecondary,
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

  Future<void> _selectDiagnosedDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (selectedDate != null) {
      setState(() {
        _selectedDiagnosedDate = selectedDate.toIso8601String();
      });
    }
  }

  Future<void> _submitDisease() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = DiseaseCreateRequest(
        diseaseName: _diseaseNameController.text.trim(),
        diseaseCode: _diseaseCodeController.text.trim().isEmpty 
            ? null 
            : _diseaseCodeController.text.trim(),
        severityLevel: _selectedSeverity,
        diagnosedDate: _selectedDiagnosedDate,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      final success = await ref.read(diseasesProvider.notifier).addDisease(request);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('疾病信息添加成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加失败，请重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
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

class _AddAllergyForm extends ConsumerStatefulWidget {
  const _AddAllergyForm();

  @override
  ConsumerState<_AddAllergyForm> createState() => _AddAllergyFormState();
}

class _AddAllergyFormState extends ConsumerState<_AddAllergyForm> {
  final _formKey = GlobalKey<FormState>();
  final _allergenNameController = TextEditingController();
  final _reactionController = TextEditingController();
  
  int _selectedType = 1;
  int? _selectedSeverity;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _allergenTypes = [
    {'value': 1, 'label': '食物', 'icon': LucideIcons.apple},
    {'value': 2, 'label': '药物', 'icon': LucideIcons.pill},
    {'value': 3, 'label': '环境', 'icon': LucideIcons.leaf},
    {'value': 4, 'label': '其他', 'icon': LucideIcons.moreHorizontal},
  ];

  @override
  void dispose() {
    _allergenNameController.dispose();
    _reactionController.dispose();
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
            _buildTypeSelector(),
            const SizedBox(height: 16),
            AppInput(
              controller: _allergenNameController,
              label: '过敏原名称',
              prefixIcon: LucideIcons.shield,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入过敏原名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildSeveritySelector(),
            const SizedBox(height: 16),
            AppInput(
              controller: _reactionController,
              label: '反应描述',
              prefixIcon: LucideIcons.fileText,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitAllergy,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加过敏'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('过敏原类型', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allergenTypes.map((type) {
            final isSelected = _selectedType == type['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type['value']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'],
                      size: 16,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['label'],
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeveritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('严重程度', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildSeverityOption(1, '轻度'),
            const SizedBox(width: 12),
            _buildSeverityOption(2, '中度'),
            const SizedBox(width: 12),
            _buildSeverityOption(3, '重度'),
          ],
        ),
      ],
    );
  }

  Widget _buildSeverityOption(int value, String label) {
    final isSelected = _selectedSeverity == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSeverity = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitAllergy() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = AllergyCreateRequest(
        allergenType: _selectedType,
        allergenName: _allergenNameController.text.trim(),
        severityLevel: _selectedSeverity,
        reactionDescription: _reactionController.text.trim().isEmpty 
            ? null 
            : _reactionController.text.trim(),
      );

      final success = await ref.read(allergiesProvider.notifier).addAllergy(request);
      
      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('过敏信息添加成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加失败，请重试')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
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