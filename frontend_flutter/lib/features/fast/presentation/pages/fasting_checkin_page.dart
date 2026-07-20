import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';

/// 轻断食每日打卡页面
class FastingCheckinPage extends ConsumerStatefulWidget {
  final int planId;
  final String? planType;

  const FastingCheckinPage({super.key, this.planId = 0, this.planType});

  @override
  ConsumerState<FastingCheckinPage> createState() => _FastingCheckinPageState();
}

class _FastingCheckinPageState extends ConsumerState<FastingCheckinPage> {
  String _feeling = 'good';
  String? _notes;
  bool _isLoading = false;
  bool _dataLoaded = false; // 数据是否加载完成
  int _daysElapsed = 0;
  int _weeklyCheckins = 0;
  int _weeklyTarget = 0;
  bool _isFastingDay = false; // 今天是否是断食日
  String? _todayWeekday; // 今天是周几
  FastingPlan? _plan; // 当前计划

  @override
  void initState() {
    super.initState();
    _loadPlanData();
  }

  Future<void> _loadPlanData() async {
    try {
      final service = ref.read(fastingServiceProvider);
      final plans = await service.getPlans();
      final activePlan = plans.cast<FastingPlan?>().firstWhere(
            (p) => p!.planId == widget.planId,
            orElse: () => null,
          );

      // 获取进度数据
      FastingProgress? progress;
      if (widget.planId > 0) {
        try {
          progress = await service.getProgress(widget.planId);
        } catch (_) {}
      }

      // 判断今天是否是断食日
      bool isFastingDay = true; // 默认为true，16:8每天都是
      if (activePlan != null && activePlan.planType != '16_8') {
        isFastingDay = activePlan.isFastingDayToday();
      }

      // 今天是周几
      final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final today = DateTime.now().weekday;

      if (mounted) {
        setState(() {
          _plan = activePlan;
          _daysElapsed = (activePlan?.daysElapsed ?? 0) + 1;
          _weeklyCheckins = progress?.weeklyCheckins ?? 0;
          _weeklyTarget = progress?.weeklyTarget ?? 0;
          _isFastingDay = isFastingDay;
          _todayWeekday = weekdayNames[today];
          _dataLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _dataLoaded = true;
          _isFastingDay = true; // 加载失败时默认允许打卡
        });
      }
    }
  }

  String get _planTypeLabel {
    switch (widget.planType) {
      case '16_8':
        return '16:8';
      case '5_2':
        return '5:2';
      case 'basic_fasting':
        return '基础断食';
      default:
        return '轻断食';
    }
  }

  bool get _is16_8 => widget.planType == '16_8' || widget.planType == null;

  final List<Map<String, dynamic>> _feelingOptions = [
    {
      'id': 'good',
      'label': '很好',
      'icon': LucideIcons.smile,
      'color': AppColors.success
    },
    {
      'id': 'normal',
      'label': '一般',
      'icon': LucideIcons.meh,
      'color': AppColors.warning
    },
    {
      'id': 'tired',
      'label': '疲惫',
      'icon': LucideIcons.frown,
      'color': AppColors.info
    },
    {
      'id': 'uncomfortable',
      'label': '不适',
      'icon': LucideIcons.alertCircle,
      'color': AppColors.error
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('今日打卡',
            style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: _dataLoaded
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _isFastingDay
                  ? _buildCheckinForm()
                  : _buildNonFastingDayHint(),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  /// 非断食日提示
  Widget _buildNonFastingDayHint() {
    return Column(
      children: [
        const SizedBox(height: 60),
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            shape: BoxShape.circle,
            boxShadow: AppColors.lightShadow,
          ),
          child: const Center(
            child: Icon(LucideIcons.calendarOff,
                size: 56, color: AppColors.textTertiary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '今天是非断食日',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '今天是${_todayWeekday ?? ""}，不需要打卡',
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 32),
        // 本周进度
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.lightShadow,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('本周进度', style: AppTextStyles.bodyMedium),
                  Text('${_weeklyCheckins}/${_weeklyTarget} 天',
                      style: AppTextStyles.h6.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _weeklyTarget > 0 ? _weeklyCheckins / _weeklyTarget : 0,
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Text(
                '完成度 ${(_weeklyTarget > 0 ? (_weeklyCheckins / _weeklyTarget * 100).toInt() : 0)}%',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 打卡表单
  Widget _buildCheckinForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 进度卡片
        _buildProgressCard(),
        const SizedBox(height: 24),

        // 断食时长（仅16:8显示）
        if (_is16_8) ...[
          _buildFastingTimer(),
          const SizedBox(height: 24),
        ],

        // 今日感受
        Text('今日感受', style: AppTextStyles.h6),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _feelingOptions
              .map((option) => _buildFeelingOption(option))
              .toList(),
        ),
        const SizedBox(height: 24),

        // 备注
        Text('备注（可选）', style: AppTextStyles.h6),
        const SizedBox(height: 12),
        TextField(
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '记录今天的感受...',
            filled: true,
            fillColor: AppColors.backgroundCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => _notes = v,
        ),
        const SizedBox(height: 32),

        // 提交按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitCheckin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('完成打卡'),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    // 根据计划类型显示不同的进度文案
    String progressLabel;
    String progressValue;

    if (_is16_8) {
      // 16:8 显示连续打卡
      progressLabel = '连续打卡';
      progressValue = '第 $_daysElapsed 天';
    } else {
      // 5:2 / 基础断食显示本周打卡
      progressLabel = '本周打卡';
      // 需要从后端获取实际数据，这里暂时用占位
      progressValue = '$_weeklyCheckins/$_weeklyTarget 天';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(LucideIcons.flame, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(progressLabel,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: Colors.white.withValues(alpha: 0.8))),
                Text(progressValue,
                    style: AppTextStyles.h4.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_planTypeLabel,
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFastingTimer() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: const Column(
        children: [
          Text('断食计时',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 12),
          Text('根据您的进食窗口计算断食时长',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFeelingOption(Map<String, dynamic> option) {
    final isSelected = _feeling == option['id'];
    return GestureDetector(
      onTap: () => setState(() => _feeling = option['id']),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (option['color'] as Color).withValues(alpha: 0.15)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? option['color'] as Color : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(option['icon'] as IconData,
                color: option['color'] as Color, size: 28),
            const SizedBox(height: 8),
            Text(option['label'],
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? option['color'] : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCheckin() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(fastingServiceProvider);
      await service.createCheckin(
        planId: widget.planId,
        checkinDate: DateTime.now().toIso8601String().split('T')[0],
        feeling: _feeling,
        completed: true,
        notes: _notes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打卡成功！')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
