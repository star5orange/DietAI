import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../providers/family_provider.dart';

/// 家人健康详情页
class FamilyHealthPage extends ConsumerStatefulWidget {
  final int userId;
  final String? userName;

  const FamilyHealthPage({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  ConsumerState<FamilyHealthPage> createState() => _FamilyHealthPageState();
}

class _FamilyHealthPageState extends ConsumerState<FamilyHealthPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(memberHealthProvider.notifier).loadMemberHealth(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName ?? '家人健康'),
        actions: [
          IconButton(
            tooltip: '饮食推荐',
            icon: const Icon(Icons.restaurant_menu),
            onPressed: () => context.push(
              '/family/diet-recommendation/${widget.userId}',
              extra: {'name': widget.userName},
            ),
          ),
          IconButton(
            tooltip: '数据权限',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => context.push(
              '/social/permission/${widget.userId}',
              extra: {'name': widget.userName},
            ),
          ),
        ],
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, MemberHealthState state) {
    if (state.isLoading) {
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
              onPressed: () => ref
                  .read(memberHealthProvider.notifier)
                  .loadMemberHealth(widget.userId),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.dailyData.isEmpty &&
        state.weightData.isEmpty &&
        state.exerciseData.isEmpty &&
        state.goal == null) {
      return const Center(
        child: Text('暂无健康数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(memberHealthProvider.notifier)
          .loadMemberHealth(widget.userId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 健康目标完成情况
          _buildCard(
            title: '健康目标',
            icon: Icons.flag,
            color: AppColors.primary,
            child: state.goal != null
                ? _buildGoalCard(state.goal!)
                : _buildEmptyHint('暂未设置健康目标'),
          ),
          const SizedBox(height: 16),
          // 每日热量摄入/消耗卡片
          if (state.dailyData.isNotEmpty) ...[
            _buildCard(
              title: '每日热量摄入/消耗',
              icon: Icons.local_fire_department,
              color: Colors.orange,
              child: _buildCalorieChart(state.dailyData),
            ),
            const SizedBox(height: 16),
          ],
          // 宠物状态卡片
          if (state.pet != null) ...[
            _buildCard(
              title: '宠物状态',
              icon: Icons.pets,
              color: Colors.purple,
              child: _buildPetCard(state.pet!),
            ),
            const SizedBox(height: 16),
          ],
          // 7日饮水趋势卡片
          if (state.dailyData.isNotEmpty) ...[
            _buildCard(
              title: '7日饮水趋势',
              icon: Icons.water_drop,
              color: Colors.blue,
              child: _buildWaterChart(state.dailyData),
            ),
            const SizedBox(height: 16),
          ],
          // 体重变化卡片
          if (state.weightData.isNotEmpty) ...[
            _buildCard(
              title: '体重变化',
              icon: Icons.monitor_weight_outlined,
              color: Colors.teal,
              child: _buildWeightList(state.weightData),
            ),
            const SizedBox(height: 16),
          ],
          // 运动记录卡片
          if (state.exerciseData.isNotEmpty) ...[
            _buildCard(
              title: '运动记录',
              icon: Icons.directions_run,
              color: Colors.deepOrange,
              child: _buildExerciseList(state.exerciseData),
            ),
            const SizedBox(height: 16),
          ],
          // 代记录饮食按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '/family/proxy-record/${widget.userId}',
                extra: {'name': widget.userName ?? '家人'},
              ),
              icon: const Icon(Icons.restaurant_outlined, color: Colors.white),
              label: Text('帮${widget.userName ?? '家人'}记录饮食'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 代记录饮水按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _showProxyWaterDialog(context),
              icon: const Icon(Icons.water_drop_outlined, color: Colors.blue),
              label: Text('代${widget.userName ?? '家人'}记录饮水'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 代记录饮水弹窗
  Future<void> _showProxyWaterDialog(BuildContext context) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('为${widget.userName ?? '家人'}记录饮水'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '饮水量 (ml)',
            hintText: '例如：250',
            suffixText: 'ml',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入有效的饮水量')),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('确认', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );

    if (amount == null || !mounted) return;

    final api = ApiService();
    final response = await api.post(
      '/family/proxy-record/water',
      queryParameters: {
        'target_user_id': widget.userId,
        'amount_ml': amount,
      },
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(response.success
                ? '已为${widget.userName ?? '家人'}记录 ${amount}ml 饮水'
                : '记录失败: ${response.message}')),
      );
    }
  }

  /// 健康目标卡片
  Widget _buildGoalCard(HealthGoalData goal) {
    final progress = goal.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              goal.goalTypeName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (goal.targetWeight != null)
              Text(
                '目标 ${goal.targetWeight!.toStringAsFixed(1)}kg',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '起始 ${goal.startWeight?.toStringAsFixed(1) ?? '-'}kg',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Text(
              '当前 ${goal.latestWeight?.toStringAsFixed(1) ?? '-'}kg',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '完成 ${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: AppColors.primary),
          ),
        ],
      ],
    );
  }

  /// 体重变化列表
  Widget _buildWeightList(List<WeightHealthData> data) {
    return Column(
      children: data.reversed.map((w) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(
                _formatDate(w.date),
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Spacer(),
              Text(
                '${w.weight.toStringAsFixed(1)}kg',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (w.bodyFatPercentage != null) ...[
                const SizedBox(width: 12),
                Text(
                  '体脂 ${w.bodyFatPercentage!.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 运动记录列表
  Widget _buildExerciseList(List<ExerciseHealthData> data) {
    return Column(
      children: data.reversed.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.fitness_center,
                  size: 16, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.exerciseName,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '${e.durationMinutes}分钟',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Text(
                '${e.caloriesBurned.toStringAsFixed(0)}kcal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieChart(List<DailyHealthData> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxCalories = data
        .map((d) => d.calories > d.burned ? d.calories : d.burned)
        .reduce((a, b) => a > b ? a : b);
    final chartHeight = 120.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: chartHeight + 40,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final intakeHeight = maxCalories > 0
                  ? (d.calories / maxCalories) * chartHeight
                  : 0.0;
              final burnedHeight = maxCalories > 0
                  ? (d.burned / maxCalories) * chartHeight
                  : 0.0;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 10,
                          height: intakeHeight,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 3),
                        Container(
                          width: 10,
                          height: burnedHeight,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${d.calories.toInt()}/${d.burned.toInt()}',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      _formatDate(d.date),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            _LegendDot(color: AppColors.primary, label: '摄入'),
            SizedBox(width: 16),
            _LegendDot(color: Colors.orange, label: '消耗'),
          ],
        ),
      ],
    );
  }

  /// 空数据占位提示
  Widget _buildEmptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 宠物心情中文名
  String _moodName(String mood) {
    switch (mood) {
      case 'happy':
        return '开心';
      case 'hungry':
        return '饥饿';
      case 'weak':
        return '虚弱';
      default:
        return '正常';
    }
  }

  String _moodIcon(String mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'hungry':
        return '🍽️';
      case 'weak':
        return '😵';
      default:
        return '🐾';
    }
  }

  /// 宠物状态卡片内容
  Widget _buildPetCard(FamilyPetData pet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 虚拟桌宠
        Row(
          children: [
            Text(_moodIcon(pet.virtualPetMood),
                style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.virtualPetName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '心情：${_moodName(pet.virtualPetMood)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        // 真实宠物
        if (pet.realPets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...pet.realPets.map((p) {
            final speciesName = p.species == 'cat'
                ? '猫咪'
                : (p.species == 'dog' ? '狗狗' : p.species);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.pets, size: 16, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.name, style: const TextStyle(fontSize: 13)),
                  ),
                  Text(
                    speciesName,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            '未绑定真实宠物',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Widget _buildWaterChart(List<DailyHealthData> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final maxWater = data.map((d) => d.water).reduce((a, b) => a > b ? a : b);
    final chartHeight = 120.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          final height =
              maxWater > 0 ? (d.water / maxWater) * chartHeight : 0.0;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${d.water}ml',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  _formatDate(d.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.month}/${date.day}';
  }
}

/// 图表图例圆点
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
