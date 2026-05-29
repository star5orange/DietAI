import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../health/presentation/pages/health_goals_page.dart';
import '../../../health/presentation/pages/weight_tracking_page.dart';
import '../../../health/presentation/pages/reminder_settings_page.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_edit_sheet.dart';
import '../widgets/health_goals_sheet.dart';
import '../widgets/weight_records_sheet.dart';
import '../widgets/health_info_sheet.dart';
import 'help_center_page.dart';
import 'about_us_page.dart';
import '../../../../core/services/api_service.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _streakDays = 0;
  int _totalRecords = 0;
  int _avgCalories = 0;
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadUserProfile();
      _loadUserStats();
    });
  }

  Future<void> _loadUserStats() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/stats');
      if (response.success && response.data != null) {
        setState(() {
          _streakDays = response.data['streak_days'] ?? 0;
          _totalRecords = response.data['total_records'] ?? 0;
          _avgCalories = response.data['avg_calories'] ?? 0;
          _statsLoaded = true;
        });
      }
    } catch (e) {
      // 静默失败，保持默认值
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {
              // TODO: 设置页面
            },
          ),
        ],
      ),
      body: userProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertCircle,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('加载失败: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(userProfileProvider.notifier).loadUserProfile(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (userProfile) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // 用户信息卡片
              _buildUserInfoCard(currentUser, userProfile),
              const SizedBox(height: 24),

              // 统计信息
              _buildStatsRow(userProfile),
              const SizedBox(height: 24),

              // 功能列表
              _buildFunctionList(),
              const SizedBox(height: 24),

              // 退出登录按钮
              _buildLogoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(User? currentUser, UserProfile? userProfile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardBackground, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 头像
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: currentUser?.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      currentUser!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          LucideIcons.user,
                          size: 40,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  )
                : const Icon(
                    LucideIcons.user,
                    size: 40,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(height: 16),

          // 昵称优先显示
          Text(
            userProfile?.realName ?? currentUser?.username ?? '用户',
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // 查看详细信息按钮
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                _showDetailedInfo(currentUser, userProfile);
              },
              icon: const Icon(LucideIcons.info, size: 18),
              label: const Text(
                '查看详细信息',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide.none,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(UserProfile userProfile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (userProfile.gender != null || userProfile.birthDate != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (userProfile.gender != null)
                _buildInfoItem('性别', userProfile.genderText),
              if (userProfile.birthDate != null)
                _buildInfoItem('生日', userProfile.birthDate!.split('T')[0]),
            ],
          ),
        if (userProfile.height != null || userProfile.weight != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (userProfile.height != null)
                _buildInfoItem('身高', '${userProfile.height}cm'),
              if (userProfile.weight != null)
                _buildInfoItem('体重', '${userProfile.weight}kg'),
            ],
          ),
        ],
        if (userProfile.bmi != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem('BMI', '${userProfile.bmi}'),
              _buildInfoItem('状态', userProfile.bmiStatus),
            ],
          ),
        ],
        if (userProfile.activityLevel != null) ...[
          const SizedBox(height: 8),
          _buildInfoItem('活动级别', userProfile.activityLevelText),
        ],
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(UserProfile? userProfile) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Flexible(
            child: _buildStatCard('连续打卡', '$_streakDays', '天', AppColors.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: _buildStatCard('总记录', '$_totalRecords', '次', AppColors.success),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: _buildStatCard('平均卡路里', '$_avgCalories', 'kcal', AppColors.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionList() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.cardBackground, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: LucideIcons.target,
            title: '健康目标',
            subtitle: '设置和管理您的健康目标',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HealthGoalsPage(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.scale,
            title: '体重记录',
            subtitle: '记录和查看体重变化',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeightTrackingPage(),
                ),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.heart,
            title: '健康信息',
            subtitle: '管理疾病和过敏信息',
            onTap: () {
              _showHealthInfoSheet();
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.bell,
            title: '提醒设置',
            subtitle: '设置用餐、饮水、运动等提醒',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ReminderSettingsPage()),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.lock,
            title: '修改密码',
            subtitle: '更新您的账户密码',
            onTap: () {
              context.push('/change-password');
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.barChart3,
            title: '数据统计',
            subtitle: '查看详细的营养分析',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据统计功能开发中，敬请期待')),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.download,
            title: '数据导出',
            subtitle: '导出您的饮食记录',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据导出功能开发中，敬请期待')),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.helpCircle,
            title: '帮助中心',
            subtitle: '常见问题和使用指南',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpCenterPage()),
              );
            },
          ),
          _buildMenuItem(
            icon: LucideIcons.info,
            title: '关于我们',
            subtitle: '了解DietAI',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsPage()),
              );
            },
            showDivider: false,
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutDialog();
        },
        icon: const Icon(LucideIcons.logOut, color: AppColors.error),
        label: const Text(
          '退出登录',
          style: TextStyle(color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTextStyles.h5.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.backgroundSecondary,
                  AppColors.backgroundSecondary.withValues(alpha: 0.5)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              LucideIcons.chevronRight,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: AppColors.divider.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  void _showEditProfileSheet(UserProfile? userProfile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileEditSheet(userProfile: userProfile),
    );
  }

  void _showHealthGoalsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HealthGoalsSheet(),
    );
  }

  void _showWeightRecordsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WeightRecordsSheet(),
    );
  }

  void _showHealthInfoSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HealthInfoSheet(),
    );
  }

  void _showDetailedInfo(User? currentUser, UserProfile? userProfile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // 标题
            const Text(
              '详细信息',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 24),

            // 详细信息内容
            if (currentUser?.username != null) ...[
              _buildDetailItem('用户名', '@${currentUser!.username}'),
              const SizedBox(height: 12),
            ],
            if (currentUser?.email != null) ...[
              _buildDetailItem('邮箱', currentUser!.email!),
              const SizedBox(height: 12),
            ],
            if (userProfile != null) ...[
              if (userProfile.gender != null) ...[
                _buildDetailItem('性别', userProfile.genderText),
                const SizedBox(height: 12),
              ],
              if (userProfile.birthDate != null) ...[
                _buildDetailItem('生日', userProfile.birthDate!.split('T')[0]),
                const SizedBox(height: 12),
              ],
              if (userProfile.height != null) ...[
                _buildDetailItem('身高', '${userProfile.height}cm'),
                const SizedBox(height: 12),
              ],
              if (userProfile.weight != null) ...[
                _buildDetailItem('体重', '${userProfile.weight}kg'),
                const SizedBox(height: 12),
              ],
              if (userProfile.bmi != null) ...[
                _buildDetailItem(
                    'BMI', '${userProfile.bmi} (${userProfile.bmiStatus})'),
                const SizedBox(height: 12),
              ],
              if (userProfile.activityLevel != null) ...[
                _buildDetailItem('活动级别', userProfile.activityLevelText),
                const SizedBox(height: 12),
              ],
            ],

            const SizedBox(height: 20),

            // 编辑按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditProfileSheet(userProfile);
                },
                icon: const Icon(LucideIcons.edit2, size: 18),
                label: const Text('编辑资料'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // 执行退出登录
              await ref.read(authStateProvider.notifier).logout();

              // 跳转到登录页
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}
