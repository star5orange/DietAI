import 'package:flutter/widgets.dart';

/// 追踪弹窗（showDialog、showModalBottomSheet 等）的打开/关闭状态
/// 当有弹窗打开时，桌宠应隐藏
class ModalTrackerObserver extends NavigatorObserver {
  static final ValueNotifier<int> modalCount = ValueNotifier(0);

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      modalCount.value++;
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      modalCount.value = (modalCount.value - 1).clamp(0, 999);
    }
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    if (route is PopupRoute) {
      modalCount.value = (modalCount.value - 1).clamp(0, 999);
    }
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute is PopupRoute) {
      modalCount.value = (modalCount.value - 1).clamp(0, 999);
    }
    if (newRoute is PopupRoute) {
      modalCount.value++;
    }
  }

  /// 当前是否有弹窗打开
  static bool get hasOpenModal => modalCount.value > 0;
}
