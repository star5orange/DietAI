import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../widgets/breed_selector.dart';
import '../../data/real_pet_api_service.dart';

/// 添加真实宠物页面
/// 包含：宠物名称、品种选择、性别、年龄、体重输入
class AddPetPage extends ConsumerStatefulWidget {
  const AddPetPage({super.key});

  @override
  ConsumerState<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends ConsumerState<AddPetPage> {
  // 表单控制器
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _customSpeciesController = TextEditingController();
  String _selectedSpecies = 'cat';
  String? _selectedBreed;
  String _selectedGender = 'male';
  DateTime? _birthDate;
  bool _isNeutered = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _customSpeciesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '添加宠物',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: const Text(
              '保存',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 宠物类型选择
            _buildSectionTitle('宠物类型'),
            const SizedBox(height: 12),
            _buildSpeciesSelector(),
            if (_selectedSpecies == 'other') ...[
              const SizedBox(height: 16),
              _buildCustomSpeciesInput(),
            ],
            const SizedBox(height: 24),

            // 宠物名称
            _buildSectionTitle('宠物名称'),
            const SizedBox(height: 12),
            _buildNameInput(),
            const SizedBox(height: 24),

            // 品种选择
            _buildSectionTitle('品种'),
            const SizedBox(height: 12),
            BreedSelectorWidget(
              species: _selectedSpecies,
              selectedBreed: _selectedBreed,
              onBreedSelected: (breed) {
                setState(() {
                  _selectedBreed = breed;
                });
              },
            ),
            const SizedBox(height: 24),

            // 性别
            _buildSectionTitle('性别'),
            const SizedBox(height: 12),
            _buildGenderSelector(),
            const SizedBox(height: 24),

            // 出生日期
            _buildSectionTitle('出生日期'),
            const SizedBox(height: 12),
            _buildBirthDateSelector(),
            const SizedBox(height: 24),

            // 体重
            _buildSectionTitle('当前体重'),
            const SizedBox(height: 12),
            _buildWeightInput(),
            const SizedBox(height: 24),

            // 绝育状态
            _buildNeuteredToggle(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// 宠物类型选择器（猫/狗/其他）
  Widget _buildSpeciesSelector() {
    return Row(
      children: [
        _buildSpeciesOption('cat', '猫咪', LucideIcons.cat),
        const SizedBox(width: 10),
        _buildSpeciesOption('dog', '狗狗', LucideIcons.dog),
        const SizedBox(width: 10),
        _buildSpeciesOption('other', '其他', LucideIcons.helpCircle),
      ],
    );
  }

  Widget _buildCustomSpeciesInput() {
    return TextField(
      controller: _customSpeciesController,
      decoration: InputDecoration(
        labelText: '请输入宠物种类（如：兔子、仓鼠、鹦鹉…）',
        hintText: '例如：兔子',
        prefixIcon: const Icon(LucideIcons.pencil),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildSpeciesOption(String species, String label, IconData icon) {
    final isSelected = _selectedSpecies == species;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSpecies = species;
            _selectedBreed = null; // 切换物种时清空品种
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 名称输入框
  Widget _buildNameInput() {
    return TextField(
      controller: _nameController,
      maxLength: 10,
      decoration: InputDecoration(
        hintText: '请输入宠物名称',
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        counterText: '',
      ),
    );
  }

  /// 性别选择器
  Widget _buildGenderSelector() {
    return Row(
      children: [
        _buildGenderOption('male', '公', Icons.male),
        const SizedBox(width: 12),
        _buildGenderOption('female', '母', Icons.female),
      ],
    );
  }

  Widget _buildGenderOption(String gender, String label, IconData icon) {
    final isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = gender;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 出生日期选择器
  Widget _buildBirthDateSelector() {
    final dateText = _birthDate != null
        ? '${_birthDate!.year}年${_birthDate!.month}月${_birthDate!.day}日'
        : '请选择出生日期';

    return GestureDetector(
      onTap: _selectBirthDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar,
                color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 12),
            Text(
              dateText,
              style: AppTextStyles.bodyMedium.copyWith(
                color: _birthDate != null
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1),
      firstDate: DateTime(2000),
      lastDate: now,
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  /// 体重输入框
  Widget _buildWeightInput() {
    return TextField(
      controller: _weightController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        hintText: '请输入体重',
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: Colors.white,
        suffixText: 'kg',
        suffixStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  /// 绝育状态开关
  Widget _buildNeuteredToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.heartPulse,
              color: AppColors.textTertiary, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已绝育',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '影响营养需求计算',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isNeutered,
            onChanged: (value) {
              setState(() {
                _isNeutered = value;
              });
            },
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// 保存宠物
  void _handleSave() async {
    // 验证必填字段
    if (_nameController.text.trim().isEmpty) {
      _showError('请输入宠物名称');
      return;
    }

    if (_selectedBreed == null) {
      _showError('请选择品种');
      return;
    }

    if (_weightController.text.trim().isEmpty) {
      _showError('请输入体重');
      return;
    }

    // 构建宠物数据
    final speciesStr = _selectedSpecies == 'other'
        ? _customSpeciesController.text.trim()
        : _selectedSpecies;
    final petData = {
      'name': _nameController.text.trim(),
      'species': speciesStr,
      'breed': _selectedBreed,
      'gender': _selectedGender,
      'birth_date': _birthDate?.toIso8601String(),
      'weight': double.tryParse(_weightController.text.trim()),
      'is_neutered': _isNeutered,
    };

    final api = RealPetApiService();
    final result = await api.createPet(petData);

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(LucideIcons.check, color: Colors.white),
              const SizedBox(width: 8),
              Text('${_nameController.text} 已添加成功！'),
            ],
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
