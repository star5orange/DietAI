import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 浮动操作按钮区域
class FloatingActionSection extends StatelessWidget {
  final VoidCallback onSaveRecord;
  final VoidCallback onShareResult;

  const FloatingActionSection({
    super.key,
    required this.onSaveRecord,
    required this.onShareResult,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 分享按钮
              Expanded(
                flex: 1,
                child: Container(
                  height: 56,
                  margin: const EdgeInsets.only(right: 12),
                  child: ElevatedButton(
                    onPressed: onShareResult,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      foregroundColor: const Color(0xFF2BAF74),
                      elevation: 8,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.share2,
                      size: 20,
                    ),
                  ),
                ),
              ),
              
              // 保存记录按钮
              Expanded(
                flex: 3,
                child: Container(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onSaveRecord,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BAF74),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF2BAF74).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.check,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '记录这餐',
                          style: TextStyle(
                            fontSize: 16,
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
        ),
      ),
    );
  }
}