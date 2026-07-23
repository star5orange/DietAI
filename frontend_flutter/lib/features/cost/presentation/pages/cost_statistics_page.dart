import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../data/services/cost_service.dart';

/// 消费统计页 - 真实API版本
/// 数据来源：GET /foods/cost-stats, GET /foods/cost-trend, POST /foods/cost-budget
class CostStatisticsPage extends ConsumerStatefulWidget {
  const CostStatisticsPage({super.key});

  @override
  ConsumerState<CostStatisticsPage> createState() => _CostStatisticsPageState();
}

class _CostStatisticsPageState extends ConsumerState<CostStatisticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CostService _costService = CostService(ApiService());

  // 真实数据
  CostStats? _costStats;
  List<CostTrendItem> _trendItems = [];
  List<Map<String, dynamic>> _sourceCategories = [];
  List<Map<String, dynamic>> _mealCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  // 日期范围选择
  String _period = 'month'; // week | month
  int _trendDays = 30;

  // 预算输入控制器
  final TextEditingController _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _costService.getCostStats(period: _period),
        _costService.getCostTrend(days: _trendDays),
      ]);

      final stats = results[0] as CostStats;
      final trend = results[1] as CostTrend;

      if (mounted) {
        setState(() {
          _costStats = stats;
          _trendItems = trend.trend;

          // 从 bySource 提取分类数据
          _sourceCategories = _parseCategoryData(stats.bySource);
          // 从 byMealTime 提取餐次数据
          _mealCategories = _parseCategoryData(stats.byMealTime);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载数据失败: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _parseCategoryData(Map<String, double> source) {
    const colors = [
      Color(0xFF4ECDC4),
      Color(0xFFFF6B6B),
      Color(0xFFFFA726),
      Color(0xFFAB47BC),
      Color(0xFF66BB6A),
      Color(0xFF42A5F5),
      Color(0xFFEC407A),
      Color(0xFF8D6E63),
    ];
    return source.entries.map((e) {
      final idx = source.keys.toList().indexOf(e.key) % colors.length;
      return {
        'name': _sourceLabelName(e.key),
        'amount': e.value,
        'color': colors[idx],
      };
    }).toList();
  }

  String _sourceLabelName(String key) {
    const labels = {
      'canteen': '食堂',
      'delivery': '外卖',
      'home': '家里',
      'restaurant': '餐厅',
      'snack': '零食',
      'other': '其他',
      // 兼容旧的中文标签
      '早餐': '早餐',
      '午餐': '午餐',
      '晚餐': '晚餐',
      '外卖': '外卖',
      '零食': '零食',
      '自制': '自制',
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack_meal': '加餐',
      'late_night': '夜宵',
    };
    return labels[key] ?? key;
  }

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
        title: Text('消费统计',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          _buildPeriodChip('周', 'week'),
          const SizedBox(width: 4),
          _buildPeriodChip('月', 'month'),
          IconButton(
            icon: const Icon(LucideIcons.settings,
                color: AppColors.textSecondary),
            onPressed: () => _showBudgetSettingDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '总览'),
            Tab(text: '分类分析'),
            Tab(text: '趋势分析'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isActive = _period == value;
    return GestureDetector(
      onTap: () {
        if (_period != value) {
          setState(() {
            _period = value;
            _trendDays = value == 'month' ? 30 : 7;
          });
          _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMessage != null && _costStats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildCategoryTab(),
        _buildTrendTab(),
      ],
    );
  }

  // ==================== Tab 1: 总览 ====================
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTotalCostCard(),
          const SizedBox(height: 20),
          _buildBudgetRemainingCard(),
          const SizedBox(height: 20),
          _buildCaloriesPerYuanCard(),
          const SizedBox(height: 20),
          _buildQuickStatsCard(),
        ],
      ),
    );
  }

  Widget _buildTotalCostCard() {
    final stats = _costStats;
    final totalCost = stats?.totalCost ?? 0.0;
    final budget = _getBudget();
    final progress = budget > 0 ? (totalCost / budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wallet, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(_period == 'month' ? '本月总开销' : '本周总开销',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${stats?.recordCount ?? 0}笔',
                    style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('¥${totalCost.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 12),
          if (budget > 0) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('预算 ¥${budget.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress > 0.8 ? Colors.orangeAccent : Colors.white,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetRemainingCard() {
    final budget = _getBudget();
    final totalCost = _costStats?.totalCost ?? 0.0;
    final remaining = budget - totalCost;
    final usagePercent =
        budget > 0 ? (totalCost / budget * 100).clamp(0, 100) : 0.0;
    final isOverBudget = budget > 0 && remaining < 0;
    final isWarning = budget > 0 && usagePercent >= 80 && !isOverBudget;
    final hasBudget = budget > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
        border: Border.all(
          color: hasBudget
              ? (isOverBudget
                  ? AppColors.error
                  : (isWarning ? AppColors.warning : AppColors.success))
              : AppColors.textTertiary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: hasBudget
          ? Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isOverBudget
                            ? AppColors.errorLight
                            : isWarning
                                ? AppColors.warning.withValues(alpha: 0.15)
                                : AppColors.successLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOverBudget
                            ? LucideIcons.alertTriangle
                            : isWarning
                                ? LucideIcons.alertCircle
                                : LucideIcons.piggyBank,
                        color: isOverBudget
                            ? AppColors.error
                            : isWarning
                                ? AppColors.warning
                                : AppColors.success,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              isOverBudget
                                  ? '已超出预算'
                                  : (isWarning ? '预算预警' : '预算剩余'),
                              style: AppTextStyles.h6
                                  .copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            isOverBudget
                                ? '超出 ¥${remaining.abs().toStringAsFixed(2)}'
                                : '剩余 ¥${remaining.toStringAsFixed(2)}',
                            style: AppTextStyles.numberSmall.copyWith(
                              color: isOverBudget
                                  ? AppColors.error
                                  : isWarning
                                      ? AppColors.warning
                                      : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOverBudget
                            ? AppColors.error.withValues(alpha: 0.1)
                            : isWarning
                                ? AppColors.warning.withValues(alpha: 0.1)
                                : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isOverBudget
                            ? '超标'
                            : (isWarning ? '${usagePercent.round()}%' : '正常'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverBudget
                              ? AppColors.error
                              : isWarning
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isWarning)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertCircle,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              usagePercent >= 95
                                  ? '已达预算的 ${usagePercent.round()}%，请注意控制消费！'
                                  : '已使用预算的 ${usagePercent.round()}%，请注意合理安排开销',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isOverBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.alertTriangle,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '已超出预算 ¥${remaining.abs().toStringAsFixed(2)}，建议调整消费习惯',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.piggyBank,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('设置预算',
                          style: AppTextStyles.h6
                              .copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('设置月度预算，控制饮食开销',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showBudgetSettingDialog(),
                  child: const Text('去设置'),
                ),
              ],
            ),
    );
  }

  Widget _buildCaloriesPerYuanCard() {
    final caloriePerYuan = _costStats?.caloriePerYuan ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.zap,
                  color: AppColors.caloriesColor, size: 20),
              const SizedBox(width: 8),
              Text('每元热量指标', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(caloriePerYuan.toStringAsFixed(1),
                      style: AppTextStyles.numberLarge
                          .copyWith(color: AppColors.caloriesColor)),
                  Text('kcal/元',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary)),
                ],
              ),
              const SizedBox(width: 40),
              _buildIndicator('经济高效', caloriePerYuan >= 8.0),
              const SizedBox(width: 12),
              _buildIndicator('营养密度', caloriePerYuan >= 6.0),
            ],
          ),
          const SizedBox(height: 12),
          Text('提示：每元热量指标反映饮食性价比，建议保持在6-8 kcal/元区间',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildIndicator(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.borderLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 14,
            color: isActive ? AppColors.success : AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? AppColors.success : AppColors.textTertiary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              )),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final stats = _costStats;
    final dailyAvg = stats?.dailyAvg ?? 0.0;
    final recordCount = stats?.recordCount ?? 0;
    final maxSingle = stats?.maxSingle ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.barChart3,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('快速统计', style: AppTextStyles.h6),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildStatItem('日均花费',
                      '¥${dailyAvg.toStringAsFixed(1)}', LucideIcons.coins)),
              Expanded(
                  child: _buildStatItem(
                      '记录笔数', '$recordCount笔', LucideIcons.calendar)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatItem(
                      '最贵单笔',
                      '¥${maxSingle.toStringAsFixed(1)}',
                      LucideIcons.trendingUp)),
              Expanded(
                  child: _buildStatItem(
                      '统计周期',
                      _period == 'month' ? '本月' : '本周',
                      LucideIcons.trendingDown)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.numberSmall
                  .copyWith(color: AppColors.textPrimary)),
          Text(label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  // ==================== Tab 2: 分类分析 ====================
  Widget _buildCategoryTab() {
    final hasSource = _sourceCategories.isNotEmpty;
    final hasMeal = _mealCategories.isNotEmpty;

    if (!hasSource && !hasMeal) {
      return _buildEmptyState('暂无消费数据，记录饮食并输入金额后将在此展示分类分析');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasSource) ...[
            _buildSectionHeader('消费来源', LucideIcons.pieChart),
            const SizedBox(height: 16),
            _buildCategoryPieChart(_sourceCategories),
            const SizedBox(height: 20),
            _buildCategoryList(_sourceCategories),
          ],
          if (hasSource && hasMeal) const SizedBox(height: 32),
          if (hasMeal) ...[
            _buildSectionHeader('餐次分布', LucideIcons.sun),
            const SizedBox(height: 16),
            _buildCategoryPieChart(_mealCategories),
            const SizedBox(height: 20),
            _buildCategoryList(_mealCategories),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(List<Map<String, dynamic>> data) {
    final totalAmount = data.fold<double>(
        0.0, (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: PieChart(
              PieChartData(
                sections: data.map((item) {
                  final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                  final percentage =
                      totalAmount > 0 ? (amount / totalAmount * 100) : 0;
                  return PieChartSectionData(
                    value: amount,
                    color: item['color'] as Color,
                    title: percentage >= 5
                        ? '${percentage.toStringAsFixed(0)}%'
                        : '',
                    radius: 60,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('总消费 ¥${totalAmount.toStringAsFixed(2)}',
              style: AppTextStyles.h6.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> data) {
    return Column(
      children: data.map((item) => _buildCategoryItem(item, data)).toList(),
    );
  }

  Widget _buildCategoryItem(
      Map<String, dynamic> item, List<Map<String, dynamic>> allData) {
    final name = item['name'] as String;
    final amount = item['amount'] as double;
    final color = item['color'] as Color;
    final totalAmount =
        allData.fold<double>(0.0, (sum, i) => sum + (i['amount'] as double));
    final percentage = totalAmount > 0 ? (amount / totalAmount * 100) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Container(
                  width: 20,
                  height: 20,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('¥${amount.toStringAsFixed(2)}',
                    style: AppTextStyles.numberXSmall.copyWith(color: color)),
              ],
            ),
          ),
          Text('${percentage.toStringAsFixed(0)}%',
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  // ==================== Tab 3: 趋势分析 ====================
  Widget _buildTrendTab() {
    final hasData = _trendItems.any((d) => d.cost > 0);

    return !hasData
        ? _buildEmptyState('暂无消费趋势数据，记录更多笔消费后将在折线图中展示变化')
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('消费趋势', LucideIcons.trendingUp),
                const SizedBox(height: 16),
                _buildTrendLineChart(),
              ],
            ),
          );
  }

  Widget _buildTrendLineChart() {
    if (_trendItems.isEmpty) return const SizedBox.shrink();

    final maxCost = _trendItems.fold<double>(0, (max, d) {
      return d.cost > max ? d.cost : max;
    });

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: (maxCost * 1.2).clamp(10, double.infinity),
          lineBarsData: [
            LineChartBarData(
              spots: _trendItems.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value.cost);
              }).toList(),
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '¥${value.toInt()}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _trendItems.length > 14 ? 7 : 3,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _trendItems.length) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime.tryParse(_trendItems[idx].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      date != null ? DateFormat('MM/dd').format(date) : '',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textTertiary),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(
              color: AppColors.borderLight,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  // ==================== Empty State ====================
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.barChart3,
                size: 64, color: AppColors.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textTertiary)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('刷新'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Helper ====================
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ],
    );
  }

  double _getBudget() {
    final stats = _costStats;
    if (stats == null) return 0.0;
    // budget = budget_remaining + total_cost
    if (stats.budgetRemaining != null) {
      return stats.budgetRemaining! + stats.totalCost;
    }
    return stats.budget ?? 0.0;
  }

  void _showBudgetSettingDialog() {
    final currentBudget = _getBudget();
    _budgetController.text =
        currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('设置月度预算', style: AppTextStyles.h4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('控制饮食开销，系统将追踪预算使用情况',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '预算金额',
                  suffixText: '元/月',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                ),
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
                final budget = double.tryParse(_budgetController.text);
                if (budget == null || budget <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('请输入有效的预算金额'),
                        backgroundColor: AppColors.error),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  await _costService.setMonthlyBudget(budget);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('预算设置成功'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('设置预算失败: $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
              ),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
