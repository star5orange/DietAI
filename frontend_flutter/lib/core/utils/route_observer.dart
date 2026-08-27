import 'package:flutter/widgets.dart';

/// 全局路由观察器：供页面通过 RouteAware 监听路由生命周期
/// （如从其他页面返回时自动刷新数据）
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
