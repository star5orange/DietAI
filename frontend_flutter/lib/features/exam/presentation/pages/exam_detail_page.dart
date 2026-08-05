import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(examMetricsProvider.notifier).loadMetrics(widget.reportId);
      ref.read(examAdviceProvider.notifier).loadAdvice(widget.reportId);
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 建议卡片
          if (adviceState.advice != null) _buildAdviceCard(adviceState.advice!),
          if (adviceState.advice != null) const SizedBox(height: 16),

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
