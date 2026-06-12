import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../../domain/services/user_service.dart';
import '../providers/profile_provider.dart';

class WeightRecordsSheet extends ConsumerStatefulWidget {
  const WeightRecordsSheet({super.key});

  @override
  ConsumerState<WeightRecordsSheet> createState() => _WeightRecordsSheetState();
}

class _WeightRecordsSheetState extends ConsumerState<WeightRecordsSheet> {
  bool _isAddingRecord = false;
  bool _showChart = true;

  @override
  void initState() {
    super.initState();
    // 加载体重记录数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(weightRecordsProvider.notifier).loadWeightRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final weightRecordsAsync = ref.watch(weightRecordsProvider);
    
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

          // 内容
          Expanded(
            child: _isAddingRecord
                ? _buildAddRecordForm()
                : _buildRecordsList(weightRecordsAsync),
          ),

          // 底部记录按钮（添加记录表单时不显示）
          if (!_isAddingRecord) _buildBottomRecordButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (_isAddingRecord) {
                setState(() {
                  _isAddingRecord = false;
                });
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(_isAddingRecord ? LucideIcons.arrowLeft : LucideIcons.x),
          ),
          Expanded(
            child: Text(
              _isAddingRecord ? '添加体重记录' : '体重记录',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
          ),
          if (!_isAddingRecord)
            IconButton(
              onPressed: () {
                setState(() {
                  _showChart = !_showChart;
                });
              },
              icon: Icon(_showChart ? LucideIcons.list : LucideIcons.barChart3),
            ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(AsyncValue<List<WeightRecord>> weightRecordsAsync) {
    return weightRecordsAsync.when(
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
              onPressed: () => ref.read(weightRecordsProvider.notifier).loadWeightRecords(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (records) {
        if (records.isEmpty) {
          return _buildEmptyState();
        }
        
        return SingleChildScrollView(
          child: Column(
            children: [
              // 图表视图
              if (_showChart) ...[
                _buildWeightChart(records),
                const SizedBox(height: 16),
              ],
              
              // 统计信息
              _buildStatsRow(records),
              
              // 记录列表
              _buildRecordsListView(records),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.scale, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            '暂无体重记录',
            style: AppTextStyles.h6.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '记录您的体重变化，追踪健康进展',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isAddingRecord = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '记录',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                Text(
                  '体重',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部记录体重按钮 — 与健康目标页「新建目标」FAB 风格一致
  Widget _buildBottomRecordButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _isAddingRecord = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '记录',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
                Text(
                  '体重',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeightChart(List<WeightRecord> records) {
    if (records.length < 2) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '至少需要2个记录才能显示图表',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    // 按时间排序
    final sortedRecords = List<WeightRecord>.from(records)
      ..sort((a, b) => DateTime.parse(a.measuredAt).compareTo(DateTime.parse(b.measuredAt)));

    // 获取最近30天的记录
    final recentRecords = ref.read(weightRecordsProvider.notifier).recentRecords;
    if (recentRecords.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '最近30天内没有记录',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppColors.divider,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < 0 || value.toInt() >= recentRecords.length) {
                    return const Text('');
                  }
                  final record = recentRecords[value.toInt()];
                  final date = DateTime.parse(record.measuredAt);
                  return Text(
                    '${date.month}/${date.day}',
                    style: AppTextStyles.bodySmall,
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}kg',
                    style: AppTextStyles.bodySmall,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: AppColors.divider),
          ),
          minX: 0,
          maxX: (recentRecords.length - 1).toDouble(),
          minY: recentRecords.map((r) => r.weight).reduce((a, b) => a < b ? a : b) - 2,
          maxY: recentRecords.map((r) => r.weight).reduce((a, b) => a > b ? a : b) + 2,
          lineBarsData: [
            LineChartBarData(
              spots: recentRecords.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.weight);
              }).toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: AppColors.cardBackground,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<WeightRecord> records) {
    final latestRecord = ref.read(weightRecordsProvider.notifier).latestRecord;
    final recentRecords = ref.read(weightRecordsProvider.notifier).recentRecords;
    
    // 计算变化趋势
    double? weightChange;
    if (recentRecords.length >= 2) {
      final sortedRecords = List<WeightRecord>.from(recentRecords)
        ..sort((a, b) => DateTime.parse(a.measuredAt).compareTo(DateTime.parse(b.measuredAt)));
      weightChange = sortedRecords.last.weight - sortedRecords.first.weight;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '当前体重',
              latestRecord?.weight.toString() ?? '--',
              'kg',
              AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '记录总数',
              records.length.toString(),
              '次',
              AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '30天变化',
              weightChange != null ? '${weightChange > 0 ? '+' : ''}${weightChange.toStringAsFixed(1)}' : '--',
              'kg',
              weightChange != null 
                  ? (weightChange > 0 ? AppColors.error : AppColors.success)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsListView(List<WeightRecord> records) {
    // 按时间倒序排序
    final sortedRecords = List<WeightRecord>.from(records)
      ..sort((a, b) => DateTime.parse(b.measuredAt).compareTo(DateTime.parse(a.measuredAt)));

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '记录历史',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedRecords.map((record) => _buildRecordCard(record)).toList(),
        ],
      ),
    );
  }

  Widget _buildRecordCard(WeightRecord record) {
    final date = DateTime.parse(record.measuredAt);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              LucideIcons.scale,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.weight}kg',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (record.bmi != null) ...[
            Text(
              'BMI: ${record.bmi!.toStringAsFixed(1)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddRecordForm() {
    return const _AddRecordForm();
  }
}

class _AddRecordForm extends ConsumerStatefulWidget {
  const _AddRecordForm();

  @override
  ConsumerState<_AddRecordForm> createState() => _AddRecordFormState();
}

class _AddRecordFormState extends ConsumerState<_AddRecordForm> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _muscleMassController = TextEditingController();
  final _notesController = TextEditingController();
  
  String? _selectedMeasureDate;
  String? _selectedDeviceType;
  bool _isLoading = false;

  final List<String> _deviceTypes = [
    '体重秤',
    '智能体重秤',
    '体脂秤',
    '其他',
  ];

  @override
  void initState() {
    super.initState();
    // 默认设置为今天
    _selectedMeasureDate = DateTime.now().toIso8601String();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 体重
            _buildSectionTitle('体重'),
            const SizedBox(height: 12),
            AppInput(
              controller: _weightController,
              label: '体重 (kg)',
              prefixIcon: LucideIcons.scale,
              type: AppInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入体重';
                }
                final weight = double.tryParse(value!);
                if (weight == null || weight <= 0 || weight > 1000) {
                  return '请输入有效的体重';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // 测量时间
            _buildSectionTitle('测量时间'),
            const SizedBox(height: 12),
            _buildMeasureDateSelector(),
            const SizedBox(height: 24),
            
            // 可选信息
            _buildSectionTitle('可选信息'),
            const SizedBox(height: 12),
            AppInput(
              controller: _bodyFatController,
              label: '体脂率 (%)',
              prefixIcon: LucideIcons.activity,
              type: AppInputType.number,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  final bodyFat = double.tryParse(value!);
                  if (bodyFat == null || bodyFat < 0 || bodyFat > 100) {
                    return '请输入有效的体脂率';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppInput(
              controller: _muscleMassController,
              label: '肌肉量 (kg)',
              prefixIcon: LucideIcons.dumbbell,
              type: AppInputType.number,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  final muscleMass = double.tryParse(value!);
                  if (muscleMass == null || muscleMass <= 0) {
                    return '请输入有效的肌肉量';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildDeviceTypeSelector(),
            const SizedBox(height: 16),
            AppInput(
              controller: _notesController,
              label: '备注',
              prefixIcon: LucideIcons.fileText,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            
            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRecord,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('添加记录'),
              ),
            ),
          ],
        ),
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

  Widget _buildMeasureDateSelector() {
    return GestureDetector(
      onTap: _selectMeasureDate,
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
                _selectedMeasureDate?.split('T')[0] ?? '选择测量日期',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: _selectedMeasureDate != null 
                      ? AppColors.textPrimary 
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设备类型', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedDeviceType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          hint: const Text('选择设备类型'),
          items: _deviceTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedDeviceType = value;
            });
          },
        ),
      ],
    );
  }

  Future<void> _selectMeasureDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedMeasureDate != null 
          ? DateTime.parse(_selectedMeasureDate!)
          : DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    
    if (selectedDate != null) {
      setState(() {
        _selectedMeasureDate = selectedDate.toIso8601String();
      });
    }
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = WeightRecordCreateRequest(
        weight: double.parse(_weightController.text),
        bodyFatPercentage: _bodyFatController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_bodyFatController.text),
        muscleMass: _muscleMassController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_muscleMassController.text),
        measuredAt: _selectedMeasureDate,
        deviceType: _selectedDeviceType,
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      final success = await ref.read(weightRecordsProvider.notifier).addWeightRecord(request);
      
      if (success) {
        if (mounted) {
          // 返回到记录列表
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('体重记录添加成功')),
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