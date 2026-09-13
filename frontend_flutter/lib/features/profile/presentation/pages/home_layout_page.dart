import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/domain/home_layout.dart';
import '../../../home/presentation/providers/home_layout_provider.dart';

/// 首页模块管理：显示/隐藏模块 + 调整顺序（保存到后端，跨设备一致）
class HomeLayoutPage extends ConsumerStatefulWidget {
  const HomeLayoutPage({super.key});

  @override
  ConsumerState<HomeLayoutPage> createState() => _HomeLayoutPageState();
}

class _HomeLayoutPageState extends ConsumerState<HomeLayoutPage> {
  List<String> _order = []; // 滚动主体模块顺序
  Set<String> _hidden = {};
  bool _initialized = false;
  bool _resetting = false;

  /// 用户是否手动调整过顺序：未调整过则不上报顺序，
  /// 避免"只切开关"把默认排序冻结成自定义顺序（那样人群差异化规则就失效了）
  bool _orderTouched = false;

  /// 即点即存：本地立即生效，网络写入做 300ms 防抖（连点/拖动时不刷请求）
  Timer? _saveDebounce;

  /// 预先持有 notifier：dispose() 中不可再用 ref，但 notifier 本身仍存活
  late final HomeLayoutNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(homeLayoutProvider.notifier);
  }

  @override
  void dispose() {
    // 用户快速返回时补一次保存，避免防抖窗口内的改动丢失
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _notifier.save(
        hiddenModules: _hidden.toList(),
        moduleOrder: _orderTouched ? _order : null,
      );
    }
    super.dispose();
  }

  void _initFromLayout(HomeLayout layout) {
    // 只管理当前模式下适用的模块（引导态只显示引导模块，避免出现点了没反应的开关）
    final applicable = {
      for (final m in layout.applicableModules) m.id,
    };
    final order = <String>[
      for (final id in layout.order)
        if (id != HomeModuleId.petSwitcher && applicable.contains(id)) id,
    ];
    // 补齐注册表里有但顺序里没有的模块（版本升级场景）
    for (final m in layout.applicableModules) {
      if (m.id != HomeModuleId.petSwitcher && !order.contains(m.id)) {
        order.add(m.id);
      }
    }
    _order = order;
    _hidden = Set<String>.from(layout.hidden);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), _persist);
  }

  Future<void> _persist() async {
    final ok = await _notifier.save(
      hiddenModules: _hidden.toList(),
      moduleOrder: _orderTouched ? _order : null,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查网络后重试')),
      );
    }
  }

  Future<void> _reset() async {
    _saveDebounce?.cancel();
    setState(() => _resetting = true);
    final ok = await _notifier.save(reset: true);
    if (!mounted) return;
    setState(() {
      _resetting = false;
      _orderTouched = false;
      _initialized = false; // 用后端返回的自动布局重新初始化草稿
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已恢复默认布局' : '操作失败，请重试')),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
      _orderTouched = true;
    });
    _scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(homeLayoutProvider);
    if (!_initialized) {
      _initFromLayout(layout);
      _initialized = true;
    }

    final headerModules = [
      for (final m in layout.applicableModules)
        if (m.region == 'header') m,
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('首页模块管理'),
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        buildDefaultDragHandles: false, // 只有右侧手柄可拖动
        onReorder: _onReorder,
        header: headerModules.isEmpty
            ? null
            : Column(
                children: [
                  for (final m in headerModules)
                    _buildModuleTile(m.id, m.title,
                        locked: m.locked, reorderable: false),
                ],
              ),
        footer: Column(
          children: [
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _resetting ? null : _reset,
                icon: const Icon(LucideIcons.rotateCcw, size: 18),
                label: const Text('恢复默认布局'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        children: [
          for (var i = 0; i < _order.length; i++)
            KeyedSubtree(
              key: ValueKey(_order[i]),
              child: _buildModuleTile(
                _order[i],
                layout.specOf(_order[i])?.title ?? _order[i],
                locked: layout.specOf(_order[i])?.locked ?? false,
                reorderable: true,
                index: i,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    String id,
    String title, {
    required bool locked,
    required bool reorderable,
    int index = 0,
  }) {
    final visible = !_hidden.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (reorderable) ...[
            // 长按/拖动手柄排序（松手即保存）
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  LucideIcons.gripVertical,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: locked ? true : visible,
            onChanged: locked
                ? null
                : (v) {
                    setState(() {
                      if (v) {
                        _hidden.remove(id);
                      } else {
                        _hidden.add(id);
                      }
                    });
                    _scheduleSave(); // 立即生效（防抖写入后端）
                  },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
