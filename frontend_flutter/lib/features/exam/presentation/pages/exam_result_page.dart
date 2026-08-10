import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/social_provider.dart';
import '../../../health/presentation/pages/health_goals_page.dart';
import '../providers/exam_provider.dart';
import '../../domain/exam_models.dart';

/// 体检识别结果页
///
/// 上传记录完成后跳转至此，展示：
/// 1. AI 从报告照片中提取的指标数据（可编辑修正）
/// 2. 与上次体检的对比趋势
/// 3. AI 基于异常指标生成的饮食 / 运动建议
class ExamResultPage extends ConsumerStatefulWidget {
  final int reportId;
  final int? userId;
  final String? ownerName; // 为谁拍的（自己/家人）
  final Map<String, dynamic>? comparedToLast;

  const ExamResultPage({
    super.key,
    required this.reportId,
    this.userId,
    this.ownerName,
    this.comparedToLast,
  });

  @override
  ConsumerState<ExamResultPage> createState() => _ExamResultPageState();
}

class _ExamResultPageState extends ConsumerState<ExamResultPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(examMetricsProvider.notifier).loadMetrics(widget.reportId);
      ref.read(examAdviceProvider.notifier).loadAdvice(widget.reportId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final metricsState = ref.watch(examMetricsProvider);
    final adviceState = ref.watch(examAdviceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: Text(
            widget.ownerName == null ? '识别结果' : '${widget.ownerName}的识别结果'),
        actions: [
          if (metricsState.metrics.isNotEmpty)
            TextButton(
              onPressed: () => _showEditAllTip(),
              child: const Text('编辑', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _buildBody(metricsState, adviceState),
    );
  }

  Widget _buildBody(
      ExamMetricsState metricsState, ExamAdviceState adviceState) {
    // 加载中
    if (metricsState.isLoading && metricsState.metrics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 未识别到任何指标
    if (!metricsState.isLoading && metricsState.metrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('未识别到指标数据', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('请确认照片清晰完整后重试',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }

    // 统计异常项
    final abnormalMetrics =
        metricsState.metrics.where((m) => m.isAbnormal).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 识别完成横幅
        _buildSuccessBanner(
            metricsState.metrics.length, abnormalMetrics.length),
        const SizedBox(height: 20),

        // 历史对比趋势
        if (widget.comparedToLast != null &&
            widget.comparedToLast!['trends'] != null) ...[
          _buildTrendSection(),
          const SizedBox(height: 24),
        ],

        // 提取的数据
        Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'AI 提取的指标',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '共 ${metricsState.metrics.length} 项',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...metricsState.metrics.map((m) => _buildMetricCard(m)),
        const SizedBox(height: 24),

        // AI 健康建议
        Row(
          children: [
            const Icon(Icons.tips_and_updates, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'AI 健康建议',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAdviceCard(adviceState),

        // 建议设置减重目标时展示入口
        if (adviceState.advice?.suggestWeightLossGoal == true) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _goSetWeightGoal,
              icon: const Icon(Icons.flag, size: 20),
              label: const Text('设置减重目标',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // 完成按钮
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('完成',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),

        // 归属修改小字
        GestureDetector(
          onTap: _showReassignPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '归属有误？点击修改为谁拍的',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// 跳转健康目标设置页
  void _goSetWeightGoal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HealthGoalsPage()),
    );
  }

  /// 归属修改：自己 + 家人选择，选中后 reassign
  Future<void> _showReassignPicker() async {
    final notifier = ref.read(friendListProvider.notifier);
    final state = ref.read(friendListProvider);
    if (state.family.isEmpty && !state.isLoading) {
      await notifier.loadFriendList();
    }
    if (!mounted) return;
    final family = ref.read(friendListProvider).family;
    final currentUserId = ref.read(currentUserProvider)?.id ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '这份报告是谁拍的？',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: const Text('自己'),
              onTap: () {
                Navigator.pop(ctx);
                _doReassign(currentUserId);
              },
            ),
            for (final f in family)
              ListTile(
                leading:
                    const Icon(Icons.family_restroom, color: AppColors.primary),
                title: Text(f.note ?? f.realName ?? f.username),
                onTap: () {
                  Navigator.pop(ctx);
                  _doReassign(f.userId);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _doReassign(int targetUserId) async {
    final res = await ref
        .read(examApiServiceProvider)
        .reassignExamReport(widget.reportId, targetUserId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success ? '归属已修改' : '修改失败：${res.message}'),
          backgroundColor: res.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  /// 识别完成横幅
  Widget _buildSuccessBanner(int totalCount, int abnormalCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF43A047).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            child:
                const Icon(Icons.check_circle, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 识别完成',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '成功提取 $totalCount 项指标，其中 ${abnormalCount > 0 ? '$abnormalCount 项异常' : '全部正常'}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 历史对比趋势
  Widget _buildTrendSection() {
    final trends = widget.comparedToLast!['trends'] as List<dynamic>? ?? [];
    if (trends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              '与上次体检对比',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...trends.map((t) {
          final metric = t['metric'] as String? ?? '';
          final double lastVal = (t['last_value'] is num)
              ? (t['last_value'] as num).toDouble()
              : double.tryParse(t['last_value']?.toString() ?? '') ?? 0;
          final double currentVal = (t['current_value'] is num)
              ? (t['current_value'] as num).toDouble()
              : double.tryParse(t['current_value']?.toString() ?? '') ?? 0;
          final double change = (t['change'] is num)
              ? (t['change'] as num).toDouble()
              : double.tryParse(t['change']?.toString() ?? '') ?? 0;
          final direction = t['direction'] as String? ?? '↓';
          final isUp = direction == '↑';
          final changeColor = isUp ? Colors.red : Colors.green;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metric,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${lastVal.toStringAsFixed(2)} → ${currentVal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: changeColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            color: changeColor,
                            size: 16,
                          ),
                          Text(
                            '${change.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: changeColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// 指标卡片（可点击编辑）
  Widget _buildMetricCard(ExamMetric metric) {
    final isAbnormal = metric.isAbnormal;
    final statusColor = isAbnormal ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAbnormal
              ? Colors.red.withValues(alpha: 0.3)
              : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              isAbnormal ? Icons.warning_amber : Icons.check,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.metricName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric.metricValue?.toStringAsFixed(2) ?? '--',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isAbnormal ? '异常' : '正常',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (metric.unit != null && metric.unit!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  metric.unit!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onPressed: () => _showEditMetricDialog(metric),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  /// 编辑指标对话框
  void _showEditMetricDialog(ExamMetric metric) {
    final valueController = TextEditingController(
      text: metric.metricValue?.toString() ?? '',
    );
    final unitController = TextEditingController(text: metric.unit ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('修正 ${metric.metricName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: '数值',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: '单位',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('标记为异常'),
              value: metric.isAbnormal,
              onChanged: (v) {
                setState(() {
                  // 这里只是 UI 预览，实际保存时一起提交
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _saveMetricEdit(
                metric.id,
                valueController.text,
                unitController.text,
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 保存指标修改
  Future<void> _saveMetricEdit(
      int metricId, String valueStr, String unit) async {
    final double? value = double.tryParse(valueStr);
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数值格式不正确')),
      );
      return;
    }

    final success = await ref.read(examMetricsProvider.notifier).updateMetric(
          metricId,
          metricValue: value,
          unit: unit.isEmpty ? null : unit,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('指标已更新')),
        );
        // 重新加载指标
        ref.read(examMetricsProvider.notifier).loadMetrics(widget.reportId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新失败')),
        );
      }
    }
  }

  /// AI 建议卡片（饮食 / 运动 / 复查）
  Widget _buildAdviceCard(ExamAdviceState adviceState) {
    // 建议加载中
    if (adviceState.isLoading && adviceState.advice == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('AI 正在分析您的指标，请稍候…', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final advice = adviceState.advice;
    if (advice == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('暂无可用的健康建议', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总体建议
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.menu_book, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.advice,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
          // 饮食建议
          if (advice.dietRecommendations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '饮食建议',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...advice.dietRecommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 15, color: Colors.orange)),
                      Expanded(
                          child:
                              Text(rec, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
          // 运动建议
          if (advice.exerciseRecommendations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              '运动建议',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...advice.exerciseRecommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ',
                          style: TextStyle(fontSize: 15, color: Colors.orange)),
                      Expanded(
                          child:
                              Text(rec, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
          // 复查提醒
          if (advice.followupReminder != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      advice.followupReminder!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditAllTip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('点击指标右侧的编辑按钮可修正单项指标')),
    );
  }
}
