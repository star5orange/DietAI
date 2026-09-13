import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/network_error_handler.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';
import '../../../../services/saved_meal_service.dart';
import '../widgets/saved_meal_card.dart';
import '../widgets/create_saved_meal_modal.dart';
import '../widgets/saved_meal_filter_modal.dart';

/// 浏览入口（首页"常用餐食 → 查看全部"）点击"使用"后，
/// 在同一个弹窗内选择餐次并填写可选消费金额/来源，再以 [SavedMealPick] 作为结果返回。
class SavedMealPick {
  const SavedMealPick({
    required this.meal,
    required this.mealName,
    required this.mealType,
    this.costAmount,
    this.costSource,
  });

  final SavedMeal meal;
  final String mealName;
  final int mealType;
  final double? costAmount;
  final String? costSource;
}

class SavedMealsPage extends StatefulWidget {
  /// [selectMealTypeFirst] 为 true 表示本页仅用于浏览/使用（无预设餐次的入口），
  /// 点击"使用"时先弹出餐次选择，再以 [SavedMealPick] 作为结果返回。
  /// 为 false 表示作为记录流程的选菜页，点击"使用"直接以 [SavedMeal] 作为结果返回。
  const SavedMealsPage({super.key, this.selectMealTypeFirst = false});

  final bool selectMealTypeFirst;

  @override
  State<SavedMealsPage> createState() => _SavedMealsPageState();
}

class _SavedMealsPageState extends State<SavedMealsPage>
    with TickerProviderStateMixin {
  final SavedMealService _savedMealService = SavedMealService();

  // 状态管理
  bool _isLoading = true;
  List<SavedMeal> _savedMeals = [];
  String _searchQuery = '';
  String? _selectedCategory;
  String? _filterSource;

  // 分页
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // 控制器
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadSavedMeals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    setState(() {
      switch (_tabController.index) {
        case 0: // 我的菜品（全部）
          _filterSource = null;
          break;
        case 1: // 收藏菜品（拍照收藏）
          _filterSource = 'record';
          break;
      }
      _currentPage = 1;
      _hasMore = true;
      _savedMeals.clear();
    });
    _loadSavedMeals();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMeals();
    }
  }

  Future<void> _loadSavedMeals({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _savedMeals.clear();
        _isLoading = true;
      });
    }

    try {
      final result = await _savedMealService.getSavedMeals(
        category: _selectedCategory,
        source: _filterSource,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (result.success && result.data != null) {
        setState(() {
          if (_currentPage == 1) {
            // 根据菜品名称去重
            final uniqueMeals = <String, SavedMeal>{};
            for (final meal in result.data!) {
              uniqueMeals[meal.mealName] = meal;
            }
            _savedMeals = uniqueMeals.values.toList();
          } else {
            // 加载更多时也要去重
            final existingNames = _savedMeals.map((m) => m.mealName).toSet();
            for (final meal in result.data!) {
              if (!existingNames.contains(meal.mealName)) {
                _savedMeals.add(meal);
              }
            }
          }
          _hasMore = result.data!.length == _pageSize;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        if (mounted) {
          NetworkErrorHandler.showError(context, result.message);
        }
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NetworkErrorHandler.handleApiError(context, e,
            onRetry: () => _loadSavedMeals());
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreMeals() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadSavedMeals();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _hasMore = true;
      _savedMeals.clear();
    });
    _loadSavedMeals();
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SavedMealFilterModal(
        selectedCategory: _selectedCategory,
        onCategoryChanged: (category) {
          setState(() {
            _selectedCategory = category;
            _currentPage = 1;
            _hasMore = true;
            _savedMeals.clear();
          });
          _loadSavedMeals();
        },
      ),
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateSavedMealModal(
        onMealCreated: (meal) {
          setState(() {
            _savedMeals.insert(0, meal);
          });
        },
      ),
    );
  }

  Future<void> _useMeal(SavedMeal meal) async {
    // 记录流程的选菜页：先返回结果到根 Navigator（与 push 端保持一致）
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(meal);
    }

    // 后端 use 计数异步更新，失败不影响核心流程
    try {
      await _savedMealService.useSavedMeal(meal.id);
    } catch (_) {
      // 静默忽略
    }
  }

  bool _useInProgress = false;

  /// 浏览入口（"查看全部"）：在同一张弹窗内选择餐次并填写可选消费金额/来源，
  /// 确认后以 [SavedMealPick] 作为结果弹回，由调用方生成饮食记录。
  /// 避免直接 pop 出无人消费的结果导致页面/黑屏异常。
  Future<void> _useMealForRecord(SavedMeal meal) async {
    if (_useInProgress) return;
    _useInProgress = true;

    // 与全 App"记录餐食"入口保持一致：仅早餐/午餐/晚餐/加餐
    // 图标与配色对齐首页"食物摄入"餐次卡（coffee/salad/moon/croissant）
    const meals = <(String, int, IconData, Color)>[
      ('早餐', 1, LucideIcons.coffee, Color(0xFF8B4513)),
      ('午餐', 2, LucideIcons.salad, Color(0xFF3ECC7A)),
      ('晚餐', 3, LucideIcons.moon, Color(0xFF9C27B0)),
      ('加餐', 4, LucideIcons.croissant, Color(0xFFEC407A)),
    ];
    const commonSources = <String>['外卖', '食堂', '餐厅', '自制', '便利店', '其他'];

    final amountController = TextEditingController();
    final sourceController = TextEditingController();

    final pick = await showModalBottomSheet<SavedMealPick>(
      context: context,
      // 默认 bottom sheet 高度上限为屏高 9/16，餐次 + 金额内容在小屏/高缩放比例下会溢出，
      // 因此放开高度限制并允许内容滚动。
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        int? chosenType;
        String chosenName = '';

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (sheetContext, setSheetState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '记录"${meal.mealName}"',
                        style: AppTextStyles.h6
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '选择餐次，并填写可选消费金额',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),

                      // 餐次选择（单选）
                      Row(
                        children: [
                          for (final (name, type, icon, color) in meals)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() {
                                  chosenType = type;
                                  chosenName = name;
                                }),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: chosenType == type
                                        ? color.withValues(alpha: 0.1)
                                        : AppColors.cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: chosenType == type
                                          ? color
                                          : AppColors.divider,
                                      width: chosenType == type ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(icon,
                                          color: chosenType == type
                                              ? color
                                              : AppColors.textSecondary,
                                          size: 20),
                                      const SizedBox(height: 6),
                                      Text(
                                        name,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: chosenType == type
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 消费金额（可选）
                      Text(
                        '消费金额（可选）',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          prefixText: '¥ ',
                          hintText: '本次花费（元）',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 消费来源（可选）
                      Text(
                        '消费来源（可选）',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in commonSources)
                            GestureDetector(
                              onTap: () => setSheetState(
                                  () => sourceController.text = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sourceController.text == s
                                      ? AppColors.primary.withValues(alpha: 0.1)
                                      : AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sourceController.text == s
                                        ? AppColors.primary
                                        : AppColors.divider,
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: sourceController.text == s
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sourceController,
                        // 手动输入时刷新 chips 高亮（chips 选中态跟随文本框内容）
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: '自定义来源（可选）',
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 操作按钮
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext), // 取消
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              // 未选餐次时禁用，避免生成无餐次的记录
                              onPressed: chosenType == null
                                  ? null
                                  : () {
                                      final costText =
                                          amountController.text.trim();
                                      final costAmount =
                                          double.tryParse(costText);
                                      final costSource =
                                          sourceController.text.trim();
                                      Navigator.pop(
                                        sheetContext,
                                        SavedMealPick(
                                          meal: meal,
                                          mealName: chosenName,
                                          mealType: chosenType!,
                                          costAmount: costAmount,
                                          costSource: costSource.isEmpty
                                              ? null
                                              : costSource,
                                        ),
                                      );
                                    },
                              child: const Text('确认记录'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    amountController.dispose();
    sourceController.dispose();

    // 取消：留在本页，允许继续操作
    if (pick == null) {
      _useInProgress = false;
      return;
    }
    if (!mounted) return;

    // 携带所选餐次与消费信息弹回浏览入口，由调用方（首页）生成饮食记录
    Navigator.of(context).pop(pick);

    // 后端 use 计数异步更新，失败不影响核心流程
    try {
      await _savedMealService.useSavedMeal(meal.id);
    } catch (_) {
      // 静默忽略
    }
  }

  Future<void> _deleteMeal(SavedMeal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除菜品'),
        content: Text('确定要删除菜品"${meal.mealName}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await _savedMealService.deleteSavedMeal(meal.id);
        if (result.success) {
          setState(() {
            _savedMeals.removeWhere((m) => m.id == meal.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message)),
          );
        } else {
          NetworkErrorHandler.showError(context, result.message);
        }
      } catch (e) {
        NetworkErrorHandler.handleApiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的菜品'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.filter),
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: _showCreateModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我的菜品'),
            Tab(text: '收藏菜品'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索菜品名称...',
                prefixIcon: const Icon(LucideIcons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
              ),
              onChanged: _onSearch,
            ),
          ),

          // 筛选条件显示
          if (_selectedCategory != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.backgroundSecondary,
              child: Row(
                children: [
                  Chip(
                    label: Text(_selectedCategory!),
                    deleteIcon: const Icon(LucideIcons.x, size: 16),
                    onDeleted: () {
                      setState(() {
                        _selectedCategory = null;
                        _currentPage = 1;
                        _hasMore = true;
                        _savedMeals.clear();
                      });
                      _loadSavedMeals();
                    },
                  ),
                ],
              ),
            ),

          // 菜品列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMealsList(), // 我的菜品
                _buildMealsList(), // 收藏菜品
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedMeals.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 60),
              const Icon(
                LucideIcons.chefHat,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无保存的菜品',
                style: AppTextStyles.h5.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击右上角的+号创建您的第一个菜品',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSavedMeals(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _savedMeals.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _savedMeals.length) {
            return _isLoadingMore
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : const SizedBox();
          }

          final meal = _savedMeals[index];
          return SavedMealCard(
            meal: meal,
            onTap: () {
              // TODO: 跳转到菜品详情页
            },
            onUse: () => widget.selectMealTypeFirst
                ? _useMealForRecord(meal)
                : _useMeal(meal),
            onDelete: () => _deleteMeal(meal),
          );
        },
      ),
    );
  }
}
