import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';

/// 常见关系称谓
const List<String> kRelationshipLabels = [
  '妈妈',
  '爸爸',
  '女儿',
  '儿子',
  '妻子',
  '丈夫',
  '爷爷',
  '奶奶',
  '外公',
  '外婆',
  '孙子',
  '孙女',
  '哥哥',
  '姐姐',
  '弟弟',
  '妹妹',
  '叔叔',
  '阿姨',
];

/// 按性别过滤称谓：1=男 2=女 3=其他/未知（不过滤）
List<String> _filterLabelsByGender(int? gender) {
  if (gender == null || gender == 3) return kRelationshipLabels;
  const maleLabels = {
    '爸爸',
    '儿子',
    '丈夫',
    '爷爷',
    '外公',
    '孙子',
    '哥哥',
    '弟弟',
    '叔叔',
  };
  const femaleLabels = {
    '妈妈',
    '女儿',
    '妻子',
    '奶奶',
    '外婆',
    '孙女',
    '姐姐',
    '妹妹',
    '阿姨',
  };
  final matched = gender == 1 ? maleLabels : femaleLabels;
  return [
    ...kRelationshipLabels.where((l) => matched.contains(l)),
    ...kRelationshipLabels.where((l) => !matched.contains(l)),
  ];
}

/// 弹出「选择关系称谓」对话框，返回选中的称谓（取消/跳过返回 null）
Future<String?> showRelationshipLabelDialog(
  BuildContext context, {
  String title = '对方和你的关系',
  String? initial,
  int? gender,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  String? selected = initial;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              gender == 1 || gender == 2
                  ? '选择对方与你的关系（已按对方性别推荐）'
                  : '选择对方与你的关系（如：妈妈、女儿），方便家人识别：',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filterLabelsByGender(gender).map((label) {
                final isSelected = selected == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selected = label),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '自定义称谓',
                hintText: '如：大哥、外婆、老伴',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => selected = v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('跳过'),
          ),
          TextButton(
            onPressed: () {
              final label = (selected ?? controller.text).trim();
              Navigator.pop(ctx, label.isEmpty ? null : label);
            },
            child: const Text('确定', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    ),
  );

  return result;
}
