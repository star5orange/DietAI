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

  // AI 解读状态
  final Map<String, String> _aiResults = {};
  final Map<String, bool> _aiLoading = {};
  final Map<String, String?> _aiErrors = {};

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

  Future<void> _startAiAnalysis(String metricType) async {
    final data = _getMetricData(metricType);
    if (data.isEmpty) return;

    setState(() {
      _aiLoading[metricType] = true;
      _aiErrors[metricType] = null;
      _aiResults[metricType] = '';
    });

    try {
      final stream = _healthAnalysisService.streamAiAnalysis(
        metricType: metricType,
        metricData: data,
      );

      await for (final event in stream) {
        if (!mounted) return;
        if (event.type == 'token') {
          setState(() {
            _aiResults[metricType] = (_aiResults[metricType] ?? '') + (event.content ?? '');
          });
        } else if (event.type == 'done') {
          setState(() => _aiLoading[metricType] = false);
        } else if (event.type == 'error') {
          setState(() {
            _aiLoading[metricType] = false;
            _aiErrors[metricType] = event.message;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiLoading[metricType] = false;
        _aiErrors[metricType] = '分析失败: $e';
      });
    }
  }

  Map<String, dynamic> _getMetricData(String metricType) {
    switch (metricType) {
      case 'bmr':
        final r = _bmrResult;
        if (r == null) return {};
        return {
          'bmr': r.bmr,
          'unit': r.unit,
          'method': r.method,
          'user_data': {
            'gender': r.userData.gender,
            'age': r.userData.age,
            'weight': r.userData.weight,
            'height': r.userData.height,
          },
          'description': r.description,
        };
      case 'tdee':
        final r = _tdeeResult;
        if (r == null) return {};
        return {
          'tdee': r.tdee,
          'bmr': r.bmr,
          'unit': r.unit,
          'activity_level': r.activityLevel,
          'activity_factor': r.activityFactor,
          'activity_description': r.activityDescription,
          'description': r.description,
        };
      case 'health-score':
        final r = _healthScoreResult;
        if (r == null) return {};
        final components = <String, dynamic>{};
        r.components.forEach((k, v) {
          components[k] = {
            'score': v.score,
            'max_score': v.maxScore,
            'description': v.description,
          };
        });
        return {
          'total_score': r.totalScore,
          'grade': r.grade,
          'components': components,
          'suggestions': r.suggestions,
        };
      case 'nutrition-balance':
        final r = _nutritionBalanceResult;
        if (r == null) return {};
        return {
          'period': {
            'start_date': r.period.startDate,
            'end_date': r.period.endDate,
            'days': r.period.days,
          },
          'averages': {
            'calories': r.averages.calories,
            'protein': r.averages.protein,
            'fat': r.averages.fat,
            'carbohydrates': r.averages.carbohydrates,
            'fiber': r.averages.fiber,
            'sodium': r.averages.sodium,
          },
          'percentages': {
            'protein': r.percentages.protein,
            'fat': r.percentages.fat,
            'carbohydrates': r.percentages.carbohydrates,
          },
          'reference': {
            'recommended_calories': r.reference.recommendedCalories,
            'calorie_ratio': r.reference.calorieRatio,
          },
          'recommendations': r.recommendations,
        };
      case 'weight-trend':
        final r = _weightTrendResult;
        if (r == null) return {};
        return {
          'trend': r.trend,
          'weight_change': r.weightChange,
          'change_percentage': r.weightChangePercentage,
          'analysis': r.analysis,
        };
      default:
        return {};
    }
  }

  Widget _buildAiSection(String metricType) {
    final isLoading = _aiLoading[metricType] ?? false;
    final result = _aiResults[metricType];
    final error = _aiErrors[metricType];
    final hasResult = result != null && result.isNotEmpty;
    final hasData = _getMetricData(metricType).isNotEmpty;

    if (!hasData) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        color: const Color(0xFFF0F7FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFB3D9FF), width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Text('AI 解读', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (hasResult && !isLoading)
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('重新分析', style: TextStyle(fontSize: 13)),
                      onPressed: () => _startAiAnalysis(metricType),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading) ...[
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    const Text('正在分析中...', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                if (result != null && result.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(result, style: const TextStyle(fontSize: 14, height: 1.6)),
                ],
              ] else if (error != null) ...[
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 14))),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('重试'),
                  onPressed: () => _startAiAnalysis(metricType),
                ),
              ] else if (hasResult) ...[
                Text(result!, style: const TextStyle(fontSize: 14, height: 1.6)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Text('🤖', style: TextStyle(fontSize: 16)),
                    label: const Text('AI 解读'),
                    onPressed: () => _startAiAnalysis(metricType),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI健康分析'),
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
            const SizedBox(height: 8),
            _buildAiSection('bmr'),
          ],
        ),
      ),
    );
  }

  Widget _buildTDEETab() {
    if (_tdeeResult == null) {
      return const Center(child: Text('暂无TDEE数据'));
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
            const SizedBox(height: 8),
            _buildAiSection('tdee'),
          ],
        ),
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
            const SizedBox(height: 8),
            _buildAiSection('health-score'),
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
            const SizedBox(height: 8),
            _buildAiSection('nutrition-balance'),
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
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _weightTrendResult!.records.length,
                        itemBuilder: (context, index) {
                          final record = _weightTrendResult!.records[index];
                          return ListTile(
                            title: Text(record.date),
                            trailing: Text('${record.weight.toStringAsFixed(1)} kg'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildAiSection('weight-trend'),
          ],
        ),
      ),
    );
  }
}
