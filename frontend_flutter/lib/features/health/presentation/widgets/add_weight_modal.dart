import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/weight_record_model.dart';
import '../providers/weight_records_provider.dart';

class AddWeightModal extends ConsumerStatefulWidget {
  final WeightRecord? existingRecord;
  final VoidCallback? onRecordAdded;

  const AddWeightModal({
    super.key,
    this.existingRecord,
    this.onRecordAdded,
  });

  @override
  ConsumerState<AddWeightModal> createState() => _AddWeightModalState();
}

class _AddWeightModalState extends ConsumerState<AddWeightModal> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _muscleMassController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _measuredAt = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    if (widget.existingRecord != null) {
      final record = widget.existingRecord!;
      _weightController.text = record.weight.toString();
      if (record.bodyFatPercentage != null) {
        _bodyFatController.text = record.bodyFatPercentage!.toString();
      }
      if (record.muscleMass != null) {
        _muscleMassController.text = record.muscleMass!.toString();
      }
      if (record.notes != null) {
        _notesController.text = record.notes!;
      }
      try {
        _measuredAt = DateTime.parse(record.measuredAt);
      } catch (e) {
        _measuredAt = DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bodyFatController.dispose();
    _muscleMassController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;
    
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                _buildHeader(isEditing),
                const SizedBox(height: 24),
                
                // 体重输入
                _buildWeightSection(),
                const SizedBox(height: 20),
                
                // 可选数据输入
                _buildOptionalDataSection(),
                const SizedBox(height: 20),
                
                // 测量时间
                _buildTimeSection(),
                const SizedBox(height: 20),
                
                // 备注
                _buildNotesSection(),
                const SizedBox(height: 32),
                
                // 底部按钮
                _buildActionButtons(isEditing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            LucideIcons.scale,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? '编辑体重记录' : '记录体重',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEditing ? '更新您的体重数据' : '记录您当前的体重和体态数据',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }

  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '体重 *',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '输入您的体重',
            suffixText: 'kg',
            prefixIcon: const Icon(LucideIcons.scale),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入体重';
            }
            final weight = double.tryParse(value);
            if (weight == null || weight <= 0 || weight > 500) {
              return '请输入有效的体重（1-500kg）';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOptionalDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '其他数据（可选）',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            // 体脂率
            Expanded(
              child: TextFormField(
                controller: _bodyFatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '体脂率',
                  hintText: '0.0',
                  suffixText: '%',
                  prefixIcon: const Icon(LucideIcons.droplet),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final bodyFat = double.tryParse(value);
                    if (bodyFat == null || bodyFat < 0 || bodyFat > 100) {
                      return '体脂率范围：0-100%';
                    }
                  }
                  return null;
                },
              ),
            ),
            
            const SizedBox(width: 12),
            
            // 肌肉量
            Expanded(
              child: TextFormField(
                controller: _muscleMassController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '肌肉量',
                  hintText: '0.0',
                  suffixText: 'kg',
                  prefixIcon: const Icon(LucideIcons.zap),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final muscleMass = double.tryParse(value);
                    if (muscleMass == null || muscleMass <= 0 || muscleMass > 200) {
                      return '肌肉量范围：1-200kg';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '测量时间',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDateTime,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendar,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getFormattedDateTime(),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '备注（可选）',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '记录当天的感受、运动情况等...',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Icon(LucideIcons.fileText),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isEditing ? '更新' : '保存'),
          ),
        ),
      ],
    );
  }

  String _getFormattedDateTime() {
    final date = _measuredAt;
    return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_measuredAt),
      );
      
      if (time != null) {
        setState(() {
          _measuredAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final weight = double.parse(_weightController.text);
      final bodyFat = _bodyFatController.text.isNotEmpty 
        ? double.parse(_bodyFatController.text) 
        : null;
      final muscleMass = _muscleMassController.text.isNotEmpty 
        ? double.parse(_muscleMassController.text) 
        : null;
      final notes = _notesController.text.isNotEmpty ? _notesController.text : null;
      final measuredAtString = _measuredAt.toIso8601String();
      
      if (widget.existingRecord != null) {
        // 更新记录
        final request = UpdateWeightRecordRequest(
          weight: weight,
          bodyFatPercentage: bodyFat,
          muscleMass: muscleMass,
          measuredAt: measuredAtString,
          notes: notes,
        );
        
        final result = await ref.read(weightRecordsProvider.notifier)
          .updateWeightRecord(widget.existingRecord!.id, request);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.success ? AppColors.success : AppColors.error,
            ),
          );
          
          if (result.success) {
            Navigator.pop(context);
            widget.onRecordAdded?.call();
          }
        }
      } else {
        // 创建记录
        final request = CreateWeightRecordRequest(
          weight: weight,
          bodyFatPercentage: bodyFat,
          muscleMass: muscleMass,
          measuredAt: measuredAtString,
          notes: notes,
        );
        
        final result = await ref.read(weightRecordsProvider.notifier)
          .createWeightRecord(request);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: result.success ? AppColors.success : AppColors.error,
            ),
          );
          
          if (result.success) {
            Navigator.pop(context);
            widget.onRecordAdded?.call();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}