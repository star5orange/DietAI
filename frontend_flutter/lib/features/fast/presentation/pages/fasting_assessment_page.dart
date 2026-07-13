import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';

/// 轻断食健康评估页面
class FastingAssessmentPage extends ConsumerStatefulWidget {
  const FastingAssessmentPage({super.key});

  @override
  ConsumerState<FastingAssessmentPage> createState() => _FastingAssessmentPageState();
}

class _FastingAssessmentPageState extends ConsumerState<FastingAssessmentPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  
  // 评估数据
  bool _hasChronicDisease = false;
  bool _isPregnant = false;
  bool _hasDiabetes = false;
  bool _hasLowBloodSugar = false;
  int _stressLevel = 3;
  int _sleepQuality = 3;

  bool _canStart = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('健康评估', style: AppTextStyles.h5.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: _handleContinue,
        onStepCancel: () => setState(() => _currentStep > 0 ? _currentStep-- : null),
        controlsBuilder: (context, details) {
          return Row(
            children: [
              ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_currentStep < 3 ? '下一步' : '完成评估'),
              ),
              if (_currentStep > 0) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('上一步'),
                ),
              ],
            ],
          );
        },
        steps: [
          _buildMedicalStep(),
          _buildLifestyleStep(),
          _buildResultStep(),
        ],
      ),
    );
  }

  Step _buildMedicalStep() {
    return Step(
      title: const Text('身体状况'),
      content: Column(
        children: [
          _buildQuestionTile('是否有慢性疾病？', _hasChronicDisease, (v) => setState(() => _hasChronicDisease = v)),
          _buildQuestionTile('是否在孕期或哺乳期？', _isPregnant, (v) => setState(() => _isPregnant = v)),
          _buildQuestionTile('是否有糖尿病？', _hasDiabetes, (v) => setState(() => _hasDiabetes = v)),
          _buildQuestionTile('是否经常低血糖？', _hasLowBloodSugar, (v) => setState(() => _hasLowBloodSugar = v)),
        ],
      ),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildLifestyleStep() {
    return Step(
      title: const Text('生活习惯'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('压力水平', style: AppTextStyles.bodyMedium),
          Slider(
            value: _stressLevel.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: ['很低', '较低', '一般', '较高', '很高'][_stressLevel - 1],
            onChanged: (v) => setState(() => _stressLevel = v.round()),
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text('睡眠质量', style: AppTextStyles.bodyMedium),
          Slider(
            value: _sleepQuality.toDouble(),
            min: 1,
            max: 5,
            divisions: 4,
            label: ['很差', '较差', '一般', '良好', '优秀'][_sleepQuality - 1],
            onChanged: (v) => setState(() => _sleepQuality = v.round()),
            activeColor: AppColors.primary,
          ),
        ],
      ),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    );
  }

  Step _buildResultStep() {
    _canStart = !_isPregnant && !_hasLowBloodSugar && _stressLevel < 4;
    
    return Step(
      title: const Text('评估结果'),
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _canStart ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _canStart ? AppColors.success : AppColors.warning),
            ),
            child: Column(
              children: [
                Icon(
                  _canStart ? LucideIcons.checkCircle : LucideIcons.alertTriangle,
                  size: 48,
                  color: _canStart ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(height: 12),
                Text(
                  _canStart ? '适合轻断食' : '建议先咨询医生',
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _canStart ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _canStart 
                      ? '您的身体状况适合尝试轻断食，建议从基础方案开始。'
                      : '根据您的评估结果，建议先咨询医生是否适合轻断食。',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
      isActive: _currentStep >= 2,
      state: StepState.indexed,
    );
  }

  Widget _buildQuestionTile(String question, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(question, style: AppTextStyles.bodyMedium)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      Navigator.pop(context, _canStart);
    }
  }
}