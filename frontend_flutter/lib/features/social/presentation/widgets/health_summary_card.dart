import 'package:flutter/material.dart';

/// 健康摘要卡片组件
/// 用于在家人/好友列表中显示简要健康状态
class HealthSummaryCard extends StatelessWidget {
  final double totalCalories;
  final double targetCalories;
  final int waterIntake;
  final int waterGoal;
  final String? petMood;
  final String? petName;

  const HealthSummaryCard({
    super.key,
    required this.totalCalories,
    required this.targetCalories,
    required this.waterIntake,
    required this.waterGoal,
    this.petMood,
    this.petName,
  });

  @override
  Widget build(BuildContext context) {
    final calorieProgress = targetCalories > 0
        ? (totalCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final waterProgress = waterGoal > 0
        ? (waterIntake / waterGoal).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 热量进度
          Row(
            children: [
              const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              const Text('热量', style: TextStyle(fontSize: 11)),
              const Spacer(),
              Text(
                '${totalCalories.toInt()} / ${targetCalories.toInt()} kcal',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: calorieProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          // 饮水进度
          Row(
            children: [
              const Icon(Icons.water_drop, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              const Text('饮水', style: TextStyle(fontSize: 11)),
              const Spacer(),
              Text(
                '${waterIntake}ml / ${waterGoal}ml',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: waterProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 4,
          ),
          // 宠物状态（可选）
          if (petMood != null && petName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pets, size: 14, color: Colors.purple),
                const SizedBox(width: 4),
                Text(
                  '$petName: ${_getMoodText(petMood!)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getMoodText(String mood) {
    switch (mood) {
      case 'happy':
        return '😊 开心';
      case 'normal':
        return '😐 正常';
      case 'hungry':
        return '😰 饥饿';
      case 'weak':
        return '😢 虚弱';
      default:
        return mood;
    }
  }
}
