import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../data/real_pet_api_service.dart';

/// 添加/编辑体重记录弹窗
class AddWeightModal extends StatefulWidget {
  final int petId;
  final VoidCallback onSaved;
  final int? recordId;
  final Map<String, dynamic>? existingData;

  const AddWeightModal({
    super.key,
    required this.petId,
    required this.onSaved,
    this.recordId,
    this.existingData,
  });

  bool get isEdit => recordId != null;

  @override
  State<AddWeightModal> createState() => _AddWeightModalState();
}

class _AddWeightModalState extends State<AddWeightModal> {
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _weightController.text =
          (widget.existingData!['weight'] ?? '').toString();
      _notesController.text = (widget.existingData!['notes'] ?? '').toString();
      final dateStr = widget.existingData!['measured_at'] as String?;
      if (dateStr != null) {
        _selectedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  const Icon(LucideIcons.scale,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    widget.isEdit ? '编辑体重' : '记录体重',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      LucideIcons.x,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 体重输入
              const Text(
                '体重 (kg)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入体重',
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: 'kg',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),

              // 日期选择
              const Text(
                '测量日期',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar,
                          size: 18, color: AppColors.textTertiary),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.chevronDown,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 备注输入
              const Text(
                '备注（可选）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: '例如：饭后称重',
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('zh', 'CN'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    final weightText = _weightController.text.trim();

    if (weightText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入体重')),
      );
      return;
    }

    final weight = double.tryParse(weightText);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的体重数值')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final api = RealPetApiService();
    ApiResponse<dynamic> result;
    if (widget.isEdit) {
      result = await api.updateWeightRecord(widget.petId, widget.recordId!, {
        'weight': weight,
        'measured_at': _selectedDate.toIso8601String(),
        'notes': _notesController.text.trim(),
      });
    } else {
      result = await api.addWeight(widget.petId, {
        'weight': weight,
        'record_time': _selectedDate.toIso8601String(),
        'notes': _notesController.text.trim(),
      });
    }

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? '体重记录已更新' : '体重记录已保存'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onSaved();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
