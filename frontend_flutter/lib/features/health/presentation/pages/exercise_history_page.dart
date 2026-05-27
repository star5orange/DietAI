import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/exercise_model.dart';
import '../../../../services/exercise_service.dart';

class ExerciseHistoryPage extends StatefulWidget {
  const ExerciseHistoryPage({super.key});

  @override
  State<ExerciseHistoryPage> createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  final ExerciseService _exerciseService = ExerciseService();
  List<ExerciseRecord> _allRecords = [];
  List<ExerciseRecord> _filteredRecords = [];
  bool _isLoading = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final result = await _exerciseService.getExerciseRecords();
      if (mounted) {
        setState(() {
          _allRecords = result.data ?? [];
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var records = _allRecords.where((r) {
      try {
        final date = DateTime.parse(r.recordedAt);
        final afterStart =
            date.isAfter(_startDate.subtract(const Duration(microseconds: 1)));
        final beforeEnd = date.isBefore(_endDate.add(const Duration(days: 1)));
        return afterStart && beforeEnd;
      } catch (e) {
        return false;
      }
    }).toList();

    if (_selectedType != null) {
      records = records.where((r) => r.exerciseType == _selectedType).toList();
    }

    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    setState(() {
      _filteredRecords = records;
    });
  }

  Map<String, List<ExerciseRecord>> _groupByDate() {
    final map = <String, List<ExerciseRecord>>{};
    for (final record in _filteredRecords) {
      final dateStr = record.recordedAt.substring(0, 10);
      map.putIfAbsent(dateStr, () => []).add(record);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: map[k]!};
  }

  String _formatDateHeader(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      String label;
      if (diff == 0) {
        label = '今天';
      } else if (diff == 1) {
        label = '昨天';
      } else if (diff == 2) {
        label = '前天';
      } else if (diff < 7) {
        label = '$diff天前';
      } else {
        label = '${date.month}月${date.day}日';
      }
      return '$label  ${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  DailyExerciseSummary _calcDaySummary(List<ExerciseRecord> records) {
    return DailyExerciseSummary(
      date: records.first.recordedAt.substring(0, 10),
      totalCaloriesBurned:
          records.fold(0.0, (sum, r) => sum + r.caloriesBurned),
      totalDurationMinutes:
          records.fold(0, (sum, r) => sum + r.durationMinutes),
      exerciseCount: records.length,
    );
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(LucideIcons.filter,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('按运动类型筛选',
                      style: AppTextStyles.h6
                          .copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _selectedType = null);
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    child: const Text('清除筛选'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExerciseType.entries.map((entry) {
                  final isSelected = _selectedType == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundColor: AppColors.backgroundSecondary,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedType = isSelected ? null : entry.key;
                      });
                      _applyFilters();
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ExerciseRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record.exerciseName}」的运动记录吗？'),
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

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title:
            const Text('运动历史', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: _showTypeFilter,
            tooltip: '按类型筛选',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final dateStr = grouped.keys.elementAt(index);
                            final dayRecords = grouped[dateStr]!;
                            final summary = _calcDaySummary(dayRecords);
                            return _buildDateSection(
                                dateStr, dayRecords, summary);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    String dateLabel;
    if (daysDiff >= 364) {
      dateLabel = '近1年';
    } else if (daysDiff >= 89) {
      dateLabel = '近3个月';
    } else if (daysDiff >= 29) {
      dateLabel = '近1个月';
    } else if (daysDiff >= 6) {
      dateLabel = '近1周';
    } else {
      dateLabel =
          '${_startDate.month}/${_startDate.day} - ${_endDate.month}/${_endDate.day}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: _showDateRangePicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.calendar,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 20, color: AppColors.border),
          const SizedBox(width: 12),
          if (_selectedType != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ExerciseType.getLabel(_selectedType!),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedType = null);
                      _applyFilters();
                    },
                    child: const Icon(LucideIcons.x,
                        size: 14, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _showTypeFilter,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.tag,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '全部类型',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text(
            '${_filteredRecords.length} 条记录',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(
    String dateStr,
    List<ExerciseRecord> records,
    DailyExerciseSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDateHeader(dateStr),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.flame, size: 14, color: AppColors.accent),
                  const SizedBox(width: 3),
                  Text(
                    summary.formattedTotalCalories,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(LucideIcons.clock,
                      size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    summary.formattedTotalDuration,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...records.map((record) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildRecordCard(record),
            )),
      ],
    );
  }

  Widget _buildRecordCard(ExerciseRecord record) {
    final typeLabel = ExerciseType.getLabel(record.exerciseType);
    final typeIcon = _getExerciseIcon(record.exerciseType);

    return Dismissible(
      key: Key(record.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await _exerciseService.deleteExerciseRecord(record.id);
        _loadData();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.trash2, color: AppColors.textInverse),
      ),
      confirmDismiss: (_) async {
        _showDeleteConfirmation(record);
        return false;
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(typeIcon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          record.exerciseName,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.formattedDate,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  record.formattedCalories,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record.formattedDuration,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
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
              _selectedType != null ||
                      _startDate !=
                          DateTime.now().subtract(const Duration(days: 30))
                  ? '没有符合条件的运动记录'
                  : '还没有运动记录',
              style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedType != null ? '尝试更换筛选条件' : '开始记录您的运动，追踪健康进展',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
