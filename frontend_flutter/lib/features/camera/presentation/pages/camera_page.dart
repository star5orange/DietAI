import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../services/food_service.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import 'food_analysis_page.dart';

/// 是否为不支持 camera 插件的桌面平台
bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux);

class CameraPage extends ConsumerStatefulWidget {
  final String? mealName;
  final int? mealType;
  final String recordDate;
  final String? recordTime;
  final double? costAmount;
  final String? costSource;
  // 代记录：目标家人用户ID（为空表示记录给自己）
  final int? proxyTargetUserId;
  final String? proxyTargetName;

  const CameraPage({
    super.key,
    this.mealName,
    this.mealType,
    required this.recordDate,
    this.recordTime,
    this.costAmount,
    this.costSource,
    this.proxyTargetUserId,
    this.proxyTargetName,
  });

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isLoading = true;
  bool _isProcessing = false;
  final ImagePicker _imagePicker = ImagePicker();
  final FoodService _foodService = FoodService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // 桌面平台不支持 camera 插件，直接跳过
    if (_isDesktop) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 请求相机权限
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _showPermissionDialog();
        return;
      }

      // 获取可用相机
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 初始化相机控制器
      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('相机初始化失败: $e');
      if (mounted) {
        NetworkErrorHandler.handleApiError(context, e);
      }
    }
  }

  void _showPermissionDialog() {
    ErrorHandler.showWarning(
      context,
      '请允许应用访问相机以拍摄食物照片',
      title: '需要相机权限',
      onConfirm: () => openAppSettings(),
    );
  }

  Future<void> _takePicture() async {
    if (_cameraController?.value.isInitialized != true || _isProcessing) return;

    try {
      setState(() => _isProcessing = true);

      final image = await _cameraController!.takePicture();
      await _processImage(File(image.path));
    } catch (e) {
      NetworkErrorHandler.handleApiError(context, e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isProcessing = true);

      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processImage(File(image.path));
      }
    } catch (e) {
      NetworkErrorHandler.handleApiError(context, e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      // 立即跳转到分析页面，并传递流式数据
      final recordDate = widget.recordDate;

      // 创建流式数据源（仅分析不落库，用户确认后再创建记录）
      final analysisStream = _foodService.createFoodRecordWithImageStream(
        imageFile: imageFile,
        recordDate: recordDate,
        mealType: widget.mealType ?? 1,
        foodName: '',
        description: '通过AI扫描识别',
        recordTime: widget.recordTime,
        cost: widget.costAmount,
        sourceTag: widget.costSource,
        targetUserId: widget.proxyTargetUserId,
        analyzeOnly: true,
      );

      // 记录原始创建数据，供用户确认后落库使用
      final pendingData = FoodRecordCreate(
        recordDate: recordDate,
        recordTime: widget.recordTime,
        mealType: widget.mealType ?? 1,
        foodName: '',
        description: '通过AI扫描识别',
        recordingMethod: 1, // AI扫描
        cost: widget.costAmount,
        sourceTag: widget.costSource,
        targetUserId: widget.proxyTargetUserId,
      );

      // 立即跳转到分析页面并传递流式数据
      _navigateToAnalysisPageWithStream(
        analysisStream,
        imageFile,
        pendingData: pendingData,
      );
    } catch (e) {
      NetworkErrorHandler.handleApiError(context, e);
    }
  }

  void _showSuccessDialog() {
    ErrorHandler.showSuccess(
      context,
      '食物图片已成功上传并创建记录',
      title: '上传成功',
      onOk: () => Navigator.pop(context),
    );
  }

  void _navigateToAnalysisPageWithStream(
    Stream<Map<String, dynamic>> analysisStream,
    File imageFile, {
    FoodRecordCreate? pendingData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAnalysisPage(
          analysisStream: analysisStream,
          imageFile: imageFile,
          analyzeOnly: true,
          pendingFoodData: pendingData,
        ),
      ),
    ).then((result) {
      // 分析页返回后，自动关闭相机页回到首页
      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _navigateToAnalysisPage(dynamic foodRecord) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAnalysisPage(foodRecord: foodRecord),
      ),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 桌面平台：显示图片选择界面
    if (_isDesktop) {
      return _buildDesktopView();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 相机预览
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else if (_cameraController?.value.isInitialized == true)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: Text(
                '相机不可用',
                style: TextStyle(color: Colors.white),
              ),
            ),

          // 顶部状态栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        LucideIcons.x,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 顶部提示文字
          Positioned(
            top: MediaQuery.of(context).padding.top + 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '将食物放在框内',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // 中央取景框
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // 四个角的装饰
                  Positioned(
                    top: -3,
                    left: -3,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    left: -3,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部控制区域
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // 拍照和相册按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 相册按钮
                        IconButton(
                          onPressed: _isProcessing ? null : _pickFromGallery,
                          icon: const Icon(
                            LucideIcons.image,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),

                        // 拍照按钮
                        GestureDetector(
                          onTap: _isProcessing ? null : _takePicture,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: _isProcessing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xFF3ECC7A),
                                        ),
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.camera,
                                    color: Color(0xFF3ECC7A),
                                    size: 32,
                                  ),
                          ),
                        ),

                        // 闪光灯按钮
                        IconButton(
                          onPressed: () {
                            // TODO: 切换闪光灯
                          },
                          icon: const Icon(
                            LucideIcons.zap,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 桌面平台视图：不支持相机，显示图片选择界面
  Widget _buildDesktopView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('AI 食物识别'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.imagePlus,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '桌面端暂不支持相机',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '请从本地选择食物图片进行 AI 识别',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 240,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickFromGallery,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(LucideIcons.upload, size: 20),
                  label: Text(
                    _isProcessing ? '识别中...' : '选择图片',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
