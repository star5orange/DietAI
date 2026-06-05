import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../pet/presentation/providers/pet_provider.dart';
import '../../../pet/data/pet_storage.dart';
import '../../../pet/domain/pet_state_calculator.dart';
import '../../../../core/themes/app_colors.dart';

class MyPetPage extends ConsumerStatefulWidget {
  const MyPetPage({super.key});

  @override
  ConsumerState<MyPetPage> createState() => _MyPetPageState();
}

class _MyPetPageState extends ConsumerState<MyPetPage> {
  static const List<Map<String, dynamic>> _petTypes = [
    {
      'type': 'cat',
      'name': '灵巧型',
      'description': '轻盈灵动，陪伴你健康饮食',
      'icon': Icons.pets,
      'color': Color(0xFF2BAF74),
    },
    {
      'type': 'dog',
      'name': '活力型',
      'description': '元气满满，监督你按时吃饭',
      'icon': Icons.cruelty_free,
      'color': Color(0xFFFF9800),
    },
    {
      'type': 'rabbit',
      'name': '温柔型',
      'description': '温婉细腻，提醒你营养均衡',
      'icon': Icons.emoji_nature,
      'color': Color(0xFFE91E63),
    },
    {
      'type': 'bear',
      'name': '守护型',
      'description': '沉稳可靠，守护你的健康目标',
      'icon': Icons.emoji_food_beverage,
      'color': Color(0xFF795548),
    },
  ];

  @override
  Widget build(BuildContext context) {
    final petState = ref.watch(petProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          '我的精灵',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentPetCard(petState),
            const SizedBox(height: 20),
            _buildVisibilityToggle(petState),
            const SizedBox(height: 20),
            _buildPetTypeSelector(petState),
            const SizedBox(height: 20),
            _buildPetInfoCard(petState),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPetCard(PetState petState) {
    final currentPet = _petTypes.firstWhere(
      (p) => p['type'] == petState.petType,
      orElse: () => _petTypes[0],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2BAF74), Color(0xFF4ECDC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2BAF74).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.asset(
              petState.gifPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                currentPet['icon'] as IconData,
                size: 40,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showRenameDialog(petState),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          petState.petName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.pencil,
                        size: 14,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv.${petState.level} ${petState.levelName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _getExpProgress(petState),
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '经验值 ${petState.exp}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _getExpProgress(PetState petState) {
    final currentLevelExp = PetStorage.expForLevel(petState.level);
    final nextLevelExp = PetStorage.expForLevel(petState.level + 1);
    if (nextLevelExp <= currentLevelExp) return 1.0;
    return ((petState.exp - currentLevelExp) / (nextLevelExp - currentLevelExp))
        .clamp(0.0, 1.0);
  }

  Widget _buildVisibilityToggle(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: petState.visible
                  ? const Color(0xFF2BAF74).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              petState.visible ? LucideIcons.eye : LucideIcons.eyeOff,
              color: petState.visible ? const Color(0xFF2BAF74) : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '在首页显示精灵',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  petState.visible ? '精灵正在首页陪伴你' : '精灵已隐藏，长按可重新开启',
                  style: TextStyle(
                    fontSize: 13,
                    color: petState.visible
                        ? const Color(0xFF2BAF74)
                        : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: petState.visible,
            onChanged: (value) {
              ref.read(petProvider.notifier).setPetVisible(value);
            },
            activeColor: const Color(0xFF2BAF74),
          ),
        ],
      ),
    );
  }

  Widget _buildPetTypeSelector(PetState petState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择精灵',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: _petTypes.length,
          itemBuilder: (context, index) {
            final pet = _petTypes[index];
            final isSelected = petState.petType == pet['type'];
            return GestureDetector(
              onTap: () {
                ref
                    .read(petProvider.notifier)
                    .setPetType(pet['type'] as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (pet['color'] as Color)
                        : const Color(0xFFE8E8E8),
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                (pet['color'] as Color).withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: (pet['color'] as Color).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: isSelected
                          ? Image.asset(
                              petState.gifPath,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                pet['icon'] as IconData,
                                size: 30,
                                color: pet['color'] as Color,
                              ),
                            )
                          : Image.asset(
                              'assets/pet/calm.gif',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                pet['icon'] as IconData,
                                size: 30,
                                color: pet['color'] as Color,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pet['name'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? (pet['color'] as Color)
                            : const Color(0xFF222222),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              (pet['color'] as Color).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Lv.${petState.level} ${petState.levelName}',
                              style: TextStyle(
                                fontSize: 11,
                                color: pet['color'] as Color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '经验 ${petState.exp}',
                              style: TextStyle(
                                fontSize: 10,
                                color: (pet['color'] as Color)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '点击选择',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPetInfoCard(PetState petState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '精灵状态',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
              LucideIcons.smile, '心情', _getExpressionName(petState.expression)),
          const Divider(height: 20),
          _buildInfoRow(LucideIcons.trendingUp, '等级',
              'Lv.${petState.level} ${petState.levelName}'),
          const Divider(height: 20),
          _buildInfoRow(LucideIcons.zap, '经验值', '${petState.exp}'),
          const Divider(height: 20),
          _buildInfoRow(LucideIcons.messageCircle, '当前对话', petState.dialogue),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2BAF74)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
      ],
    );
  }

  String _getExpressionName(PetExpression expression) {
    const names = {
      PetExpression.satisfied: '满足',
      PetExpression.anxious: '焦虑',
      PetExpression.happy: '开心',
      PetExpression.calm: '平静',
      PetExpression.expect: '期待',
      PetExpression.weak: '虚弱',
      PetExpression.hungry: '饥饿',
    };
    return names[expression] ?? '平静';
  }

  void _showRenameDialog(PetState petState) {
    final controller = TextEditingController(text: petState.petName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('为你的精灵命名'),
        content: TextField(
          controller: controller,
          maxLength: 10,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '输入新名字',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F7F6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(petProvider.notifier).setPetName(name);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2BAF74),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
