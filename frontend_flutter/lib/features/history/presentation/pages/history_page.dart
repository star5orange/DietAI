import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../services/saved_meal_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/food_image_preview.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final FoodService _foodService = FoodService();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  List<FoodRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dateString =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      print('📋 历史页面加载记录: date=$dateString');
      final result = await _foodService.getFoodRecordsByDay(dateString);

      print(
          '📋 加载结果: success=${result.success}, message=${result.message}, dataNull=${result.data == null}');
      if (result.success && result.data != null) {
        print('📋 记录数量: ${result.data!.length}');
        for (int i = 0; i < result.data!.length; i++) {
          final r = result.data![i];
          print(
              '📋 记录[$i]: id=${r.id}, foodName=${r.foodName}, nutritionDetail=${r.nutritionDetail != null}');
        }
        setState(() {
          _records = result.data!;
        });
      } else {
        print('📋 加载失败: ${result.message}');
      }
    } catch (e, stackTrace) {
      print('📋 加载食物记录异常: $e');
      print('📋 堆栈: $stackTrace');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('饮食记录'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search),
            onPressed: () {
              // TODO: 搜索功能
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: () {
              // TODO: 筛选功能
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.testTube),
            onPressed: () {
              Navigator.pushNamed(context, '/history/test');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期选择器
            GestureDetector(
              onTap: () => _selectDate(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.backgroundSecondary, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.calendar,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getDateDisplayText(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      LucideIcons.chevronDown,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 记录列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadRecords,
                      child: _records.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.calendar,
                                    size: 48,
                                    color: AppColors.textTertiary,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    '该日期暂无记录',
                                    style: TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              children: _buildMealSections(),
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 添加新记录
        },
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  String _getDateDisplayText() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (selectedDay == today) {
      return '今天 - ${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';
    } else if (selectedDay == today.subtract(const Duration(days: 1))) {
      return '昨天 - ${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';
    } else {
      return '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _loadRecords();
    }
  }

  List<Widget> _buildMealSections() {
    // 按餐次分组记录
    final Map<int, List<FoodRecord>> mealGroups = {};
    for (final record in _records) {
      if (!mealGroups.containsKey(record.mealType)) {
        mealGroups[record.mealType] = [];
      }
      mealGroups[record.mealType]!.add(record);
    }

    final List<Widget> sections = [];
    final mealTypes = [1, 2, 3, 4]; // 早餐、午餐、晚餐、零食

    for (final mealType in mealTypes) {
      if (mealGroups.containsKey(mealType)) {
        final records = mealGroups[mealType]!;
        final widgets =
            records.map((record) => _buildFoodItemFromRecord(record)).toList();

        sections.add(_buildMealSection(
            _getMealName(mealType), _getMealColor(mealType), widgets));
        sections.add(const SizedBox(height: 16));
      }
    }

    return sections;
  }

  String _getMealName(int mealType) {
    switch (mealType) {
      case 1:
        return '早餐';
      case 2:
        return '午餐';
      case 3:
        return '晚餐';
      case 4:
        return '零食';
      default:
        return '其他';
    }
  }

  Color _getMealColor(int mealType) {
    switch (mealType) {
      case 1:
        return AppColors.breakfastColor;
      case 2:
        return AppColors.lunchColor;
      case 3:
        return AppColors.dinnerColor;
      case 4:
        return AppColors.snackColor;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildFoodItemFromRecord(FoodRecord record) {
    // 优先使用 analysisResult 中的卡路里数据，如果没有则使用 nutritionDetail
    final calories = record.analysisResult?.nutritionFacts.totalCalories ??
        record.nutritionDetail?.calories ??
        0.0;
    String time = '';

    // 优先使用 recordTime（用户选择的用餐时间），其次用 createdAt
    final timeStr = record.recordTime ?? record.createdAt;
    if (timeStr.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(timeStr);
        time =
            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        if (timeStr.length > 16) {
          time = timeStr.substring(11, 16);
        } else {
          time = timeStr;
        }
      }
    }

    return _buildFoodItem(
      record.foodName ?? '未命名食物',
      record.description ?? '',
      '${calories.round()} kcal',
      time,
      record.imageUrl, // 添加图片URL
      record, // 传递整个记录对象以便后续操作
    );
  }

  Widget _buildMealSection(String title, Color color, List<Widget> foods) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 餐次标题
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: color,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // 食物列表
          ...foods,
        ],
      ),
    );
  }

  Widget _buildFoodItem(
      String name, String amount, String calories, String time,
      [String? imageUrl, FoodRecord? record]) {
    return InkWell(
      onTap: record != null ? () => _showFoodDetailModal(record) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.divider.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // 食物图片预览
            if (imageUrl != null && imageUrl.isNotEmpty && record != null)
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.backgroundSecondary,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FoodImagePreview(
                    foodRecord: record,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    showFullScreen: false,
                    showLoadingIndicator: false,
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.backgroundSecondary,
                ),
                child: Icon(
                  LucideIcons.utensils,
                  color: AppColors.textTertiary,
                  size: 24,
                ),
              ),

            // 食物信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (amount.isNotEmpty)
                    Text(
                      amount,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // 卡路里和时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    calories,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // 更多操作
            if (record != null) ...[
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                onSelected: (action) => _handleFoodAction(record, action),
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    LucideIcons.moreVertical,
                    color: AppColors.textTertiary,
                    size: 16,
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(LucideIcons.eye, size: 16),
                        SizedBox(width: 8),
                        Text('查看详情'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(LucideIcons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('编辑'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'save_as_meal',
                    child: Row(
                      children: [
                        Icon(LucideIcons.bookmark, size: 16),
                        SizedBox(width: 8),
                        Text('保存为菜品'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Row(
                      children: [
                        Icon(LucideIcons.copy, size: 16),
                        SizedBox(width: 8),
                        Text('复制记录'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '删除',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 显示食物详情模态框
  void _showFoodDetailModal(FoodRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFoodDetailModal(record),
    );
  }

  /// 构建食物详情模态框
  Widget _buildFoodDetailModal(FoodRecord record) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  '食物详情',
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x),
                ),
              ],
            ),
          ),

          // 详情内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 食物图片
                  if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.backgroundSecondary,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FoodImagePreview(
                          foodRecord: record,
                          showFullScreen: true,
                        ),
                      ),
                    ),

                  // 基本信息
                  _buildDetailSection('基本信息', [
                    _buildDetailRow('食物名称', record.foodName ?? '未命名食物'),
                    if (record.description != null &&
                        record.description!.isNotEmpty)
                      _buildDetailRow('描述', record.description!),
                    _buildDetailRow('餐次', record.mealTypeName),
                    _buildDetailRow(
                        '记录时间', record.recordTime ?? record.createdAt),
                    _buildDetailRow('分析状态', record.analysisStatusName),
                  ]),

                  const SizedBox(height: 20),

                  // 营养信息
                  _buildNutritionSection(record),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 底部操作按钮
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleFoodAction(record, 'edit');
                    },
                    icon: const Icon(LucideIcons.edit, size: 18),
                    label: const Text('编辑'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleFoodAction(record, 'save_as_meal');
                    },
                    icon: const Icon(LucideIcons.bookmark, size: 18),
                    label: const Text('保存为菜品'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.h6.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(FoodRecord record) {
    // 优先使用 nutritionData 数据，然后是 analysisResult，最后是 nutritionDetail
    final nutritionData = record.nutritionData;
    final analysisResult = record.analysisResult;
    final nutritionDetail = record.nutritionDetail;

    if (nutritionData == null &&
        analysisResult == null &&
        nutritionDetail == null) {
      return _buildDetailSection('营养信息', [
        _buildDetailRow('状态', '暂无营养分析数据'),
      ]);
    }

    final List<Widget> nutritionRows = [];

    if (nutritionData != null) {
      // 使用 nutritionData 数据
      final data = nutritionData!;

      // 宏量营养素
      if (data['calories'] != null) {
        nutritionRows.add(
            _buildDetailRow('热量', '${(data['calories'] as num).round()} kcal'));
      }
      if (data['protein'] != null) {
        nutritionRows.add(
            _buildDetailRow('蛋白质', '${(data['protein'] as num).round()} g'));
      }
      if (data['fat'] != null) {
        nutritionRows
            .add(_buildDetailRow('脂肪', '${(data['fat'] as num).round()} g'));
      }
      if (data['carbohydrates'] != null) {
        nutritionRows.add(_buildDetailRow(
            '碳水化合物', '${(data['carbohydrates'] as num).round()} g'));
      }
      if (data['dietary_fiber'] != null) {
        nutritionRows.add(_buildDetailRow(
            '膳食纤维', '${(data['dietary_fiber'] as num).round()} g'));
      }
      if (data['sugar'] != null) {
        nutritionRows
            .add(_buildDetailRow('糖类', '${(data['sugar'] as num).round()} g'));
      }

      // 微量营养素
      if (data['sodium'] != null) {
        nutritionRows
            .add(_buildDetailRow('钠', '${(data['sodium'] as num).round()} mg'));
      }
      if (data['cholesterol'] != null) {
        nutritionRows.add(_buildDetailRow(
            '胆固醇', '${(data['cholesterol'] as num).round()} mg'));
      }

      // 维生素
      if (data['vitamin_a'] != null) {
        nutritionRows.add(_buildDetailRow(
            '维生素A', '${(data['vitamin_a'] as num).round()} μg'));
      }
      if (data['vitamin_c'] != null) {
        nutritionRows.add(_buildDetailRow(
            '维生素C', '${(data['vitamin_c'] as num).round()} mg'));
      }
      if (data['vitamin_d'] != null) {
        nutritionRows.add(_buildDetailRow(
            '维生素D', '${(data['vitamin_d'] as num).round()} μg'));
      }

      // 矿物质
      if (data['calcium'] != null) {
        nutritionRows.add(
            _buildDetailRow('钙', '${(data['calcium'] as num).round()} mg'));
      }
      if (data['iron'] != null) {
        nutritionRows
            .add(_buildDetailRow('铁', '${(data['iron'] as num).round()} mg'));
      }
      if (data['potassium'] != null) {
        nutritionRows.add(
            _buildDetailRow('钾', '${(data['potassium'] as num).round()} mg'));
      }

      // 置信度
      if (data['confidence_score'] != null) {
        final confidence = (data['confidence_score'] as num) * 100;
        nutritionRows.add(_buildDetailRow('置信度', '${confidence.round()}%'));
      }
    } else if (analysisResult != null) {
      final nutrition = analysisResult.nutritionFacts;
      final macros = nutrition.macronutrients;
      final vitamins = nutrition.vitaminsMinerals;

      // 基本营养信息
      nutritionRows.addAll([
        _buildDetailRow('热量', '${nutrition.totalCalories.round()} kcal'),
        _buildDetailRow('蛋白质', '${macros.protein.round()} g'),
        _buildDetailRow('脂肪', '${macros.fat.round()} g'),
        _buildDetailRow('碳水化合物', '${macros.carbohydrates.round()} g'),
        _buildDetailRow('膳食纤维', '${macros.dietaryFiber.round()} g'),
        _buildDetailRow('糖类', '${macros.sugar.round()} g'),
      ]);

      // 维生素和矿物质信息（如果有）
      if (vitamins != null) {
        if (vitamins.sodium != null) {
          nutritionRows
              .add(_buildDetailRow('钠', '${vitamins.sodium!.round()} mg'));
        }
        if (vitamins.cholesterol != null) {
          nutritionRows.add(
              _buildDetailRow('胆固醇', '${vitamins.cholesterol!.round()} mg'));
        }
        if (vitamins.vitaminA != null) {
          nutritionRows
              .add(_buildDetailRow('维生素A', '${vitamins.vitaminA!.round()} μg'));
        }
        if (vitamins.vitaminC != null) {
          nutritionRows
              .add(_buildDetailRow('维生素C', '${vitamins.vitaminC!.round()} mg'));
        }
        if (vitamins.calcium != null) {
          nutritionRows
              .add(_buildDetailRow('钙', '${vitamins.calcium!.round()} mg'));
        }
        if (vitamins.iron != null) {
          nutritionRows
              .add(_buildDetailRow('铁', '${vitamins.iron!.round()} mg'));
        }
      }

      // 健康等级
      if (nutrition.healthLevel != null) {
        nutritionRows
            .add(_buildDetailRow('健康等级', '${nutrition.healthLevel}/10'));
      }
    } else if (nutritionDetail != null) {
      // 使用 nutritionDetail 数据
      nutritionRows.addAll([
        _buildDetailRow('热量', '${nutritionDetail.calories.round()} kcal'),
        _buildDetailRow('蛋白质', '${nutritionDetail.protein.round()} g'),
        _buildDetailRow('脂肪', '${nutritionDetail.fat.round()} g'),
        _buildDetailRow('碳水化合物', '${nutritionDetail.carbohydrates.round()} g'),
        _buildDetailRow('膳食纤维', '${nutritionDetail.dietaryFiber.round()} g'),
        _buildDetailRow('糖类', '${nutritionDetail.sugar.round()} g'),
        _buildDetailRow('钠', '${nutritionDetail.sodium.round()} mg'),
        _buildDetailRow('胆固醇', '${nutritionDetail.cholesterol.round()} mg'),
        _buildDetailRow('维生素A', '${nutritionDetail.vitaminA.round()} μg'),
        _buildDetailRow('维生素C', '${nutritionDetail.vitaminC.round()} mg'),
        _buildDetailRow('维生素D', '${nutritionDetail.vitaminD.round()} μg'),
        _buildDetailRow('钙', '${nutritionDetail.calcium.round()} mg'),
        _buildDetailRow('铁', '${nutritionDetail.iron.round()} mg'),
        _buildDetailRow('钾', '${nutritionDetail.potassium.round()} mg'),
      ]);

      // 分析方法和置信度
      if (nutritionDetail.analysisMethod != null) {
        nutritionRows
            .add(_buildDetailRow('分析方法', nutritionDetail.analysisMethod!));
      }
      if (nutritionDetail.confidenceScore != null) {
        nutritionRows.add(_buildDetailRow(
            '置信度', '${(nutritionDetail.confidenceScore! * 100).round()}%'));
      }
    }

    return _buildDetailSection('营养信息', nutritionRows);
  }

  /// 处理食物操作
  void _handleFoodAction(FoodRecord record, String action) {
    switch (action) {
      case 'view':
        _showFoodDetailModal(record);
        break;
      case 'edit':
        _showEditFoodDialog(record);
        break;
      case 'save_as_meal':
        _showSaveAsMealDialog(record);
        break;
      case 'duplicate':
        // TODO: 复制记录
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('复制功能开发中...')),
        );
        break;
      case 'delete':
        _showDeleteConfirmDialog(record);
        break;
    }
  }

  /// 显示删除确认对话框
  void _showDeleteConfirmDialog(FoodRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除食物记录'),
        content: Text('确定要删除"${record.foodName ?? '未命名食物'}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteFoodRecord(record);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示保存为菜品对话框
  void _showSaveAsMealDialog(FoodRecord record) {
    final TextEditingController nameController = TextEditingController(
      text: record.foodName ?? '',
    );
    final TextEditingController descController = TextEditingController(
      text: record.description ?? '',
    );
    final TextEditingController categoryController = TextEditingController();

    final List<String> availableCategories = [
      '主食',
      '蔬菜',
      '肉类',
      '汤类',
      '小食',
      '饮品',
      '甜品',
      '其他'
    ];

    String? selectedCategory;
    List<String> selectedTags = [];
    final List<String> availableTags = [
      '健康',
      '减脂',
      '增肌',
      '高蛋白',
      '低脂',
      '低糖',
      '高纤维',
      '素食',
      '快手菜'
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('保存为菜品'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 菜品名称
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '菜品名称 *',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),

                  // 描述
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: '描述',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    maxLength: 500,
                  ),
                  const SizedBox(height: 16),

                  // 分类选择
                  const Text('分类',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((category) {
                      final isSelected = selectedCategory == category;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategory = isSelected ? null : category;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 标签选择
                  const Text('标签',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedTags.remove(tag);
                            } else {
                              selectedTags.add(tag);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 营养信息预览
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '营养信息预览',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        _buildNutritionPreview(record),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final mealName = nameController.text.trim();
                if (mealName.isNotEmpty) {
                  Navigator.pop(context);
                  _saveAsMeal(
                    record,
                    mealName,
                    descController.text.trim(),
                    selectedCategory,
                    selectedTags,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入菜品名称')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                '保存',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    descController.dispose();
    categoryController.dispose();
  }

  Widget _buildNutritionPreview(FoodRecord record) {
    final analysisResult = record.analysisResult;
    final nutritionDetail = record.nutritionDetail;

    if (analysisResult == null && nutritionDetail == null) {
      return const Text('暂无营养信息', style: TextStyle(color: Colors.grey));
    }

    double calories = 0;
    double protein = 0;
    double fat = 0;
    double carbs = 0;

    if (analysisResult != null) {
      calories = analysisResult.nutritionFacts.totalCalories;
      protein = analysisResult.nutritionFacts.macronutrients.protein;
      fat = analysisResult.nutritionFacts.macronutrients.fat;
      carbs = analysisResult.nutritionFacts.macronutrients.carbohydrates;
    } else if (nutritionDetail != null) {
      calories = nutritionDetail.calories;
      protein = nutritionDetail.protein;
      fat = nutritionDetail.fat;
      carbs = nutritionDetail.carbohydrates;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNutrientChip('热量', '${calories.round()} kcal', Colors.orange),
        _buildNutrientChip('蛋白质', '${protein.round()} g', Colors.blue),
        _buildNutrientChip('脂肪', '${fat.round()} g', Colors.green),
        _buildNutrientChip('碳水', '${carbs.round()} g', Colors.purple),
      ],
    );
  }

  Widget _buildNutrientChip(String label, String value, Color color) {
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveAsMeal(
    FoodRecord record,
    String mealName,
    String description,
    String? category,
    List<String> tags,
  ) async {
    try {
      final savedMealService = SavedMealService();
      final result = await savedMealService.createSavedMealFromRecord(
        foodRecordId: record.id,
        mealName: mealName,
        description: description.isNotEmpty ? description : null,
        category: category,
        tags: tags.isNotEmpty ? tags : null,
      );

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('菜品"$mealName"保存成功！'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: ${result.message}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存菜品失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showEditFoodDialog(FoodRecord record) {
    final nameController = TextEditingController(text: record.foodName ?? '');
    final descController =
        TextEditingController(text: record.description ?? '');
    int selectedMealType = record.mealType;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑食物记录'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '食物名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedMealType,
                  decoration: const InputDecoration(
                    labelText: '用餐类型',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('早餐')),
                    DropdownMenuItem(value: 2, child: Text('午餐')),
                    DropdownMenuItem(value: 3, child: Text('晚餐')),
                    DropdownMenuItem(value: 4, child: Text('加餐')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedMealType = value ?? 1);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final foodData = FoodRecordCreate(
                  recordDate: record.recordDate,
                  recordTime: record.recordTime,
                  mealType: selectedMealType,
                  foodName: nameController.text.trim(),
                  description: descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  imageUrl: record.imageUrl,
                  recordingMethod: record.recordingMethod,
                );

                final result =
                    await _foodService.updateFoodRecord(record.id, foodData);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (result.success) {
                    _loadRecords();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('食物记录已更新')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新失败: ${result.message}')),
                    );
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  /// 删除食物记录
  void _deleteFoodRecord(FoodRecord record) async {
    try {
      final result = await _foodService.deleteFoodRecord(record.id);
      if (result.success || result.notFound) {
        final dateString =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        await _foodService.invalidateRecordsCache(dateString);
        setState(() {
          _records.removeWhere((r) => r.id == record.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.notFound ? '记录已不存在，已从列表移除' : '食物记录已删除')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: ${result.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }
}
