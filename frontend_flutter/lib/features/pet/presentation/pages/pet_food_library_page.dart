import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/real_pet_api_service.dart';

/// 宠物食品库页面
/// 展示预置宠物食品营养数据，支持搜索和浏览
/// 支持拍照识别食品包装营养成分表
class PetFoodLibraryPage extends StatefulWidget {
  const PetFoodLibraryPage({super.key});

  @override
  State<PetFoodLibraryPage> createState() => _PetFoodLibraryPageState();
}

class _PetFoodLibraryPageState extends State<PetFoodLibraryPage> {
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() => _isLoading = true);
    final api = RealPetApiService();
    final res = await api.getFoodDatabase();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.isSuccess && res.data != null) {
          final items = res.data!['foods'] as List<dynamic>? ?? [];
          // 按类别分组
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final item in items) {
            final cat = (item['category'] as String?) ?? '其他';
            grouped
                .putIfAbsent(cat, () => [])
                .add(Map<String, dynamic>.from(item as Map));
          }
          _categories = grouped.entries
              .map((e) => {
                    'category': e.key,
                    'icon': _categoryIcon(e.key),
                    'foods': e.value,
                  })
              .toList();
        } else {
          _categories = [];
        }
      });
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '干粮':
        return LucideIcons.package;
      case '湿粮':
      case '罐头':
        return LucideIcons.fish;
      case '鲜食':
        return LucideIcons.utensils;
      case '零食':
        return LucideIcons.candy;
      default:
        return LucideIcons.bone;
    }
  }

  Future<void> _scanFood() async {
    // 拍照获取食品包装图片
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null || !mounted) return;

    setState(() => _isScanning = true);

    try {
      // 读取图片并转 base64
      final bytes = await File(image.path).readAsBytes();
      final base64 = base64Encode(bytes);

      // 调用 OCR API
      final api = RealPetApiService();
      final res = await api.ocrPetFood(base64);

      if (!mounted) return;

      if (res.isSuccess && res.data != null) {
        final data = res.data!;
        _showOcrResultDialog(data);
      } else {
        _showSnackBar(res.message ?? '识别失败，请重试');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('识别出错: $e');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showOcrResultDialog(Map<String, dynamic> data) {
    final brand = data['brand'] as String? ?? '';
    final foodName = data['food_name'] as String? ?? '未知食品';
    final calories = data['calories_per_100g'];
    final protein = data['protein_per_100g'];
    final fat = data['fat_per_100g'];
    final carbs = data['carbs_per_100g'];
    final rawText = data['raw_text'] as String?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.camera, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('识别结果',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (brand.isNotEmpty) _buildOcrRow('品牌', brand),
              _buildOcrRow('产品名', foodName),
              _buildOcrRow(
                  '热量', calories != null ? '${calories} kcal/100g' : '未识别'),
              _buildOcrRow('蛋白质', protein != null ? '${protein}g/100g' : '未识别'),
              _buildOcrRow('脂肪', fat != null ? '${fat}g/100g' : '未识别'),
              _buildOcrRow('碳水', carbs != null ? '${carbs}g/100g' : '未识别'),
              if (rawText != null && rawText.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('原始文本',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rawText,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '宠物食品库',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.camera, color: AppColors.primary),
            tooltip: '拍照识别营养成分',
            onPressed: _isScanning ? null : _scanFood,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      '无法加载食品数据，请检查网络连接',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 提示卡片
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.info,
                                size: 16, color: AppColors.primary),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '营养数据来源：品牌官方数据。数值均为每100g含量。',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 分类展示
                      for (final category in _categories) ...[
                        _buildCategoryCard(category),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final foods = category['foods'] as List;
    final icon = category['icon'] as IconData;
    final categoryName = category['category'] as String? ?? '其他';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                '$categoryName (${foods.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < foods.length; i++)
            _buildFoodItem(foods[i], i != foods.length - 1),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food, bool showDivider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 食品信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food['name'],
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        if ((food['brand'] ?? '') != '' && food['brand'] != '-')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              food['brand'],
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '适用：${food['species']}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 营养数据
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${food['calories']} kcal',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.caloriesColor),
                  ),
                  Text(
                    '蛋白 ${food['protein']}g',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    '脂肪 ${food['fat']}g',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              color: AppColors.borderLight.withValues(alpha: 0.5), height: 1),
      ],
    );
  }
}
