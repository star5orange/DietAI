import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

class RecipeDetailPage extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] ?? '养生食谱';
    final description = recipe['description'] ?? '';
    final benefits = recipe['benefits'] ?? '';
    final ingredients = recipe['ingredients'] as List? ?? [];
    final steps = recipe['steps'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('食谱详情',
            style: AppTextStyles.h5.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食谱头部
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B86E5), Color(0xFF36D1DC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.soup,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                  if (benefits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.heart,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('功效：$benefits',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 食材清单
            if (ingredients.isNotEmpty) ...[
              _buildSectionTitle(
                  LucideIcons.shoppingBag, '食材清单', const Color(0xFF43A047)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundCard,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.lightShadow,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ingredients
                      .map((item) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF43A047)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFF43A047)
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Text(item.toString(),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF43A047),
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 烹饪步骤
            if (steps.isNotEmpty) ...[
              _buildSectionTitle(
                  LucideIcons.listOrdered, '烹饪步骤', const Color(0xFF5B86E5)),
              const SizedBox(height: 10),
              ...steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B86E5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text('${index + 1}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundCard,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: AppColors.lightShadow,
                          ),
                          child: Text(step.toString(),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 20),

            // 温馨提示
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, color: AppColors.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('温馨提示：食疗效果因人而异，建议根据自身体质适量食用。如有特殊疾病，请遵医嘱。',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.info, height: 1.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
