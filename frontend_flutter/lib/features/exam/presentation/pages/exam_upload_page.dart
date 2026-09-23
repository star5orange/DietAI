import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/tts_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/exam_provider.dart';
import 'exam_detail_page.dart';
import 'exam_result_page.dart';

/// 体检报告上传页面（一步式拍照 + AI 自动识别 + 语音引导）
///
/// PRD D9 / 5.4：体检数据属敏感个人信息，仅本人可录入与修改，
/// 因此本页固定上传到当前登录账号，不再提供「为家人拍」切换。
class ExamUploadPage extends ConsumerStatefulWidget {
  const ExamUploadPage({super.key});

  @override
  ConsumerState<ExamUploadPage> createState() => _ExamUploadPageState();
}

class _ExamUploadPageState extends ConsumerState<ExamUploadPage> {
  final _imagePicker = ImagePicker();
  final _ttsService = TtsService();
  final List<File> _selectedImages = []; // 多页报告：一次可拍多张
  bool _isUploading = false;
  // 隐私开关：是否允许 AI 分析（默认关闭，仅本地私有存储）
  bool _aiAnalysisEnabled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // 语音引导：一步式拍照
      _ttsService.speak('您好，请把体检报告平放在桌面上，保证光线充足，然后拍摄照片。').catchError((_) {});
    });
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  /// 相机直拍（一步式，支持多页追加）
  Future<void> _takePhoto() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image != null) {
        setState(() => _selectedImages.add(File(image.path)));
        // 语音引导：告知已拍页数与下一步操作
        _ttsService
            .speak(_selectedImages.length == 1
                ? '照片已拍摄。如果报告只有一页，请点击下方的开始分析；如果还有下一页，请继续拍摄。'
                : '第 ${_selectedImages.length} 页已拍摄。继续拍摄下一页，或点击开始分析。')
            .catchError((_) {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  /// 从相册选择（追加到多页列表）
  Future<void> _pickFromGallery() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImages.add(File(image.path)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 上传并触发 AI 识别（支持多张照片）
  Future<void> _uploadReport() async {
    if (_selectedImages.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final targetUserId = ref.read(currentUserProvider)?.id ?? 0;
      final uploadResult =
          await ref.read(examReportListProvider.notifier).uploadReport(
                photos: List.of(_selectedImages),
                userId: targetUserId,
                aiAnalysisEnabled: _aiAnalysisEnabled,
              );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (uploadResult != null) {
        final report = uploadResult.report;
        // 记住"最近一次体检"（首页大按钮展示，仅本人）
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_exam_owner_name_$targetUserId', '自己');
        await prefs.setInt(
            'last_exam_owner_user_id_$targetUserId', targetUserId);
        // 记住本次体检月份（首页展示"最近：$owner · YYYY-MM"）
        final now = DateTime.now();
        await prefs.setString(
          'last_exam_owner_date_$targetUserId',
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
        );

        // 模糊页提示：语音引导重拍（仍保留识别结果）
        if (uploadResult.blurPages.isNotEmpty) {
          final pagesText = uploadResult.blurPages.join('、');
          final blurMessage = '第$pagesText页照片不太清楚，识别结果可能不准，建议重新拍摄。';
          _ttsService.speak(blurMessage).catchError((_) {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(blurMessage)),
            );
          }
        } else if (_aiAnalysisEnabled) {
          _ttsService.speak('体检报告上传成功，正在为您展示识别结果。').catchError((_) {});
        } else {
          _ttsService.speak('体检报告已保存到本地私有空间，未开启 AI 分析。').catchError((_) {});
        }
        if (!mounted) return;
        if (!_aiAnalysisEnabled) {
          // 未开启 AI 分析：没有识别结果，直接进详情页查看本地存储的报告
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ExamDetailPage(
                reportId: report.id,
                userId: targetUserId,
              ),
            ),
          );
          return;
        }
        // 跳转识别结果页：展示提取的指标 + AI 饮食/运动建议
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ExamResultPage(
              reportId: report.id,
              userId: targetUserId,
              ownerName: '自己',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 未拍照时拦截返回，询问是否退出；已拍照/分析中不拦截
      canPop: _selectedImages.isNotEmpty || _isUploading,
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
                    // 隐私提醒 + AI 分析开关（默认关闭）
                    _buildPrivacyCard(),
                    const SizedBox(height: 16),

                    // 一步式拍照区（支持多页：已拍 0 张显示拍摄入口，否则显示多页预览）
                    if (_selectedImages.isEmpty)
                      _buildCameraAction()
                    else
                      _buildPreviewSection(),

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

  /// 隐私提醒 + 「允许 AI 分析」开关（默认关闭，仅本地私有存储）
  Widget _buildPrivacyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '体检数据为敏感个人信息，仅在本人授权范围内使用',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '关闭时报告照片与文字仅存储在本地私有空间，不会送往 AI 分析。',
            style: AppTextStyles.bodySmall,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _aiAnalysisEnabled,
            onChanged: _isUploading
                ? null
                : (v) => setState(() => _aiAnalysisEnabled = v),
            title: const Text(
              '允许 AI 分析',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              _aiAnalysisEnabled ? 'AI 将识别指标并生成健康建议' : '默认关闭（仅本地私有存储）',
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  /// 拍照后分析中界面：✅ 已开始分析 → 缩略图 → ⏳ AI 正在提取
  Widget _buildAnalyzingCard() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text(
                  _aiAnalysisEnabled ? '已开始分析...' : '正在上传...',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedImages.first,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  _aiAnalysisEnabled
                      ? 'AI 正在提取体检指标...'
                      : '正在保存到本地私有空间（未开启 AI 分析）...',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _aiAnalysisEnabled
                  ? '正在上传（共 ${_selectedImages.length} 张），分析完成后自动跳转结果页'
                  : '正在上传（共 ${_selectedImages.length} 张），保存完成后自动跳转报告详情',
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

  /// 多页预览区：缩略图 + 继续拍下一页 + 开始分析
  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 多页缩略图横排
        SizedBox(
          height: 200,
          child: _selectedImages.length == 1
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    _selectedImages.first,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = _selectedImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            image,
                            width: 140,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '第${index + 1}页',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_selectedImages.length > 1)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _selectedImages.removeAt(index)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _takePhoto,
                icon: const Icon(Icons.add_a_photo),
                label: Text('继续拍第 ${_selectedImages.length + 1} 页'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('从相册选择'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadReport,
            icon: const Icon(Icons.auto_awesome),
            label: Text('开始分析（${_selectedImages.length} 张）'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _isUploading
                ? null
                : () => setState(() => _selectedImages.clear()),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('全部重拍'),
          ),
        ),
      ],
    );
  }
}
