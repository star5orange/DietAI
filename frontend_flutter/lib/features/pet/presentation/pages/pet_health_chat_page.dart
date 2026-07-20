import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../chat/presentation/pages/chat_page.dart';

/// 宠物健康咨询专用聊天页面
/// 封装通用 ChatPage，预设 sessionType=6（宠物健康咨询）
/// 并在顶部显示当前宠物信息
class PetHealthChatPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> pet;

  const PetHealthChatPage({super.key, required this.pet});

  @override
  ConsumerState<PetHealthChatPage> createState() => _PetHealthChatPageState();
}

class _PetHealthChatPageState extends ConsumerState<PetHealthChatPage> {
  @override
  Widget build(BuildContext context) {
    final name = (widget.pet['name'] as String?) ?? '宠物';
    final species = (widget.pet['species'] as String?) ?? 'cat';
    final breed = (widget.pet['breed'] as String?) ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // 顶部宠物信息卡片
          Container(
            color: Colors.white,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(LucideIcons.chevronLeft,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                species == 'dog'
                                    ? LucideIcons.dog
                                    : LucideIcons.cat,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$name 健康咨询',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  // 宠物信息摘要卡片
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              species == 'dog'
                                  ? LucideIcons.dog
                                  : LucideIcons.cat,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${species == 'dog' ? '狗' : '猫'} · ${breed.isNotEmpty ? breed : '未知品种'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.shieldCheck,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'AI顾问',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 免责声明
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.alertTriangle,
                            color: AppColors.warning, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI建议仅供参考，宠物健康问题请咨询专业兽医',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 聊天内容区域（复用通用 ChatPage，隐藏其 AppBar）
          Expanded(
            child: ChatPage(
              sessionType: 6, // 宠物健康咨询
              title: '$name 健康咨询',
              hideAppBar: true, // 使用外层的顶部卡片
            ),
          ),
        ],
      ),
    );
  }
}
