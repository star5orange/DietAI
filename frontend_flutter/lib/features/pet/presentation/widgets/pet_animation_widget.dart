import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../providers/pet_provider.dart';
import '../../domain/pet_state_calculator.dart';
import '../../domain/pet_skin_config.dart';

/// 宠物心情枚举
enum PetMood { normal, happy, hungry, anxious, weak }

/// 心情配置
class MoodConfig {
  final String name;
  final String emoji;
  final Color color;
  final Color bgColor;
  final List<String> dialogues;
  final IconData icon;
  final String Function(PetSkin skin) getGifAsset;

  const MoodConfig({
    required this.name,
    required this.emoji,
    required this.color,
    required this.bgColor,
    required this.dialogues,
    required this.icon,
    required this.getGifAsset,
  });

  /// 获取指定皮肤的GIF资源路径
  String gifAssetFor(PetSkin skin) => getGifAsset(skin);
}

/// 心情配置映射（根据皮肤动态获取GIF路径）
final Map<PetMood, MoodConfig> kMoodConfigs = {
  PetMood.happy: MoodConfig(
    name: '开心',
    emoji: '😊',
    color: AppColors.success,
    bgColor: const Color(0xFFE8F5E9),
    dialogues: ['今天吃得很棒哦！', '营养均衡，继续保持~', '完美的一天！', '好开心~'],
    icon: LucideIcons.smile,
    getGifAsset: (skin) =>
        kPetSkinConfigs[skin]?.happyGif ?? 'assets/pet/happy.gif',
  ),
  PetMood.normal: MoodConfig(
    name: '正常',
    emoji: '🙂',
    color: AppColors.primary,
    bgColor: const Color(0xFFE3F2FD),
    dialogues: ['今天也要好好吃饭哦', '记得记录饮食~', '嗯~', '继续加油！'],
    icon: LucideIcons.meh,
    getGifAsset: (skin) =>
        kPetSkinConfigs[skin]?.normalGif ??
        'assets/pet/calm.gif', // 后备使用 calm.gif
  ),
  PetMood.hungry: MoodConfig(
    name: '饿了',
    emoji: '😋',
    color: AppColors.warning,
    bgColor: const Color(0xFFFFF3E0),
    dialogues: ['肚子饿了...', '该吃饭啦！', '想吃东西~', '好饿~'],
    icon: LucideIcons.utensils,
    getGifAsset: (skin) =>
        kPetSkinConfigs[skin]?.hungryGif ?? 'assets/pet/hungry.gif',
  ),
  PetMood.anxious: MoodConfig(
    name: '焦虑',
    emoji: '😰',
    color: AppColors.info,
    bgColor: const Color(0xFFE1F5FE),
    dialogues: ['记得多喝水哦...', '有点担心...', '要规律饮食哦~'],
    icon: LucideIcons.cloudRain,
    getGifAsset: (skin) =>
        kPetSkinConfigs[skin]?.anxiousGif ?? 'assets/pet/anxious.gif',
  ),
  PetMood.weak: MoodConfig(
    name: '虚弱',
    emoji: '😢',
    color: AppColors.error,
    bgColor: const Color(0xFFFFEBEE),
    dialogues: ['好饿...还没吃东西...', '记得按时吃饭哦...', '...'],
    icon: LucideIcons.heartCrack,
    getGifAsset: (skin) =>
        kPetSkinConfigs[skin]?.weakGif ?? 'assets/pet/weak.gif',
  ),
};

/// 宠物动画组件
/// 展示宠物状态、心情动画、等级徽章
class PetAnimationWidget extends ConsumerStatefulWidget {
  final double size;
  final bool showLevelBadge;
  final bool showMoodIndicator;
  final bool enableInteraction;
  final PetMood? mood;
  final int? level;
  final int? exp;
  final int? maxExp;
  final PetSkin? skin; // 可选的皮肤参数

  const PetAnimationWidget({
    super.key,
    this.size = 120,
    this.showLevelBadge = false,
    this.showMoodIndicator = false,
    this.enableInteraction = false,
    this.mood,
    this.level,
    this.exp,
    this.maxExp,
    this.skin,
  });

  @override
  ConsumerState<PetAnimationWidget> createState() => _PetAnimationWidgetState();
}

class _PetAnimationWidgetState extends ConsumerState<PetAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  int _interactionCount = 0;
  String? _showDialogue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  PetMood _getCurrentMood() {
    if (widget.mood != null) return widget.mood!;
    // 从 provider 获取
    final petState = ref.watch(petProvider);
    final expression = petState.expression;
    switch (expression) {
      case PetExpression.satisfied:
      case PetExpression.happy:
        return PetMood.happy;
      case PetExpression.hungry:
        return PetMood.hungry;
      case PetExpression.anxious:
        return PetMood.anxious;
      case PetExpression.weak:
        return PetMood.weak;
      default:
        return PetMood.normal;
    }
  }

  MoodConfig _getMoodConfig(PetMood mood) {
    return kMoodConfigs[mood] ?? kMoodConfigs[PetMood.normal]!;
  }

  /// 获取当前皮肤类型
  PetSkin _getCurrentSkin() {
    if (widget.skin != null) return widget.skin!;
    // 从 provider 获取（如果存在）
    // 这里暂时返回默认皮肤，后续可以从 petProvider 获取
    return PetSkin.defaultPet;
  }

  void _handleInteraction() {
    setState(() {
      _interactionCount++;
      final mood = _getCurrentMood();
      final config = _getMoodConfig(mood);
      _showDialogue = config
          .dialogues[DateTime.now().millisecond % config.dialogues.length];
    });

    // 触发经验增加
    ref.read(petProvider.notifier).addExp(5);

    // 3秒后清除对话
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showDialogue = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mood = _getCurrentMood();
    final config = _getMoodConfig(mood);
    final currentSkin = _getCurrentSkin();

    return GestureDetector(
      onTap: widget.enableInteraction ? _handleInteraction : null,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 宠物主体动画
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -_bounceAnimation.value),
                child: child,
              );
            },
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: widget.size,
                height: widget.size,
                child: ClipOval(
                  child: Image.asset(
                    config.gifAssetFor(currentSkin), // 使用皮肤相关的GIF路径
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            config.bgColor,
                            config.bgColor.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                      child: Icon(
                        config.icon,
                        size: widget.size * 0.5,
                        color: config.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 对话气泡
          if (_showDialogue != null)
            Positioned(
              top: -30,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.lightShadow,
                  ),
                  child: Text(
                    _showDialogue!,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: config.color),
                  ),
                ),
              ),
            ),

          // 等级徽章
          if (widget.showLevelBadge)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Lv.${widget.level ?? ref.watch(petProvider).level}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // 心情指示器
          if (widget.showMoodIndicator)
            Positioned(
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.lightShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      config.icon,
                      size: 14,
                      color: config.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      config.name,
                      style: AppTextStyles.caption.copyWith(
                        color: config.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 互动效果 - 经验值飘字
          if (_interactionCount > 0)
            Positioned(
              top: -10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 1 - value,
                    child: Transform.translate(
                      offset: Offset(0, -20 * value),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.zap,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 2),
                          Text(
                            '+${_interactionCount * 5} EXP',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                onEnd: () => setState(() => _interactionCount = 0),
              ),
            ),

          // 经验条（可选）
          if (widget.exp != null &&
              widget.maxExp != null &&
              widget.showLevelBadge)
            Positioned(
              bottom: -20,
              child: SizedBox(
                width: widget.size * 0.8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (widget.exp! / widget.maxExp!).clamp(0.0, 1.0),
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(config.color),
                    minHeight: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
