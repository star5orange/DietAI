import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/exam_provider.dart';

/// 体检报告列表页面
class ExamReportsPage extends ConsumerStatefulWidget {
  final int? userId;

  const ExamReportsPage({super.key, this.userId});

  @override
  ConsumerState<ExamReportsPage> createState() => _ExamReportsPageState();
}

class _ExamReportsPageState extends ConsumerState<ExamReportsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final userId = widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
      ref.read(examReportListProvider.notifier).loadReports(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examReportListProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? 0;
    final isSelf = widget.userId == null || widget.userId == currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelf ? '我的体检报告' : '家人的体检报告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => context.push('/exam/upload'),
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ExamReportListState state) {
    if (state.isLoading && state.reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(state.error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final userId = widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
                ref.read(examReportListProvider.notifier).loadReports(userId);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('还没有体检报告', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.push('/exam/upload'),
              icon: const Icon(Icons.upload_file),
              label: const Text('上传体检报告'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId = widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
        await ref.read(examReportListProvider.notifier).loadReports(userId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.reports.length,
        itemBuilder: (context, index) {
          final report = state.reports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildReportCard(report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(
          '/exam/detail/${report.id}',
          extra: {'userId': widget.userId},
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: report.abnormalCount > 0
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      report.abnormalCount > 0 ? Icons.warning : Icons.check_circle,
                      color: report.abnormalCount > 0 ? Colors.red : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(report.examDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.hospitalName ?? '体检机构未知',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              if (report.abnormalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        '${report.abnormalCount} 项指标异常',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        '所有指标正常',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
