import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dietRecommendationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}的饮食建议'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(DietRecommendationState state) {
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

    if (state.recommendations.isEmpty) {
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
        await ref
            .read(dietRecommendationProvider.notifier)
            .loadRecommendations(widget.userId);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.recommendations.length,
        itemBuilder: (context, index) {
          final recommendation = state.recommendations[index];
          return _buildRecommendationCard(recommendation);
        },
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
