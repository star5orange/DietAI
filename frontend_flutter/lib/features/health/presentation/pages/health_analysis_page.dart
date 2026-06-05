import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/health_analysis_service.dart';
import '../../../../shared/domain/models/api_response.dart';

class HealthAnalysisPage extends ConsumerStatefulWidget {
  const HealthAnalysisPage({super.key});

  @override
  ConsumerState<HealthAnalysisPage> createState() => _HealthAnalysisPageState();
}

class _HealthAnalysisPageState extends ConsumerState<HealthAnalysisPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HealthAnalysisService _healthAnalysisService = HealthAnalysisService();

  BMRResult? _bmrResult;
  TDEEResult? _tdeeResult;
  HealthScoreResult? _healthScoreResult;
  NutritionBalanceResult? _nutritionBalanceResult;
  WeightTrendResult? _weightTrendResult;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadHealthData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHealthData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _healthAnalysisService.getBMR(),
        _healthAnalysisService.getTDEE(),
        _healthAnalysisService.getHealthScore(),
        _healthAnalysisService.getNutritionBalance(),
        _healthAnalysisService.getWeightTrend(),
      ]);

      setState(() {
        final bmrRes = results[0] as ApiResponse<BMRResult>;
        final tdeeRes = results[1] as ApiResponse<TDEEResult>;
        final healthRes = results[2] as ApiResponse<HealthScoreResult>;
        final nutritionRes = results[3] as ApiResponse<NutritionBalanceResult>;
        final weightRes = results[4] as ApiResponse<WeightTrendResult>;

        if (bmrRes.success && bmrRes.data != null) _bmrResult = bmrRes.data;
        if (tdeeRes.success && tdeeRes.data != null) _tdeeResult = tdeeRes.data;
        if (healthRes.success && healthRes.data != null) _healthScoreResult = healthRes.data;
        if (nutritionRes.success && nutritionRes.data != null) _nutritionBalanceResult = nutritionRes.data;
        if (weightRes.success && weightRes.data != null) _weightTrendResult = weightRes.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '加载健康数据失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealthData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'BMR'),
            Tab(text: 'TDEE'),
            Tab(text: '健康评分'),
            Tab(text: '营养平衡'),
            Tab(text: '体重趋势'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadHealthData, child: const Text('重试')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBMRTab(),
                    _buildTDEETab(),
                    _buildHealthScoreTab(),
                    _buildNutritionBalanceTab(),
                    _buildWeightTrendTab(),
                  ],
                ),
    );
  }

  Widget _buildBMRTab() {
    if (_bmrResult == null) {
      return const Center(child: Text('暂无BMR数据'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('基础代谢率 (BMR)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('${_bmrResult!.bmr.round()} ${_bmrResult!.unit}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('计算方法: ${_bmrResult!.method}'),
                  if (_bmrResult!.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_bmrResult!.description, style: const TextStyle(color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTDEETab() {
    if (_tdeeResult == null) {
      return const Center(child: Text('暂无TDEE数据'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('每日总能量消耗 (TDEE)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('${_tdeeResult!.tdee.round()} ${_tdeeResult!.unit}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('活动系数: ${_tdeeResult!.activityFactor}'),
                  Text('活动水平: ${_tdeeResult!.activityDescription}'),
                  const SizedBox(height: 8),
                  Text('基础代谢: ${_tdeeResult!.bmr.round()} ${_tdeeResult!.unit}'),
                  if (_tdeeResult!.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_tdeeResult!.description, style: const TextStyle(color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreTab() {
    if (_healthScoreResult == null) {
      return const Center(child: Text('暂无健康评分数据'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('健康评分', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('${_healthScoreResult!.totalScore.round()}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Text(_healthScoreResult!.grade, style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                    if (_healthScoreResult!.components.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('评分明细：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._healthScoreResult!.components.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${entry.key}: ${entry.value.score}/${entry.value.maxScore} - ${entry.value.description}'),
                      )),
                    ],
                    if (_healthScoreResult!.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('建议：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._healthScoreResult!.suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $s'),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionBalanceTab() {
    if (_nutritionBalanceResult == null) {
      return const Center(child: Text('暂无营养平衡数据'));
    }

    final avg = _nutritionBalanceResult!.averages;
    final pct = _nutritionBalanceResult!.percentages;
    final ref = _nutritionBalanceResult!.reference;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('营养平衡分析', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('分析周期: ${_nutritionBalanceResult!.period.startDate} ~ ${_nutritionBalanceResult!.period.endDate}'),
                    const SizedBox(height: 12),
                    const Text('日均摄入：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('• 热量: ${avg.calories.toStringAsFixed(1)} kcal'),
                    Text('• 蛋白质: ${avg.protein.toStringAsFixed(1)} g'),
                    Text('• 脂肪: ${avg.fat.toStringAsFixed(1)} g'),
                    Text('• 碳水化合物: ${avg.carbohydrates.toStringAsFixed(1)} g'),
                    Text('• 膳食纤维: ${avg.fiber.toStringAsFixed(1)} g'),
                    Text('• 钠: ${avg.sodium.toStringAsFixed(1)} mg'),
                    const SizedBox(height: 12),
                    const Text('营养素比例：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('• 蛋白质: ${pct.protein.toStringAsFixed(1)}%'),
                    Text('• 脂肪: ${pct.fat.toStringAsFixed(1)}%'),
                    Text('• 碳水化合物: ${pct.carbohydrates.toStringAsFixed(1)}%'),
                    const SizedBox(height: 12),
                    Text('推荐热量: ${ref.recommendedCalories.toStringAsFixed(1)} kcal'),
                    Text('热量达标率: ${(ref.calorieRatio * 100).toStringAsFixed(1)}%'),
                    if (_nutritionBalanceResult!.recommendations.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('建议：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._nutritionBalanceResult!.recommendations.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $r'),
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightTrendTab() {
    if (_weightTrendResult == null) {
      return const Center(child: Text('暂无体重趋势数据'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('体重趋势', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('趋势: ${_weightTrendResult!.trend}'),
                  Text('体重变化: ${_weightTrendResult!.weightChange.toStringAsFixed(2)} kg'),
                  Text('变化率: ${_weightTrendResult!.weightChangePercentage.toStringAsFixed(2)}%'),
                  const SizedBox(height: 8),
                  Text('分析: ${_weightTrendResult!.analysis}'),
                  if (_weightTrendResult!.records.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('历史记录：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _weightTrendResult!.records.length,
                        itemBuilder: (context, index) {
                          final record = _weightTrendResult!.records[index];
                          return ListTile(
                            title: Text(record.date),
                            trailing: Text('${record.weight.toStringAsFixed(1)} kg'),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
