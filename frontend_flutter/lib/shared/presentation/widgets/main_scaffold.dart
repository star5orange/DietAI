import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/landing_preference.dart';
import '../../../core/services/modal_tracker.dart';
import '../../../features/pet/presentation/widgets/pet_widget.dart';
import '../../../features/pet/presentation/providers/pet_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const MainScaffold({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  double _petLeft = -1;
  double _petTop = -1;
  bool _positionLoaded = false;
  bool _showRecycleBin = false;
  bool _isDragging = false;
  bool _modalOpen = false;

  @override
  void initState() {
    super.initState();
    _initPetPosition();
    ModalTrackerObserver.modalCount.addListener(_onModalCountChanged);
  }

  @override
  void dispose() {
    ModalTrackerObserver.modalCount.removeListener(_onModalCountChanged);
    super.dispose();
  }

  void _onModalCountChanged() {
    final isOpen = ModalTrackerObserver.hasOpenModal;
    if (isOpen != _modalOpen) {
      setState(() {
        _modalOpen = isOpen;
      });
    }
  }

  Future<void> _initPetPosition() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    final storage = ref.read(petProvider.notifier).storage;
    if (storage != null) {
      setState(() {
        _petLeft = storage.positionX;
        _petTop = storage.positionY;
        _positionLoaded = true;
      });
    } else {
      _positionLoaded = true;
    }
  }

  bool _isOverRecycleBin() {
    final screenSize = MediaQuery.of(context).size;
    final binCenterX = screenSize.width / 2;
    final binCenterY = screenSize.height - 160;
    final distance = ((_petLeft + 48 - binCenterX).abs() +
        (_petTop + 48 - binCenterY).abs());
    return distance < 120;
  }

  void _onPetLongPress() {
    setState(() {
      _showRecycleBin = true;
      _isDragging = true;
    });
  }

  void _onPetDragEnd() {
    if (_showRecycleBin && _isOverRecycleBin()) {
      _confirmHidePet();
    }
    setState(() {
      _showRecycleBin = false;
      _isDragging = false;
    });
    final storage = ref.read(petProvider.notifier).storage;
    if (storage != null) {
      storage.positionX = _petLeft;
      storage.positionY = _petTop;
    }
  }

  void _confirmHidePet() {
    final storage = ref.read(petProvider.notifier).storage;
    if (storage != null && storage.skipHideConfirm) {
      ref.read(petProvider.notifier).setPetVisible(false);
      return;
    }

    bool dontRemind = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('隐藏精灵'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('确定要隐藏精灵吗？\n您可以在「个人中心 → 我的精灵」中重新开启显示。'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setDialogState(() {
                    dontRemind = !dontRemind;
                  });
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: dontRemind,
                        onChanged: (v) {
                          setDialogState(() {
                            dontRemind = v ?? false;
                          });
                        },
                        activeColor: const Color(0xFF2BAF74),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '下次不再提醒',
                      style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (dontRemind) {
                  storage?.skipHideConfirm = true;
                }
                Navigator.of(ctx).pop();
                ref.read(petProvider.notifier).setPetVisible(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('确定隐藏'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final petState = ref.watch(petProvider);
    final showPet = _positionLoaded && petState.visible && !_modalOpen;

    if (_positionLoaded) {
      final storage = ref.read(petProvider.notifier).storage;
      if (storage != null && (storage.positionX < 0 || storage.positionY < 0)) {
        _petLeft = 16;
        _petTop = screenSize.height - 280;
      } else if (_petLeft < 0) {
        _petLeft = 16;
        _petTop = screenSize.height - 280;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (showPet)
            Positioned(
              left: _petLeft,
              top: _petTop,
              child: GestureDetector(
                onLongPress: _onPetLongPress,
                onPanUpdate: (details) {
                  setState(() {
                    _petLeft = (_petLeft + details.delta.dx)
                        .clamp(0.0, screenSize.width - 96);
                    _petTop = (_petTop + details.delta.dy)
                        .clamp(0.0, screenSize.height - 200);
                  });
                  if (!_isDragging) {
                    setState(() {
                      _isDragging = true;
                      _showRecycleBin = true;
                    });
                  }
                },
                onPanEnd: (_) => _onPetDragEnd(),
                child: AnimatedOpacity(
                  opacity: _showRecycleBin && _isOverRecycleBin() ? 0.4 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const PetWidget(
                    size: 96,
                    draggable: true,
                    showBubble: true,
                  ),
                ),
              ),
            ),
          if (_showRecycleBin)
            Positioned(
              left: screenSize.width / 2 - 40,
              top: screenSize.height - 160,
              child: AnimatedScale(
                scale: _isOverRecycleBin() ? 1.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isOverRecycleBin()
                        ? Colors.red.withValues(alpha: 0.9)
                        : Colors.red.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 28),
                      SizedBox(height: 2),
                      Text(
                        '隐藏',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  /// 域高亮：非 tab 页面按业务归属点亮所属 tab（如体检页点亮「健康」、家人页点亮「社交」）
  bool _inDomain(String location, String tabRoute) {
    switch (tabRoute) {
      case AppConstants.homeRoute: // 首页域：对话页 + 数据看板（跟随启动偏好）
        return location == '/' || location == '/dashboard';
      case AppConstants.historyRoute:
        return location == '/history';
      case AppConstants.healthRoute: // 健康域：健康/体重趋势/养生/体检/断食/花销/宠物健康
        return location == '/health' ||
            location == '/weight-trend' ||
            location == '/constitution-quiz' ||
            location == '/wellness' ||
            location == '/cost-statistics' ||
            location.startsWith('/exam') ||
            location.startsWith('/fasting') ||
            location == '/my-pet' ||
            location == '/add-pet' ||
            location == '/pet-feeding' ||
            location == '/pet-food-library' ||
            location == '/generate-pet-avatar' ||
            location == '/pet-weekly-report' ||
            location.startsWith('/real-pet-detail');
      case AppConstants.socialRoute: // 社交域：社交/家人看板/家人周报等
        return location.startsWith('/social') ||
            location == '/family-dashboard' ||
            location.startsWith('/family');
      case AppConstants.profileRoute: // 我的域：我的/提醒设置/AI 风格
        return location == '/profile' ||
            location == '/reminder-settings' ||
            location == '/advisor-style';
      default:
        return location == tabRoute;
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    // 「首页」tab 跟随启动落地偏好动态指向（对话页 ↔ 数据看板）
    final landing = ref.watch(landingProvider);
    final homeTabRoute = landing == LandingPreference.dashboard
        ? '/dashboard'
        : AppConstants.homeRoute;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.blackWithOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                icon: LucideIcons.home,
                label: '首页',
                route: homeTabRoute,
                isActive: _inDomain(currentLocation, AppConstants.homeRoute),
              ),
              _buildNavItem(
                context,
                icon: LucideIcons.clock,
                label: '历史',
                route: AppConstants.historyRoute,
                isActive: _inDomain(currentLocation, AppConstants.historyRoute),
              ),
              _buildNavItem(
                context,
                icon: LucideIcons.activity,
                label: '健康',
                route: AppConstants.healthRoute,
                isActive: _inDomain(currentLocation, AppConstants.healthRoute),
              ),
              _buildNavItem(
                context,
                icon: LucideIcons.users,
                label: '社交',
                route: AppConstants.socialRoute,
                isActive: _inDomain(currentLocation, AppConstants.socialRoute),
              ),
              _buildNavItem(
                context,
                icon: LucideIcons.user,
                label: '我的',
                route: AppConstants.profileRoute,
                isActive: _inDomain(currentLocation, AppConstants.profileRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    final color = isActive ? AppColors.primary : AppColors.textTertiary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryWithOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
