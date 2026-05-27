import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/api_service.dart';
import '../../../profile/domain/services/user_service.dart';
import '../../../../shared/domain/models/api_response.dart';

class DiseaseManagemenetPage extends ConsumerStatefulWidget {
  const DiseaseManagemenetPage({super.key});

  @override
  ConsumerState<DiseaseManagemenetPage> createState() =>
      _DiseaseManagemenetPageState();
}

class _DiseaseManagemenetPageState extends ConsumerState<DiseaseManagemenetPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UserService _userService = UserService(ApiService());

  List<DiseaseInfo> _diseases = [];
  List<AllergyInfo> _allergies = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMedicalData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicalData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 并行加载疾病和过敏信息
      final results = await Future.wait([
        _userService.getDiseases(),
        _userService.getAllergies(),
      ]);

      setState(() {
        final diseasesResponse = results[0] as ApiResponse<List<DiseaseInfo>>;
        final allergiesResponse = results[1] as ApiResponse<List<AllergyInfo>>;
        if (diseasesResponse.success && diseasesResponse.data != null) {
          _diseases = diseasesResponse.data!;
        }
        if (allergiesResponse.success && allergiesResponse.data != null) {
          _allergies = allergiesResponse.data!;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载医疗信息失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('疾病管理'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '疾病管理'),
            Tab(text: '过敏管理'),
            Tab(text: '饮食建议'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMedicalData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDiseaseManagementTab(),
                    _buildAllergyManagementTab(),
                    _buildDietaryAdviceTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadMedicalData,
            child: const Text('重新加载'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseManagementTab() {
    return RefreshIndicator(
      onRefresh: _loadMedicalData,
      child: _diseases.isEmpty
          ? _buildEmptyDiseaseState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _diseases.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDiseaseOverview();
                }
                final disease = _diseases[index - 1];
                return _buildDiseaseCard(disease);
              },
            ),
    );
  }

  Widget _buildEmptyDiseaseState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无疾病信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '添加疾病信息以获得个性化的饮食建议',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDiseaseDialog(),
            icon: const Icon(Icons.add),
            label: const Text('添加疾病信息'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseOverview() {
    final currentDiseases = _diseases.where((d) => d.isCurrent).length;
    final totalDiseases = _diseases.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_information, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  '疾病概览',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    '当前疾病',
                    currentDiseases.toString(),
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    '历史记录',
                    (totalDiseases - currentDiseases).toString(),
                    Colors.grey,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    '过敏信息',
                    _allergies.length.toString(),
                    Colors.orange,
                  ),
                ),
              ],
            ),
            if (currentDiseases > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '您有当前疾病，请严格按照医生建议和系统推荐进行饮食管理',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
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

  Widget _buildDiseaseCard(DiseaseInfo disease) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: disease.isCurrent ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    disease.diseaseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildSeverityChip(disease.severityLevel),
              ],
            ),
            if (disease.diseaseCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '疾病编码: ${disease.diseaseCode}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            if (disease.diagnosedDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '诊断日期: ${_formatDate(disease.diagnosedDate!)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
            if (disease.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                disease.notes,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: disease.isCurrent
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    disease.isCurrent ? '当前疾病' : '历史记录',
                    style: TextStyle(
                      fontSize: 12,
                      color: disease.isCurrent ? Colors.red : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                _buildDietaryRecommendationButton(disease),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(int severityLevel) {
    String text;
    Color color;

    switch (severityLevel) {
      case 1:
        text = '轻度';
        color = Colors.green;
        break;
      case 2:
        text = '中度';
        color = Colors.orange;
        break;
      case 3:
        text = '重度';
        color = Colors.red;
        break;
      default:
        text = '未知';
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDietaryRecommendationButton(DiseaseInfo disease) {
    return TextButton.icon(
      onPressed: () => _showDietaryRecommendations(disease),
      icon: const Icon(Icons.restaurant_menu, size: 16),
      label: const Text('饮食建议'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildAllergyManagementTab() {
    return RefreshIndicator(
      onRefresh: _loadMedicalData,
      child: _allergies.isEmpty
          ? _buildEmptyAllergyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _allergies.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildAllergyOverview();
                }
                final allergy = _allergies[index - 1];
                return _buildAllergyCard(allergy);
              },
            ),
    );
  }

  Widget _buildEmptyAllergyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无过敏信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '添加过敏信息以避免摄入过敏食物',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddAllergyDialog(),
            icon: const Icon(Icons.add),
            label: const Text('添加过敏信息'),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyOverview() {
    final severeCounts = _allergies.where((a) => a.severityLevel >= 3).length;
    final moderateCounts = _allergies.where((a) => a.severityLevel == 2).length;
    final mildCounts = _allergies.where((a) => a.severityLevel == 1).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '过敏概览',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    '严重过敏',
                    severeCounts.toString(),
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    '中度过敏',
                    moderateCounts.toString(),
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    '轻度过敏',
                    mildCounts.toString(),
                    Colors.yellow[700]!,
                  ),
                ),
              ],
            ),
            if (severeCounts > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '您有严重过敏物质，请格外注意避免相关食物',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllergyCard(AllergyInfo allergy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getAllergenTypeIcon(allergy.allergenType),
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allergy.allergenName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildSeverityChip(allergy.severityLevel),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getAllergenTypeName(allergy.allergenType),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (allergy.reactionDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '过敏反应: ${allergy.reactionDescription}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showAvoidanceTips(allergy),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('避免建议'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietaryAdviceTab() {
    if (_diseases.isEmpty && _allergies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无个性化建议',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '请先添加疾病或过敏信息以获得个性化的饮食建议',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_diseases.where((d) => d.isCurrent).isNotEmpty) ...[
            _buildDiseaseBasedAdvice(),
            const SizedBox(height: 16),
          ],
          if (_allergies.isNotEmpty) ...[
            _buildAllergyBasedAdvice(),
            const SizedBox(height: 16),
          ],
          _buildGeneralGuidelines(),
        ],
      ),
    );
  }

  Widget _buildDiseaseBasedAdvice() {
    final currentDiseases = _diseases.where((d) => d.isCurrent).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.medical_information, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  '疾病相关饮食建议',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...currentDiseases.map((disease) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease.diseaseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._getDiseaseAdvice(disease.diseaseName).map((advice) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(advice)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergyBasedAdvice() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '过敏相关注意事项',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._allergies.map((allergy) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          allergy.allergenName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSeverityChip(allergy.severityLevel),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._getAllergyAvoidanceAdvice(allergy).map((advice) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(advice)),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralGuidelines() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '通用健康指导',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              '定期监测健康指标，及时调整饮食方案',
              '保持均衡营养，不要过度限制',
              '如有不适，请及时咨询医生',
              '记录饮食反应，帮助优化管理方案',
              '保持规律作息，适量运动'
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
  IconData _getAllergenTypeIcon(int type) {
    switch (type) {
      case 1:
        return Icons.grass; // 食物
      case 2:
        return Icons.eco; // 环境
      case 3:
        return Icons.medical_services; // 药物
      default:
        return Icons.warning;
    }
  }

  String _getAllergenTypeName(int type) {
    switch (type) {
      case 1:
        return '食物过敏';
      case 2:
        return '环境过敏';
      case 3:
        return '药物过敏';
      default:
        return '其他过敏';
    }
  }

  List<String> _getDiseaseAdvice(String diseaseName) {
    // 这里应该有一个疾病-饮食建议的数据库或API
    // 目前用硬编码的示例
    final advice = {
      '糖尿病': [
        '控制碳水化合物摄入，选择低升糖指数食物',
        '定时定量进餐，避免暴饮暴食',
        '增加膳食纤维摄入，多吃蔬菜',
        '限制糖分和甜食',
      ],
      '高血压': [
        '减少钠盐摄入，每日不超过6克',
        '增加钾元素摄入，多吃香蕉、橙子等',
        '控制总热量，维持健康体重',
        '限制饱和脂肪酸摄入',
      ],
      '高血脂': [
        '减少饱和脂肪和反式脂肪摄入',
        '增加ω-3脂肪酸摄入，多吃深海鱼',
        '多吃富含可溶性纤维的食物',
        '控制胆固醇摄入',
      ],
    };

    return advice[diseaseName] ??
        [
          '请咨询医生或营养师获得专业建议',
          '保持均衡饮食，注意营养搭配',
          '定期复查，监测病情变化',
        ];
  }

  List<String> _getAllergyAvoidanceAdvice(AllergyInfo allergy) {
    // 这里应该有一个过敏原-避免建议的数据库
    final advice = {
      '牛奶': ['避免所有乳制品', '仔细阅读食品标签', '选择植物奶替代'],
      '鸡蛋': ['避免含蛋食品', '注意疫苗成分', '寻找蛋白质替代来源'],
      '花生': ['严格避免花生及其制品', '注意交叉污染', '随身携带急救药物'],
      '大豆': ['避免豆制品', '注意隐藏成分', '选择其他蛋白质来源'],
    };

    return advice[allergy.allergenName] ??
        [
          '严格避免该过敏原',
          '仔细阅读食品标签和成分表',
          '告知餐厅服务员您的过敏情况',
          '随身携带抗过敏药物',
        ];
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '添加医疗信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.medical_information, color: Colors.red),
              title: const Text('添加疾病信息'),
              onTap: () {
                Navigator.pop(context);
                _showAddDiseaseDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber, color: Colors.orange),
              title: const Text('添加过敏信息'),
              onTap: () {
                Navigator.pop(context);
                _showAddAllergyDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDiseaseDialog() {
    // TODO: 实现添加疾病信息的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('添加疾病信息功能开发中')),
    );
  }

  void _showAddAllergyDialog() {
    // TODO: 实现添加过敏信息的对话框
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('添加过敏信息功能开发中')),
    );
  }

  void _showDietaryRecommendations(DiseaseInfo disease) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${disease.diseaseName} - 饮食建议'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _getDiseaseAdvice(disease.diseaseName).map((advice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(advice)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAvoidanceTips(AllergyInfo allergy) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${allergy.allergenName} - 避免建议'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _getAllergyAvoidanceAdvice(allergy).map((advice) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(advice)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

// 数据模型（这些应该在合适的模型文件中定义）
class DiseaseInfo {
  final int id;
  final String diseaseName;
  final String diseaseCode;
  final int severityLevel;
  final String? diagnosedDate;
  final bool isCurrent;
  final String notes;

  DiseaseInfo({
    required this.id,
    required this.diseaseName,
    required this.diseaseCode,
    required this.severityLevel,
    this.diagnosedDate,
    required this.isCurrent,
    required this.notes,
  });

  factory DiseaseInfo.fromJson(Map<String, dynamic> json) {
    return DiseaseInfo(
      id: json['id'] ?? 0,
      diseaseName: json['disease_name'] ?? '',
      diseaseCode: json['disease_code'] ?? '',
      severityLevel: json['severity_level'] ?? 1,
      diagnosedDate: json['diagnosed_date'],
      isCurrent: json['is_current'] ?? true,
      notes: json['notes'] ?? '',
    );
  }
}

class AllergyInfo {
  final int id;
  final int allergenType;
  final String allergenName;
  final int severityLevel;
  final String reactionDescription;

  AllergyInfo({
    required this.id,
    required this.allergenType,
    required this.allergenName,
    required this.severityLevel,
    required this.reactionDescription,
  });

  factory AllergyInfo.fromJson(Map<String, dynamic> json) {
    return AllergyInfo(
      id: json['id'] ?? 0,
      allergenType: json['allergen_type'] ?? 1,
      allergenName: json['allergen_name'] ?? '',
      severityLevel: json['severity_level'] ?? 1,
      reactionDescription: json['reaction_description'] ?? '',
    );
  }
}
