import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../social/presentation/providers/family_provider.dart';
import '../providers/diet_recommendation_provider.dart';

/// 饮食推荐页面
class DietRecommendationPage extends ConsumerStatefulWidget {
  final int userId;
  final String userName;

  const DietRecommendationPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<DietRecommendationPage> createState() =>
      _DietRecommendationPageState();
}

class _DietRecommendationPageState
    extends ConsumerState<DietRecommendationPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(dietRecommendationProvider.notifier)
          .loadRecommendations(widget.userId);
      // 家人饮食偏好共享：加载所有家人偏好用于配餐参考
      ref.read(familyDietPreferencesProvider.notifier).loadDietPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dietRecommendationProvider);
    final prefState = ref.watch(familyDietPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}的饮食建议'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(state, prefState),
    );
  }

  Widget _buildBody(
      DietRecommendationState state, FamilyDietPreferencesState prefState) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '加载失败: ${state.error}',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(dietRecommendationProvider.notifier)
                    .loadRecommendations(widget.userId);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.recommendations.isEmpty && prefState.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无饮食建议',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '基于体检数据和饮食偏好生成个性化建议',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref
              .read(dietRecommendationProvider.notifier)
              .loadRecommendations(widget.userId),
          ref
              .read(familyDietPreferencesProvider.notifier)
              .loadDietPreferences(),
        ]);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.recommendations.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 家人饮食偏好共享区块（配餐参考）
                if (prefState.members.isNotEmpty)
                  _buildFamilyPrefsSection(prefState),
                if (prefState.members.isNotEmpty) const SizedBox(height: 16),
              ],
            );
          }
          final recommendation = state.recommendations[index - 1];
          return _buildRecommendationCard(recommendation);
        },
      ),
    );
  }

  /// 家人饮食偏好共享区块：展示每位家人偏好的饮食与忌口
  Widget _buildFamilyPrefsSection(FamilyDietPreferencesState prefState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.group, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              '家人饮食偏好',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '配餐时参考全家人偏好与忌口',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 12),
        for (final member in prefState.members) ...[
          _buildMemberPrefCard(member),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildMemberPrefCard(FamilyDietPreference member) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person,
                    size: 18, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  member.displayName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (member.constitutionType?.isNotEmpty == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      member.constitutionType!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (member.dietaryPreferences.isNotEmpty) ...[
              Text('偏好饮食',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.dietaryPreferences.map((pref) {
                  return Chip(
                    avatar: const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    label: Text(pref),
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (member.foodDislikes.isNotEmpty) ...[
              Text('忌口食物',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700])),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: member.foodDislikes.map((food) {
                  return Chip(
                    avatar: const Icon(Icons.cancel,
                        size: 16, color: Colors.red),
                    label: Text(food),
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
            if (member.dietaryPreferences.isEmpty &&
                member.foodDislikes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '未设置饮食偏好',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> recommendation) {
    final type = recommendation['type'] ?? 'general';
    final advice = recommendation['advice'] ?? '';
    final foods = List<String>.from(recommendation['recommended_foods'] ?? []);
    final avoidFoods = List<String>.from(recommendation['avoid_foods'] ?? []);

    IconData icon;
    Color color;
    String title;
    switch (type) {
      case 'blood_sugar':
        icon = Icons.bloodtype;
        color = Colors.red;
        title = '血糖控制建议';
        break;
      case 'blood_pressure':
        icon = Icons.favorite;
        color = Colors.pink;
        title = '血压管理建议';
        break;
      case 'cholesterol':
        icon = Icons.science;
        color = Colors.purple;
        title = '胆固醇控制建议';
        break;
      case 'uric_acid':
        icon = Icons.science_outlined;
        color = Colors.teal;
        title = '尿酸控制建议';
        break;
      case 'weight':
        icon = Icons.fitness_center;
        color = Colors.orange;
        title = '体重管理建议';
        break;
      default:
        icon = Icons.restaurant_menu;
        color = AppColors.primary;
        title = '通用饮食建议';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 建议描述
            if (advice.isNotEmpty) ...[
              Text(
                advice,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],

            // 推荐食物
            if (foods.isNotEmpty) ...[
              const Text(
                '推荐食物',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: foods.map((food) {
                  return Chip(
                    avatar: const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                    label: Text(food),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // 避免食物
            if (avoidFoods.isNotEmpty) ...[
              const Text(
                '建议避免',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: avoidFoods.map((food) {
                  return Chip(
                    avatar:
                        const Icon(Icons.cancel, size: 16, color: Colors.red),
                    label: Text(food),
                    backgroundColor: Colors.red.withOpacity(0.1),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
