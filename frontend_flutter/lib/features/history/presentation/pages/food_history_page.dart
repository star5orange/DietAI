import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/food_image_preview.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/api_response.dart';

/// 食物历史页面
class FoodHistoryPage extends ConsumerStatefulWidget {
  const FoodHistoryPage({super.key});

  @override
  ConsumerState<FoodHistoryPage> createState() => _FoodHistoryPageState();
}

class _FoodHistoryPageState extends ConsumerState<FoodHistoryPage> {
  final FoodService _foodService = FoodService();
  List<FoodRecord> _foodRecords = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFoodRecords();
  }

  /// 加载食物记录
  Future<void> _loadFoodRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _foodService.getFoodRecords(
        page: 1,
        pageSize: 50,
      );

      if (response.success && response.data != null) {
        setState(() {
          _foodRecords = response.data!.records;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message ?? '加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 刷新数据
  Future<void> _refresh() async {
    await _loadFoodRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食物记录历史'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_foodRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无食物记录',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _foodRecords.length,
        itemBuilder: (context, index) {
          final record = _foodRecords[index];
          return _buildFoodRecordCard(record);
        },
      ),
    );
  }

  Widget _buildFoodRecordCard(FoodRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.foodName.isNotEmpty ? record.foodName : '未命名食物',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.mealTypeName,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(record.analysisStatus),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.analysisStatusName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (record.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                record.description!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
            if (record.imageUrl != null) ...[
              const SizedBox(height: 12),
              Text(
                '食物图片',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: FoodImagePreview(
                  foodRecord: record,
                  fit: BoxFit.cover,
                  showFullScreen: true,
                ),
              ),
            ],
            if (record.nutritionDetail != null) ...[
              const SizedBox(height: 12),
              _buildNutritionInfo(record.nutritionDetail!),
            ],
            const SizedBox(height: 8),
            Text(
              '记录时间: ${record.createdAt}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionInfo(NutritionDetail nutrition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '营养成分',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNutritionItem('热量', '${nutrition.calories.toStringAsFixed(1)} kcal'),
              ),
              Expanded(
                child: _buildNutritionItem('蛋白质', '${nutrition.protein.toStringAsFixed(1)}g'),
              ),
              Expanded(
                child: _buildNutritionItem('脂肪', '${nutrition.fat.toStringAsFixed(1)}g'),
              ),
              Expanded(
                child: _buildNutritionItem('碳水', '${nutrition.carbohydrates.toStringAsFixed(1)}g'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1: // 待分析
        return Colors.orange;
      case 2: // 分析中
        return Colors.blue;
      case 3: // 已完成
        return Colors.green;
      case 4: // 分析失败
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 