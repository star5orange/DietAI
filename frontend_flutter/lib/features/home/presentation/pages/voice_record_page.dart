import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../camera/presentation/pages/food_analysis_page.dart';

class VoiceRecordPage extends StatefulWidget {
  final String mealName;
  final int mealType;
  final String recordDate;
  final String? recordTime;
  final double? costAmount;
  final String? costSource;
  // 代记录：目标家人用户ID（为空表示记录给自己）
  final int? proxyTargetUserId;

  const VoiceRecordPage({
    super.key,
    required this.mealName,
    required this.mealType,
    required this.recordDate,
    this.recordTime,
    this.costAmount,
    this.costSource,
    this.proxyTargetUserId,
  });

  @override
  State<VoiceRecordPage> createState() => _VoiceRecordPageState();
}

class _VoiceRecordPageState extends State<VoiceRecordPage>
    with TickerProviderStateMixin {
  final FoodService _foodService = FoodService();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _isRecognizing = false;
  bool _isSubmitting = false;
  String? _recordingPath;
  int _recordDuration = 0;
  Timer? _timer;
  String? _errorMessage;
  String? _recognizedText;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await Permission.microphone.isGranted;
      if (!hasPermission) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('需要麦克风权限才能录音'),
                  backgroundColor: AppColors.error),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}${Platform.pathSeparator}voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // 开始录音 - 使用最简配置确保兼容性
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordDuration = 0;
        _errorMessage = null;
        _recognizedText = null;
      });
      _pulseController.repeat();

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordDuration++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();
      _pulseController.stop();

      final path = await _recorder.stop();

      setState(() => _isRecording = false);

      if (path != null && await File(path).exists()) {
        _recordingPath = path;
        final fileSize = await File(path).length();
        print('📂 录音文件: $path, 大小: $fileSize bytes');
        if (fileSize < 1000) {
          // 文件太小，可能录音失败
          setState(() {
            _errorMessage = '录音数据异常（文件过小），请检查麦克风是否正常';
          });
          return;
        }
        await _recognizeVoice();
      } else {
        setState(() {
          _errorMessage = '录音保存失败，请重试';
        });
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = '录音停止失败: $e';
      });
    }
  }

  Future<void> _recognizeVoice() async {
    if (_recordingPath == null) return;

    setState(() => _isRecognizing = true);

    try {
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        setState(() {
          _isRecognizing = false;
          _errorMessage = '录音文件不存在';
        });
        return;
      }

      final result = await _foodService.recognizeVoice(file);

      if (result.success && result.data != null) {
        final text = result.data!['text'] as String? ?? '';
        if (text.isNotEmpty && mounted) {
          setState(() {
            _isRecognizing = false;
            _recognizedText = text;
          });
          // 弹出确认弹窗
          _showConfirmDialog(text);
        } else {
          setState(() {
            _isRecognizing = false;
            _errorMessage = '未能识别到有效内容，请重新录音';
          });
        }
      } else {
        setState(() {
          _isRecognizing = false;
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isRecognizing = false;
        // 从异常信息中提取更友好的提示
        final msg = e.toString();
        if (msg.contains('silence') || msg.contains('no valid speech')) {
          _errorMessage = '未检测到语音，请对着麦克风说话后重试';
        } else {
          _errorMessage = '识别失败: $e';
        }
      });
    }
  }

  void _showConfirmDialog(String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部拖拽指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 标题
            Row(
              children: [
                const Icon(LucideIcons.mic, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('识别结果', style: AppTextStyles.h6),
              ],
            ),
            const SizedBox(height: 16),
            // 识别文本
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Text(
                text,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 24),
            // 操作按钮
            Row(
              children: [
                // 直接记录
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitDirectRecord(text);
                    },
                    icon: const Icon(LucideIcons.zap, size: 18),
                    label: const Text('直接记录'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // AI 分析
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitWithAI(text);
                    },
                    icon: const Icon(LucideIcons.sparkles, size: 18),
                    label: const Text('AI 分析'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 重新录音
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _recognizedText = null;
                    _errorMessage = null;
                  });
                },
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('重新录音'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 直接记录（跳过 AI 分析）
  Future<void> _submitDirectRecord(String foodName) async {
    setState(() => _isSubmitting = true);

    try {
      final record = FoodRecordCreate(
        recordDate: widget.recordDate,
        recordTime: widget.recordTime ?? DateTime.now().toIso8601String(),
        mealType: widget.mealType,
        foodName: foodName,
        description: foodName,
        recordingMethod: 3, // 语音记录
        cost: widget.costAmount,
        sourceTag: widget.costSource,
        targetUserId: widget.proxyTargetUserId,
      );

      final result = await _foodService.createFoodRecord(record);

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('记录成功'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 1)),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('记录失败: ${result.message}'),
                backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// AI 分析流程
  Future<void> _submitWithAI(String foodName) async {
    setState(() => _isSubmitting = true);

    try {
      final record = FoodRecordCreate(
        recordDate: widget.recordDate,
        recordTime: widget.recordTime ?? DateTime.now().toIso8601String(),
        mealType: widget.mealType,
        foodName: foodName,
        description: foodName,
        recordingMethod: 3, // 语音记录
        cost: widget.costAmount,
        sourceTag: widget.costSource,
        targetUserId: widget.proxyTargetUserId,
      );

      final stream = _foodService.createFoodRecordStream(record);

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodAnalysisPage(
              analysisStream: stream,
            ),
          ),
        ).then((result) {
          if (result == true && mounted) {
            Navigator.of(context).pop(true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('语音记录'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 录音按钮
            GestureDetector(
              onTapDown: (_isRecognizing || _isSubmitting)
                  ? null
                  : (_) => _startRecording(),
              onTapUp: _isRecording ? (_) => _stopRecording() : null,
              onTapCancel: _isRecording ? () => _stopRecording() : null,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? AppColors.error.withOpacity(0.1)
                      : AppColors.primary.withOpacity(0.1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 脉冲动画
                    if (_isRecording)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + _pulseController.value * 0.3,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.error.withOpacity(
                                      1.0 - _pulseController.value),
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    // 图标
                    Icon(
                      _isRecording ? LucideIcons.micOff : LucideIcons.mic,
                      size: 48,
                      color: _isRecording ? AppColors.error : AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 状态文字
            if (_isRecording) ...[
              Text(
                _formatDuration(_recordDuration),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error),
              ),
              const SizedBox(height: 8),
              Text('松开结束录音',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ] else if (_isRecognizing) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('正在识别...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primary)),
            ] else if (_isSubmitting) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('正在提交...',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primary)),
            ] else if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text('重新录音'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ] else ...[
              Text('按住开始录音',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
