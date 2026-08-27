import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/exam_provider.dart';
import '../../domain/exam_models.dart';

/// 体检报告列表页面（顶部日历 + 记录列表）
///
/// 日历中仅"有体检报告的日期"高亮可点击，其余日期暗灰不可点击；
/// 点击高亮日期可筛选下方记录，点击记录进入详情。
class ExamReportsPage extends ConsumerStatefulWidget {
  final int? userId;

  const ExamReportsPage({super.key, this.userId});

  @override
  ConsumerState<ExamReportsPage> createState() => _ExamReportsPageState();
}

class _ExamReportsPageState extends ConsumerState<ExamReportsPage> {
  late DateTime _displayMonth; // 日历当前显示的月份
  DateTime? _selectedDate; // 选中的日期（null = 全部）

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayMonth = DateTime(now.year, now.month);
    Future.microtask(() {
      final userId = widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
      ref.read(examReportListProvider.notifier).loadReports(userId);
    });
  }

  /// 有报告的日期集合（仅年月日）
  Set<DateTime> _highlightDates(List<ExamReport> reports) {
    return reports
        .map((r) => DateTime(r.examDate.year, r.examDate.month, r.examDate.day))
        .toSet();
  }

  /// 按选中日期过滤（null = 全部）
  List<ExamReport> _filterReports(List<ExamReport> reports) {
    final d = _selectedDate;
    if (d == null) return reports;
    return reports
        .where((r) =>
            r.examDate.year == d.year &&
            r.examDate.month == d.month &&
            r.examDate.day == d.day)
        .toList();
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
                final userId =
                    widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
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

    final highlights = _highlightDates(state.reports);
    final filtered = _filterReports(state.reports);

    return RefreshIndicator(
      onRefresh: () async {
        final userId = widget.userId ?? ref.read(currentUserProvider)?.id ?? 0;
        await ref.read(examReportListProvider.notifier).loadReports(userId);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 日历
          _ExamCalendar(
            displayMonth: _displayMonth,
            highlightDates: highlights,
            selectedDate: _selectedDate,
            onSelect: (date) => setState(() => _selectedDate = date),
            onPrevMonth: () => setState(() {
              _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month - 1);
              _selectedDate = null;
            }),
            onNextMonth: () => setState(() {
              _displayMonth =
                  DateTime(_displayMonth.year, _displayMonth.month + 1);
              _selectedDate = null;
            }),
          ),
          const SizedBox(height: 12),

          // 筛选栏
          _buildFilterBar(state.reports.length, filtered.length),
          const SizedBox(height: 8),

          // 记录列表
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: const Center(
                child: Text('当天没有体检记录', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...filtered.map((report) => _buildReportCard(report)),
        ],
      ),
    );
  }

  /// 筛选状态栏
  Widget _buildFilterBar(int total, int shown) {
    return Row(
      children: [
        Text(
          _selectedDate == null
              ? '全部记录 ($total)'
              : '${_formatDate(_selectedDate!)} 的记录 ($shown)',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (_selectedDate != null)
          TextButton(
            onPressed: () => setState(() => _selectedDate = null),
            child: const Text('查看全部'),
          ),
      ],
    );
  }

  Widget _buildReportCard(ExamReport report) {
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
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      report.abnormalCount > 0
                          ? Icons.warning
                          : Icons.check_circle,
                      color:
                          report.abnormalCount > 0 ? Colors.red : Colors.green,
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (report.abnormalCount > 0 ? Colors.red : Colors.green)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      report.abnormalCount > 0
                          ? Icons.warning
                          : Icons.check_circle,
                      size: 16,
                      color:
                          report.abnormalCount > 0 ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      report.abnormalCount > 0
                          ? '${report.abnormalCount} 项指标异常'
                          : '所有指标正常',
                      style: TextStyle(
                        color: report.abnormalCount > 0
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 复查提醒标签
              if (report.followupDate != null &&
                  report.followupDate!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '复查提醒：${report.followupDate}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

/// 月历组件：仅"有体检报告的日期"高亮可点击，其余日期暗灰
class _ExamCalendar extends StatelessWidget {
  final DateTime displayMonth;
  final Set<DateTime> highlightDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelect;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  const _ExamCalendar({
    required this.displayMonth,
    required this.highlightDates,
    this.selectedDate,
    required this.onSelect,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  bool _isHighlight(DateTime d) => highlightDates.contains(d);

  bool _isSelected(DateTime d) =>
      selectedDate != null &&
      d.year == selectedDate!.year &&
      d.month == selectedDate!.month &&
      d.day == selectedDate!.day;

  @override
  Widget build(BuildContext context) {
    // 本月天数
    final daysInMonth =
        DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    // 周一开头的星期偏移（周一=0）
    final leading =
        DateTime(displayMonth.year, displayMonth.month, 1).weekday % 7;
    // 单元格总数（7 的倍数，至少 6 行）
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 月份切换栏
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevMonth,
              ),
              Text(
                '${displayMonth.year}年${displayMonth.month}月',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 星期表头
          Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((w) => Expanded(
                      child: Center(
                        child: Text(
                          w,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),

          // 日期格子
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: List.generate(totalCells, (index) {
              final day = index - leading + 1;
              // 不在本月范围 → 空白占位
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(displayMonth.year, displayMonth.month, day);
              final highlight = _isHighlight(date);
              final selected = _isSelected(date);

              if (!highlight) {
                // 无记录日期：暗灰不可点击
                return Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                );
              }

              // 有记录日期：高亮可点击
              return GestureDetector(
                onTap: () => onSelect(date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(width: 6),
              const Text('有体检记录',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
