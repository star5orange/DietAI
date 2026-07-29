import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 品种选择器组件
/// 支持猫/狗品种搜索和选择，混血/其他支持手动输入
class BreedSelectorWidget extends StatefulWidget {
  final String species;
  final String? selectedBreed;
  final ValueChanged<String?> onBreedSelected;

  const BreedSelectorWidget({
    super.key,
    required this.species,
    this.selectedBreed,
    required this.onBreedSelected,
  });

  @override
  State<BreedSelectorWidget> createState() => _BreedSelectorWidgetState();
}

class _BreedSelectorWidgetState extends State<BreedSelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customBreedController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _customFocusNode = FocusNode();
  List<String> _filteredBreeds = [];
  bool _showDropdown = false;
  bool _showCustomInput = false;
  bool _isLoadingBreeds = false;

  static const _customBreedKeys = ['混血（串串）', '其他'];

  // 硬编码品种数据（作为API失败时的回退）
  static const _fallbackCatBreeds = [
    '橘猫',
    '英短（英国短毛猫）',
    '布偶猫',
    '暹罗猫',
    '美短（美国短毛猫）',
    '波斯猫',
    '缅因猫',
    '金吉拉',
    '中华田园猫',
    '狸花猫',
    '玄猫',
    '三花猫',
    '混血（串串）',
    '其他',
  ];

  static const _fallbackDogBreeds = [
    '泰迪（贵宾犬）',
    '柯基',
    '金毛',
    '拉布拉多',
    '哈士奇',
    '博美',
    '比熊',
    '萨摩耶',
    '边境牧羊犬',
    '德国牧羊犬',
    '雪纳瑞',
    '法斗（法国斗牛犬）',
    '柴犬',
    '中华田园犬',
    '混血（串串）',
    '其他',
  ];

  // 可被API更新的品种列表
  List<String> _catBreeds = List.from(_fallbackCatBreeds);
  List<String> _dogBreeds = List.from(_fallbackDogBreeds);

  List<String> get _currentBreeds {
    switch (widget.species) {
      case 'cat':
        return _catBreeds;
      case 'dog':
        return _dogBreeds;
      default:
        return _customBreedKeys; // 其他物种直接显示手动输入选项
    }
  }

  @override
  void initState() {
    super.initState();
    _filteredBreeds = _currentBreeds;
    _fetchBreeds();
  }

  @override
  void didUpdateWidget(BreedSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.species != widget.species) {
      _searchController.clear();
      _customBreedController.clear();
      _filteredBreeds = _currentBreeds;
      _showCustomInput = false;
      _fetchBreeds();
    }
  }

  Future<void> _fetchBreeds() async {
    // 其他物种不需要请求品种列表
    if (widget.species != 'cat' && widget.species != 'dog') return;

    setState(() => _isLoadingBreeds = true);
    try {
      final response = await ApiService().get(
        '/pets/breeds',
        queryParameters: {'species': widget.species},
      );
      if (response.success &&
          response.data != null &&
          response.data['items'] != null) {
        final items = response.data['items'] as List;
        final breeds = items.map((e) => e['breed_name'].toString()).toList();
        // 追加混血和其他选项
        breeds.addAll(_customBreedKeys);
        if (mounted) {
          setState(() {
            if (widget.species == 'cat') {
              _catBreeds = breeds;
            } else if (widget.species == 'dog') {
              _dogBreeds = breeds;
            }
            _filteredBreeds = _currentBreeds;
          });
        }
      }
    } catch (_) {
      // API 失败，使用硬编码回退数据
    } finally {
      if (mounted) setState(() => _isLoadingBreeds = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customBreedController.dispose();
    _searchFocusNode.dispose();
    _customFocusNode.dispose();
    super.dispose();
  }

  void _filterBreeds(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBreeds = _currentBreeds;
      } else {
        _filteredBreeds = _currentBreeds
            .where((breed) => breed.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择器输入框
        GestureDetector(
          onTap: () {
            if (_showCustomInput) {
              setState(() {
                _showCustomInput = false;
              });
            }
            setState(() {
              _showDropdown = true;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _showDropdown || _showCustomInput
                    ? AppColors.primary
                    : AppColors.borderLight,
                width: _showDropdown || _showCustomInput ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.search,
                    color: AppColors.textTertiary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selectedBreed ?? '搜索或选择品种',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: widget.selectedBreed != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _showDropdown
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),

        // 自定义输入框（混血/其他）
        if (_showCustomInput)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customBreedController,
                    focusNode: _customFocusNode,
                    decoration: InputDecoration(
                      hintText: '请输入品种名称',
                      hintStyle: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _onBreedPicked(value.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _customBreedController.text.trim();
                    if (text.isNotEmpty) {
                      _onBreedPicked(text);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),

        // 下拉列表
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 搜索框
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _filterBreeds,
                    decoration: InputDecoration(
                      hintText: '搜索品种...',
                      hintStyle: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.backgroundSecondary,
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        size: 18,
                        color: AppColors.textTertiary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),

                // 品种列表
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredBreeds.length,
                    itemBuilder: (context, index) {
                      final breed = _filteredBreeds[index];
                      final isSelected = widget.selectedBreed == breed;

                      return InkWell(
                        onTap: () {
                          if (_customBreedKeys.contains(breed)) {
                            // 选择混血/其他 → 弹出输入框
                            setState(() {
                              _showDropdown = false;
                              _showCustomInput = true;
                              _customBreedController.clear();
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _customFocusNode.requestFocus();
                            });
                          } else {
                            _onBreedPicked(breed);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySurface
                                : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  breed,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  LucideIcons.check,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _onBreedPicked(String breed) {
    widget.onBreedSelected(breed);
    setState(() {
      _showDropdown = false;
      _showCustomInput = false;
      _searchController.clear();
      _customBreedController.clear();
    });
  }
}
