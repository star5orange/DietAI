import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/themes/app_colors.dart';
import '../providers/home_layout_provider.dart';

/// 首页偏好问卷（情境式）
///
/// 不直接问"要哪些功能"，而是问身体目标与日常习惯；
/// 由后端根据答案推导首页该展示哪些模块、哪些优先展示。
class HomePreferencePage extends ConsumerStatefulWidget {
  const HomePreferencePage({super.key});

  @override
  ConsumerState<HomePreferencePage> createState() =>
      _HomePreferencePageState();
}

/// 一道题：标题 + 若干选项
class _Question {
  final String key;
  final String title;
  final List<(String, String)> options; // (value, label)

  const _Question(this.key, this.title, this.options);
}

class _HomePreferencePageState extends ConsumerState<HomePreferencePage> {
  static const List<_Question> _questions = [
    _Question('goal', '你的身体目标更接近哪种？', [
      ('leaner', '想再瘦一点'),
      ('stronger', '想更有力量/线条'),
      ('keep', '保持现状就好'),
    ]),
    _Question('checkup', '最近做过体检吗？', [
      ('recent', '一年内做过'),
      ('long_ago', '两年以上没做'),
      ('never', '没做过/不记得'),
    ]),
    _Question('spending', '平时会算伙食花销吗？', [
      ('track', '会记账'),
      ('sometimes', '偶尔看看'),
      ('never', '基本不看'),
    ]),
    _Question('wellness', '换季时会留意时令养生吗？', [
      ('follow', '会关注'),
      ('casual', '偶尔听说'),
      ('no', '不太关注'),
    ]),
    _Question('pet', '家里有毛孩子吗？', [
      ('have', '有'),
      ('plan', '打算养'),
      ('no', '暂时没有'),
    ]),
  ];

  final Map<String, String> _answers = {};
  bool _saving = false;
  bool _initialized = false;

  bool get _allAnswered =>
      _questions.every((q) => (_answers[q.key] ?? '').isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(homeLayoutProvider);
    if (!_initialized) {
      // 回显上次答案，便于以后修改
      final saved = layout.preferenceAnswers;
      for (final q in _questions) {
        final v = saved[q.key];
        if (v != null && v.isNotEmpty) _answers[q.key] = v;
      }
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('了解你的情况'),
        backgroundColor: AppColors.backgroundCard,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          const Text(
            '回答几个小问题，首页会更贴合你的日常',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          for (final q in _questions) ...[
            Text(q.title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in q.options)
                  _optionChip(
                    label: label,
                    selected: _answers[q.key] == value,
                    onTap: () => setState(() => _answers[q.key] = value),
                  ),
              ],
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: (!_allAnswered || _saving) ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_allAnswered ? '完成' : '请回答全部问题',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await ref
        .read(homeLayoutProvider.notifier)
        .saveAnswers(Map<String, String>.from(_answers));
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存失败，请检查网络后重试')),
      );
    }
  }

  Widget _optionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
