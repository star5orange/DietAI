import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../shared/domain/models/water_intake_model.dart';
import '../../../shared/presentation/widgets/animated_progress_circle.dart';
import '../../../services/water_service.dart';

class WaterIntakeWidget extends StatefulWidget {
  final VoidCallback? onTapDetails;
  final DateTime selectedDate;

  const WaterIntakeWidget({
    super.key,
    this.onTapDetails,
    required this.selectedDate,
  });

  @override
  State<WaterIntakeWidget> createState() => _WaterIntakeWidgetState();
}

class _WaterIntakeWidgetState extends State<WaterIntakeWidget>
    with TickerProviderStateMixin {
  final WaterService _waterService = WaterService();
  DailyWaterSummary? _summary;
  List<WaterIntakeRecord> _todayRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(WaterIntakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = widget.selectedDate.toIso8601String().substring(0, 10);
      final summaryResult = await _waterService.getDailySummary(dateStr);
      final recordsResult = await _waterService.getWaterRecords(
        startDate: dateStr,
        endDate: dateStr,
      );
      final todayRecords = recordsResult.data ?? [];

      if (mounted) {
        setState(() {
          _summary = summaryResult.data;
          _todayRecords = todayRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _quickAdd({int amountMl = 250, String? drinkType, String? timeSlot}) async {
    final result = await _waterService.addWaterIntake(
        amountMl: amountMl,
        recordedAt: widget.selectedDate,
        drinkType: drinkType);

    if (result.success) {
      await _loadData();
      if (mounted) {
        final msg = drinkType != null && drinkType != '水'
            ? '已添加 ${amountMl}ml $drinkType'
            : '已添加 ${amountMl}ml 饮水';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: ${result.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showCustomAmountDialog() {
    final controller = TextEditingController(text: '250');
    String selectedTimeSlot = _getCurrentTimeSlot();
    String selectedDrinkType = '水';

    const timeSlots = [
      ('早餐时段', '6:00-9:00'),
      ('上午', '9:00-11:30'),
      ('午餐时段', '11:30-13:00'),
      ('下午', '13:00-17:30'),
      ('晚餐时段', '17:30-19:30'),
      ('晚间', '19:30-23:00'),
    ];

    const drinkTypes = ['水', '茶', '咖啡', '果汁', '牛奶', '其他'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('记录饮水', style: AppTextStyles.h4),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 饮水量
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '饮水量 (ml)',
                    hintText: '请输入饮水量',
                    suffixText: 'ml',
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [100, 200, 250, 500, 750].map((v) {
                    return ActionChip(
                      label: Text('${v}ml'),
                      onPressed: () => controller.text = v.toString(),
                      backgroundColor: AppColors.infoLight,
                      labelStyle: const TextStyle(color: AppColors.info),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 饮品类型
                Text('饮品类型', style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: drinkTypes.map((type) {
                    final isSelected = selectedDrinkType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (_) {
                        setDialogState(() => selectedDrinkType = type);
                      },
                      selectedColor: AppColors.info,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // 时间段
                Text('时间段', style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: timeSlots.map((slot) {
                    final isSelected = selectedTimeSlot == slot.$1;
                    return ChoiceChip(
                      label: Text('${slot.$1} ${slot.$2}'),
                      selected: isSelected,
                      onSelected: (_) {
                        setDialogState(() => selectedTimeSlot = slot.$1);
                      },
                      selectedColor: AppColors.info,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.textInverse : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final amount = int.tryParse(controller.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context);
                  _quickAdd(
                    amountMl: amount,
                    drinkType: selectedDrinkType,
                    timeSlot: selectedTimeSlot,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: AppColors.textInverse),
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentTimeSlot() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 9) return '早餐时段';
    if (hour >= 9 && hour < 11) return '上午';
    if (hour >= 11 && hour < 13) return '午餐时段';
    if (hour >= 13 && hour < 17) return '下午';
    if (hour >= 17 && hour < 19) return '晚餐时段';
    return '晚间';
  }

  Future<void> _undoLastRecord() async {
    if (_todayRecords.isEmpty) return;
    // _todayRecords 按存储顺序排列（最新在前），第一条才是最近添加的
    final lastRecord = _todayRecords.first;
    final amountMl = lastRecord.amountMl;
    final result = await _waterService.deleteWaterRecord(lastRecord.id);
    if (result.success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已撤回 ${amountMl}ml 饮水记录'),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('撤回失败: ${result.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showGoalSettingDialog() {
    final currentGoal = _summary?.goalMl ?? 2000;
    final controller =
        TextEditingController(text: (currentGoal ~/ 1000).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置每日饮水目标', style: AppTextStyles.h4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '目标 (升)',
                hintText: '例如：2',
                suffixText: '升',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [1, 1.5, 2, 2.5, 3].map((v) {
                return ActionChip(
                  label: Text('${v}L'),
                  onPressed: () => controller.text = v.toString(),
                  backgroundColor: AppColors.infoLight,
                  labelStyle: const TextStyle(color: AppColors.info),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final liters = double.tryParse(controller.text);
              if (liters != null && liters > 0) {
                Navigator.pop(context);
                await _waterService.setGoal((liters * 1000).round());
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: AppColors.textInverse),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showTodayRecordsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(LucideIcons.droplets,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Text('今日饮水记录',
                      style: AppTextStyles.h6
                          .copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    _summary?.formattedTotal ?? '0 ml',
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_todayRecords.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(LucideIcons.droplets,
                        size: 48, color: AppColors.textTertiary),
                    SizedBox(height: 12),
                    Text('暂无饮水记录',
                        style: TextStyle(color: AppColors.textTertiary)),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _todayRecords.length,
                  itemBuilder: (context, index) {
                    final record = _todayRecords[index];
                    return Dismissible(
                      key: Key(record.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) async {
                        await _waterService.deleteWaterRecord(record.id);
                        _loadData();
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: AppColors.error,
                        child: const Icon(LucideIcons.trash2,
                            color: AppColors.textInverse),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(LucideIcons.droplet,
                                  color: AppColors.info, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(record.formattedAmount,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w500))),
                            Text(record.formattedTime,
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final progress = summary?.progress ?? 0.0;
    final totalMl = summary?.totalMl ?? 0;
    final goalMl = summary?.goalMl ?? 2000;
    final isGoalReached = summary?.isGoalReached ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isGoalReached
            ? AppColors.successGradient
            : LinearGradient(
                colors: [AppColors.info, AppColors.infoLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isGoalReached ? AppColors.success : AppColors.info)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.droplets,
                  color: AppColors.textInverse, size: 22),
              const SizedBox(width: 10),
              Text('今日饮水',
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textInverse,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_todayRecords.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.undo2, size: 18),
                  color: AppColors.textInverse,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '撤回上一次记录',
                  onPressed: _undoLastRecord,
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _showGoalSettingDialog,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.whiteWithOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.target,
                          color: AppColors.textInverse, size: 14),
                      const SizedBox(width: 4),
                      Text('${_formatWater(goalMl)}L',
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textInverse,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _isLoading
              ? SizedBox(
                  width: 140,
                  height: 140,
                  child: Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textInverse))),
                )
              : GestureDetector(
                  onTap: _showTodayRecordsSheet,
                  child: AnimatedProgressCircle(
                    progress: progress,
                    size: 140,
                    strokeWidth: 10,
                    progressColor: AppColors.textInverse,
                    backgroundColor: AppColors.whiteWithOpacity(0.25),
                    showPulse: !isGoalReached,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            totalMl >= 1000
                                ? _formatWater(totalMl)
                                : '$totalMl',
                            style: AppTextStyles.numberLarge
                                .copyWith(color: AppColors.textInverse)),
                        Text(totalMl >= 1000 ? '升' : 'ml',
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.whiteWithOpacity(0.7))),
                        const SizedBox(height: 4),
                        Text(
                          isGoalReached
                              ? '✅ 已达标'
                              : '还差 ${_formatWaterWithUnit(summary?.remainingMl ?? 0)}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.whiteWithOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildQuickAddButton('250ml', 250)),
              const SizedBox(width: 8),
              Expanded(child: _buildQuickAddButton('500ml', 500)),
              const SizedBox(width: 8),
              Expanded(child: _buildCustomAddButton()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(String label, int amountMl) {
    return GestureDetector(
      onTap: () => _quickAdd(amountMl: amountMl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.whiteWithOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.whiteWithOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus,
                color: AppColors.textInverse, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textInverse, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAddButton() {
    return GestureDetector(
      onTap: _showCustomAmountDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.whiteWithOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.whiteWithOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.slidersHorizontal,
                color: AppColors.textInverse, size: 16),
            const SizedBox(width: 4),
            Text('自定义',
                style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textInverse, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 智能格式化水量：不足1L用ml，1L以上最多两位小数去尾部零
  String _formatWater(int ml) {
    if (ml < 1000) return '$ml';
    final liters = ml / 1000;
    return liters.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// 格式化水量带单位
  String _formatWaterWithUnit(int ml) {
    if (ml < 1000) return '${ml}ml';
    return '${_formatWater(ml)}L';
  }
}
