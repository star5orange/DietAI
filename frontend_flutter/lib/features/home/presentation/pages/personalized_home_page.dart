import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../../profile/domain/services/user_service.dart';
import '../../../../services/health_analysis_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/user_model.dart';

class PersonalizedHomePage extends ConsumerStatefulWidget {
  const PersonalizedHomePage({super.key});

  @override
  ConsumerState<PersonalizedHomePage> createState() =>
      _PersonalizedHomePageState();
}

class _PersonalizedHomePageState extends ConsumerState<PersonalizedHomePage> {
  final UserService _userService = UserService(ApiService());
  final HealthAnalysisService _healthAnalysisService = HealthAnalysisService();

  UserProfile? _userProfile;
  List<Disease> _diseases = [];
  List<Allergy> _allergies = [];
  HealthScoreResult? _healthScore;
  bool _isLoading = false;
  String? _errorMessage;

  // 用户类型
  UserType _userType = UserType.general;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 并行加载用户数据
      final results = await Future.wait([
        _userService.getUserProfile(),
        _userService.getDiseases(),
        _userService.getAllergies(),
        _healthAnalysisService.getHealthScore(),
      ]);

      setState(() {
        final userProfileResponse = results[0] as ApiResponse<UserProfile>;
        final diseasesResponse = results[1] as ApiResponse<List<Disease>>;
        final allergiesResponse = results[2] as ApiResponse<List<Allergy>>;
        final healthScoreResponse =
            results[3] as ApiResponse<HealthScoreResult>;

        if (userProfileResponse.success && userProfileResponse.data != null) {
          _userProfile = userProfileResponse.data!;
        }
        if (diseasesResponse.success && diseasesResponse.data != null) {
          _diseases = diseasesResponse.data!;
        }
        if (allergiesResponse.success && allergiesResponse.data != null) {
          _allergies = allergiesResponse.data!;
        }
        if (healthScoreResponse.success && healthScoreResponse.data != null) {
          _healthScore = healthScoreResponse.data!;
        }

        // 根据用户数据判断用户类型
        _userType = _determineUserType();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载用户数据失败: $e';
        _isLoading = false;
      });
    }
  }

  UserType _determineUserType() {
    // 根据疾病信息判断用户类型
    if (_diseases.any((d) => d.isCurrent)) {
      return UserType.medical;
    }

    // 根据健康目标判断
    if (_userProfile?.healthGoals?.any((goal) =>
            goal.goalType == 'weight_loss' || goal.goalType == 'muscle_gain') ==
        true) {
      return UserType.fitness;
    }

    return UserType.general;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    // 根据用户类型显示不同的主页
    switch (_userType) {
      case UserType.medical:
        return _buildMedicalUserHome();
      case UserType.fitness:
        return _buildFitnessUserHome();
      case UserType.general:
      default:
        return _buildGeneralUserHome();
    }
  }

  Widget _buildMedicalUserHome() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康管理'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.medical_information),
            onPressed: () => _navigateToPage('/disease-management'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMedicalWelcomeCard(),
              const SizedBox(height: 16),
              _buildMedicalAlertsCard(),
              const SizedBox(height: 16),
              _buildDiseaseOverviewCard(),
              const SizedBox(height: 16),
              _buildMedicalQuickActions(),
              const SizedBox(height: 16),
              _buildTodayMealsCard(),
              const SizedBox(height: 16),
              _buildMedicalRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicalWelcomeCard() {
    final currentDiseases = _diseases.where((d) => d.isCurrent).length;

    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information,
                    color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  '您好，${_userProfile?.realName ?? '用户'}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '您目前有 $currentDiseases 项需要关注的健康状况，请严格按照医嘱和系统建议进行饮食管理。',
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.grey, size: 16),
                const SizedBox(width: 4),
                Text(
                  '最后更新: ${DateTime.now().toString().substring(0, 16)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalAlertsCard() {
    final severeDiseases = _diseases
        .where((d) => d.isCurrent && (d.severityLevel ?? 0) >= 3)
        .toList();
    final severeAllergies =
        _allergies.where((a) => (a.severityLevel ?? 0) >= 3).toList();

    if (severeDiseases.isEmpty && severeAllergies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  '重要提醒',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...severeDiseases
                .map((disease) => Text(
                      '• ${disease.diseaseName}：请严格遵循饮食限制',
                      style: const TextStyle(color: Colors.orange),
                    ))
                .toList(),
            ...severeAllergies
                .map((allergy) => Text(
                      '• 严重过敏：${allergy.allergenName}，请完全避免',
                      style: const TextStyle(color: Colors.orange),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '健康状况概览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    '当前疾病',
                    _diseases.where((d) => d.isCurrent).length.toString(),
                    Colors.red,
                    Icons.medical_information,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '过敏信息',
                    _allergies.length.toString(),
                    Colors.orange,
                    Icons.warning_amber,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '健康评分',
                    _healthScore?.totalScore.toStringAsFixed(0) ?? '--',
                    _getScoreColor(_healthScore?.totalScore ?? 0),
                    Icons.health_and_safety,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildQuickActionButton(
                  '疾病管理',
                  Icons.medical_information,
                  Colors.red,
                  () => _navigateToPage('/disease-management'),
                ),
                _buildQuickActionButton(
                  'AI咨询',
                  Icons.chat,
                  Colors.blue,
                  () => _navigateToPage('/chat?type=medical'),
                ),
                _buildQuickActionButton(
                  '饮食建议',
                  Icons.restaurant_menu,
                  Colors.green,
                  () => _navigateToPage('/dietary-advice'),
                ),
                _buildQuickActionButton(
                  '健康分析',
                  Icons.analytics,
                  Colors.purple,
                  () => _navigateToPage('/health-analysis'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessUserHome() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健身管理'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            onPressed: () => _navigateToPage('/fitness'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFitnessWelcomeCard(),
              const SizedBox(height: 16),
              _buildFitnessProgressCard(),
              const SizedBox(height: 16),
              _buildFitnessQuickActions(),
              const SizedBox(height: 16),
              _buildTodayMealsCard(),
              const SizedBox(height: 16),
              _buildFitnessRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFitnessWelcomeCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  '加油，${_userProfile?.realName ?? '健身达人'}！',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '坚持就是胜利！让我们一起追求更健康的生活方式。',
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '今天也要加油哦！',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '健身进度',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    '目标体重',
                    '${_userProfile?.targetWeight ?? '--'} kg',
                    Colors.blue,
                    Icons.track_changes,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '当前体重',
                    '${_userProfile?.weight ?? '--'} kg',
                    Colors.green,
                    Icons.monitor_weight,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    'BMI',
                    _userProfile?.bmi?.toStringAsFixed(1) ?? '--',
                    _getBMIColor(_userProfile?.bmi ?? 0),
                    Icons.health_and_safety,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildQuickActionButton(
                  '记录饮食',
                  Icons.camera_alt,
                  Colors.green,
                  () => _navigateToPage('/food-record'),
                ),
                _buildQuickActionButton(
                  '运动计划',
                  Icons.fitness_center,
                  Colors.blue,
                  () => _navigateToPage('/fitness-plan'),
                ),
                _buildQuickActionButton(
                  '体重记录',
                  Icons.monitor_weight,
                  Colors.orange,
                  () => _navigateToPage('/weight-record'),
                ),
                _buildQuickActionButton(
                  'AI教练',
                  Icons.chat,
                  Colors.purple,
                  () => _navigateToPage('/chat?type=fitness'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralUserHome() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DietAI'),
        backgroundColor: Colors.green[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _navigateToPage('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGeneralWelcomeCard(),
              const SizedBox(height: 16),
              _buildGeneralOverviewCard(),
              const SizedBox(height: 16),
              _buildGeneralQuickActions(),
              const SizedBox(height: 16),
              _buildTodayMealsCard(),
              const SizedBox(height: 16),
              _buildGeneralRecommendations(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralWelcomeCard() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.restaurant, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  '您好，${_userProfile?.realName ?? '美食爱好者'}！',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '欢迎使用DietAI，让我们一起探索健康美食的世界。',
              style: TextStyle(fontSize: 16, color: Colors.green),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '每天都有新发现！',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '健康概览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatusItem(
                    'BMI',
                    _userProfile?.bmi?.toStringAsFixed(1) ?? '--',
                    _getBMIColor(_userProfile?.bmi ?? 0),
                    Icons.health_and_safety,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '健康评分',
                    _healthScore?.totalScore.toStringAsFixed(0) ?? '--',
                    _getScoreColor(_healthScore?.totalScore ?? 0),
                    Icons.star,
                  ),
                ),
                Expanded(
                  child: _buildStatusItem(
                    '今日记录',
                    '3', // 模拟数据
                    Colors.blue,
                    Icons.restaurant_menu,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '快捷操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildQuickActionButton(
                  '拍照识别',
                  Icons.camera_alt,
                  Colors.blue,
                  () => _navigateToPage('/camera'),
                ),
                _buildQuickActionButton(
                  'AI助手',
                  Icons.chat,
                  Colors.green,
                  () => _navigateToPage('/chat'),
                ),
                _buildQuickActionButton(
                  '健康分析',
                  Icons.analytics,
                  Colors.purple,
                  () => _navigateToPage('/health-analysis'),
                ),
                _buildQuickActionButton(
                  '数据统计',
                  Icons.bar_chart,
                  Colors.orange,
                  () => _navigateToPage('/data-visualization'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 通用组件
  Widget _buildStatusItem(
      String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayMealsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日饮食',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => _navigateToPage('/food-history'),
                  child: const Text('查看更多'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 模拟今日饮食数据
            _buildMealItem('早餐', '燕麦粥 + 鸡蛋', '08:30', 320),
            _buildMealItem('午餐', '鸡胸肉沙拉', '12:15', 450),
            _buildMealItem('晚餐', '未记录', '--', 0),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(
      String mealType, String food, String time, int calories) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: calories > 0 ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealType,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  food,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (calories > 0)
                Text(
                  '${calories}kcal',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  '今日医疗建议',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              '严格控制钠盐摄入，每日不超过6克',
              '避免高糖食物，选择低升糖指数食材',
              '定时服药，监测血压变化',
              '如有不适请及时就医'
            ].map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(tip)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fitness_center, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '今日健身建议',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              '运动前后记得补充水分',
              '增加蛋白质摄入，促进肌肉恢复',
              '控制总热量，创造合理的热量缺口',
              '保证充足睡眠，有助于身体恢复'
            ].map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(tip)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralRecommendations() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.restaurant, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  '今日健康贴士',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              '多吃新鲜蔬果，补充维生素和纤维',
              '保持饮水量，每日至少8杯水',
              '控制油盐糖，养成清淡饮食习惯',
              '规律作息，有助于新陈代谢'
            ].map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(tip)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // 辅助方法
  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.lightGreen;
    if (score >= 70) return Colors.orange;
    if (score >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  Color _getBMIColor(double bmi) {
    if (bmi >= 18.5 && bmi <= 24.9) return Colors.green;
    if (bmi >= 17.0 && bmi <= 27.9) return Colors.orange;
    return Colors.red;
  }

  void _navigateToPage(String route) {
    // TODO: 实现路由跳转
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('跳转到: $route')),
    );
  }
}

// 用户类型枚举
enum UserType {
  general, // 普通用户
  medical, // 疾病管理用户
  fitness, // 健身用户
}

// 简化的数据模型（实际应该在合适的模型文件中定义）
class UserProfile {
  final String? realName;
  final double? weight;
  final double? targetWeight;
  final double? bmi;
  final List<HealthGoal>? healthGoals;

  UserProfile({
    this.realName,
    this.weight,
    this.targetWeight,
    this.bmi,
    this.healthGoals,
  });
}

class HealthGoal {
  final String goalType;
  final double? targetWeight;

  HealthGoal({
    required this.goalType,
    this.targetWeight,
  });
}

class DiseaseInfo {
  final String diseaseName;
  final bool isCurrent;
  final int severityLevel;

  DiseaseInfo({
    required this.diseaseName,
    required this.isCurrent,
    required this.severityLevel,
  });
}

class AllergyInfo {
  final String allergenName;
  final int severityLevel;

  AllergyInfo({
    required this.allergenName,
    required this.severityLevel,
  });
}
