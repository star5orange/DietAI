import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../widgets/pet_weight_chart.dart';
import '../widgets/add_weight_modal.dart';
import '../widgets/pet_avatar_display.dart';
import '../widgets/edit_pet_dialog.dart';
import '../widgets/add_feeding_record_modal.dart';
import 'generate_pet_avatar_page.dart';
import 'pet_feeding_page.dart';
import 'pet_food_library_page.dart';
import 'pet_weekly_report_page.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../data/real_pet_api_service.dart';
import '../../presentation/providers/pet_provider.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/utils/species_utils.dart';

/// 真实宠物详情页
/// 包含：宠物档案、体重趋势图、饮食日报、AI建议
class RealPetDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> pet;

  const RealPetDetailPage({super.key, required this.pet});

  @override
  ConsumerState<RealPetDetailPage> createState() => _RealPetDetailPageState();
}

class _RealPetDetailPageState extends ConsumerState<RealPetDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;
  bool _isLoading = true;

  // API 数据
  List<Map<String, dynamic>> _weightRecords = [];
  List<Map<String, dynamic>> _feedingRecords = [];
  List<Map<String, dynamic>> _waterRecords = []; // 新增：饮水记录
  List<Map<String, dynamic>> _vaccineRecords = [];
  List<Map<String, dynamic>> _dewormingRecords = [];
  Map<String, dynamic>? _nutritionTargets;
  Map<String, dynamic>? _dailySummary;
  Map<String, dynamic>? _healthScore;
  String? _aiAdvice;
  String? _aiDisclaimer;
  Map<String, String> _emotionUrls = {}; // AI 生成的情绪变体 URL
  String _selectedEmotion = 'normal'; // 当前选中的情绪

  int get _petId => (widget.pet['id'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTabIndex = _tabController.index);
      }
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final api = RealPetApiService();

    await Future.wait([
      // 刷新宠物基本信息（年龄、体重等）
      api.getPet(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          widget.pet.addAll(r.data!);
          // 加载已生成的 AI 形象情绪变体 URL
          final emotions = r.data!['avatar_emotions'] as Map<String, dynamic>?;
          if (emotions != null && emotions.isNotEmpty) {
            _emotionUrls =
                emotions.map((k, v) => MapEntry(k, v?.toString() ?? ''));
          }
        }
      }).catchError((_) {}),
      // 体重记录
      api.getWeightRecords(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final records = r.data!['records'] as List<dynamic>? ?? [];
          _weightRecords =
              records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }).catchError((_) {}),
      // 饮食记录
      api.getFeedingRecords(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final rawRecords = r.data!['records'] as List<dynamic>? ?? [];
          _feedingRecords = rawRecords.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            m['food'] = (m['food_name'] as String?) ?? '';
            m['amount_g'] = (m['amount_grams'] as num?)?.toDouble() ?? 0;
            m['time'] = (m['record_time'] as String?) ?? '';
            m['source'] = (m['from_source'] as String?) ?? '手动';
            return m;
          }).toList();
        }
      }).catchError((_) {}),
      // 疫苗记录
      api.getVaccineRecords(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final records = r.data!['records'] as List<dynamic>? ?? [];
          _vaccineRecords =
              records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }).catchError((_) {}),
      // 驱虫记录
      api.getDewormingRecords(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final records = r.data!['records'] as List<dynamic>? ?? [];
          _dewormingRecords =
              records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }).catchError((_) {}),
      // 饮水记录
      api.getWaterRecords(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final records = r.data!['records'] as List<dynamic>? ?? [];
          _waterRecords =
              records.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }).catchError((_) {}),
      // 喂食计划（含营养目标）
      api.getFeedingPlan(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          _nutritionTargets = r.data;
        }
      }).catchError((_) {}),
      // 今日汇总
      api
          .getDailySummary(
              _petId, DateTime.now().toIso8601String().substring(0, 10))
          .then((r) {
        if (r.isSuccess && r.data != null) {
          _dailySummary = r.data;
        }
      }).catchError((_) {}),
      // AI 建议
      api.getAiAdvice(_petId).then((r) {
        if (r.isSuccess && r.data != null) {
          final data = r.data!;
          final aiEnhanced = (data['ai_enhanced'] as String?)?.trim();
          final generalAdvice =
              (data['general_advice'] as List<dynamic>?)?.join('\n') ?? '';
          final nutritionTips =
              (data['nutrition_tips'] as List<dynamic>?)?.join('\n') ?? '';
          final disclaimer = data['disclaimer'] as String? ?? '';
          final parts = <String>[];
          if (aiEnhanced != null && aiEnhanced.isNotEmpty) {
            parts.add(aiEnhanced);
          }
          if (generalAdvice.isNotEmpty) parts.add(generalAdvice);
          if (nutritionTips.isNotEmpty) parts.add(nutritionTips);
          _aiAdvice = parts.join('\n\n');
          _aiDisclaimer = disclaimer;
        }
      }).catchError((_) {}),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final speciesIcon = getSpeciesIcon(pet['species'] as String?);
    final speciesLabel = getSpeciesLabel(pet['species'] as String?);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: (_activeTabIndex == 2 || _activeTabIndex == 3)
          ? FloatingActionButton(
              onPressed: _activeTabIndex == 2
                  ? _showAddFeedingModal
                  : _showAddWaterModal,
              backgroundColor: AppColors.primary,
              child: Icon(
                _activeTabIndex == 2 ? LucideIcons.plus : LucideIcons.droplets,
                color: Colors.white,
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 头部区域
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.messageCircle,
                          color: Colors.white),
                      onPressed: () => _startPetChat(),
                      tooltip: 'AI宠物咨询',
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.edit3, color: Colors.white),
                      onPressed: () => _showEditDialog(),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // 宠物头像
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                speciesIcon,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // 宠物名称
                            Text(
                              pet['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // 品种标签
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                pet['breed'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Tab栏
                SliverPersistentHeader(
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textTertiary,
                      indicatorColor: AppColors.primary,
                      labelStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      tabs: const [
                        Tab(text: '档案'),
                        Tab(text: '体重'),
                        Tab(text: '饮食'),
                        Tab(text: '饮水'),
                        Tab(text: '疫苗'),
                        Tab(text: '驱虫'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),

                // Tab内容
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(),
                      _buildWeightTab(),
                      _buildDietTab(),
                      _buildWaterTab(),
                      _buildVaccineTab(),
                      _buildDewormingTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// 档案Tab
  Widget _buildProfileTab() {
    final pet = widget.pet;
    final speciesIcon = getSpeciesIcon(pet['species'] as String?);
    final speciesLabel = getSpeciesLabel(pet['species'] as String?);

    // 仅使用本页状态，不依赖 petProvider（真实宠物形象与虚拟桌宠独立）
    final hasEmotions = _emotionUrls.isNotEmpty;
    final rawUrl = pet['avatar_url'] as String?;
    final displayImageUrl =
        (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 宠物形象展示
          Center(
            child: Column(
              children: [
                PetAvatarDisplay(
                  emotion: _selectedEmotion,
                  size: 100,
                  breed: pet['breed'] as String?,
                  species: pet['species'] as String?,
                  customImageUrl: displayImageUrl,
                  emotionUrls: hasEmotions ? _emotionUrls : null,
                ),
                // 情绪变体选择器（仅在已生成形象时显示）
                if (hasEmotions) ...[
                  const SizedBox(height: 12),
                  EmotionSelector(
                    selectedEmotion: _selectedEmotion,
                    onEmotionSelected: (emotion) {
                      setState(() => _selectedEmotion = emotion);
                    },
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _navigateToGenerateAvatar(),
                  icon: const Icon(LucideIcons.wand2, size: 16),
                  label: const Text('生成专属形象'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          // 基本信息卡片
          _buildSectionCard(
            title: '基本信息',
            icon: LucideIcons.user,
            children: [
              _buildInfoRow('物种', getSpeciesLabel(pet['species'] as String?),
                  speciesIcon),
              _buildInfoRow('品种', pet['breed'] ?? '-', LucideIcons.tag),
              _buildInfoRow('年龄', () {
                final age = pet['age'];
                return age != null ? '$age' : '-';
              }(), LucideIcons.calendar),
              _buildInfoRow(
                  '性别', pet['gender'] == 'male' ? '公' : '母', Icons.male),
              _buildInfoRow('体重', () {
                // 优先从本地体重记录获取最新体重
                if (_weightRecords.isNotEmpty) {
                  final latest = _weightRecords.first;
                  final w = latest['weight'];
                  if (w != null) return '${w} kg';
                }
                final w = pet['weight'];
                return w != null ? '$w kg' : '-';
              }(), LucideIcons.scale),
            ],
          ),
          const SizedBox(height: 16),

          // 营养目标卡片
          _buildSectionCard(
            title: '每日营养目标',
            icon: LucideIcons.target,
            children: [
              _buildNutritionRow(
                  '热量', '${_nutritionTargets?['daily_calories'] ?? '-'} kcal'),
              _buildNutritionRow(
                  '蛋白质', '${_nutritionTargets?['daily_protein'] ?? '-'}g'),
              _buildNutritionRow(
                  '脂肪', '${_nutritionTargets?['daily_fat'] ?? '-'}g'),
            ],
          ),
          const SizedBox(height: 16),

          // 健康评分
          if (_healthScore != null)
            _buildSectionCard(
              title: '健康评分',
              icon: LucideIcons.heartPulse,
              children: [
                _buildNutritionRow(
                    '综合评分', '${_healthScore!['total_score'] ?? '-'} / 100'),
                if (_healthScore!['diet_score'] != null)
                  _buildNutritionRow('饮食', '${_healthScore!['diet_score']}'),
                if (_healthScore!['weight_score'] != null)
                  _buildNutritionRow('体重', '${_healthScore!['weight_score']}'),
              ],
            ),
          if (_healthScore != null) const SizedBox(height: 16),

          // AI建议卡片
          _buildAiAdviceCard(),
        ],
      ),
    );
  }

  /// 体重Tab
  Widget _buildWeightTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 添加体重按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddWeightModal(),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('记录体重'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 体重趋势图
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.lightShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.trendingUp,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('体重趋势',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                PetWeightChart(records: _weightRecords),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 体重记录列表
          const Text(
            '历史记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._weightRecords.map((record) => _buildWeightRecordItem(record)),
        ],
      ),
    );
  }

  /// 饮食Tab
  Widget _buildDietTab() {
    // 过滤出今天的记录
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayRecords = _feedingRecords.where((r) {
      final recordTime = r['time'] as String?;
      return recordTime != null && recordTime.startsWith(today);
    }).toList();

    final totalCalories = todayRecords.fold<int>(
        0, (sum, r) => sum + ((r['calories'] as num?)?.toInt() ?? 0));
    final targetCalories = _dailySummary?['target_calories'] as int? ?? 250;
    final ratio =
        targetCalories > 0 ? (totalCalories / targetCalories * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 今日摄入概览
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  '今日摄入',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalCalories kcal',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '目标 $targetCalories kcal',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '达标 $ratio%',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 今日饮食记录
          const Text(
            '今日饮食',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...todayRecords.asMap().entries.map(
                (entry) => Dismissible(
                  key: ValueKey('feed_${entry.key}_${entry.value['time']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.trash2, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('删除「${entry.value['food']}」的饮食记录？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.error),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                    return confirmed ?? false;
                  },
                  onDismissed: (_) {
                    setState(() {
                      _feedingRecords.removeAt(entry.key);
                    });
                  },
                  child: _buildFeedingRecordItem(entry.value, entry.key),
                ),
              ),
          const SizedBox(height: 16),

          // 快捷入口
          _buildQuickLink(
            icon: LucideIcons.clipboardList,
            title: '完整饮食报告',
            subtitle: '查看营养摄入详情与AI建议',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PetFeedingPage(pet: widget.pet)),
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickLink(
            icon: LucideIcons.bookOpen,
            title: '宠物食品库',
            subtitle: '浏览常见宠物食品营养数据',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PetFoodLibraryPage()),
            ),
          ),
          const SizedBox(height: 8),
          _buildQuickLink(
            icon: LucideIcons.barChart3,
            title: '饮食周报',
            subtitle: '近7天热量摄入趋势分析',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PetWeeklyReportPage(pet: widget.pet)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 辅助组件 ====================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary)),
          ),
          Text(value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(value,
              style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildAiAdviceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('AI健康建议',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _aiAdvice ?? '加载中...',
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.info,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _aiDisclaimer ?? 'AI建议仅供参考，宠物健康问题请咨询专业兽医。',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightRecordItem(Map<String, dynamic> record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.scale,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record['weight'] ?? '-'} kg',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  (record['measured_at'] as String?) ?? '-',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (record['notes'] != null && record['notes'].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                record['notes'],
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedingRecordItem(Map<String, dynamic> record, [int? index]) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.caloriesColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.utensils,
                color: AppColors.caloriesColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['food'],
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${record['amount_g']}g · ${record['time']}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record['calories']} kcal',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.caloriesColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record['source'],
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ==================== 操作方法 ====================

  void _showAddWeightModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddWeightModal(
        petId: _petId,
        onSaved: () {
          Navigator.pop(context);
          _loadAllData();
        },
      ),
    );
  }

  void _showEditDialog() async {
    final result = await showDialog(
      context: context,
      builder: (_) => EditPetDialog(pet: widget.pet),
    );

    if (!mounted) return;

    if (result == 'deleted') {
      Navigator.pop(context, 'deleted');
    } else if (result is Map) {
      // 重新从后端获取最新数据，确保年龄和体重正确
      try {
        final api = RealPetApiService();
        final res = await api.getPet(_petId);
        if (res.isSuccess && res.data != null) {
          setState(() {
            widget.pet.addAll(res.data!);
          });
        }
        // 同步刷新体重记录，确保档案页体重显示最新值
        final weightRes = await api.getWeightRecords(_petId);
        if (weightRes.isSuccess && weightRes.data != null) {
          final records = (weightRes.data!['records'] as List<dynamic>?) ?? [];
          setState(() {
            _weightRecords = records
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      } catch (_) {
        // 兜底：用编辑返回的数据
        setState(() {
          widget.pet.addAll(result.cast<String, dynamic>());
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('信息已更新'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  /// 启动宠物 AI 对话
  void _startPetChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          sessionType: 6,
          petId: _petId,
          title: '${widget.pet['name']} - 健康咨询',
        ),
      ),
    );
  }

  /// 添加饮食记录
  void _showAddFeedingModal() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddFeedingRecordModal(petId: _petId),
    );

    if (result == null || !mounted) return;

    setState(() {
      _feedingRecords.add(Map<String, dynamic>.from(result as Map));
    });
  }

  /// 添加饮水记录
  void _showAddWaterModal() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PetWaterModal(petId: _petId),
    );

    if (result != null && mounted) {
      _loadAllData();
    }
  }

  /// 饮水推荐量（根据品种/体重动态计算）
  Widget _buildWaterRecommendation() {
    // 获取最新体重
    double? latestWeight;
    if (_weightRecords.isNotEmpty) {
      latestWeight = (_weightRecords.first['weight'] as num?)?.toDouble();
    }

    final species = widget.pet['species'] as String? ?? 'cat';
    // 粗略估算每公斤饮水量：狗60ml，猫50ml，其他55ml
    final mlPerKg = species == 'dog' ? 60.0 : (species == 'cat' ? 50.0 : 55.0);
    final recommended =
        latestWeight != null ? (latestWeight * mlPerKg).round() : 150;

    // 计算今日饮水量
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayRecords = _waterRecords.where((r) {
      final recordTime = r['record_time'] as String?;
      return recordTime != null && recordTime.startsWith(today);
    }).toList();

    final totalMl = todayRecords.fold<double>(0, (sum, r) {
      return sum + ((r['amount_ml'] as num?)?.toDouble() ?? 0);
    });

    final progress = (totalMl / recommended).clamp(0.0, 1.0);
    final isGoalReached = totalMl >= recommended;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGoalReached
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
              : [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isGoalReached ? AppColors.success : const Color(0xFF29B6F6))
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 标题行
          Row(
            children: [
              const Icon(LucideIcons.droplets, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text('今日饮水',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.target,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 3),
                    Text('${recommended}ml',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 进度环
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 进度环背景
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // 中心内容
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        totalMl >= 1000
                            ? '${(totalMl / 1000).toStringAsFixed(1)}'
                            : '${totalMl.round()}',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    Text(totalMl >= 1000 ? '升' : 'ml',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 4),
                    Text(
                      isGoalReached
                          ? '✅ 已达标'
                          : '还差 ${recommended - totalMl.round()}ml',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 快捷添加按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildQuickWaterButton('50ml', 50),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickWaterButton('100ml', 100),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCustomWaterButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 快捷添加饮水按钮
  Widget _buildQuickWaterButton(String label, int amountMl) {
    return GestureDetector(
      onTap: () => _quickAddWater(amountMl: amountMl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.plus, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 自定义添加饮水按钮
  Widget _buildCustomWaterButton() {
    return GestureDetector(
      onTap: _showAddWaterModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.slidersHorizontal, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('自定义',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 快捷添加饮水
  Future<void> _quickAddWater({required int amountMl}) async {
    final api = RealPetApiService();
    final now = DateTime.now();
    final result = await api.addWater(_petId, {
      'amount_ml': amountMl,
      'record_time': now.toIso8601String(),
      'from_source': '手动',
    });

    if (result.isSuccess) {
      // 重新加载数据
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已添加 ${amountMl}ml 饮水'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: ${result.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 饮水Tab
  Widget _buildWaterTab() {
    // 计算今日饮水量
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayRecords = _waterRecords.where((r) {
      final recordTime = r['record_time'] as String?;
      return recordTime != null && recordTime.startsWith(today);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 推荐量（根据品种/体重动态计算）
          _buildWaterRecommendation(),

          const SizedBox(height: 16),

          // 今日饮水记录列表
          if (todayRecords.isNotEmpty)
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.history,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        const Text('今日记录',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        if (todayRecords.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _undoLastWaterRecord(),
                            icon: const Icon(LucideIcons.undo2, size: 14),
                            label: const Text('撤回'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textTertiary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...todayRecords.map((record) {
                    return _buildWaterRecordItem(record);
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 饮水记录项
  Widget _buildWaterRecordItem(Map<String, dynamic> record) {
    final amountMl = (record['amount_ml'] as num?)?.toInt() ?? 0;
    final recordTime = record['record_time'] as String?;
    final source = record['from_source'] as String? ?? '手动';

    String timeText = '';
    if (recordTime != null) {
      try {
        final dt = DateTime.parse(recordTime);
        timeText =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.droplet,
                color: AppColors.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$amountMl ml',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (source.isNotEmpty)
                  Text(source,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Text(timeText,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(LucideIcons.trash2,
                size: 16, color: AppColors.error),
            onPressed: () => _deleteWaterRecord(record['id']),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '删除',
          ),
        ],
      ),
    );
  }

  /// 撤回最后一条饮水记录
  Future<void> _undoLastWaterRecord() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayRecords = _waterRecords.where((r) {
      final recordTime = r['record_time'] as String?;
      return recordTime != null && recordTime.startsWith(today);
    }).toList();

    if (todayRecords.isEmpty) return;

    final lastRecord = todayRecords.first;
    final recordId = lastRecord['id'];

    // 删除记录
    final api = RealPetApiService();
    final result = await api.deleteWaterRecord(_petId, recordId);

    if (result.isSuccess) {
      await _loadAllData();
      if (mounted) {
        final amountMl = (lastRecord['amount_ml'] as num?)?.toInt() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已撤回 ${amountMl}ml 饮水记录'),
            backgroundColor: AppColors.info,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('撤回失败: ${result.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 删除单条饮水记录
  Future<void> _deleteWaterRecord(int recordId) async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条饮水记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final api = RealPetApiService();
    final result = await api.deleteWaterRecord(_petId, recordId);

    if (result.isSuccess) {
      // 本地移除记录，避免 _loadAllData() 导致的 loading 状态问题
      setState(() {
        _waterRecords.removeWhere((r) => r['id'] == recordId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('饮水记录已删除'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: ${result.message}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 跳转到形象生成页
  void _navigateToGenerateAvatar() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeneratePetAvatarPage(
          petId: (widget.pet['id'] as num?)?.toInt() ?? 0,
          petName: widget.pet['name'] as String? ?? '未命名',
          species: widget.pet['species'] as String? ?? '猫',
        ),
      ),
    );

    // 处理返回的生成结果
    if (result != null && result is Map<String, dynamic>) {
      final imageUrl = result['image_url'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // 显示加载提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在应用专属形象...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // 更新宠物档案的 avatar_url
        final api = RealPetApiService();
        final updateResult = await api.updatePet(_petId, {
          'avatar_url': imageUrl,
        });

        if (updateResult.isSuccess) {
          // 刷新数据
          await _loadAllData();

          // 保存情绪变体到本地状态（仅用于本页展示，不影响桌宠）
          final emotions = (result['emotions'] as Map<String, dynamic>?)
                  ?.map((k, v) => MapEntry(k, v.toString())) ??
              {};
          setState(() {
            _emotionUrls = emotions;
          });

          // 显示成功提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('专属形象已应用'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          // 显示失败提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('应用形象失败: ${updateResult.message}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        // image_url 为空
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('生成的形象无效'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  /// 疫苗Tab
  Widget _buildVaccineTab() {
    final vaccines = _vaccineRecords;

    // 构建疫苗提醒列表
    final vaccineReminders = <Map<String, dynamic>>[];
    for (final v in vaccines) {
      final nextDate = v['next_vaccination_date'] as String?;
      if (nextDate != null && nextDate.isNotEmpty) {
        final next = DateTime.tryParse(nextDate);
        if (next != null) {
          final daysLeft = next.difference(DateTime.now()).inDays;
          String nextLabel;
          String icon;
          if (daysLeft < 0) {
            icon = '🔴';
            nextLabel = '已过期 ${(-daysLeft)} 天';
          } else if (daysLeft <= 7) {
            icon = '🟡';
            nextLabel = '还有 $daysLeft 天';
          } else {
            icon = '🟢';
            nextLabel = '${nextDate.split('-')[1]}月${nextDate.split('-')[2]}日';
          }
          vaccineReminders.add({
            'title': '${v['vaccine_name']}',
            'next': '下次: $nextLabel',
            'icon': icon,
            'id': v['id'],
          });
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 + 添加按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('疫苗记录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => _showVaccineDialog(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (vaccines.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('暂无疫苗记录，点击「添加」录入',
                    style: TextStyle(color: AppColors.textTertiary)),
              ),
            )
          else
            ...vaccines.map((v) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                        child: Text('💉', style: TextStyle(fontSize: 20))),
                  ),
                  title: Text(
                    v['vaccine_name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '接种: ${v['vaccinated_at'] ?? '-'}${v['next_vaccination_date'] != null ? '  ·  下次: ${v['next_vaccination_date']}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _showVaccineDialog(existing: v);
                      if (action == 'delete') _deleteVaccine(v);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          // 健康提醒（疫苗 + 驱虫）
          if (vaccineReminders.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.bellRing,
                          color: AppColors.warning, size: 18),
                      SizedBox(width: 8),
                      Text('健康提醒',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...vaccineReminders.map((r) => _buildReminderItem(r)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(reminder['icon'] as String? ?? '🐾',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder['title'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '下次: ${reminder['next']}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '待执行',
              style: TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// 添加/编辑疫苗弹窗
  Future<void> _showVaccineDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?['vaccine_name'] as String? ?? '');
    final notesCtrl =
        TextEditingController(text: existing?['notes'] as String? ?? '');
    DateTime? vaccinatedAt = existing?['vaccinated_at'] != null
        ? DateTime.tryParse(existing!['vaccinated_at'] as String)
        : DateTime.now();
    DateTime? nextDate = existing?['next_vaccination_date'] != null
        ? DateTime.tryParse(existing!['next_vaccination_date'] as String)
        : null;
    final isEdit = existing != null;
    final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(isEdit ? '编辑疫苗记录' : '添加疫苗记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '疫苗名称', hintText: '如：猫三联、狂犬疫苗'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('接种日期'),
                  subtitle: Text(vaccinatedAt != null
                      ? '${vaccinatedAt!.year}-${vaccinatedAt!.month.toString().padLeft(2, '0')}-${vaccinatedAt!.day.toString().padLeft(2, '0')}'
                      : '请选择'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: vaccinatedAt ?? DateTime.now(),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDState(() => vaccinatedAt = picked);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('下次接种日期（可选）'),
                  subtitle: Text(nextDate != null
                      ? '${nextDate!.year}-${nextDate!.month.toString().padLeft(2, '0')}-${nextDate!.day.toString().padLeft(2, '0')}'
                      : '未设置'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nextDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setDState(() => nextDate = null),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setDState(() => nextDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: '备注（可选）', hintText: '如：接种医院、品牌等'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                if (vaccinatedAt == null) return;
                final api = RealPetApiService();
                final data = <String, dynamic>{
                  'vaccine_name': nameCtrl.text.trim(),
                  'vaccinated_at':
                      '${vaccinatedAt!.year}-${vaccinatedAt!.month.toString().padLeft(2, '0')}-${vaccinatedAt!.day.toString().padLeft(2, '0')}',
                  'next_vaccination_date': nextDate != null
                      ? '${nextDate!.year}-${nextDate!.month.toString().padLeft(2, '0')}-${nextDate!.day.toString().padLeft(2, '0')}'
                      : null,
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                };
                ApiResponse<Map<String, dynamic>> resp;
                if (isEdit) {
                  resp = await api.updateVaccine(
                      petId, existing['id'] as int, data);
                } else {
                  resp = await api.addVaccine(petId, data);
                }
                if (mounted && resp.isSuccess) {
                  await _loadAllData();
                  if (!mounted) return;
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除疫苗记录
  Future<void> _deleteVaccine(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${record['vaccine_name']}」的记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
      final recordId = record['id'] as int;
      final api = RealPetApiService();
      final resp = await api.deleteVaccine(petId, recordId);
      if (mounted && resp.isSuccess) {
        await _loadAllData();
      }
    }
  }

  /// 驱虫Tab
  Widget _buildDewormingTab() {
    final records = _dewormingRecords;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('驱虫记录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => _showDewormingDialog(),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('暂无驱虫记录，点击「添加」录入',
                    style: TextStyle(color: AppColors.textTertiary)),
              ),
            )
          else
            ...records.map((d) {
              final type = d['deworming_type'] as String? ?? '';
              final typeLabel = type == 'internal'
                  ? '体内驱虫'
                  : type == 'external'
                      ? '体外驱虫'
                      : type;
              final icon = type == 'internal' ? '💊' : '🧴';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                        child:
                            Text(icon, style: const TextStyle(fontSize: 20))),
                  ),
                  title: Text(typeLabel,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '日期: ${d['treated_at'] ?? '-'}${d['next_treatment_date'] != null ? '  ·  下次: ${d['next_treatment_date']}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _showDewormingDialog(existing: d);
                      if (action == 'delete') _deleteDeworming(d);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showDewormingDialog({Map<String, dynamic>? existing}) async {
    final types = ['internal', 'external'];
    final typeLabels = ['体内驱虫', '体外驱虫'];
    final isEdit = existing != null;
    final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
    String? selectedType;
    DateTime? treatedAt;
    DateTime? nextDate;
    final notesCtrl = TextEditingController();

    if (existing != null) {
      selectedType = existing['deworming_type'] as String?;
      treatedAt = existing['treated_at'] != null
          ? DateTime.tryParse(existing['treated_at'] as String)
          : null;
      nextDate = existing['next_treatment_date'] != null
          ? DateTime.tryParse(existing['next_treatment_date'] as String)
          : null;
      notesCtrl.text = existing['notes'] as String? ?? '';
    }

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(isEdit ? '编辑驱虫记录' : '添加驱虫记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('驱虫类型',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(types.length, (i) {
                    final isSelected = selectedType == types[i];
                    return GestureDetector(
                      onTap: () => setDState(() => selectedType = types[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySurface
                              : AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(typeLabels[i],
                            style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('驱虫日期'),
                  subtitle: Text(treatedAt != null
                      ? '${treatedAt!.year}-${treatedAt!.month.toString().padLeft(2, '0')}-${treatedAt!.day.toString().padLeft(2, '0')}'
                      : '请选择'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: treatedAt ?? DateTime.now(),
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDState(() => treatedAt = picked);
                  },
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('下次驱虫日期（可选）'),
                  subtitle: Text(nextDate != null
                      ? '${nextDate!.year}-${nextDate!.month.toString().padLeft(2, '0')}-${nextDate!.day.toString().padLeft(2, '0')}'
                      : '未设置'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nextDate != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setDState(() => nextDate = null),
                        ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: nextDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (picked != null) setDState(() => nextDate = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedType == null) return;
                if (treatedAt == null) return;
                final api = RealPetApiService();
                final data = <String, dynamic>{
                  'deworming_type': selectedType!,
                  'treated_at':
                      '${treatedAt!.year}-${treatedAt!.month.toString().padLeft(2, '0')}-${treatedAt!.day.toString().padLeft(2, '0')}',
                  'next_treatment_date': nextDate != null
                      ? '${nextDate!.year}-${nextDate!.month.toString().padLeft(2, '0')}-${nextDate!.day.toString().padLeft(2, '0')}'
                      : null,
                  'notes': notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                };
                ApiResponse<Map<String, dynamic>> resp;
                if (isEdit) {
                  resp = await api.updateDeworming(
                      petId, existing!['id'] as int, data);
                } else {
                  resp = await api.addDeworming(petId, data);
                }
                if (mounted && resp.isSuccess) {
                  await _loadAllData();
                  if (!mounted) return;
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDeworming(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条驱虫记录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;
      final recordId = record['id'] as int;
      final api = RealPetApiService();
      final resp = await api.deleteDeworming(petId, recordId);
      if (mounted && resp.isSuccess) {
        await _loadAllData();
      }
    }
  }
}

/// 宠物饮水记录弹窗
class _PetWaterModal extends StatefulWidget {
  final int petId;
  const _PetWaterModal({required this.petId});

  @override
  State<_PetWaterModal> createState() => _PetWaterModalState();
}

class _PetWaterModalState extends State<_PetWaterModal> {
  final _amountController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入饮水量'), backgroundColor: AppColors.error),
      );
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请输入有效的饮水量'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    final api = RealPetApiService();
    final result = await api.addWater(widget.petId, {
      'amount_ml': amount.toInt(),
      'from_source': 'manual',
    });

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.isSuccess) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('记录饮水',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('水量（毫升）', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '如 100',
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      suffix: const Text('ml'),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('保存',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Tab栏委托
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
