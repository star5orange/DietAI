import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import 'food_analysis_page.dart';

class CameraPage extends ConsumerStatefulWidget {
  final String? mealName;
  final int? mealType;
  final String recordDate;
  final String? recordTime;

  const CameraPage({
    super.key,
    this.mealName,
    this.mealType,
    required this.recordDate,
    this.recordTime,
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

      // 创建流式数据源
      final analysisStream = _foodService.createFoodRecordWithImageStream(
        imageFile: imageFile,
        recordDate: recordDate,
        mealType: widget.mealType ?? 1,
        foodName: widget.mealName ?? '未知食物',
        description: '通过AI扫描识别',
        recordTime: widget.recordTime,
      );

      // 立即跳转到分析页面并传递流式数据
      _navigateToAnalysisPageWithStream(analysisStream, imageFile);
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
      Stream<Map<String, dynamic>> analysisStream, File imageFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAnalysisPage(
          analysisStream: analysisStream,
          imageFile: imageFile,
        ),
      ),
    );
  }

  void _navigateToAnalysisPage(dynamic foodRecord) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAnalysisPage(foodRecord: foodRecord),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              height: 200,
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
                    const SizedBox(height: 20),

                    // AI扫描器按钮
                    _buildBottomButton(
                      LucideIcons.scanLine,
                      'AI扫描器',
                      () => _takePicture(),
                      isActive: true,
                    ),

                    const SizedBox(height: 30),

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

  Widget _buildBottomButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.black : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
