import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/exercise_model.dart';
import '../../../../services/exercise_service.dart';
import 'exercise_history_page.dart';

class ExerciseRecordPage extends StatefulWidget {
  const ExerciseRecordPage({super.key});

  @override
  State<ExerciseRecordPage> createState() => _ExerciseRecordPageState();
}

class _ExerciseRecordPageState extends State<ExerciseRecordPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ExerciseService _exerciseService = ExerciseService();
  List<ExerciseRecord> _records = [];
  DailyExerciseSummary? _todaySummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final recordsResult = await _exerciseService.getExerciseRecords();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final summaryResult = await _exerciseService.getDailySummary(todayStr);

      if (mounted) {
        setState(() {
          _records = recordsResult.data ?? [];
          _todaySummary = summaryResult.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '运动记录',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showAddExerciseModal(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textInverse,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(LucideIcons.activity, size: 18),
                  text: '今日概览',
                ),
                Tab(
                  icon: Icon(LucideIcons.list, size: 18),
                  text: '历史记录',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayOverviewTab(),
                _buildHistoryListTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExerciseModal(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        icon: const Icon(LucideIcons.dumbbell),
        label: const Text(
          '记录运动',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTodaySummaryCard(),
            const SizedBox(height: 20),
            _buildTodayRecordsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard() {
    final summary = _todaySummary;
    final calories = summary?.totalCaloriesBurned ?? 0.0;
    final duration = summary?.totalDurationMinutes ?? 0;
    final count = summary?.exerciseCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.flame, color: AppColors.textInverse, size: 24),
              SizedBox(width: 12),
              Text(
                '今日运动概览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textInverse,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '消耗热量',
                  '${calories.toStringAsFixed(0)}',
                  'kcal',
                  LucideIcons.flame,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '运动时长',
                  '$duration',
                  '分钟',
                  LucideIcons.clock,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '运动次数',
                  '$count',
                  '次',
                  LucideIcons.repeat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.whiteWithOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.whiteWithOpacity(0.7), size: 16),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textInverse,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.whiteWithOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.whiteWithOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRecordsList() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayRecords =
        _records.where((r) => r.recordedAt.startsWith(todayStr)).toList();

    if (todayRecords.isEmpty) {
      return _buildEmptyState('今天还没有运动记录', '点击下方按钮开始记录运动');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日记录',
          style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...todayRecords.map((record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildExerciseRecordCard(record),
            )),
      ],
    );
  }

  Widget _buildHistoryListTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ExerciseHistoryPage()),
            ),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.calendarRange,
                      color: AppColors.textInverse, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '查看完整运动历史',
                      style: TextStyle(
                        color: AppColors.textInverse,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.chevronRight,
                      color: AppColors.textInverse, size: 18),
                ],
              ),
            ),
          ),
          Expanded(
            child: _records.isEmpty
                ? _buildEmptyState('还没有运动记录', '开始记录您的运动，追踪健康进展')
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildExerciseRecordCard(_records[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRecordCard(ExerciseRecord record) {
    final typeLabel = ExerciseType.getLabel(record.exerciseType);
    final typeIcon = _getExerciseIcon(record.exerciseType);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      record.exerciseName,
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.formattedDate,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.formattedCalories,
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                record.formattedDuration,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: AppColors.textTertiary,
            onPressed: () => _showDeleteConfirmation(record),
          ),
        ],
      ),
    );
  }

  IconData _getExerciseIcon(String type) {
    switch (type) {
      case 'running':
        return LucideIcons.bike;
      case 'walking':
        return LucideIcons.footprints;
      case 'cycling':
        return LucideIcons.bike;
      case 'swimming':
        return LucideIcons.waves;
      case 'yoga':
        return LucideIcons.heart;
      case 'strength':
        return LucideIcons.dumbbell;
      case 'hiit':
        return LucideIcons.zap;
      case 'dance':
        return LucideIcons.music;
      case 'basketball':
      case 'football':
        return LucideIcons.trophy;
      case 'badminton':
      case 'tennis':
        return LucideIcons.target;
      default:
        return LucideIcons.activity;
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.dumbbell,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddExerciseModal(),
              icon: const Icon(LucideIcons.plus),
              label: const Text('添加记录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExerciseModal(
        onRecordAdded: _loadData,
        exerciseService: _exerciseService,
      ),
    );
  }

  void _showDeleteConfirmation(ExerciseRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record.exerciseName}」的运动记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _exerciseService.deleteExerciseRecord(record.id);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('运动记录已删除'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverse,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _AddExerciseModal extends StatefulWidget {
  final VoidCallback onRecordAdded;
  final ExerciseService exerciseService;

  const _AddExerciseModal({
    required this.onRecordAdded,
    required this.exerciseService,
  });

  @override
  State<_AddExerciseModal> createState() => _AddExerciseModalState();
}

class _AddExerciseModalState extends State<_AddExerciseModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = 'running';
  bool _isAutoCalories = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateAutoCalories() {
    if (!_isAutoCalories) return;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final calories =
        widget.exerciseService.estimateCalories(_selectedType, duration);
    _caloriesController.text = calories.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: bottomPadding + 24,
        ),
        child: Form(
          key: _formKey,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '记录运动',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '运动类型',
                style: AppTextStyles.labelLarge,
              ),
              const SizedBox(height: 8),
              _buildExerciseTypeGrid(),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '运动名称',
                  hintText: '例如：晨跑、游泳训练',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.tag, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入运动名称' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '运动时长（分钟）',
                  hintText: '例如：30',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.clock, size: 20),
                  suffixText: '分钟',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入运动时长';
                  final val = int.tryParse(v);
                  if (val == null || val <= 0) return '请输入有效时长';
                  return null;
                },
                onChanged: (_) => _updateAutoCalories(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '消耗热量',
                    style: AppTextStyles.labelLarge,
                  ),
                  const Spacer(),
                  Text(
                    _isAutoCalories ? '自动估算' : '手动输入',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  Switch(
                    value: _isAutoCalories,
                    onChanged: (v) {
                      setState(() => _isAutoCalories = v);
                      if (v) _updateAutoCalories();
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                enabled: !_isAutoCalories,
                decoration: InputDecoration(
                  labelText: '消耗热量（kcal）',
                  hintText: '例如：200',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(LucideIcons.flame, size: 20),
                  suffixText: 'kcal',
                  filled: _isAutoCalories,
                  fillColor: _isAutoCalories
                      ? AppColors.backgroundSecondary
                      : Colors.transparent,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return '请输入消耗热量';
                  final val = double.tryParse(v);
                  if (val == null || val < 0) return '请输入有效热量';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '记录运动感受或其他信息',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(LucideIcons.fileText, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textInverse,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textInverse),
                          ),
                        )
                      : const Text(
                          '保存记录',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTypeGrid() {
    final entries = ExerciseType.entries;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final isSelected = _selectedType == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedType = entry.key);
            _updateAutoCalories();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? AppColors.textInverse
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final result = await widget.exerciseService.createExerciseRecord(
        CreateExerciseRecordRequest(
          exerciseName: _nameController.text.trim(),
          exerciseType: _selectedType,
          durationMinutes: int.parse(_durationController.text),
          caloriesBurned: double.parse(_caloriesController.text),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onRecordAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor:
                result.success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
