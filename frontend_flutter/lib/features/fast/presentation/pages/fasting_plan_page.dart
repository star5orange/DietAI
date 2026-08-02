import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../data/services/fasting_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
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
  List<FastingPlan> _completedPlans = [];
  bool _checkedInToday = false;
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
      // 并行加载活动计划、已完成计划和断食计划类型
      final results = await Future.wait([
        service.getPlans(status: 'active'),
        service.getPlans(status: 'completed'),
        _fetchPlanTypes(),
      ]);
      final plans = results[0] as List<FastingPlan>;
      final completedPlans = results[1] as List<FastingPlan>;
      if (plans.isNotEmpty) {
        final plan = plans.first;
        // Parallel load progress and checkins
        FastingProgress? progress;
        int checkinCount = 0;
        bool checkedInToday = false;
        try {
          final results = await Future.wait([
            service.getProgress(plan.planId),
            service.getCheckins(plan.planId),
          ]);
          progress = results[0] as FastingProgress;
          final checkins = results[1] as List<FastingCheckin>;
          checkinCount = checkins.length;
          // 检查今日是否已打卡
          final today = DateTime.now();
          final todayStr =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          checkedInToday =
              checkins.any((c) => c.checkinDate == todayStr && c.completed);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _activePlan = plan;
            _progress = progress;
            _completedPlans = completedPlans;
            _checkedInToday = checkedInToday;
            _streakDays = progress?.streakDays ?? 0;
            _checkinCount = checkinCount;
            _weekCount = progress != null
                ? ((progress.daysElapsed / 7).ceil()).clamp(1, 52)
                : 1;
            _weeklyCheckins = progress?.weeklyCheckins ?? 0;
            _weeklyTarget = progress?.weeklyTarget ?? 0;
          });
        }
      } else {
        if (mounted) setState(() => _completedPlans = completedPlans);
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
              const SizedBox(height: 18),
              _buildRefeedInfoCard(),
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
            // 已完成计划记录
            if (_completedPlans.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildCompletedPlansSection(),
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
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '进食窗口 ${plan.eatingWindowStart} - ${plan.eatingWindowEnd}',
                            style: AppTextStyles.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => _editEatingWindow(plan),
                            child: Icon(
                              LucideIcons.pencil,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
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
            icon: _checkedInToday
                ? LucideIcons.checkCircle
                : LucideIcons.clipboardCheck,
            label:
                _checkedInToday ? '今日已打卡' : (isFastingDay ? '今日打卡' : '今日非断食日'),
            color: _checkedInToday
                ? AppColors.success
                : (isFastingDay ? AppColors.primary : AppColors.textTertiary),
            onTap: (_checkedInToday || !isFastingDay)
                ? () {} // 已打卡或非断食日不可点
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FastingCheckinPage(
                            planId: plan.planId, planType: plan.planType),
                      ),
                    ).then((_) => _loadPlans());
                  },
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
          // 5:2/基础断食：显示已完成断食日数量
          if (_activePlan!.planType != '16_8' && p.expectedFastingDays > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '已完成 ${p.completedCount}/${p.expectedFastingDays} 个断食日',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
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

  // ==================== 已完成计划 ====================

  Widget _buildRefeedInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '断食结束后需要逐步恢复饮食（复食阶段），'
              '创建计划后可查看分阶段的复食指导方案，'
              '帮助您的身体平稳过渡。',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已完成计划', style: AppTextStyles.h6),
        const SizedBox(height: 12),
        ..._completedPlans.map((plan) => _buildCompletedPlanCard(plan)),
      ],
    );
  }

  Widget _buildCompletedPlanCard(FastingPlan plan) {
    final daysText = plan.daysElapsed != null ? '${plan.daysElapsed}天' : '--';
    final typeName = _planTypeName(plan);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FastingRefeedPage(planId: plan.planId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.checkCircle,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeName,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.startDate.substring(0, 10)} 起 · $daysText',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDisclaimer() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 24),
            SizedBox(width: 8),
            Text('免责声明',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '轻断食并非适用于所有人。在开始任何断食计划之前，请确认以下事项：',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _disclaimerItem('您已年满18周岁，且身体发育成熟'),
              _disclaimerItem('您目前没有处于怀孕、备孕或哺乳期'),
              _disclaimerItem('您没有严重的慢性疾病（如糖尿病、低血糖、心脏病、肝肾疾病等）'),
              _disclaimerItem('您没有进食障碍病史（如厌食症、暴食症）'),
              _disclaimerItem('您知晓断食期间可能出现头晕、乏力、注意力不集中等反应'),
              _disclaimerItem('您愿意在身体出现严重不适时立即停止断食并咨询医生'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  '本应用提供的断食建议仅供参考，不构成医疗建议。'
                  '如有任何健康疑虑，请先咨询专业医生。',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('我已了解，继续'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _disclaimerItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _startPlan(String planId) async {
    // 首次使用需确认免责声明
    final accepted = await _showDisclaimer();
    if (!accepted) return;

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
      final profile = ref.read(userProfileProvider).value;
      await service.createPlan(
        planType: planType,
        startDate: DateTime.now().toIso8601String().split('T')[0],
        fastingDays: fastingDays,
        startWeight: profile?.weight,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('计划已创建，快去打卡吧！')),
        );
        // 重新加载，由 _loadPlans 统一设置 _activePlan
        setState(() => _isLoading = true);
        await _loadPlans();
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

  /// 修改进食窗口
  Future<void> _editEatingWindow(FastingPlan plan) async {
    TimeOfDay startTime = _parseTime(plan.eatingWindowStart ?? '08:00');
    TimeOfDay endTime = _parseTime(plan.eatingWindowEnd ?? '16:00');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) {
        TimeOfDay localStart = startTime;
        TimeOfDay localEnd = endTime;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final formatTime = (TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
            return AlertDialog(
              title: const Text('修改进食窗口'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('调整每日进食时间段',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('开始时间',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: localStart,
                              );
                              if (picked != null) {
                                setDialogState(() => localStart = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Text(formatTime(localStart),
                                  style: AppTextStyles.h6.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(LucideIcons.arrowRight,
                            color: AppColors.textTertiary, size: 20),
                      ),
                      Column(
                        children: [
                          Text('结束时间',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: localEnd,
                              );
                              if (picked != null) {
                                setDialogState(() => localEnd = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary),
                              ),
                              child: Text(formatTime(localEnd),
                                  style: AppTextStyles.h6.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, {
                    'start': formatTime(localStart),
                    'end': formatTime(localEnd),
                  }),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      final service = ref.read(fastingServiceProvider);
      await service.updatePlan(
        plan.planId,
        eatingWindowStart: result['start'],
        eatingWindowEnd: result['end'],
      );
      if (mounted) {
        // 刷新状态
        setState(() => _isLoading = true);
        await _loadPlans();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('进食窗口已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
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
      final stoppedPlanId = _activePlan!.planId;
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
        // 停止后直接跳转复食指导
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FastingRefeedPage(planId: stoppedPlanId),
          ),
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
