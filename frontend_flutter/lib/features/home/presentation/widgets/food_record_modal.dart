import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FoodRecordModal extends StatelessWidget {
  final String mealName;
  final Function(String) onRecordMethod;

  const FoodRecordModal({
    super.key,
    required this.mealName,
    required this.onRecordMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 标题
            const Text(
              '记录食物',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 记录方式选项
            ..._buildRecordOptions(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecordOptions() {
    final options = [
      _RecordOption(
        icon: LucideIcons.scanLine,
        title: 'AI扫描器',
        methodId: 'ai_scan',
        isNew: false,
      ),
      _RecordOption(
        icon: LucideIcons.messageSquare,
        title: '文字描述',
        methodId: 'text_describe',
        isNew: false,
      ),
      _RecordOption(
        icon: LucideIcons.bookmark,
        title: '已保存的菜品',
        methodId: 'saved_meals',
        isNew: false,
      ),
    ];

    return options.map((option) => _buildOptionTile(option)).toList();
  }

  Widget _buildOptionTile(_RecordOption option) {
    return GestureDetector(
      onTap: () => onRecordMethod(option.methodId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标容器
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF3ECC7A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 标题
            Expanded(
              child: Text(
                option.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            
            // 新建标签
            if (option.isNew)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6F61),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '新建',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordOption {
  final IconData icon;
  final String title;
  final String methodId;
  final bool isNew;

  const _RecordOption({
    required this.icon,
    required this.title,
    required this.methodId,
    required this.isNew,
  });
} 