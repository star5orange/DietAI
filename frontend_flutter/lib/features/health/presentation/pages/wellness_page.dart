import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../services/wellness_service.dart';
import 'recipe_detail_page.dart';

class WellnessPage extends StatefulWidget {
  const WellnessPage({super.key});

  @override
  State<WellnessPage> createState() => _WellnessPageState();
}

class _WellnessPageState extends State<WellnessPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WellnessService _wellnessService = WellnessService();
  Map<String, dynamic>? _recommendation;
  List<Map<String, dynamic>> _solarTerms = [];
  List<Map<String, dynamic>> _wellnessTips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _wellnessService.getDailyRecommendation(),
        _wellnessService.getSolarTerms(),
        _wellnessService.getWellnessTips(),
      ]);

      if (mounted) {
        setState(() {
          _recommendation =
              (results[0] as ApiResponse<Map<String, dynamic>>).data;
          _solarTerms =
              (results[1] as ApiResponse<List<Map<String, dynamic>>>).data ??
                  [];
          _wellnessTips =
              (results[2] as ApiResponse<List<Map<String, dynamic>>>).data ??
                  [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        title: Text('养生推荐',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '今日推荐'),
            Tab(text: '节气养生'),
            Tab(text: '养生知识'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyRecommendTab(),
                _buildSolarTermTab(),
                _buildKnowledgeTab(),
              ],
            ),
    );
  }

  Widget _buildDailyRecommendTab() {
    if (_recommendation == null) {
      return const Center(child: Text('暂无推荐数据'));
    }

    final tips = _recommendation!['wellness_tips'] as List? ?? [];
    final ingredients =
        _recommendation!['recommended_ingredients'] as List? ?? [];
    final recipes = _recommendation!['recommended_recipes'] as List? ?? [];
    final avoidFoods = _recommendation!['foods_to_avoid'] as List? ?? [];
    final solarTerm = _recommendation!['current_solar_term'] ?? '芒种';
    final season = _recommendation!['current_season'] ?? '夏季';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前节气卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sun, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Text('当前节气：$solarTerm',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('$season · 顺时而养',
                    style:
                        const TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 养生贴士
          _buildSectionTitle(
              LucideIcons.lightbulb, '养生贴士', const Color(0xFFFFA726)),
          const SizedBox(height: 10),
          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA726).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(tip.toString(),
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 20),

          // 推荐食材
          _buildSectionTitle(
              LucideIcons.apple, '推荐食材', const Color(0xFF43A047)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ingredients.map((item) {
              final name = item is Map
                  ? item['name'] ?? item.toString()
                  : item.toString();
              final benefit = item is Map ? item['benefit'] ?? '' : '';
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF43A047).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF43A047))),
                    if (benefit.isNotEmpty)
                      Text(benefit,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textTertiary)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 推荐食谱
          _buildSectionTitle(
              LucideIcons.chefHat, '推荐食谱', const Color(0xFF5B86E5)),
          const SizedBox(height: 10),
          ...recipes.map((recipe) {
            final r = recipe as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RecipeDetailPage(recipe: r),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.lightShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B86E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.soup,
                            color: Color(0xFF5B86E5), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['name'] ?? '',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(r['description'] ?? '',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // 避免食物
          _buildSectionTitle(
              LucideIcons.alertTriangle, '饮食禁忌', const Color(0xFFEF5350)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: avoidFoods
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFEF5350).withValues(alpha: 0.2)),
                      ),
                      child: Text(item.toString(),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFEF5350))),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSolarTermTab() {
    if (_solarTerms.isEmpty) {
      return const Center(child: Text('暂无节气数据'));
    }

    // 按月份分组节气 (date格式 "MM-DD")
    final monthNames = [
      '',
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月'
    ];
    final termByMonth = <int, List<Map<String, dynamic>>>{};
    for (final term in _solarTerms) {
      final date = term['date'] ?? '';
      final month = int.tryParse(date.split('-')[0]) ?? 0;
      termByMonth.putIfAbsent(month, () => []).add(term);
    }

    // 找当前节气所在的月份
    int? currentMonth;
    for (final term in _solarTerms) {
      if (term['is_current'] == true) {
        final date = term['date'] ?? '';
        currentMonth = int.tryParse(date.split('-')[0]);
        break;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4, // 每季度一屏
      itemBuilder: (context, quarterIdx) {
        final startMonth = quarterIdx * 3 + 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 季度标题
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: quarterIdx > 0 ? 8 : 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _quarterGradient(startMonth),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _quarterName(startMonth),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // 该季度三个月
            ...List.generate(3, (i) {
              final month = startMonth + i;
              final terms = termByMonth[month] ?? [];
              if (terms.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: currentMonth == month
                      ? AppColors.primary.withValues(alpha: 0.04)
                      : AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  border: currentMonth == month
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1)
                      : null,
                  boxShadow: AppColors.lightShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 月份头
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: currentMonth == month
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : AppColors.backgroundGray.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _monthIcon(month),
                            size: 16,
                            color: currentMonth == month
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            monthNames[month],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: currentMonth == month
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (currentMonth == month) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('本月',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 节气格子
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: terms.map((term) {
                          final day = (term['date'] ?? '').split('-').last;
                          final isCurrent = term['is_current'] == true;
                          return GestureDetector(
                            onTap: isCurrent
                                ? null
                                : () => _showTermDetailSheet(context, term),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppColors.primary
                                    : (isCurrent
                                        ? AppColors.primary
                                            .withValues(alpha: 0.08)
                                        : AppColors.backgroundGray
                                            .withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(10),
                                border: isCurrent
                                    ? null
                                    : Border.all(color: AppColors.borderLight),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    term['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isCurrent
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$day日',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCurrent
                                          ? Colors.white70
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                  if (term['description'] != null &&
                                      term['description'].isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        term['description'],
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: isCurrent
                                              ? Colors.white60
                                              : AppColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showTermDetailSheet(BuildContext context, Map<String, dynamic> term) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43A047).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(LucideIcons.calendar,
                        color: Color(0xFF43A047), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(term['name'] ?? '',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      Text('${term['date'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (term['description'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGray.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    term['description'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  List<Color> _quarterGradient(int startMonth) {
    if (startMonth <= 3)
      return const [Color(0xFF66BB6A), Color(0xFF43A047)]; // 春
    if (startMonth <= 6)
      return const [Color(0xFFFF7043), Color(0xFFE64A19)]; // 夏
    if (startMonth <= 9)
      return const [Color(0xFFFFA726), Color(0xFFF57C00)]; // 秋
    return const [Color(0xFF42A5F5), Color(0xFF1E88E5)]; // 冬
  }

  String _quarterName(int startMonth) {
    if (startMonth <= 3) return '春季  ·  万物复苏';
    if (startMonth <= 6) return '夏季  ·  生机勃勃';
    if (startMonth <= 9) return '秋季  ·  硕果累累';
    return '冬季  ·  养精蓄锐';
  }

  IconData _monthIcon(int month) {
    switch (month) {
      case 1:
        return LucideIcons.snowflake;
      case 2:
        return LucideIcons.sunrise;
      case 3:
        return LucideIcons.flower2;
      case 4:
        return LucideIcons.sun;
      case 5:
        return LucideIcons.leaf;
      case 6:
        return LucideIcons.umbrella;
      case 7:
        return LucideIcons.sun;
      case 8:
        return LucideIcons.thermometer;
      case 9:
        return LucideIcons.wind;
      case 10:
        return LucideIcons.moon;
      case 11:
        return LucideIcons.cloudRain;
      case 12:
        return LucideIcons.snowflake;
      default:
        return LucideIcons.calendar;
    }
  }

  Widget _buildKnowledgeTab() {
    if (_wellnessTips.isEmpty) {
      return const Center(
        child: Text('暂无养生知识', style: TextStyle(color: AppColors.textTertiary)),
      );
    }

    // 判断数据格式：有 items 字段是前端分组格式，有 category+content 是后端扁平格式
    final firstItem = _wellnessTips.first;
    final isGrouped = firstItem.containsKey('items');

    if (isGrouped) {
      return _buildGroupedKnowledge();
    }
    return _buildFlatKnowledge();
  }

  /// 前端 fallback 分组格式：{title, icon, color, items: [...]}
  Widget _buildGroupedKnowledge() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _wellnessTips.map((section) {
        final icon = _parseIcon(section['icon']?.toString() ?? 'heart');
        final color = _parseColor(section['color']?.toString() ?? '#43A047');
        final title = section['title']?.toString() ?? '';
        final items =
            (section['items'] as List?)?.map((e) => e.toString()).toList() ??
                [];

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.lightShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const Divider(
                    height: 1,
                    color: AppColors.textTertiary,
                    indent: 14,
                    endIndent: 14),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 后端扁平格式：{category, title, content, recommended_foods, ...}
  /// 按 category 分组展示
  Widget _buildFlatKnowledge() {
    // 按 category 分组
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tip in _wellnessTips) {
      final cat = tip['category']?.toString() ?? '其他';
      grouped.putIfAbsent(cat, () => []);
      grouped[cat]!.add(tip);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: grouped.entries.map((entry) {
        final category = entry.key;
        final tips = entry.value;
        final config = _categoryConfig(category);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类标题
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: config['color'] as Color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(config['icon'] as IconData,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 该分类下的每条知识点
              ...tips.map((tip) {
                final title = tip['title']?.toString() ?? '';
                final content = tip['content']?.toString() ?? '';
                final foods =
                    (tip['recommended_foods'] as List?)?.cast<String>() ?? [];
                final avoid =
                    (tip['avoid_foods'] as List?)?.cast<String>() ?? [];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: (config['color'] as Color)
                              .withValues(alpha: 0.15)),
                      boxShadow: AppColors.lightShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        if (content.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(content,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                        ],
                        if (foods.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: foods.map((f) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('推荐: $f',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.success)),
                              );
                            }).toList(),
                          ),
                        ],
                        if (avoid.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: avoid.map((a) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.error.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('少食: $a',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.error)),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 根据 category 返回对应的图标和颜色
  Map<String, dynamic> _categoryConfig(String category) {
    switch (category) {
      case '体质':
        return {
          'icon': LucideIcons.heartPulse,
          'color': const Color(0xFFEF5350),
        };
      case '季节':
      case '四季':
        return {
          'icon': LucideIcons.sun,
          'color': const Color(0xFFFFA726),
        };
      case '饮食':
        return {
          'icon': LucideIcons.utensils,
          'color': const Color(0xFF43A047),
        };
      case '节气':
        return {
          'icon': LucideIcons.calendar,
          'color': const Color(0xFF42A5F5),
        };
      default:
        return {
          'icon': LucideIcons.leaf,
          'color': AppColors.primary,
        };
    }
  }

  IconData _parseIcon(String name) {
    switch (name) {
      case 'heart_pulse':
        return LucideIcons.heartPulse;
      case 'heart':
        return LucideIcons.heart;
      case 'sun':
        return LucideIcons.sun;
      case 'utensils':
        return LucideIcons.utensils;
      case 'leaf':
        return LucideIcons.leaf;
      case 'apple':
        return LucideIcons.apple;
      case 'droplets':
        return LucideIcons.droplets;
      case 'moon':
        return LucideIcons.moon;
      case 'zap':
        return LucideIcons.zap;
      case 'flame':
        return LucideIcons.flame;
      case 'sprout':
        return LucideIcons.sprout;
      case 'dumbbell':
        return LucideIcons.dumbbell;
      case 'sparkles':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.heart;
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
