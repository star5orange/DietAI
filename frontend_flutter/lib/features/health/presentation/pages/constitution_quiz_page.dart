import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../../../../features/profile/domain/services/user_service.dart';

class ConstitutionQuizPage extends StatefulWidget {
  const ConstitutionQuizPage({super.key});

  @override
  State<ConstitutionQuizPage> createState() => _ConstitutionQuizPageState();
}

class _ConstitutionQuizPageState extends State<ConstitutionQuizPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, int> _answers = {};
  bool _isSubmitting = false;
  String? _result;
  String? _resultDescription;
  String? _resultAdvice;

  static const _questions = [
    _QuizQuestion(
      title: '体力与精力',
      question: '您平时的体力和精力状态如何？',
      options: [
        _QuizOption(text: '精力充沛，不易疲劳', scores: {'pinghe': 3}),
        _QuizOption(text: '容易疲劳，气短懒言', scores: {'qixu': 3}),
        _QuizOption(text: '经常感到手脚发凉', scores: {'yangxu': 3}),
        _QuizOption(text: '容易口干咽燥', scores: {'yinxu': 3}),
      ],
    ),
    _QuizQuestion(
      title: '怕冷或怕热',
      question: '您对冷热的感受如何？',
      options: [
        _QuizOption(text: '耐寒耐热，适应力强', scores: {'pinghe': 3}),
        _QuizOption(text: '特别怕冷，喜热饮食', scores: {'yangxu': 3}),
        _QuizOption(text: '特别怕热，喜冷饮食', scores: {'shire': 2, 'yinxu': 2}),
        _QuizOption(text: '冬天怕冷夏天怕热', scores: {'qixu': 2}),
      ],
    ),
    _QuizQuestion(
      title: '睡眠质量',
      question: '您的睡眠状况如何？',
      options: [
        _QuizOption(text: '睡眠良好，精力恢复快', scores: {'pinghe': 3}),
        _QuizOption(text: '入睡困难或多梦易醒', scores: {'qiyu': 3}),
        _QuizOption(text: '睡眠浅，容易惊醒', scores: {'yinxu': 2, 'qixu': 1}),
        _QuizOption(text: '嗜睡，睡不解乏', scores: {'tanshi': 3}),
      ],
    ),
    _QuizQuestion(
      title: '情绪状态',
      question: '您平时的情绪状态如何？',
      options: [
        _QuizOption(text: '情绪稳定，心态平和', scores: {'pinghe': 3}),
        _QuizOption(text: '容易忧郁，多愁善感', scores: {'qiyu': 3}),
        _QuizOption(text: '容易急躁易怒', scores: {'shire': 2, 'xueyu': 1}),
        _QuizOption(text: '容易紧张焦虑', scores: {'qixu': 2, 'qiyu': 1}),
      ],
    ),
    _QuizQuestion(
      title: '体型特征',
      question: '您的体型特征更接近哪种？',
      options: [
        _QuizOption(text: '体型匀称，不胖不瘦', scores: {'pinghe': 3}),
        _QuizOption(text: '偏胖，腹部松软', scores: {'tanshi': 3}),
        _QuizOption(text: '偏瘦，肌肉松软', scores: {'qixu': 2, 'yinxu': 1}),
        _QuizOption(text: '偏胖，面部油腻', scores: {'shire': 3}),
      ],
    ),
    _QuizQuestion(
      title: '皮肤状况',
      question: '您的皮肤状况如何？',
      options: [
        _QuizOption(text: '皮肤润泽，有弹性', scores: {'pinghe': 3}),
        _QuizOption(text: '皮肤偏暗，有色素沉着', scores: {'xueyu': 3}),
        _QuizOption(text: '皮肤容易过敏', scores: {'tebing': 3}),
        _QuizOption(text: '皮肤偏油，容易长痘', scores: {'shire': 2, 'tanshi': 1}),
      ],
    ),
    _QuizQuestion(
      title: '口唇与口味',
      question: '您的口唇和口味偏好如何？',
      options: [
        _QuizOption(text: '口唇红润，口味正常', scores: {'pinghe': 3}),
        _QuizOption(text: '口淡无味，食欲不振', scores: {'qixu': 2, 'yangxu': 1}),
        _QuizOption(text: '口苦口干，口臭', scores: {'shire': 3}),
        _QuizOption(text: '口干不欲饮', scores: {'xueyu': 2, 'yinxu': 1}),
      ],
    ),
    _QuizQuestion(
      title: '消化功能',
      question: '您的消化功能如何？',
      options: [
        _QuizOption(text: '消化良好，食欲正常', scores: {'pinghe': 3}),
        _QuizOption(text: '容易腹胀，消化不良', scores: {'qixu': 2, 'tanshi': 1}),
        _QuizOption(text: '大便黏滞不爽', scores: {'shire': 2, 'tanshi': 2}),
        _QuizOption(text: '大便偏稀，容易腹泻', scores: {'yangxu': 2, 'qixu': 1}),
      ],
    ),
    _QuizQuestion(
      title: '出汗情况',
      question: '您的出汗情况如何？',
      options: [
        _QuizOption(text: '出汗正常，运动后微汗', scores: {'pinghe': 3}),
        _QuizOption(text: '容易自汗（白天出汗）', scores: {'qixu': 3}),
        _QuizOption(text: '容易盗汗（夜间出汗）', scores: {'yinxu': 3}),
        _QuizOption(text: '出汗较多，黏腻不爽', scores: {'shire': 2, 'tanshi': 1}),
      ],
    ),
    _QuizQuestion(
      title: '舌象特征',
      question: '您的舌头状况更接近哪种？',
      options: [
        _QuizOption(text: '舌色淡红，苔薄白', scores: {'pinghe': 3}),
        _QuizOption(text: '舌淡胖，有齿痕', scores: {'qixu': 2, 'yangxu': 1}),
        _QuizOption(text: '舌红少苔', scores: {'yinxu': 3}),
        _QuizOption(text: '舌苔厚腻', scores: {'tanshi': 2, 'shire': 1}),
      ],
    ),
    _QuizQuestion(
      title: '疼痛与不适',
      question: '您是否有以下不适？',
      options: [
        _QuizOption(text: '无明显不适', scores: {'pinghe': 3}),
        _QuizOption(text: '身体某处刺痛，位置固定', scores: {'xueyu': 3}),
        _QuizOption(text: '关节酸痛，怕风怕冷', scores: {'yangxu': 2, 'qixu': 1}),
        _QuizOption(text: '胸闷叹气，胁肋胀痛', scores: {'qiyu': 3}),
      ],
    ),
    _QuizQuestion(
      title: '过敏与敏感',
      question: '您对环境或食物的敏感程度如何？',
      options: [
        _QuizOption(text: '不过敏，适应力强', scores: {'pinghe': 3}),
        _QuizOption(text: '容易过敏（花粉、食物等）', scores: {'tebing': 3}),
        _QuizOption(text: '对药物比较敏感', scores: {'tebing': 2, 'qixu': 1}),
        _QuizOption(text: '换季时容易不适', scores: {'qixu': 2, 'yangxu': 1}),
      ],
    ),
  ];

  static const _constitutionInfo = {
    'pinghe': _ConstitutionInfo(
      name: '平和质',
      emoji: '☯️',
      color: Color(0xFF22C55E),
      description: '阴阳气血调和，体态适中，面色润泽，精力充沛，睡眠良好，性格随和开朗。',
      advice: '继续保持均衡饮食、适度运动、规律作息的良好习惯。饮食宜粗细搭配，荤素合理，不宜偏食。',
    ),
    'qixu': _ConstitutionInfo(
      name: '气虚质',
      emoji: '💨',
      color: Color(0xFFEAB308),
      description: '元气不足，容易疲劳，气短懒言，易出汗，抵抗力较弱，容易感冒。',
      advice: '宜食益气健脾食物：山药、黄芪、大枣、小米。避免过度劳累，适合散步、太极拳等柔和运动。',
    ),
    'yangxu': _ConstitutionInfo(
      emoji: '🔥',
      name: '阳虚质',
      color: Color(0xFFEF4444),
      description: '阳气不足，手足不温，畏寒怕冷，喜热饮食，精神不振，面色柔白。',
      advice: '宜食温阳食物：羊肉、生姜、桂圆、核桃。注意保暖，避免生冷食物，适合慢跑、日光浴。',
    ),
    'yinxu': _ConstitutionInfo(
      emoji: '🌙',
      name: '阴虚质',
      color: Color(0xFF8B5CF6),
      description: '阴液亏少，口燥咽干，手足心热，易烦躁，睡眠偏少，体型偏瘦。',
      advice: '宜食滋阴食物：银耳、百合、枸杞、鸭肉。避免辛辣燥热食物，保持心情平和，避免熬夜。',
    ),
    'tanshi': _ConstitutionInfo(
      emoji: '💧',
      name: '痰湿质',
      color: Color(0xFF06B6D4),
      description: '痰湿凝聚，体型肥胖，腹部松软，面部油腻，多汗且黏，口黏腻。',
      advice: '宜食健脾利湿食物：薏米、冬瓜、荷叶、白萝卜。减少甜食油腻，增加运动量，控制体重。',
    ),
    'shire': _ConstitutionInfo(
      emoji: '🌡️',
      name: '湿热质',
      color: Color(0xFFF97316),
      description: '湿热内蕴，面垢油光，易生痤疮，口苦口干，身重困倦，大便黏滞。',
      advice: '宜食清热利湿食物：绿豆、苦瓜、黄瓜、莲藕。忌辛辣油腻，保持皮肤清洁，居住环境宜通风干燥。',
    ),
    'xueyu': _ConstitutionInfo(
      emoji: '🩸',
      name: '血瘀质',
      color: Color(0xFFDC2626),
      description: '血行不畅，肤色晦暗，色素沉着，容易出现瘀斑，口唇暗淡。',
      advice: '宜食活血化瘀食物：山楂、黑豆、醋、红花。适度运动促进血液循环，保持心情舒畅。',
    ),
    'qiyu': _ConstitutionInfo(
      emoji: '😔',
      name: '气郁质',
      color: Color(0xFF6366F1),
      description: '气机郁滞，神情抑郁，忧虑脆弱，形体瘦弱，烦闷不乐，胸胁胀痛。',
      advice: '宜食行气解郁食物：玫瑰花、柑橘、萝卜、佛手。多参加社交活动，听音乐，保持乐观心态。',
    ),
    'tebing': _ConstitutionInfo(
      emoji: '🛡️',
      name: '特禀质',
      color: Color(0xFFEC4899),
      description: '先天禀赋不足或过敏体质，易对花粉、食物、药物等过敏，皮肤易起荨麻疹。',
      advice: '明确过敏原并避免接触。饮食宜清淡均衡，增强体质。季节交替时注意防护。',
    ),
  };

  void _selectOption(int questionIndex, int optionIndex) {
    setState(() {
      _answers[questionIndex] = optionIndex;
    });
  }

  void _nextPage() {
    if (_currentPage < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  void _calculateResult() {
    final scores = <String, int>{};
    for (final entry in _answers.entries) {
      final question = _questions[entry.key];
      final selectedOption = question.options[entry.value];
      for (final score in selectedOption.scores.entries) {
        scores[score.key] = (scores[score.key] ?? 0) + score.value;
      }
    }

    String topConstitution = 'pinghe';
    int topScore = 0;
    for (final entry in scores.entries) {
      if (entry.value > topScore) {
        topScore = entry.value;
        topConstitution = entry.key;
      }
    }

    final info = _constitutionInfo[topConstitution]!;
    setState(() {
      _result = topConstitution;
      _resultDescription = info.description;
      _resultAdvice = info.advice;
    });
  }

  Future<void> _submitResult() async {
    setState(() => _isSubmitting = true);
    try {
      final userService = UserService(ApiService());
      final result = await userService.updateUserProfile(
        UserProfileUpdateRequest(constitutionType: _result),
      );
      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('体质类型已保存'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: ${result.message}'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存出错: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showConstitutionSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('选择体质类型',
                  style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('您可以手动选择您的体质类型',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ..._constitutionInfo.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildConstitutionOption(
                      entry.key,
                      entry.value,
                      _result == entry.key,
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConstitutionOption(
      String key, _ConstitutionInfo info, bool isSelected) {
    return Material(
      color: isSelected
          ? info.color.withValues(alpha: 0.08)
          : AppColors.backgroundCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          setState(() {
            _result = key;
            _resultDescription = info.description;
            _resultAdvice = info.advice;
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? info.color : AppColors.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(info.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(info.name,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: info.color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('体质自测', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _result != null ? _buildResultView() : _buildQuizView(),
    );
  }

  Widget _buildQuizView() {
    final answeredCount = _answers.length;
    final progress = answeredCount / _questions.length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.backgroundCard,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('第 ${_currentPage + 1} / ${_questions.length} 题',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  Text('$answeredCount / ${_questions.length} 已答',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.backgroundTertiary,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final q = _questions[index];
              final selectedOption = _answers[index];
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryWithOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(q.title,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                    const SizedBox(height: 16),
                    Text(q.question,
                        style: AppTextStyles.h5
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    ...List.generate(q.options.length, (optIdx) {
                      final opt = q.options[optIdx];
                      final isSelected = selectedOption == optIdx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: isSelected
                              ? AppColors.primaryWithOpacity(0.06)
                              : AppColors.backgroundCard,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _selectOption(index, optIdx),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.borderLight,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.backgroundTertiary,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.borderLight,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : Center(
                                            child: Text(
                                              String.fromCharCode(
                                                  65 + optIdx),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(opt.text,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            boxShadow: AppColors.lightShadow,
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevPage,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: Text('上一题',
                          style: TextStyle(color: AppColors.primary)),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _answers[_currentPage] != null
                        ? (_currentPage < _questions.length - 1
                            ? _nextPage
                            : _calculateResult)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textInverse,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor:
                          AppColors.primaryWithOpacity(0.4),
                    ),
                    child: Text(
                      _currentPage < _questions.length - 1 ? '下一题' : '查看结果',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final info = _constitutionInfo[_result!]!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  info.color.withValues(alpha: 0.1),
                  info.color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: info.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('您的体质类型',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(info.name,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w800,
                      color: info.color,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.lightShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.fileText,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('体质特征',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_resultDescription!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.lightShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.lightbulb,
                        size: 18, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text('养生建议',
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_resultAdvice!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary, height: 1.6)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _showConstitutionSelector,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.pencil,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('手动修改体质类型',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitResult,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: AppColors.primaryWithOpacity(0.4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('保存体质类型',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                setState(() {
                  _result = null;
                  _answers.clear();
                  _currentPage = 0;
                  _pageController.jumpToPage(0);
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: AppColors.textTertiary),
              ),
              child: Text('重新测试',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _QuizQuestion {
  final String title;
  final String question;
  final List<_QuizOption> options;

  const _QuizQuestion({
    required this.title,
    required this.question,
    required this.options,
  });
}

class _QuizOption {
  final String text;
  final Map<String, int> scores;

  const _QuizOption({required this.text, required this.scores});
}

class _ConstitutionInfo {
  final String name;
  final String emoji;
  final Color color;
  final String description;
  final String advice;

  const _ConstitutionInfo({
    required this.name,
    required this.emoji,
    required this.color,
    required this.description,
    required this.advice,
  });
}
