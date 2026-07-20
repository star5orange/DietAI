import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/real_pet_api_service.dart';
import '../widgets/pet_nutrition_progress.dart';
import '../widgets/pet_ai_advice_card.dart';
import '../widgets/add_feeding_record_modal.dart';

/// 宠物饮食日报页面
/// 展示今日营养摄入、饮食记录、AI建议，支持手动添加记录
class PetFeedingPage extends StatefulWidget {
  final Map<String, dynamic> pet;

  const PetFeedingPage({super.key, required this.pet});

  @override
  State<PetFeedingPage> createState() => _PetFeedingPageState();
}

class _PetFeedingPageState extends State<PetFeedingPage> {
  final RealPetApiService _api = RealPetApiService();
  List<Map<String, dynamic>> _feedingRecords = [];
  bool _isLoading = true;
  int _targetCalories = 250;
  double _targetProtein = 22;
  double _targetFat = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final petId = (widget.pet['id'] as num?)?.toInt() ?? 0;

    // 并行加载喂食计划和今日记录
    final results = await Future.wait([
      _api.getFeedingPlan(petId),
      _api.getFeedingRecords(petId),
    ]);

    // 解析喂食计划
    final planRes = results[0];
    if (planRes.isSuccess && planRes.data != null) {
      _targetCalories =
          (planRes.data!['daily_calories'] as num?)?.round() ?? _targetCalories;
      _targetProtein = (planRes.data!['daily_protein'] as num?)?.toDouble() ??
          _targetProtein;
    }

    // 解析今日记录
    final recordsRes = results[1];
    final records = <Map<String, dynamic>>[];
    if (recordsRes.isSuccess && recordsRes.data != null) {
      final rawRecords = recordsRes.data!['records'] as List<dynamic>? ?? [];
      for (final r in rawRecords) {
        final m = Map<String, dynamic>.from(r as Map);
        m['food'] = (m['food_name'] as String?) ?? '';
        m['amount_g'] = ((m['amount_grams'] as num?)?.toDouble() ?? 0);
        m['calories'] = ((m['calories'] as num?)?.toDouble() ?? 0).round();
        m['protein'] = double.parse(
            ((m['protein'] as num?)?.toDouble() ?? 0).toStringAsFixed(1));
        m['fat'] = double.parse(
            ((m['fat'] as num?)?.toDouble() ?? 0).toStringAsFixed(1));
        final rt = m['record_time'] as String?;
        m['time'] = rt != null
            ? rt.substring(
                rt.length >= 16 ? 11 : 0, rt.length >= 16 ? 16 : rt.length)
            : '';
        m['source'] = (m['from_source'] as String?) ?? '手动';
        records.add(m);
      }
    }

    if (mounted) {
      setState(() {
        _feedingRecords = records;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalCalories = _feedingRecords.fold(
        0, (sum, r) => sum + ((r['calories'] as num?)?.toInt() ?? 0));
    final double totalProtein = _feedingRecords.fold(
        0.0, (sum, r) => sum + ((r['protein'] as num?)?.toDouble() ?? 0));
    final double totalFat = _feedingRecords.fold(
        0.0, (sum, r) => sum + ((r['fat'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.pet['name']} - 饮食日报',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendar,
                            color: AppColors.textTertiary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('yyyy年MM月dd日').format(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 营养进度环
                  PetNutritionProgress(
                    currentCalories: totalCalories,
                    targetCalories: _targetCalories,
                    currentProtein: totalProtein,
                    targetProtein: _targetProtein,
                    currentFat: totalFat,
                    targetFat: _targetFat,
                  ),
                  const SizedBox(height: 16),

                  // 饮食记录列表
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
                        Row(
                          children: [
                            const Icon(LucideIcons.utensils,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              '饮食记录',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Text(
                              '${_feedingRecords.length}餐',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textTertiary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showAddRecordModal,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(LucideIcons.plus,
                                    color: AppColors.primary, size: 16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_feedingRecords.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            child: const Center(
                              child: Text('暂无记录，点击 + 添加',
                                  style:
                                      TextStyle(color: AppColors.textTertiary)),
                            ),
                          )
                        else
                          ..._feedingRecords
                              .map((record) => _buildFeedingRecordItem(record)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showAddRecordModal() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddFeedingRecordModal(
          petId: (widget.pet['id'] as num?)?.toInt() ?? 0),
    );

    if (result == null || !mounted) return;

    setState(() {
      _feedingRecords.add(Map<String, dynamic>.from(result as Map));
    });
  }

  Widget _buildFeedingRecordItem(Map<String, dynamic> record) {
    final source = record['source'] as String? ?? '手动';
    final sourceIcon = source == '硬件' ? LucideIcons.wifi : LucideIcons.pencil;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // 食物图标
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.caloriesColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.fish,
                color: AppColors.caloriesColor, size: 20),
          ),
          const SizedBox(width: 12),

          // 食物信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['food'],
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${record['amount_g']}g',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record['time'],
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                    const SizedBox(width: 8),
                    Icon(sourceIcon, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 2),
                    Text(
                      source,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 热量
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record['calories']} kcal',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.caloriesColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '蛋白 ${record['protein']}g',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '脂肪 ${record['fat']}g',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
