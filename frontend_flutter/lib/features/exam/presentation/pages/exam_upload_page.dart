import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/presentation/providers/social_provider.dart';
import '../../../social/domain/social_models.dart';
import '../providers/exam_provider.dart';

/// 体检报告上传页面（一步式拍照 + AI 自动识别 + 语音引导）
class ExamUploadPage extends ConsumerStatefulWidget {
  const ExamUploadPage({super.key});

  @override
  ConsumerState<ExamUploadPage> createState() => _ExamUploadPageState();
}

class _ExamUploadPageState extends ConsumerState<ExamUploadPage> {
  final _imagePicker = ImagePicker();
  final _ttsService = TtsService();
  File? _selectedImage;
  int? _selectedUserId; // null = 自己
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // 加载家人列表（用于"为谁拍"）
      ref.read(friendListProvider.notifier).loadFriendList();
      // 语音引导：一步式拍照
      _ttsService.speak('您好，请把体检报告平放在桌面上，保证光线充足，然后拍摄照片。').catchError((_) {});
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  /// 相机直拍（一步式）
  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        _ttsService.speak('照片已拍摄，正在分析体检报告，请稍等。').catchError((_) {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  /// 从相册选择
  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 上传并触发 AI 识别
  Future<void> _uploadReport() async {
    if (_selectedImage == null) return;

    setState(() => _isUploading = true);
    try {
      final currentUserId = ref.read(currentUserProvider)?.id ?? 0;
      final targetUserId = _selectedUserId ?? currentUserId;
      final success = await ref
          .read(examReportListProvider.notifier)
          .uploadReport(photo: _selectedImage!, userId: targetUserId);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (success) {
        // 记住"最近为谁拍"，首页大按钮展示
        final ownerName = _resolveOwnerName(targetUserId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_exam_owner_name', ownerName);

        _ttsService.speak('体检报告上传成功，AI 正在识别指标。').catchError((_) {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传成功，AI 正在识别指标')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('上传失败，请重试')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  String _resolveOwnerName(int userId) {
    if (userId == (ref.read(currentUserProvider)?.id ?? 0)) {
      return '自己';
    }
    final family = ref.read(friendListProvider).family;
    for (final f in family) {
      if (f.userId == userId) {
        return f.note ?? f.realName ?? f.username;
      }
    }
    return '家人';
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendListProvider);
    final family = friendState.family;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        title: const Text('拍体检报告'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 为谁拍
            _buildOwnerSelector(family,
                showNoFamilyHint: family.isEmpty && !friendState.isLoading),
            const SizedBox(height: 20),

            // 一步式拍照区
            if (_selectedImage == null)
              _buildCameraAction()
            else
              _buildPreviewSection(),

            const SizedBox(height: 24),

            // 开始识别按钮
            if (_selectedImage != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '开始识别',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            const SizedBox(height: 24),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '拍摄时请确保报告平铺、光线充足、字迹清晰。AI 会自动识别体检日期、医院和各项指标，异常项目会标红并给出建议。',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 为谁拍：自己 + 家人选择
  Widget _buildOwnerSelector(List<UserRelation> family,
      {required bool showNoFamilyHint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '为谁拍',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildOwnerChip('我自己', null),
            ...family.map((f) {
              final label = f.note ?? f.realName ?? f.username;
              return _buildOwnerChip(label, f.userId);
            }),
          ],
        ),
        if (showNoFamilyHint)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '（暂无可选的家人，将默认拍给自己）',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
      ],
    );
  }

  Widget _buildOwnerChip(String label, int? userId) {
    final selected = _selectedUserId == userId;
    return GestureDetector(
      onTap: () => setState(() => _selectedUserId = userId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              userId == null ? Icons.person : Icons.family_restroom,
              size: 15,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 一步式拍照大按钮
  Widget _buildCameraAction() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _takePhoto,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                '拍体检报告',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '对准报告，按快门即可',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickFromGallery,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        '或从相册选择',
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 拍摄后的预览区
  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            _selectedImage!,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.refresh),
                label: const Text('重新拍摄'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('换一张'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
