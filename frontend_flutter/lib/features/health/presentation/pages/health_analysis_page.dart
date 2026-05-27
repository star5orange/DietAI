import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health_analysis_service.dart';
import '../../shared/domain/models/api_response.dart';

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
      // 并行加载所有健康数据
      final results = await Future.wait([
        _healthAnalysisService.calculateBMR(),
        _healthAnalysisService.calculateTDEE(),
        _healthAnalysisService.getHealthScore(),
        _healthAnalysisService.analyzeNutritionBalance(),
        _healthAnalysisService.getWeightTrend(),
      ]);

      setState(() {
        if (results[0].success) _bmrResult = results[0].data as BMRResult?;
        if (results[1].success) _tdeeResult = results[1].data as TDEEResult?;
        if (results[2].success) _healthScoreResult = results[2].data as HealthScoreResult?;
        if (results[3].success) _nutritionBalanceResult = results[3].data as NutritionBalanceResult?;
        if (results[4].success) _weightTrendResult = results[4].data as WeightTrendResult?;
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
                      Icon(
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
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadHealthData,
                        child: const Text('重试'),
                      ),
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
                  const Text(
                    '基础代谢率 (BMR)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_bmrResult!.bmr.round()} kcal/日',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('计算公式: ${_bmrResult!.formula}'),
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
                  const Text(
                    '每日总能量消耗 (TDEE)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_tdeeResult!.tdee.round()} kcal/日',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('活动系数: ${_tdeeResult!.activityFactor}'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '健康评分',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_healthScoreResult!.score.round()}',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        _healthScoreResult!.level,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_healthScoreResult!.recommendations.isNotEmpty) ...[
                    const Text(
                      '建议：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._healthScoreResult!.recommendations.map((rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $rec'),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBalanceTab() {
    if (_nutritionBalanceResult == null) {
      return const Center(child: Text('暂无营养平衡数据'));
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
                  const Text(
                    '营养平衡分析',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_nutritionBalanceResult!.deficiencies.isNotEmpty) ...[
                    const Text(
                      '营养不足：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    ..._nutritionBalanceResult!.deficiencies.map((def) => Text('• $def')),
                    const SizedBox(height: 16),
                  ],
                  if (_nutritionBalanceResult!.excesses.isNotEmpty) ...[
                    const Text(
                      '营养过量：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    ..._nutritionBalanceResult!.excesses.map((exc) => Text('• $exc')),
                    const SizedBox(height: 16),
                  ],
                  if (_nutritionBalanceResult!.recommendations.isNotEmpty) ...[
                    const Text(
                      '建议：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ..._nutritionBalanceResult!.recommendations.entries.map((entry) => 
                        Text('• ${entry.key}: ${entry.value}')),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                  const Text(
                    '体重趋势',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('变化率: ${_weightTrendResult!.changeRate.toStringAsFixed(2)} kg/月'),
                  const SizedBox(height: 8),
                  Text('预测: ${_weightTrendResult!.prediction}'),
                  const SizedBox(height: 16),
                  if (_weightTrendResult!.trend.isNotEmpty) ...[
                    const Text(
                      '趋势数据：',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _weightTrendResult!.trend.length,
                        itemBuilder: (context, index) {
                          final point = _weightTrendResult!.trend[index];
                          return ListTile(
                            title: Text('${point['date'] ?? ''}'),
                            trailing: Text('${point['weight'] ?? ''} kg'),
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