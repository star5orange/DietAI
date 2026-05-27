import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

/// 增强版相机页面
class EnhancedCameraPage extends StatefulWidget {
  const EnhancedCameraPage({super.key});

  @override
  State<EnhancedCameraPage> createState() => _EnhancedCameraPageState();
}

class _EnhancedCameraPageState extends State<EnhancedCameraPage>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  // 动画控制器
  late AnimationController _slideUpController;
  late Animation<Offset> _slideUpAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _captureController;
  late Animation<double> _captureAnimation;
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _slideUpController.dispose();
    _fadeController.dispose();
    _captureController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    // 滑入动画
    _slideUpController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideUpAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideUpController,
      curve: Curves.easeOutCubic,
    ));

    // 淡入动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // 拍照动画
    _captureController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _captureAnimation = Tween<double>(begin: 1, end: 0.8).animate(
      CurvedAnimation(parent: _captureController, curve: Curves.easeInOut),
    );

    // 扫描器动画
    _scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scannerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.linear),
    );

    _scannerController.repeat();
  }

  Future<void> _initializeCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDialog();
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras?.isNotEmpty == true) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _controller!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });

          // 启动动画
          _fadeController.forward();
          _slideUpController.forward();
        }
      }
    } catch (e) {
      print('相机初始化失败: $e');
      _showErrorDialog('相机初始化失败', '请检查相机权限或设备支持');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 相机预览
          _buildCameraPreview(),

          // 扫描框和指引
          _buildScanningOverlay(),

          // 底部控制栏
          _buildBottomControls(),

          // 顶部提示
          _buildTopHints(),

          // 加载指示器
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        // 闪光灯控制
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              _isFlashOn ? LucideIcons.flashlight : LucideIcons.flashlightOff,
              color: _isFlashOn ? Colors.yellow : Colors.white,
              size: 20,
            ),
            onPressed: _toggleFlash,
          ),
        ),

        // 切换相机
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              LucideIcons.rotateCw,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _switchCamera,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2BAF74),
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ClipRRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width /
                  _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: ScanningOverlayPainter(),
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  // 扫描框角落
                  _buildScanCorner(Alignment.topLeft),
                  _buildScanCorner(Alignment.topRight),
                  _buildScanCorner(Alignment.bottomLeft),
                  _buildScanCorner(Alignment.bottomRight),

                  // 扫描线动画
                  AnimatedBuilder(
                    animation: _scannerAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 280 * _scannerAnimation.value - 2,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF2BAF74),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2BAF74).withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        child: CustomPaint(
          painter: CornerPainter(alignment),
        ),
      ),
    );
  }

  Widget _buildTopHints() {
    return SafeArea(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.camera,
                      color: Color(0xFF2BAF74),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '将食物对准取景框中心',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2BAF74).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '💡 AI将自动识别食物并分析营养成分',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return SlideTransition(
      position: _slideUpAnimation,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 功能提示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureHint(LucideIcons.image, '相册选择'),
                      _buildFeatureHint(LucideIcons.camera, '拍照识别'),
                      _buildFeatureHint(LucideIcons.sparkles, 'AI分析'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 控制按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 相册按钮
                      _buildControlButton(
                        icon: LucideIcons.image,
                        onTap: _pickFromGallery,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),

                      // 拍照按钮
                      AnimatedBuilder(
                        animation: _captureAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _captureAnimation.value,
                            child: _buildCaptureButton(),
                          );
                        },
                      ),

                      // 设置按钮
                      _buildControlButton(
                        icon: LucideIcons.settings,
                        onTap: _showCameraSettings,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHint(IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.7),
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.4,
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTapDown: (_) => _captureController.forward(),
      onTapUp: (_) => _captureController.reverse(),
      onTapCancel: () => _captureController.reverse(),
      onTap: _takePicture,
      child: Container(
        width: 80,
        height: 80,
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
              color: const Color(0xFF2BAF74).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.camera,
            color: Color(0xFF2BAF74),
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF2BAF74),
              strokeWidth: 3,
            ),
            SizedBox(height: 16),
            Text(
              '正在处理图片...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFlash() async {
    if (_controller != null) {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  void _switchCamera() async {
    if (_cameras != null && _cameras!.length > 1) {
      setState(() {
        _isRearCameraSelected = !_isRearCameraSelected;
      });

      final newCamera = _isRearCameraSelected ? _cameras![0] : _cameras![1];

      await _controller?.dispose();
      _controller = CameraController(
        newCamera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      setState(() {});
    }
  }

  void _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final XFile image = await _controller!.takePicture();

      // 这里应该跳转到分析页面
      Navigator.pop(context, File(image.path));
    } catch (e) {
      print('拍照失败: $e');
      _showErrorDialog('拍照失败', '请重试');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        Navigator.pop(context, File(image.path));
      }
    } catch (e) {
      print('选择图片失败: $e');
      _showErrorDialog('选择图片失败', '请重试');
    }
  }

  void _showCameraSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '相机设置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(LucideIcons.layoutGrid),
              title: const Text('网格线'),
              trailing: Switch(
                value: false,
                onChanged: (value) {},
              ),
            ),
            ListTile(
              leading: const Icon(LucideIcons.timer),
              title: const Text('定时拍摄'),
              trailing: Switch(
                value: false,
                onChanged: (value) {},
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要相机权限'),
        content: const Text('为了拍摄食物照片，请授予相机权限。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 扫描框遮罩绘制器
class ScanningOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 280,
      height: 280,
    );

    // 绘制遮罩
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(scanRect, const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 扫描框角落绘制器
class CornerPainter extends CustomPainter {
  final Alignment alignment;

  CornerPainter(this.alignment);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2BAF74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(0, 15);
      path.lineTo(0, 0);
      path.lineTo(15, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(size.width - 15, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, 15);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, size.height - 15);
      path.lineTo(0, size.height);
      path.lineTo(15, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(size.width - 15, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - 15);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
