import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../camera/presentation/pages/camera_page.dart';
import '../../../home/presentation/pages/text_describe_page.dart';
import '../../../home/presentation/pages/voice_record_page.dart';

/// 代记录饮食页面（中转页）
/// 让家人为其他家人记录饮食：选择餐次 + 记录方式（拍照/语音/文字）
class ProxyRecordPage extends StatefulWidget {
  final int targetUserId;
  final String targetUserName;

  const ProxyRecordPage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<ProxyRecordPage> createState() => _ProxyRecordPageState();
}

class _ProxyRecordPageState extends State<ProxyRecordPage> {
  String _selectedMealType = 'breakfast';

  static const List<Map<String, String>> _mealTypes = [
    {'value': 'breakfast', 'label': '早餐'},
    {'value': 'lunch', 'label': '午餐'},
    {'value': 'dinner', 'label': '晚餐'},
    {'value': 'snack', 'label': '加餐'},
  ];

  int _getMealTypeInt(String value) {
    switch (value) {
      case 'breakfast':
        return 1;
      case 'lunch':
        return 2;
      case 'dinner':
        return 3;
      default:
        return 4;
    }
  }

  String _getMealLabel(String value) {
    return _mealTypes.firstWhere((t) => t['value'] == value)['label']!;
  }

  void _navigateToRecordPage(String method) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final recordTime = DateTime.now().toIso8601String();
    final mealType = _getMealTypeInt(_selectedMealType);
    final mealName = _getMealLabel(_selectedMealType);

    switch (method) {
      case 'ai_scan':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraPage(
              mealName: mealName,
              mealType: mealType,
              recordDate: dateStr,
              recordTime: recordTime,
              proxyTargetUserId: widget.targetUserId,
              proxyTargetName: widget.targetUserName,
            ),
          ),
        );
        break;
      case 'voice_record':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VoiceRecordPage(
              mealName: mealName,
              mealType: mealType,
              recordDate: dateStr,
              recordTime: recordTime,
              proxyTargetUserId: widget.targetUserId,
            ),
          ),
        );
        break;
      case 'text_describe':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextDescribePage(
              mealName: mealName,
              mealType: mealType,
              recordDate: dateStr,
              recordTime: recordTime,
              proxyTargetUserId: widget.targetUserId,
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('帮${widget.targetUserName}记录'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '正在为${widget.targetUserName}记录饮食，记录将计入其账户，并由其本人收到通知',
                      style: TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 餐次选择
            const Text(
              '餐次',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _mealTypes.map((type) {
                final value = type['value']!;
                final label = type['label']!;
                final isSelected = _selectedMealType == value;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMealType = value);
                    }
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey[700],
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 记录方式
            const Text(
              '选择记录方式',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildMethodTile(
              icon: Icons.camera_alt,
              color: Colors.orange,
              title: '拍照记录',
              subtitle: '拍摄食物照片，AI自动识别营养',
              onTap: () => _navigateToRecordPage('ai_scan'),
            ),
            _buildMethodTile(
              icon: Icons.mic,
              color: Colors.blue,
              title: '语音记录',
              subtitle: '说出食物名称，语音识别记录',
              onTap: () => _navigateToRecordPage('voice_record'),
            ),
            _buildMethodTile(
              icon: Icons.keyboard_alt_outlined,
              color: AppColors.primary,
              title: '手动输入',
              subtitle: '手动输入食物名称与营养信息',
              onTap: () => _navigateToRecordPage('text_describe'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
