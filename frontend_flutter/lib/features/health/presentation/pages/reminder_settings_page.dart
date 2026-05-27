import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/reminder_model.dart';
import '../../../../services/reminder_service.dart';

class ReminderSettingsPage extends StatefulWidget {
  const ReminderSettingsPage({super.key});

  @override
  State<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderSettingsPageState extends State<ReminderSettingsPage> {
  final ReminderService _reminderService = ReminderService();
  List<ReminderRecord> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _reminderService.getReminders();
      if (mounted) {
        setState(() {
          _reminders = result.data ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleReminder(ReminderRecord record, bool value) async {
    try {
      await _reminderService.toggleReminder(record.id, value);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '提醒已开启' : '提醒已关闭'),
            backgroundColor: value ? AppColors.success : AppColors.textTertiary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddReminderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditReminderModal(
        onSave: (record) async {
          await _reminderService.addReminder(record);
          _loadData();
        },
      ),
    );
  }

  void _showEditReminderModal(ReminderRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddEditReminderModal(
        existingRecord: record,
        onSave: (updated) async {
          await _reminderService.updateReminder(updated);
          _loadData();
        },
      ),
    );
  }

  void _showDeleteConfirmation(ReminderRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('确认删除',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
        content: Text('确定要删除「${record.title}」提醒吗？此操作不可撤销。',
            style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _reminderService.deleteReminder(record.id);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('提醒已删除'),
                        backgroundColor: AppColors.success),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('删除失败: $e'),
                        backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverse,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title:
            const Text('提醒设置', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _reminders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildQuickAddHint(),
                      const SizedBox(height: 16),
                      ..._reminders.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReminderCard(r),
                          )),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderModal,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        elevation: 4,
        icon: const Icon(LucideIcons.bellPlus, size: 20),
        label:
            const Text('添加提醒', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildQuickAddHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryWithOpacity(0.08),
            AppColors.primaryLight.withValues(alpha: 0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryWithOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryWithOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.lightbulb,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置提醒，养成健康习惯',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('定时提醒帮助你坚持饮食和运动计划',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ReminderRecord record) {
    final typeIcon = ReminderType.getIcon(record.type);
    final typeLabel = ReminderType.getLabel(record.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: record.isEnabled
                      ? AppColors.primaryWithOpacity(0.1)
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                    child:
                        Text(typeIcon, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            record.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: record.isEnabled
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: record.isEnabled
                                ? AppColors.primaryWithOpacity(0.08)
                                : AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: record.isEnabled
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.message ?? '',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: record.isEnabled,
                onChanged: (v) => _toggleReminder(record, v),
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.clock,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  record.formattedTime,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: record.isEnabled
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(LucideIcons.repeat,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    record.repeatDaysText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: record.isEnabled
                          ? AppColors.textSecondary
                          : AppColors.textTertiary,
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
                      _showEditReminderModal(record);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(record);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryWithOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.bell,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text('暂无提醒',
                style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('添加提醒帮助你养成健康习惯',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showAddReminderModal,
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('添加提醒'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditReminderModal extends StatefulWidget {
  final ReminderRecord? existingRecord;
  final Future<void> Function(ReminderRecord) onSave;

  const _AddEditReminderModal({this.existingRecord, required this.onSave});

  @override
  State<_AddEditReminderModal> createState() => _AddEditReminderModalState();
}

class _AddEditReminderModalState extends State<_AddEditReminderModal> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedType = ReminderType.meal;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  List<int> _selectedDays = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRecord != null) {
      final r = widget.existingRecord!;
      _selectedType = r.type;
      _selectedTime = TimeOfDay(hour: r.hour, minute: r.minute);
      _selectedDays = List<int>.from(r.repeatDays);
      _titleController.text = r.title;
      _messageController.text = r.message ?? '';
    } else {
      _titleController.text = ReminderType.getLabel(_selectedType);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String type) {
    setState(() {
      _selectedType = type;
      if (widget.existingRecord == null) {
        _titleController.text = ReminderType.getLabel(type);
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context)
                .colorScheme
                .copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _setAllDays() {
    setState(() {
      if (_selectedDays.length == 7) {
        _selectedDays.clear();
      } else {
        _selectedDays = [1, 2, 3, 4, 5, 6, 7];
      }
    });
  }

  void _setWorkdays() {
    setState(() {
      _selectedDays = [1, 2, 3, 4, 5];
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入提醒标题'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      final record = ReminderRecord(
        id: widget.existingRecord?.id ?? now.millisecondsSinceEpoch.toString(),
        type: _selectedType,
        title: _titleController.text.trim(),
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        repeatDays: _selectedDays,
        isEnabled: widget.existingRecord?.isEnabled ?? true,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        createdAt: widget.existingRecord?.createdAt ?? now.toIso8601String(),
      );

      await widget.onSave(record);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingRecord != null ? '提醒已更新' : '提醒已添加'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            left: 24, right: 24, top: 16, bottom: bottomPadding + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(isEditing ? '编辑提醒' : '添加提醒',
                style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _buildSectionLabel('提醒类型'),
            const SizedBox(height: 8),
            _buildTypeGrid(),
            const SizedBox(height: 20),
            _buildSectionLabel('提醒时间'),
            const SizedBox(height: 8),
            _buildTimePicker(),
            const SizedBox(height: 20),
            _buildSectionLabel('重复日'),
            const SizedBox(height: 8),
            _buildRepeatDays(),
            const SizedBox(height: 20),
            _buildSectionLabel('提醒标题'),
            const SizedBox(height: 8),
            _buildTextField(_titleController, '例如：早餐时间', LucideIcons.type,
                maxLines: 1),
            const SizedBox(height: 16),
            _buildSectionLabel('提醒内容（可选）'),
            const SizedBox(height: 8),
            _buildTextField(
                _messageController, '例如：记得吃早餐，补充能量', LucideIcons.messageSquare,
                maxLines: 2),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textInverse))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isEditing ? LucideIcons.check : LucideIcons.plus,
                              size: 18),
                          const SizedBox(width: 8),
                          Text(isEditing ? '保存修改' : '添加提醒',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: AppTextStyles.labelLarge);
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true,
        fillColor: AppColors.backgroundSecondary,
        prefixIcon: Padding(
          padding: maxLines > 1
              ? const EdgeInsets.only(bottom: 24)
              : EdgeInsets.zero,
          child: Icon(icon, size: 20, color: AppColors.textTertiary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildTypeGrid() {
    final entries = ReminderType.entries;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final isSelected = _selectedType == entry.key;
        final icon = ReminderType.getIcon(entry.key);
        return GestureDetector(
          onTap: () => _onTypeChanged(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.primary : AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      isSelected ? AppColors.primary : AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AppColors.textInverse
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryWithOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.clock,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
              style: AppTextStyles.numberMedium
                  .copyWith(color: AppColors.textPrimary),
            ),
            const Spacer(),
            Icon(LucideIcons.chevronDown,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatDays() {
    const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    return Column(
      children: [
        Row(
          children: [
            _buildQuickSelectChip('每天', _selectedDays.length == 7, _setAllDays),
            const SizedBox(width: 8),
            _buildQuickSelectChip(
                '工作日',
                _selectedDays.length == 5 &&
                    ![6, 7].any((d) => _selectedDays.contains(d)),
                _setWorkdays),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final day = i + 1;
            final isSelected = _selectedDays.contains(day);
            return GestureDetector(
              onTap: () => _toggleDay(day),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.backgroundTertiary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.borderLight),
                ),
                child: Center(
                  child: Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppColors.textInverse
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuickSelectChip(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
