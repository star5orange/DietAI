import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/social_provider.dart';
import '../providers/exam_provider.dart';
import '../../domain/exam_models.dart';

/// 体检报告详情页面
class ExamDetailPage extends ConsumerStatefulWidget {
  final int reportId;
  final int? userId;

  const ExamDetailPage({super.key, required this.reportId, this.userId});

  @override
  ConsumerState<ExamDetailPage> createState() => _ExamDetailPageState();
}

class _ExamDetailPageState extends ConsumerState<ExamDetailPage> {
  final TtsService _ttsService = TtsService();
  bool _isSpeaking = false;
  ExamReportDetail? _detail;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(examMetricsProvider.notifier).loadMetrics(widget.reportId);
      ref.read(examAdviceProvider.notifier).loadAdvice(widget.reportId);
      ref.read(friendListProvider.notifier).loadFriendList();
      _loadDetail();
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  int get _effectiveUserId =>
      widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;

  Future<void> _loadDetail() async {
    final res = await ref
        .read(examApiServiceProvider)
        .getExamReportDetail(_effectiveUserId, widget.reportId);
    if (mounted && res.success && res.data != null) {
      setState(() => _detail = res.data);
    }
  }

  Future<void> _speakAdvice(ExamAdvice advice) async {
    // 构建播报文本
    final buffer = StringBuffer();
    buffer.write(advice.advice);
    if (advice.dietRecommendations.isNotEmpty) {
      buffer.write('饮食建议：');
      for (var rec in advice.dietRecommendations) {
        buffer.write('$rec。');
      }
    }
    if (advice.exerciseRecommendations.isNotEmpty) {
      buffer.write('运动建议：');
      for (var rec in advice.exerciseRecommendations) {
        buffer.write('$rec。');
      }
    }
    if (advice.followupReminder != null) {
      buffer.write('复查提醒：${advice.followupReminder}');
    }

    setState(() => _isSpeaking = true);
    try {
      await _ttsService.speak(buffer.toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音播报失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricsState = ref.watch(examMetricsProvider);
    final adviceState = ref.watch(examAdviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('体检报告详情'),
      ),
      body: _buildBody(metricsState, adviceState),
    );
  }

  Widget _buildBody(
      ExamMetricsState metricsState, ExamAdviceState adviceState) {
    // 顶部固定报告信息卡，下方为指标内容区
    return Column(
      children: [
        if (_detail != null) _buildReportInfoCard(_detail!),
        Expanded(child: _buildMetricsContent(metricsState, adviceState)),
      ],
    );
  }

  Widget _buildMetricsContent(
      ExamMetricsState metricsState, ExamAdviceState adviceState) {
    if (metricsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (metricsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(metricsState.error!,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(examMetricsProvider.notifier)
                    .loadMetrics(widget.reportId);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (metricsState.metrics.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无指标数据', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // 按类别分组指标
    final groupedMetrics = <String, List<ExamMetric>>{};
    for (final metric in metricsState.metrics) {
      groupedMetrics.putIfAbsent(metric.category, () => []).add(metric);
    }
    // 异常指标（历年趋势区块）
    final abnormalMetrics =
        metricsState.metrics.where((m) => m.isAbnormal).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 建议卡片
          if (adviceState.advice != null) _buildAdviceCard(adviceState.advice!),
          if (adviceState.advice != null) const SizedBox(height: 16),

          // 历年趋势：异常指标
          _buildTrendSection(abnormalMetrics),
          const SizedBox(height: 8),

          // 操作按钮排
          _buildActionButtons(),
          const SizedBox(height: 16),

          // 指标分组
          ...groupedMetrics.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _getCategoryName(entry.key),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...entry.value.map((metric) => _buildMetricCard(metric)),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 顶部"报告信息"卡：体检日期 / 医院 / 原始照片 / 复查提醒
  Widget _buildReportInfoCard(ExamReportDetail detail) {
    final photoUrl = detail.photoUrl;
    final followupDate = detail.followupDate;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                '报告信息',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
              Icons.calendar_today, '体检日期', _formatDate(detail.examDate)),
          if (detail.hospitalName != null && detail.hospitalName!.isNotEmpty)
            _buildInfoRow(Icons.local_hospital, '医院', detail.hospitalName!),
          if (detail.ownerName != null && detail.ownerName!.isNotEmpty)
            _buildInfoRow(Icons.person, '归属', detail.ownerName!),
          if (photoUrl != null && photoUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showPhotoPreview(photoUrl),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.photo_camera,
                        color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '查看原始报告照片',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (followupDate != null && followupDate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_note, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '复查提醒：$followupDate',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.orange),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  /// 历年趋势区块：列出异常指标，点击进入趋势页
  Widget _buildTrendSection(List<ExamMetric> abnormalMetrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '历年趋势',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '点击异常指标查看历年变化',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        if (abnormalMetrics.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('本次体检无异常指标',
                    style: TextStyle(fontSize: 13, color: Colors.green)),
              ],
            ),
          )
        else
          ...abnormalMetrics.map((m) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.show_chart, color: Colors.orange),
                  title:
                      Text(m.metricName, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${m.metricValue?.toStringAsFixed(2) ?? '--'} ${m.unit ?? ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => context.push(
                    '/exam/trend/$_effectiveUserId/${Uri.encodeComponent(m.metricName)}',
                  ),
                ),
              )),
      ],
    );
  }

  /// 操作按钮排：设置复查提醒 / 应用饮食建议 / 归属修改
  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showFollowupOptions,
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('设置复查提醒'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openDietRecommendation,
                icon: const Icon(Icons.restaurant_menu, size: 18),
                label: const Text('应用饮食建议'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showReassignPicker,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '归属有误？修改为谁拍的',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 复查提醒设置：选日期 / 取消提醒
  void _showFollowupOptions() {
    final hasFollowup = _detail?.followupDate != null;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.event_available, color: AppColors.primary),
              title: const Text('设置复查提醒日期'),
              subtitle: const Text('选择复查日期，到点提醒'),
              onTap: () async {
                Navigator.pop(ctx);
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365 * 3)),
                );
                if (picked != null && mounted) {
                  final dateStr =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  await _saveFollowup(dateStr);
                }
              },
            ),
            if (hasFollowup)
              ListTile(
                leading: const Icon(Icons.event_busy, color: Colors.red),
                title: const Text('取消复查提醒'),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveFollowup(null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFollowup(String? date) async {
    final res = await ref
        .read(examApiServiceProvider)
        .setFollowupDate(widget.reportId, date);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.success
              ? (date == null ? '已取消复查提醒' : '复查提醒已设置')
              : '设置失败：${res.message}'),
          backgroundColor: res.success ? Colors.green : Colors.red,
        ),
      );
      if (res.success) _loadDetail();
    }
  }

  /// 应用饮食建议：跳转饮食推荐页
  void _openDietRecommendation() {
    final ownerName = _detail?.ownerName ?? '家人';
    context.push(
      '/family/diet-recommendation/$_effectiveUserId',
      extra: {'name': ownerName},
    );
  }

  /// 归属修改：自己 + 家人选择
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
      if (res.success) _loadDetail();
    }
  }

  /// 查看原始报告照片（大图预览）
  void _showPhotoPreview(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      SizedBox(height: 12),
                      Text('照片加载失败', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildAdviceCard(ExamAdvice advice) {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 健康建议',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.stop : Icons.volume_up,
                    color: _isSpeaking ? Colors.red : AppColors.primary,
                  ),
                  tooltip: _isSpeaking ? '停止播报' : '语音播报',
                  onPressed: _isSpeaking
                      ? () => _ttsService.stop()
                      : () => _speakAdvice(advice),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice.advice,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            if (advice.dietRecommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '饮食建议:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...advice.dietRecommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  )),
            ],
            if (advice.exerciseRecommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                '运动建议:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...advice.exerciseRecommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(rec)),
                      ],
                    ),
                  )),
            ],
            if (advice.followupReminder != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_note,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        advice.followupReminder!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(ExamMetric metric) {
    final isAbnormal = metric.isAbnormal;
    final statusColor = isAbnormal ? Colors.red : Colors.green;
    final statusText = isAbnormal ? '异常' : '正常';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showMetricDetail(metric),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.metricName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    metric.metricValue?.toStringAsFixed(2) ?? '--',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    metric.unit ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (metric.referenceMin != null &&
                      metric.referenceMax != null)
                    Text(
                      '参考: ${metric.referenceMin!.toStringAsFixed(2)}-${metric.referenceMax!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMetricDetail(ExamMetric metric) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.metricName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditMetricDialog(metric);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('当前值: ', style: TextStyle(fontSize: 16)),
                  Text(
                    '${metric.metricValue?.toStringAsFixed(2) ?? '--'} ${metric.unit ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: metric.isAbnormal ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (metric.referenceMin != null && metric.referenceMax != null)
                Row(
                  children: [
                    const Text('参考范围: ', style: TextStyle(fontSize: 16)),
                    Text(
                      '${metric.referenceMin!.toStringAsFixed(2)}-${metric.referenceMax!.toStringAsFixed(2)} ${metric.unit ?? ''}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  final userId =
                      widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
                  context.push(
                    '/exam/trend/$userId/${Uri.encodeComponent(metric.metricName)}',
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('查看趋势'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditMetricDialog(ExamMetric metric) {
    final valueController = TextEditingController(
      text: metric.metricValue?.toString() ?? '',
    );
    final isAbnormalController = TextEditingController(
      text: metric.isAbnormal ? '异常' : '正常',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修正指标: ${metric.metricName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: '指标值 (${metric.unit ?? ''})',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: metric.isAbnormal ? 'abnormal' : 'normal',
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('正常')),
                      DropdownMenuItem(value: 'abnormal', child: Text('异常')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
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
                          onPressed: () async {
                            final newValue =
                                double.tryParse(valueController.text);
                            final status =
                                (metric.isAbnormal ? 'abnormal' : 'normal');

                            if (newValue == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请输入有效的数值')),
                              );
                              return;
                            }

                            try {
                              final api = ref.read(examApiServiceProvider);
                              final response = await api.updateExamMetric(
                                metric.id,
                                metricValue: newValue,
                                status: status,
                                isAbnormal: status == 'abnormal',
                              );

                              if (response.success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('指标修正成功'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                // 重新加载指标
                                ref
                                    .read(examMetricsProvider.notifier)
                                    .loadMetrics(widget.reportId);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('修正失败: ${response.message}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('修正失败: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getCategoryName(String category) {
    final categoryNames = {
      'blood_sugar': '血糖',
      'blood_lipid': '血脂',
      'blood_pressure': '血压',
      'liver_function': '肝功能',
      'kidney_function': '肾功能',
      'blood_routine': '血常规',
      'urine_routine': '尿常规',
      'other': '其他',
    };
    return categoryNames[category] ?? category;
  }
}
