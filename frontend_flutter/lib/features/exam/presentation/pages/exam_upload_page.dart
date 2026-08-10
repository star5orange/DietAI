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
import 'exam_result_page.dart';

/// 体检报告上传页面（一步式拍照 + AI 自动识别 + 语音引导）
///
/// 从家庭看板点 📸 进入时传入 [ownerUserId]（为谁拍），
/// 进入后直接打开相机，拍照后自动上传分析并跳转结果页。
class ExamUploadPage extends ConsumerStatefulWidget {
  final int? ownerUserId; // null = 自己
  final String? ownerName;

  const ExamUploadPage({super.key, this.ownerUserId, this.ownerName});

  @override
  ConsumerState<ExamUploadPage> createState() => _ExamUploadPageState();
}

class _ExamUploadPageState extends ConsumerState<ExamUploadPage> {
  final _imagePicker = ImagePicker();
  final _ttsService = TtsService();
  File? _selectedImage;
  int? _selectedUserId; // null = 自己
  bool _isUploading = false;
  bool _autoCameraOpened = false;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.ownerUserId;
    Future.microtask(() async {
      // 加载家人列表（用于"为谁拍"切换）
      ref.read(friendListProvider.notifier).loadFriendList();
      // 普通进入时记住上次的选择（需求：上次选过就记住，顶部小字提示）
      if (widget.ownerUserId == null) {
        final prefs = await SharedPreferences.getInstance();
        final lastId = prefs.getInt('last_exam_owner_user_id');
        if (lastId != null && mounted) {
          setState(() => _selectedUserId = lastId);
        }
      }
      // 语音引导：一步式拍照
      _ttsService.speak('您好，请把体检报告平放在桌面上，保证光线充足，然后拍摄照片。').catchError((_) {});
      // 从家庭看板 📸 进入：直接打开相机
      if (widget.ownerUserId != null && !_autoCameraOpened) {
        _autoCameraOpened = true;
        _takePhoto();
      }
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
        // 一步式：拍照后直接自动上传分析，不需要点确认
        _uploadReport();
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
        // 一步式：选择后直接自动上传分析
        _uploadReport();
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
      final report = await ref
          .read(examReportListProvider.notifier)
          .uploadReport(photo: _selectedImage!, userId: targetUserId);

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (report != null) {
        // 记住"最近为谁拍"，首页大按钮展示 + 下次进入默认选中
        final ownerName = _resolveOwnerName(targetUserId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_exam_owner_name', ownerName);
        await prefs.setInt('last_exam_owner_user_id', targetUserId);
        // 记住本次体检月份（首页展示"最近：$owner · YYYY-MM"）
        final now = DateTime.now();
        await prefs.setString(
          'last_exam_owner_date',
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
        );

        _ttsService.speak('体检报告上传成功，正在为您展示识别结果。').catchError((_) {});
        if (!mounted) return;
        // 跳转识别结果页：展示提取的指标 + AI 饮食/运动建议
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ExamResultPage(
              reportId: report.id,
              userId: targetUserId,
              ownerName: ownerName,
              comparedToLast: report.comparedToLast,
            ),
          ),
        );
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

    return PopScope(
      // 未拍照时拦截返回，询问是否退出；已拍照/分析中不拦截
      canPop: _selectedImage != null || _isUploading,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (shouldExit && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        appBar: AppBar(
          title: const Text('拍体检报告'),
          actions: [
            // ❓ 重播语音引导
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: '重播语音引导',
              onPressed: () => _ttsService
                  .speak('请把体检报告平放在桌面上，保证光线充足，然后拍摄照片。')
                  .catchError((_) {}),
            ),
          ],
        ),
        // 拍照后：分析中全屏卡片
        body: _isUploading
            ? _buildAnalyzingCard()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部小字提示"为谁拍"：正在为 妈妈 拍照
                    _buildOwnerBanner(),
                    const SizedBox(height: 16),

                    // 一步式拍照区
                    if (_selectedImage == null)
                      _buildCameraAction()
                    else
                      _buildPreviewSection(),

                    // 底部小字切换：不点就不管
                    const SizedBox(height: 12),
                    _buildSwitchRow(family),
                    const SizedBox(height: 16),

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
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '打开 → 对准报告 → 按快门 → 完事。日期、医院由 AI 自动识别，拍照后自动分析，不需要点确认。',
                              style:
                                  TextStyle(fontSize: 13, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// 未拍照退出确认弹窗
  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('还没有拍照'),
        content: const Text('还没有拍照，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续拍照'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 顶部小字提示"为谁拍"：正在为 妈妈 拍照
  Widget _buildOwnerBanner() {
    final currentUserId = ref.read(currentUserProvider)?.id ?? 0;
    final ownerName = _resolveOwnerName(_selectedUserId ?? currentUserId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '正在为 $ownerName 拍照',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// 底部小字切换"为谁拍"：不点就不管
  Widget _buildSwitchRow(List<UserRelation> family) {
    final currentUserId = ref.read(currentUserProvider)?.id ?? 0;
    final selectedId = _selectedUserId ?? currentUserId;

    final targets = <({String label, int? userId})>[
      (label: '自己', userId: null),
      ...family.map((f) => (
            label: f.note ?? f.realName ?? f.username,
            userId: f.userId,
          )),
    ];
    final others = targets
        .where((t) => (t.userId ?? currentUserId) != selectedId)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 4,
      children: [
        for (final t in others)
          GestureDetector(
            onTap: () => setState(() => _selectedUserId = t.userId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '切换为 ${t.label}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 拍照后分析中界面：✅ 已开始分析 → 缩略图 → ⏳ AI 正在提取
  Widget _buildAnalyzingCard() {
    final currentUserId = ref.read(currentUserProvider)?.id ?? 0;
    final ownerName = _resolveOwnerName(_selectedUserId ?? currentUserId);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  '已开始分析...',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedImage!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('AI 正在提取体检指标...', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '正在为 $ownerName 上传，分析完成后自动跳转结果页',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
