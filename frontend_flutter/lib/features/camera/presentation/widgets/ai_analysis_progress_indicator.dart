import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// AI分析进度指示器组件
class AIAnalysisProgressIndicator extends StatefulWidget {
  final double progress;
  final String currentStep;
  final List<String> steps;
  final int currentStepIndex;

  const AIAnalysisProgressIndicator({
    super.key,
    required this.progress,
    required this.currentStep,
    required this.steps,
    required this.currentStepIndex,
  });

  @override
  State<AIAnalysisProgressIndicator> createState() => _AIAnalysisProgressIndicatorState();
}

class _AIAnalysisProgressIndicatorState extends State<AIAnalysisProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.linear),
    );

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // AI分析图标和进度
          _buildAnalysisHeader(),
          
          const SizedBox(height: 24),
          
          // 当前步骤显示
          _buildCurrentStep(),
          
          const SizedBox(height: 24),
          
          // 进度条
          _buildProgressBar(),
          
          const SizedBox(height: 20),
          
          // 步骤列表
          _buildStepsList(),
        ],
      ),
    );
  }

  Widget _buildAnalysisHeader() {
    return Row(
      children: [
        // AI图标动画
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2BAF74),
                      Color(0xFF3ECC7A),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2BAF74).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI正在分析您的食物',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '分析进度 ${(widget.progress * 100).round()}%',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2BAF74).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // 波纹动画指示器
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 波纹效果
                    for (int i = 0; i < 3; i++)
                      AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (context, child) {
                          final delay = i * 0.3;
                          final animValue = (_waveAnimation.value - delay).clamp(0.0, 1.0);
                          return Container(
                            width: 32 * (1 + animValue * 0.5),
                            height: 32 * (1 + animValue * 0.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2BAF74).withValues(alpha: 0.1 * (1 - animValue)),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    // 中心点
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2BAF74),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Text(
              widget.currentStep,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '分析进度',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
              ),
            ),
            Text(
              '${(widget.progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2BAF74),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // 背景进度条
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // 进度填充
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 8,
                width: MediaQuery.of(context).size.width * widget.progress * 0.8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2BAF74),
                      Color(0xFF3ECC7A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2BAF74).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '分析步骤',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        
        const SizedBox(height: 12),
        
        ...widget.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < widget.currentStepIndex;
          final isCurrent = index == widget.currentStepIndex;
          final isUpcoming = index > widget.currentStepIndex;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // 步骤状态指示器
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isCompleted 
                      ? const Color(0xFF2BAF74)
                      : isCurrent 
                        ? const Color(0xFF2BAF74).withValues(alpha: 0.7)
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted 
                      ? LucideIcons.check 
                      : isCurrent 
                        ? LucideIcons.circle
                        : LucideIcons.circle,
                    size: 12,
                    color: isCompleted || isCurrent 
                      ? Colors.white 
                      : Colors.grey[600],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 步骤文本
                Text(
                  step,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCurrent 
                      ? FontWeight.w600 
                      : FontWeight.w400,
                    color: isCompleted || isCurrent 
                      ? const Color(0xFF222222)
                      : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}