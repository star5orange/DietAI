/// 首页模块布局模型
///
/// 模块 id 必须与后端 `shared/services/home_layout_service.py` 的 HOME_MODULES 保持一致。
library;

/// 首页模块 id 常量
class HomeModuleId {
  static const petSwitcher = 'pet_switcher';
  static const crowdTag = 'crowd_tag';
  static const examEntry = 'exam_entry';
  static const calorie = 'calorie';
  static const water = 'water';
  static const solarTerm = 'solar_term';
  static const cost = 'cost';
  static const favorites = 'favorites';
  static const foodIntake = 'food_intake';
  // 新用户引导模块
  static const onboardingPreference = 'onboarding_preference';
  static const onboardingRecord = 'onboarding_record';
  static const onboardingProfile = 'onboarding_profile';
  static const onboardingConstitution = 'onboarding_constitution';
  static const onboardingAddPet = 'onboarding_add_pet';
}

/// 布局模式
class HomeLayoutMode {
  static const normal = 'normal';
  static const onboarding = 'onboarding';
}

/// 模块元信息（由后端注册表下发）
class HomeModuleSpec {
  final String id;
  final String title;
  final String description;
  final bool locked; // true = 保底模块，不可隐藏
  final String region; // header / body
  final List<String> modes; // 该模块适用的布局模式

  const HomeModuleSpec({
    required this.id,
    required this.title,
    this.description = '',
    this.locked = false,
    this.region = 'body',
    this.modes = const [HomeLayoutMode.normal, HomeLayoutMode.onboarding],
  });

  factory HomeModuleSpec.fromJson(Map<String, dynamic> json) => HomeModuleSpec(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        locked: json['locked'] as bool? ?? false,
        region: json['region'] as String? ?? 'body',
        modes: json['modes'] is List
            ? (json['modes'] as List).map((e) => e.toString()).toList()
            : const [HomeLayoutMode.normal, HomeLayoutMode.onboarding],
      );

  bool appliesTo(String mode) => modes.contains(mode);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'locked': locked,
        'region': region,
        'modes': modes,
      };
}

/// 首页布局（已应用分群规则与用户定制）
class HomeLayout {
  final List<HomeModuleSpec> modules;
  final List<String> order;
  final Set<String> hidden;
  final Map<String, String> variants; // 例如 {'exam_entry': 'compact'}
  final bool isCustomized;
  final Map<String, dynamic> signals;
  final String mode; // normal / onboarding
  final Map<String, dynamic> preferences; // 引导问卷偏好 {focus, interests}

  const HomeLayout({
    required this.modules,
    required this.order,
    required this.hidden,
    this.variants = const {},
    this.isCustomized = false,
    this.signals = const {},
    this.mode = HomeLayoutMode.normal,
    this.preferences = const {},
  });

  bool get isOnboarding => mode == HomeLayoutMode.onboarding;

  /// 问卷选择的主要目标（fat_loss / fitness / balanced）
  String get preferenceFocus => (preferences['focus'] as String?) ?? '';

  /// 问卷选择的关注点（cost / wellness / exam / water / pet）
  List<String> get preferenceInterests => preferences['interests'] is List
      ? (preferences['interests'] as List).map((e) => e.toString()).toList()
      : const [];

  /// 问卷原始答案 {goal, checkup, spending, wellness, pet}
  Map<String, String> get preferenceAnswers {
    final raw = preferences['answers'];
    if (raw is! Map) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  bool isVisible(String id) => !hidden.contains(id);

  String? variantOf(String id) => variants[id];

  /// 当前模式下适用的模块（管理页只展示这些，避免出现点了没反应的开关）
  List<HomeModuleSpec> get applicableModules =>
      [for (final m in modules) if (m.appliesTo(mode)) m];

  HomeModuleSpec? specOf(String id) {
    for (final m in modules) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 滚动主体内的模块（按顺序）
  List<HomeModuleSpec> get bodyModules => [
        for (final id in order)
          if (id != HomeModuleId.petSwitcher)
            if (specOf(id) != null) specOf(id)!,
      ];

  factory HomeLayout.fromJson(Map<String, dynamic> json) {
    final rawModules = json['modules'];
    final rawHidden = json['hidden'];
    final rawVariants = json['variants'];
    final rawSignals = json['signals'];
    final rawPrefs = json['preferences'];

    return HomeLayout(
      modules: rawModules is List
          ? rawModules
              .whereType<Map>()
              .map((e) => HomeModuleSpec.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      order: json['order'] is List
          ? (json['order'] as List).map((e) => e.toString()).toList()
          : _defaultOrder,
      hidden: rawHidden is List
          ? (rawHidden).map((e) => e.toString()).toSet()
          : const {},
      variants: rawVariants is Map
          ? Map<String, String>.fromEntries(
              rawVariants.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())))
          : const {},
      isCustomized: json['is_customized'] as bool? ?? false,
      signals: rawSignals is Map ? Map<String, dynamic>.from(rawSignals) : const {},
      mode: json['mode'] as String? ?? HomeLayoutMode.normal,
      preferences:
          rawPrefs is Map ? Map<String, dynamic>.from(rawPrefs) : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'modules': modules.map((m) => m.toJson()).toList(),
        'order': order,
        'hidden': hidden.toList(),
        'variants': variants,
        'is_customized': isCustomized,
        'signals': signals,
        'mode': mode,
        'preferences': preferences,
      };

  static const List<String> _defaultOrder = [
    HomeModuleId.petSwitcher,
    HomeModuleId.crowdTag,
    HomeModuleId.examEntry,
    HomeModuleId.calorie,
    HomeModuleId.water,
    HomeModuleId.solarTerm,
    HomeModuleId.cost,
    HomeModuleId.favorites,
    HomeModuleId.foodIntake,
  ];

  static const List<HomeModuleSpec> _defaultModules = [
    HomeModuleSpec(id: HomeModuleId.petSwitcher, title: '宠物切换入口', region: 'header',
        description: '“我的健康 / 宠物”切换'),
    HomeModuleSpec(id: HomeModuleId.crowdTag, title: '人群标签卡'),
    HomeModuleSpec(id: HomeModuleId.examEntry, title: '体检报告入口'),
    HomeModuleSpec(id: HomeModuleId.calorie, title: '热量目标', locked: true),
    HomeModuleSpec(id: HomeModuleId.water, title: '今日饮水'),
    HomeModuleSpec(id: HomeModuleId.solarTerm, title: '节气养生'),
    HomeModuleSpec(id: HomeModuleId.cost, title: '消费概览'),
    HomeModuleSpec(id: HomeModuleId.favorites, title: '常用餐食'),
    HomeModuleSpec(id: HomeModuleId.foodIntake, title: '饮食记录', locked: true),
  ];

  /// 兜底布局：接口不可用时全部可见、按默认顺序，避免模块凭空消失
  static HomeLayout fallback() => const HomeLayout(
        modules: _defaultModules,
        order: _defaultOrder,
        hidden: {},
      );
}
