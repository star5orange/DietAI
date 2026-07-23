import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/real_pet_api_service.dart';

/// 编辑宠物信息弹窗
class EditPetDialog extends StatefulWidget {
  final Map<String, dynamic> pet;

  const EditPetDialog({super.key, required this.pet});

  @override
  State<EditPetDialog> createState() => _EditPetDialogState();
}

class _EditPetDialogState extends State<EditPetDialog> {
  late TextEditingController _nameController;
  late TextEditingController _weightController;
  String _selectedGender = 'male';
  bool _isNeutered = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet['name'] ?? '');
    _weightController =
        TextEditingController(text: widget.pet['weight']?.toString() ?? '');
    _selectedGender = widget.pet['gender'] ?? 'male';
    _isNeutered = widget.pet['is_neutered'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(LucideIcons.edit3,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Text(
                  '编辑宠物信息',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child:
                      const Icon(LucideIcons.x, color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 名称
            _buildLabel('名称'),
            const SizedBox(height: 6),
            _buildTextField(_nameController, '宠物名称', maxLength: 10),
            const SizedBox(height: 16),

            // 性别
            _buildLabel('性别'),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildGenderOption('male', '公'),
                const SizedBox(width: 12),
                _buildGenderOption('female', '母'),
              ],
            ),
            const SizedBox(height: 16),

            // 体重
            _buildLabel('体重'),
            const SizedBox(height: 6),
            _buildTextField(_weightController, '体重',
                suffix: 'kg', isNumber: true),
            const SizedBox(height: 16),

            // 绝育
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('已绝育',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Switch(
                    value: _isNeutered,
                    onChanged: (v) => setState(() => _isNeutered = v),
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('删除'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('保存',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {String? suffix, bool isNumber = false, int? maxLength}) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildGenderOption(String gender, String label) {
    final isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primarySurface
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('名称不能为空');
      return;
    }
    setState(() => _isSaving = true);

    final api = RealPetApiService();
    final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
    final updateData = <String, dynamic>{
      'name': _nameController.text.trim(),
      'gender': _selectedGender,
      'is_neutered': _isNeutered,
    };

    // 体重变更 → 通过体重记录专用接口保存
    final weightVal = double.tryParse(_weightController.text.trim());
    final oldWeight = (widget.pet['weight'] as num?)?.toDouble();
    final weightChanged = weightVal != null && weightVal != oldWeight;

    final result = await api.updatePet(petId, updateData);

    if (result.isSuccess && weightChanged && weightVal != null) {
      await api.addWeight(petId, {'weight': weightVal});
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('宠物信息已更新'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, result.data);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.message), backgroundColor: AppColors.error),
      );
    }
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${widget.pet['name']} 吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final api = RealPetApiService();
              final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
              final result = await api.deletePet(petId);
              if (!mounted) return;
              if (result.isSuccess) {
                Navigator.pop(context, 'deleted');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }
}
