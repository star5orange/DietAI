import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../widgets/avatar_generation_progress.dart';
import '../widgets/pet_avatar_display.dart';
import '../../data/real_pet_api_service.dart';

/// 生成宠物形象页面
/// 支持拍照上传或文字描述输入
class GeneratePetAvatarPage extends ConsumerStatefulWidget {
  final int petId;
  final String petName;
  final String species;

  const GeneratePetAvatarPage({
    super.key,
    required this.petId,
    required this.petName,
    required this.species,
  });

  @override
  ConsumerState<GeneratePetAvatarPage> createState() =>
      _GeneratePetAvatarPageState();
}

class _GeneratePetAvatarPageState extends ConsumerState<GeneratePetAvatarPage> {
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();
  
  String _selectedMode = 'description'; // 'photo' 或 'description'
  String _selectedStyle = 'cartoon';
  File? _selectedImage;
  String? _imageBase64;
  bool _isGenerating = false;
  int _regenCount = 0;
  String? _currentTaskId;
  Timer? _pollTimer;
  String _progressMessage = '正在分析特征...';
  double _progressValue = 0.0;

  // 预设描述选项
  static const _presetDescriptions = [
    {'label': '白色', 'value': '白色毛发'},
    {'label': '黑色', 'value': '黑色毛发'},
    {'label': '橘色', 'value': '橘色毛发'},
    {'label': '花色', 'value': '花色毛发'},
    {'label': '蓝眼睛', 'value': '蓝色眼睛'},
    {'label': '绿眼睛', 'value': '绿色眼睛'},
    {'label': '胖嘟嘟', 'value': '体型圆润'},
    {'label': '瘦高', 'value': '体型瘦高'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '生成专属形象',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isGenerating ? _buildGeneratingView() : _buildInputView(),
    );
  }

  /// 输入视图
  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 提示卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '为 ${widget.petName} 生成专属形象',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'AI将根据照片或描述生成可爱的卡通形象',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 模式选择
          _buildSectionTitle('选择生成方式'),
          const SizedBox(height: 12),
          _buildModeSelector(),
          const SizedBox(height: 24),

          // 根据模式显示不同内容
          if (_selectedMode == 'photo') _buildPhotoUploadSection(),
          if (_selectedMode == 'description') _buildDescriptionSection(),

          const SizedBox(height: 32),

          // 生成按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleGenerate,
              icon: const Icon(LucideIcons.wand2, size: 18),
              label: const Text('开始生成'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 提示
          Center(
            child: Text(
              '预计需要 15-30 秒',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// 模式选择器
  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeOption(
            mode: 'photo',
            label: '上传照片',
            icon: LucideIcons.camera,
            subtitle: '拍一张宠物照片',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeOption(
            mode: 'description',
            label: '文字描述',
            icon: LucideIcons.pencil,
            subtitle: '描述宠物外观特征',
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String mode,
    required String label,
    required IconData icon,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          if (mode == 'photo') {
            _descriptionController.clear();
          } else {
            _selectedImage = null;
            _imageBase64 = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 照片上传区域
  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('上传宠物照片'),
        const SizedBox(height: 12),
        
        // 照片预览或上传按钮
        if (_selectedImage != null)
          _buildImagePreview()
        else
          _buildUploadButtons(),
        
        const SizedBox(height: 16),
        
        // 补充描述(可选)
        _buildSectionTitle('补充描述(可选)'),
        const SizedBox(height: 8),
        Text(
          '添加更多细节可以获得更好的生成效果',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),
        _buildDescriptionInput(),
      ],
    );
  }

  /// 照片预览
  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 20),
                  onPressed: _pickImage,
                  tooltip: '更换照片',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(LucideIcons.x, size: 20, color: AppColors.error),
                  onPressed: () {
                    setState(() {
                      _selectedImage = null;
                      _imageBase64 = null;
                    });
                  },
                  tooltip: '移除照片',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 上传按钮组
  Widget _buildUploadButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildUploadButton(
            icon: LucideIcons.camera,
            label: '拍照',
            onTap: () => _pickImage(source: ImageSource.camera),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildUploadButton(
            icon: LucideIcons.image,
            label: '从相册选择',
            onTap: () => _pickImage(source: ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 描述输入区域
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('选择风格'),
        const SizedBox(height: 12),
        _buildStyleSelector(),
        const SizedBox(height: 24),

        _buildSectionTitle('描述宠物外观'),
        const SizedBox(height: 12),
        _buildDescriptionInput(),
        const SizedBox(height: 12),

        // 快捷标签
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetDescriptions.map((preset) {
            final isSelected = _descriptionController.text.contains(preset['value']!);
            return GestureDetector(
              onTap: () => _togglePreset(preset['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primarySurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  preset['label']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStyleSelector() {
    return Row(
      children: [
        _buildStyleOption('cartoon', '卡通', LucideIcons.smile),
        const SizedBox(width: 12),
        _buildStyleOption('anime', '动漫', LucideIcons.star),
      ],
    );
  }

  Widget _buildStyleOption(String style, String label, IconData icon) {
    final isSelected = _selectedStyle == style;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStyle = style;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TextField(
      controller: _descriptionController,
      maxLines: 3,
      maxLength: 100,
      decoration: InputDecoration(
        hintText: '例如：橘猫，白色手套，绿色眼睛，体型圆润',
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  /// 选择照片
  Future<void> _pickImage({ImageSource? source}) async {
    try {
      final ImageSource imageSource = source ?? ImageSource.gallery;
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        final bytes = await imageFile.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          _selectedImage = imageFile;
          _imageBase64 = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
      }
    }
  }

  void _togglePreset(String value) {
    final currentText = _descriptionController.text;
    if (currentText.contains(value)) {
      // 移除
      final newText = currentText
          .replaceFirst(value, '')
          .replaceAll(RegExp(r',\s*,'), ',')
          .replaceAll(RegExp(r'^\s*,\s*'), '')
          .replaceAll(RegExp(r',\s*$'), '')
          .trim();
      _descriptionController.text = newText;
    } else {
      // 添加
      final newText = currentText.isEmpty ? value : '$currentText, $value';
      _descriptionController.text = newText;
    }
    setState(() {});
  }

  void _handleGenerate() async {
    // 验证输入
    if (_selectedMode == 'photo') {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先上传宠物照片')),
        );
        return;
      }
    } else {
      if (_descriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请描述宠物外观')),
        );
        return;
      }
    }

    _regenCount++;
    setState(() {
      _isGenerating = true;
      _progressValue = 0.0;
      _progressMessage = '正在提交生成任务...';
    });

    final api = RealPetApiService();
    final res = await api.generateAvatar(
      widget.petId,
      mode: _selectedMode,
      photo: _imageBase64,
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;

    if (res.isSuccess && res.data != null) {
      _currentTaskId = res.data!['task_id'] as String?;
      _startPolling();
    } else {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : '生成服务暂不可用，请稍后重试'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    int elapsed = 0;
    const maxTicks = 30;

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      elapsed++;
      final progressMsgs = [
        '正在分析特征...',
        '正在生成基础形象...',
        '正在优化细节...',
        '正在创建情绪变体...'
      ];

      setState(() {
        _progressValue = elapsed / maxTicks;
        _progressMessage = progressMsgs[(elapsed ~/ 2) % progressMsgs.length];
      });

      if (_currentTaskId == null) {
        timer.cancel();
        _finishGeneration({'image_url': null, 'emotions': {}});
        return;
      }

      final api = RealPetApiService();
      final taskRes = await api.getGenerationTask(_currentTaskId!);

      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }

      if (taskRes.isSuccess && taskRes.data != null) {
        final status = taskRes.data!['status'] as String?;
        if (status == 'done') {
          timer.cancel();
          final avatarUrl = taskRes.data!['base_image_url'] as String? ?? '';
          _finishGeneration({
            'image_url': avatarUrl,
            'emotions': taskRes.data!['emotions'] ?? {},
          });
        } else if (status == 'failed') {
          timer.cancel();
          _finishGeneration({'image_url': null, 'emotions': {}});
        }
      }

      if (elapsed >= maxTicks) {
        timer.cancel();
        _finishGeneration({'image_url': null, 'emotions': {}});
      }
    });
  }

  /// 生成中视图
  Widget _buildGeneratingView() {
    return AvatarGenerationProgress(
      petName: widget.petName,
      description: _descriptionController.text,
      regenCount: _regenCount,
      progressValue: _progressValue,
      progressMessage: _progressMessage,
      onComplete: (result) {
        setState(() {
          _isGenerating = false;
        });
        _showResultDialog(result);
      },
    );
  }

  void _finishGeneration(Map<String, dynamic> result) {
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
    });
    _showResultDialog(result);
  }

  void _showResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.checkCircle, color: AppColors.success, size: 48),
              const SizedBox(height: 12),
              Text(
                _regenCount > 1 ? '重新生成完成！' : '形象生成成功！',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _regenCount > 1 ? '试试看是否更满意？' : '看起来不错吧？',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: PetAvatarDisplay(
                  emotion: 'happy',
                  size: 80,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleGenerate();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('重新生成'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('使用形象'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}