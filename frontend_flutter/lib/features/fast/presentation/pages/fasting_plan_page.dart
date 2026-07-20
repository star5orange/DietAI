import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';
import 'fasting_checkin_page.dart';
import 'fasting_progress_page.dart';
import 'fasting_refeed_page.dart';

/// 轻断食计划主页
class FastingPlanPage extends ConsumerStatefulWidget {
  const FastingPlanPage({super.key});

  @override
  ConsumerState<FastingPlanPage> createState() => _FastingPlanPageState();
}

class _FastingPlanPageState extends ConsumerState<FastingPlanPage> {
  FastingPlan? _activePlan;
  FastingProgress? _progress;
  int _streakDays = 0;
  int _checkinCount = 0;
  int _weekCount = 0;
  int _weeklyCheckins = 0;
  int _weeklyTarget = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final service = ref.read(fastingServiceProvider);
      // 并行加载活动计划和断食计划类型
      final results = await Future.wait([
        service.getPlans(status: 'active'),
        _fetchPlanTypes(),
      ]);
      final plans = results[0] as List<FastingPlan>;
      if (plans.isNotEmpty) {
        final plan = plans.first;
        // Parallel load progress and checkins
        FastingProgress? progress;
        int checkinCount = 0;
        try {
          final results = await Future.wait([
            service.getProgress(plan.planId),
            service.getCheckins(plan.planId),
          ]);
          progress = results[0] as FastingProgress;
          checkinCount = (results[1] as List<FastingCheckin>).length;
        } catch (_) {}

        if (mounted) {
          setState(() {
            _activePlan = plan;
            _progress = progress;
            _streakDays = progress?.streakDays ?? 0;
            _checkinCount = checkinCount;
            _weekCount = progress != null
                ? ((progress.daysElapsed / 7).ceil()).clamp(1, 52)
                : 1;
            _weeklyCheckins = progress?.weeklyCheckins ?? 0;
            _weeklyTarget = progress?.weeklyTarget ?? 0;
          });
        }
      }
    } catch (_) {
      // 后端不可用，使用空状态
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 获取计划类型中文名
  String _planTypeName(FastingPlan plan) {
    switch (plan.planType) {
      case '16_8':
        return '16:8 轻断食';
      case '5_2':
        return '5:2 轻断食';
      case 'basic_fasting':
        return '基础断食';
      default:
        return plan.planType;
    }
  }

  Future<void> _fetchPlanTypes() async {
    try {
      final response = await ApiService().get('/fasting/plan-types');
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final planIcons = {
          '16_8': LucideIcons.clock,
          '5_2': LucideIcons.calendar,
          'basic_fasting': LucideIcons.moon,
        };
        final planNames = {
          '16_8': '16:8 轻断食',
          '5_2': '5:2 轻断食',
          'basic_fasting': '基础断食',
        };
        final updated = items.map((item) {
          final id = (item['plan_type'] ?? item['id'] ?? '').toString();
          return {
            'id': id,
            'name': (item['name'] ?? planNames[id] ?? id).toString(),
            'desc': (item['description'] ?? item['desc'] ?? '').toString(),
            'icon': planIcons[id] ?? LucideIcons.clock,
          };
        }).toList();

        if (updated.isNotEmpty && mounted) {
          setState(() => _planTypes = updated);
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    }
  }

  // 计划类型数据——优先从后端获取，硬编码数据作为回退
  static const List<Map<String, dynamic>> _fallbackPlanTypes = [
    {
      'id': '16_8',
      'name': '16:8 轻断食',
      'desc': '每日禁食16小时，进食8小时',
      'icon': LucideIcons.clock
    },
    {
      'id': '5_2',
      'name': '5:2 轻断食',
      'desc': '每周5天正常吃，2天低热量',
      'icon': LucideIcons.calendar
    },
    {
      'id': 'basic_fasting',
      'name': '基础断食',
      'desc': '每周1-2天24小时断食',
      'icon': LucideIcons.moon
    },
  ];

  List<Map<String, dynamic>> _planTypes = List.from(_fallbackPlanTypes);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前状态卡片
            if (_activePlan != null) ...[
              _buildActivePlanCard(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ] else ...[
              _buildNoPlanCard(),
            ],
            const SizedBox(height: 24),

            // 选择计划类型
            if (_activePlan == null) ...[
              Text('选择计划类型', style: AppTextStyles.h6),
              const SizedBox(height: 12),
              ..._planTypes.map((plan) => _buildPlanCard(plan)),
              const SizedBox(height: 24),
            ],

            // 进度摘要 (有活动计划时显示)
            if (_progress != null) ...[
              const SizedBox(height: 8),
              _buildProgressSummary(),
              const SizedBox(height: 24),
              // 16:8 显示连续打卡卡片，5:2/基础断食显示本周进度卡片
              if (_activePlan?.planType == '16_8')
                _buildStreakCard()
              else
                _buildWeeklyProgressCard(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== 活跃计划卡片 ====================
  Widget _buildActivePlanCard() {
    final plan = _activePlan!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.mediumShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.checkCircle,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('进行中的计划',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.8))),
                    Text(_planTypeName(plan),
                        style: AppTextStyles.h5.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    if (plan.eatingWindowStart != null &&
                        plan.eatingWindowEnd != null)
                      Text(
                        '进食窗口 ${plan.eatingWindowStart} - ${plan.eatingWindowEnd}',
                        style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _stopPlan,
                child: Text('停止',
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Builder(builder: (context) {
            // 根据计划类型显示不同的进度指标
            final planType = _activePlan!.planType;
            final is16_8 = planType == '16_8';

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (is16_8)
                  _buildStatItem('连续打卡', '${_streakDays}天', LucideIcons.flame)
                else
                  _buildStatItem('本周打卡', '${_weeklyCheckins}/${_weeklyTarget}天',
                      LucideIcons.flame),
                _buildStatItem('累计打卡', '${_checkinCount}次', LucideIcons.check),
                _buildStatItem('当前周期', '第${_weekCount}周', LucideIcons.calendar),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: AppTextStyles.h6
                .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  // ==================== 操作按钮 ====================
  Widget _buildActionButtons() {
    final plan = _activePlan!;
    final isFastingDay = plan.isFastingDayToday();

    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.clipboardCheck,
            label: isFastingDay ? '今日打卡' : '今日非断食日',
            color: isFastingDay ? AppColors.primary : AppColors.textTertiary,
            onTap: isFastingDay
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FastingCheckinPage(
                            planId: plan.planId, planType: plan.planType),
                      ),
                    ).then((_) => _loadPlans());
                  }
                : () {}, // 空回调，按钮不可用时
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.trendingUp,
            label: '进度追踪',
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FastingProgressPage(planId: plan.planId),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.utensils,
            label: '复食指导',
            color: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FastingRefeedPage(planId: plan.planId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: AppTextStyles.caption
                      .copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 进度摘要 ====================
  Widget _buildProgressSummary() {
    final p = _progress!;
    final rate = p.completionRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.target,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('完成度', style: AppTextStyles.h6),
              const Spacer(),
              Text('${rate.toStringAsFixed(0)}%',
                  style: AppTextStyles.numberSmall.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: AppColors.borderLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniStat('${p.daysElapsed}/${p.daysTotal}天', '已坚持'),
              const SizedBox(width: 24),
              _buildMiniStat(
                  p.weightChange != null
                      ? '${p.weightChange!.toStringAsFixed(1)} kg'
                      : '--',
                  '体重变化'),
              const SizedBox(width: 24),
              _buildMiniStat(_feelingLabel(p.feelingAvg), '主要体感'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
      ],
    );
  }

  String _feelingLabel(String feeling) {
    switch (feeling) {
      case 'good':
        return '良好';
      case 'normal':
        return '正常';
      case 'tired':
        return '疲劳';
      case 'uncomfortable':
        return '不适';
      default:
        return feeling;
    }
  }

  // ==================== 无计划卡片 ====================
  Widget _buildNoPlanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.calendarPlus,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('暂无进行中的计划',
              style: AppTextStyles.h6.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('选择下方计划类型开始轻断食之旅',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  // ==================== 计划类型选择卡片 ====================
  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isActive = _activePlan != null && _activePlan!.planType == plan['id'];
    return GestureDetector(
      onTap: () => _startPlan(plan['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : AppColors.divider.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isActive ? AppColors.primary : AppColors.textTertiary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(plan['icon'] as IconData,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                  size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name'],
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(plan['desc'],
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ==================== 连续打卡卡片 ====================
  Widget _buildStreakCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.flame, color: AppColors.warning, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('连续打卡 $_streakDays 天',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('保持下去，效果更佳！',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 本周进度卡片（5:2/基础断食） ====================
  Widget _buildWeeklyProgressCard() {
    final rate =
        _weeklyTarget > 0 ? (_weeklyCheckins / _weeklyTarget * 100).toInt() : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.calendarCheck, color: AppColors.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本周打卡 $_weeklyCheckins/$_weeklyTarget 天',
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$rate%',
              style: AppTextStyles.h5.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ==================== 业务逻辑 ====================

  void _startPlan(String planId) async {
    // 5:2 和基础断食需要先选择断食日
    if (planId == '5_2' || planId == 'basic_fasting') {
      final requiredDays = planId == '5_2' ? 2 : null; // null 表示 1-2 天
      final selectedDays = await _showDaySelectionDialog(requiredDays);
      if (selectedDays == null || selectedDays.isEmpty) return;

      await _createPlanWithDays(planId, selectedDays);
    } else {
      // 16:8 直接创建
      await _createPlanWithDays(planId, null);
    }
  }

  /// 显示断食日选择对话框
  Future<List<int>?> _showDaySelectionDialog(int? requiredDays) async {
    final selectedDays = <int>[];
    final dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(
            requiredDays == 2 ? '选择2天断食日' : '选择1-2天断食日',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                requiredDays == 2 ? '请选择每周的2天作为断食日' : '请选择每周的1-2天作为断食日',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final isSelected = selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedDays.remove(day);
                        } else {
                          // 检查是否超过限制
                          if (requiredDays == null) {
                            // basic_fasting: 最多2天
                            if (selectedDays.length < 2) {
                              selectedDays.add(day);
                            }
                          } else if (selectedDays.length < requiredDays) {
                            selectedDays.add(day);
                          }
                        }
                      });
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayNames[index],
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                // 验证选择数量
                if (requiredDays != null &&
                    selectedDays.length != requiredDays) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('请选择$requiredDays天')),
                  );
                  return;
                }
                if (requiredDays == null &&
                    (selectedDays.isEmpty || selectedDays.length > 2)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请选择1-2天')),
                  );
                  return;
                }
                Navigator.pop(ctx, selectedDays);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  /// 创建断食计划（带断食日）
  Future<void> _createPlanWithDays(
      String planType, List<int>? fastingDays) async {
    try {
      final service = ref.read(fastingServiceProvider);
      final result = await service.createPlan(
        planType: planType,
        startDate: DateTime.now().toIso8601String().split('T')[0],
        fastingDays: fastingDays,
      );
      final planIdCreated = result['plan_id'] ?? 0;
      setState(() {
        _activePlan = FastingPlan(
          planId: planIdCreated,
          planType: planType,
          status: 'active',
          startDate: DateTime.now().toIso8601String().split('T')[0],
        );
        _streakDays = 1;
        _checkinCount = 0;
        _weekCount = 1;
        _progress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划已创建，快去打卡吧！')),
        );
        // 重新加载完整进度数据
        _loadPlans();
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertCircle, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('创建失败',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        content: Text(message,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _stopPlan() async {
    if (_activePlan == null) return;

    // 确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('停止计划'),
        content: const Text('确定要停止当前的轻断食计划吗？停止后可以重新开始。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('停止'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final service = ref.read(fastingServiceProvider);
      await service.stopPlan(_activePlan!.planId);
      setState(() {
        _activePlan = null;
        _progress = null;
        _streakDays = 0;
        _checkinCount = 0;
        _weekCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划已停止')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('停止失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text('轻断食计划',
          style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
