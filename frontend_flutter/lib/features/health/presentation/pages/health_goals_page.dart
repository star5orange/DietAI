import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/health_goals_model.dart';
import '../providers/health_goals_provider.dart';
import '../widgets/health_goal_card.dart';
import '../widgets/create_goal_modal.dart';
import '../widgets/goal_progress_card.dart';

class HealthGoalsPage extends ConsumerStatefulWidget {
  const HealthGoalsPage({super.key});

  @override
  ConsumerState<HealthGoalsPage> createState() => _HealthGoalsPageState();
}

class _HealthGoalsPageState extends ConsumerState<HealthGoalsPage> {
  @override
  Widget build(BuildContext context) {
    final healthGoalsAsync = ref.watch(healthGoalsProvider);
    final activeGoalsAsync = ref.watch(activeHealthGoalsProvider);
    final hasGoals =
        healthGoalsAsync.whenOrNull(data: (goals) => goals.isNotEmpty) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '健康目标',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showCreateGoalModal(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(healthGoalsProvider.notifier).refresh(),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, hasGoals ? 96 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveGoalsOverview(activeGoalsAsync),
              const SizedBox(height: 24),
              _buildGoalsSection(healthGoalsAsync),
            ],
          ),
        ),
      ),
      floatingActionButton: hasGoals
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateGoalModal(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
              icon: const Icon(LucideIcons.target, size: 20),
              label: const Text(
                '新建目标',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildActiveGoalsOverview(
      AsyncValue<List<HealthGoal>> activeGoalsAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.target,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '活跃目标',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          activeGoalsAsync.when(
            data: (goals) {
              if (goals.isEmpty) {
                return const Text(
                  '暂无活跃目标，点击下方按钮创建新目标',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                );
              }
              return Column(
                children: goals
                    .take(2)
                    .map((goal) => GoalProgressCard(goal: goal))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            error: (error, _) => Text(
              '加载失败: $error',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalsSection(AsyncValue<List<HealthGoal>> healthGoalsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所有目标',
          style: AppTextStyles.h4.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        healthGoalsAsync.when(
          data: (goals) {
            if (goals.isEmpty) {
              return _buildEmptyState();
            }
            return Column(
              children: goals
                  .map((goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: HealthGoalCard(
                          goal: goal,
                          onEdit: () => _showEditGoalModal(goal),
                          onDelete: () => _showDeleteConfirmation(goal),
                        ),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              children: [
                const Icon(
                  LucideIcons.alertCircle,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败: $error',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.read(healthGoalsProvider.notifier).refresh(),
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.target,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '还没有健康目标',
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设定一个目标，开始您的健康之旅',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateGoalModal(),
            icon: const Icon(LucideIcons.plus),
            label: const Text('创建目标'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGoalModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalModal(
        onGoalCreated: () {
          ref.read(healthGoalsProvider.notifier).refresh();
        },
      ),
    );
  }

  void _showEditGoalModal(HealthGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalModal(
        existingGoal: goal,
        onGoalCreated: () {
          ref.read(healthGoalsProvider.notifier).refresh();
        },
      ),
    );
  }

  void _showDeleteConfirmation(HealthGoal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除目标"${goal.goalTypeText}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(healthGoalsProvider.notifier)
                  .deleteHealthGoal(goal.id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor:
                        result.success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
