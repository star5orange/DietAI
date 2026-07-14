/// 桌宠皮肤配置
/// 定义不同桌宠的外观、名称和资源路径

/// 桌宠皮肤类型
enum PetSkin {
  defaultPet('default', '桌宠一', 'assets/pet/'), // 初始名称为"桌宠一"
  christine('christine', '桌宠二', 'assets/pet/christine/'); // 初始名称为"桌宠二"

  const PetSkin(this.key, this.defaultName, this.assetPath);

  final String key;
  final String defaultName; // 改为默认名称，用户可以自定义
  final String assetPath;

  /// 从字符串键值获取皮肤类型
  static PetSkin fromKey(String key) {
    return PetSkin.values.firstWhere(
      (skin) => skin.key == key,
      orElse: () => PetSkin.defaultPet,
    );
  }
}

/// 桌宠皮肤配置映射
class PetSkinConfig {
  final PetSkin skin;
  final String happyGif;
  final String normalGif;
  final String hungryGif;
  final String anxiousGif;
  final String weakGif;
  final String expectGif;
  final String fatGif;

  const PetSkinConfig({
    required this.skin,
    required this.happyGif,
    required this.normalGif,
    required this.hungryGif,
    required this.anxiousGif,
    required this.weakGif,
    required this.expectGif,
    required this.fatGif,
  });

  /// 根据皮肤类型创建配置
  factory PetSkinConfig.fromSkin(PetSkin skin) {
    final base = skin.assetPath;
    // 默认桌宠使用 calm.gif，克里斯汀使用 normal.gif
    if (skin == PetSkin.defaultPet) {
      return PetSkinConfig(
        skin: skin,
        happyGif: '${base}happy.gif',
        normalGif: '${base}calm.gif', // 默认桌宠使用 calm.gif
        hungryGif: '${base}hungry.gif',
        anxiousGif: '${base}anxious.gif',
        weakGif: '${base}weak.gif',
        expectGif: '${base}expect.gif',
        fatGif: '${base}satisfied.gif', // 默认桌宠使用 satisfied.gif 作为肥胖状态
      );
    }
    return PetSkinConfig(
      skin: skin,
      happyGif: '${base}happy.gif',
      normalGif: '${base}normal.gif',
      hungryGif: '${base}hungry.gif',
      anxiousGif: '${base}anxious.gif',
      weakGif: '${base}weak.gif',
      expectGif: '${base}expect.gif',
      fatGif: '${base}fat.gif',
    );
  }
}

/// 所有桌宠皮肤配置
final Map<PetSkin, PetSkinConfig> kPetSkinConfigs = {
  PetSkin.defaultPet: PetSkinConfig.fromSkin(PetSkin.defaultPet),
  PetSkin.christine: PetSkinConfig.fromSkin(PetSkin.christine),
};
