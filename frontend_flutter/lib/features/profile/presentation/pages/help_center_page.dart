import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('帮助中心'),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('快速入门'),
          const SizedBox(height: 8),
          _buildFAQItem(
            icon: LucideIcons.camera,
            question: '如何记录饮食？',
            answer: '点击首页的"拍照识别"按钮，拍摄食物照片即可自动识别食物和热量。您也可以手动搜索食物并添加记录。',
          ),
          _buildFAQItem(
            icon: LucideIcons.scale,
            question: '如何记录体重？',
            answer: '进入"健康"页面，点击"体重追踪"模块，即可添加体重记录。系统会自动生成体重趋势图表。',
          ),
          _buildFAQItem(
            icon: LucideIcons.target,
            question: '如何设置健康目标？',
            answer: '在"健康"页面中点击"健康目标"，可以设置每日热量目标、体重目标等。系统会根据您的目标提供饮食建议。',
          ),
          _buildFAQItem(
            icon: LucideIcons.heart,
            question: '如何填写健康信息？',
            answer: '在"我的"页面中点击"健康信息"，可以添加疾病史、过敏信息等。这些信息将帮助AI为您提供更精准的饮食建议。',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('常见问题'),
          const SizedBox(height: 8),
          _buildFAQItem(
            icon: LucideIcons.image,
            question: '食物识别不准确怎么办？',
            answer: '如果AI识别结果不准确，您可以在识别结果页面手动修改食物名称和分量。也可以直接通过搜索功能手动添加食物。',
          ),
          _buildFAQItem(
            icon: LucideIcons.bell,
            question: '如何设置用餐提醒？',
            answer: '进入"我的"→"提醒设置"，可以开启早餐、午餐、晚餐的用餐提醒，以及饮水提醒和运动提醒。',
          ),
          _buildFAQItem(
            icon: LucideIcons.messageSquare,
            question: '如何与AI助手对话？',
            answer: '点击首页底部的"AI助手"标签，即可进入对话页面。您可以询问饮食建议、营养知识等问题。',
          ),
          _buildFAQItem(
            icon: LucideIcons.shield,
            question: '我的数据安全吗？',
            answer: '您的所有数据都经过加密存储，我们严格遵守隐私保护政策，不会将您的个人信息分享给第三方。',
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('功能说明'),
          const SizedBox(height: 8),
          _buildFAQItem(
            icon: LucideIcons.utensils,
            question: '饮食记录支持哪些功能？',
            answer: '支持拍照识别、手动搜索添加、历史记录查看、每日营养摄入统计、热量追踪等功能。',
          ),
          _buildFAQItem(
            icon: LucideIcons.droplets,
            question: '饮水提醒如何使用？',
            answer: '在提醒设置中开启饮水提醒后，系统会按照设定的时间间隔提醒您喝水，并记录每日饮水量。',
          ),
          _buildFAQItem(
            icon: LucideIcons.activity,
            question: '运动记录功能说明？',
            answer: '您可以手动添加运动记录，包括运动类型、时长和消耗热量。系统会综合饮食和运动数据计算每日热量平衡。',
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.headphones, size: 32, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  '还有其他问题？',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '通过AI助手随时向我们提问',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTextStyles.headlineSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required IconData icon,
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        title: Text(
          question,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            answer,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
