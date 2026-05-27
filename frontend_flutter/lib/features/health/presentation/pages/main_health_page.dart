import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../health/presentation/pages/health_goals_page.dart';
import '../../../health/presentation/pages/weight_tracking_page.dart';
import '../../../health/presentation/pages/data_visualization_page.dart';
import '../../../health/presentation/pages/health_analysis_page.dart';
import '../../../health/presentation/pages/exercise_record_page.dart';
import '../../../health/presentation/pages/reminder_settings_page.dart';
import '../../../health/presentation/pages/constitution_quiz_page.dart';
import '../../../../shared/presentation/widgets/water_intake_widget.dart';

class HealthPage extends StatelessWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('健康'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 快速健康指标卡片
            _buildHealthSummaryCard(),

            const SizedBox(height: 24),

            const WaterIntakeWidget(),

            const SizedBox(height: 24),

            _buildFeatureGrid(context),

            const SizedBox(height: 24),

            // 健康建议卡片
            _buildHealthTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
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
              Icon(
                LucideIcons.heart,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                '今日健康概览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '卡路里',
                  '1,245 / 2,000',
                  'kcal',
                  0.62,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '步数',
                  '6,842',
                  '步',
                  0.68,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  '水分',
                  '1.2 / 2.0',
                  'L',
                  0.6,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  '睡眠',
                  '7.5',
                  '小时',
                  0.94,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, String unit, double progress) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: LucideIcons.target,
        title: '健康目标',
        subtitle: '设置和追踪健康目标',
        color: AppColors.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HealthGoalsPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.scale,
        title: '体重管理',
        subtitle: '记录和追踪体重变化',
        color: AppColors.accent,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeightTrackingPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.barChart3,
        title: '数据分析',
        subtitle: '查看健康数据趋势',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const DataVisualizationPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.brain,
        title: 'AI健康分析',
        subtitle: '获取个性化健康建议',
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HealthAnalysisPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.dumbbell,
        title: '运动记录',
        subtitle: '记录运动消耗热量',
        color: const Color(0xFF06B6D4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ExerciseRecordPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.bell,
        title: '提醒设置',
        subtitle: '设置饮食健康提醒',
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReminderSettingsPage()),
        ),
      ),
      _FeatureItem(
        icon: LucideIcons.clipboardCheck,
        title: '体质自测',
        subtitle: '了解您的中医体质',
        color: const Color(0xFF10B981),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ConstitutionQuizPage()),
        ),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return _buildFeatureCard(feature);
      },
    );
  }

  Widget _buildFeatureCard(_FeatureItem feature) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  color: feature.color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature.title,
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  feature.subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
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
              Icon(
                LucideIcons.lightbulb,
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '今日健康小贴士',
                style: AppTextStyles.h6.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHealthTip(
            '💧 记得多喝水',
            '今天的饮水量还差800ml，保持充足的水分有助于新陈代谢。',
          ),
          const SizedBox(height: 12),
          _buildHealthTip(
            '🚶‍♀️ 增加运动量',
            '距离今日目标还差3,158步，不如饭后散个步吧！',
          ),
          const SizedBox(height: 12),
          _buildHealthTip(
            '🥗 营养均衡',
            '今天的蔬菜摄入量不足，建议晚餐增加绿叶蔬菜。',
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTip(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
