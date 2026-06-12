import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/utils/network_error_handler.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../services/saved_meal_service.dart';
import '../widgets/saved_meal_card.dart';
import '../widgets/create_saved_meal_modal.dart';
import '../widgets/saved_meal_filter_modal.dart';

class SavedMealsPage extends StatefulWidget {
  const SavedMealsPage({super.key});

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
  bool? _filterIsPublic;

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
    _tabController = TabController(length: 3, vsync: this);
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
        case 0: // 我的菜品
          _filterIsPublic = false;
          break;
        case 1: // 收藏菜品
          _filterIsPublic = true;
          break;
        case 2: // 全部菜品
          _filterIsPublic = null;
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
        isPublic: _filterIsPublic,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (result.success && result.data != null) {
        setState(() {
          if (_currentPage == 1) {
            _savedMeals = result.data!;
          } else {
            _savedMeals.addAll(result.data!);
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

  Future<void> _onMealAction(SavedMeal meal, String action) async {
    switch (action) {
      case 'favorite':
        await _toggleFavorite(meal);
        break;
      case 'use':
        await _useMeal(meal);
        break;
      case 'edit':
        // TODO: 实现编辑功能
        break;
      case 'delete':
        await _deleteMeal(meal);
        break;
    }
  }

  Future<void> _toggleFavorite(SavedMeal meal) async {
    try {
      final result = await _savedMealService.toggleFavoriteMeal(meal.id);
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
        // 刷新列表
        _loadSavedMeals(refresh: true);
      } else {
        NetworkErrorHandler.showError(context, result.message);
      }
    } catch (e) {
      NetworkErrorHandler.handleApiError(context, e);
    }
  }

  Future<void> _useMeal(SavedMeal meal) async {
    // 先返回结果到根 Navigator（与 push 端保持一致）
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
            Tab(text: '全部菜品'),
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
                  borderSide: BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
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
                _buildMealsList(), // 全部菜品
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
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
            onAction: (action) => _onMealAction(meal, action),
          );
        },
      ),
    );
  }
}
