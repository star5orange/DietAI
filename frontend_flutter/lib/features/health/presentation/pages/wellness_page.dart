import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
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
      final recRes = await _wellnessService.getDailyRecommendation();
      final solarRes = await _wellnessService.getSolarTerms();

      if (mounted) {
        setState(() {
          _recommendation = recRes.data;
          _solarTerms = solarRes.data ?? [];
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _solarTerms.length,
      itemBuilder: (context, index) {
        final term = _solarTerms[index];
        final isCurrent = term['is_current'] == true;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
              boxShadow: AppColors.lightShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : const Color(0xFF43A047).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.calendar,
                    color:
                        isCurrent ? AppColors.primary : const Color(0xFF43A047),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(term['name'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              )),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('当前',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          '${term['date'] ?? ''} · ${term['description'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKnowledgeTab() {
    final knowledgeList = [
      {
        'title': '中医九种体质',
        'icon': LucideIcons.heartPulse,
        'color': const Color(0xFFEF5350),
        'items': [
          '平和质：最健康的体质，阴阳气血调和',
          '气虚质：元气不足，容易疲劳感冒',
          '阳虚质：阳气不足，畏寒怕冷',
          '阴虚质：阴液亏少，口干手足心热',
          '痰湿质：痰湿凝聚，形体肥胖',
          '湿热质：湿热内蕴，面垢油光',
          '血瘀质：血行不畅，肤色晦暗',
          '气郁质：气机郁滞，情绪低落',
          '特禀质：过敏体质，易过敏',
        ],
      },
      {
        'title': '四季养生原则',
        'icon': LucideIcons.sun,
        'color': const Color(0xFFFFA726),
        'items': [
          '春养肝：早睡早起，舒展身体，宜食绿色蔬菜',
          '夏养心：晚睡早起，适当午休，宜食苦味食物',
          '秋养肺：早睡早起，润燥养阴，宜食白色食物',
          '冬养肾：早睡晚起，保暖防寒，宜食黑色食物',
        ],
      },
      {
        'title': '饮食养生要点',
        'icon': LucideIcons.utensils,
        'color': const Color(0xFF43A047),
        'items': [
          '饮食有节：定时定量，不暴饮暴食',
          '五味调和：酸苦甘辛咸均衡摄入',
          '因时制宜：根据季节调整饮食结构',
          '因人制宜：根据体质选择适宜食物',
          '药食同源：善用药膳调理身体',
        ],
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: knowledgeList.map((section) {
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
                          color: (section['color'] as Color)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(section['icon'] as IconData,
                            color: section['color'] as Color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(section['title'] as String,
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
                ...(section['items'] as List<String>).map((item) => Padding(
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
                              color: section['color'] as Color,
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
