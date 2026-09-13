import 'dart:convert';
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
  // 识别模式：false=餐食识别（AI 图像分析），true=包装食品（营养成分表 OCR）
  bool _isLabelMode = false;
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
      debugPrint('相机初始化失败: $e');
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
      final file = File(image.path);
      if (_isLabelMode) {
        await _processLabelImage(file);
      } else {
        await _processImage(file);
      }
    } catch (e) {
      NetworkErrorHandler.handleApiError(context, e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      setState(() => _isProcessing = true);

      // 包装标签模式压缩图片（与宠物食品 OCR 一致：1024/85），减小 base64 体积
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: _isLabelMode ? 1024 : null,
        maxHeight: _isLabelMode ? 1024 : null,
        imageQuality: _isLabelMode ? 85 : null,
      );
      if (image != null) {
        final file = File(image.path);
        if (_isLabelMode) {
          await _processLabelImage(file);
        } else {
          await _processImage(file);
        }
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

  // ============================================================
  // 包装食品营养成分表识别（复用宠物食品 OCR 的 DashScope qwen-vl 模式）
  // ============================================================

  Future<void> _processLabelImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(bytes);

      final res = await _foodService.ocrFoodLabel(imageBase64);
      if (!mounted) return;

      if (res.isSuccess && res.data != null) {
        final data = res.data!;
        final hasNutrition = data['calories_per_100g'] != null ||
            data['protein_per_100g'] != null ||
            data['fat_per_100g'] != null ||
            data['carbs_per_100g'] != null;

        if (data['is_packaged_food'] == false) {
          _showNotPackagedDialog();
        } else if (!hasNutrition) {
          // OCR 服务异常（额度耗尽/模型未开通）或未识别到营养数据，透出原始信息便于排查
          _showLabelFailedDialog(
            (data['raw_text'] as String?)?.trim() ?? '',
          );
        } else {
          // 识别成功即自动进入 AI 分析，无需手动确认（与餐食识别一致）
          _startLabelAnalysisFromOcr(data);
        }
      } else {
        ErrorHandler.showError(
          this.context,
          res.message.isEmpty ? '包装食品识别失败，请重试' : res.message,
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(this.context, '包装食品识别出错: $e');
      }
    }
  }

  void _showNotPackagedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未识别到包装食品'),
        content: const Text('这张照片看起来不是预包装食品。请拍摄带有营养成分表的食品包装，或切换到"餐食识别"模式。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('重新拍摄'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isLabelMode = false);
            },
            child: const Text('切换到餐食识别'),
          ),
        ],
      ),
    );
  }

  void _showLabelFailedDialog(String rawText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未能识别营养信息'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请确认拍摄的是清晰完整的营养成分表，并保证光线充足后重试。'),
              if (rawText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rawText,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('重新拍摄'),
          ),
        ],
      ),
    );
  }

  /// OCR 成功后自动进入 AI 分析（与餐食识别行为一致：识别完直接出 AI 建议）
  ///
  /// 食用量默认取包装标注的每份克数（无标注则按 100g），
  /// 需要调整时可在分析页用"份数"增减。
  void _startLabelAnalysisFromOcr(Map<String, dynamic> data) {
    final brand = (data['brand'] as String?)?.trim() ?? '';
    final foodName = (data['food_name'] as String?)?.trim() ?? '未知食品';
    final displayName = brand.isNotEmpty ? '$brand $foodName' : foodName;

    final servingSizeG = (data['serving_size_g'] as num?)?.toDouble();
    final amount =
        (servingSizeG != null && servingSizeG > 0) ? servingSizeG : 100.0;

    _startLabelAnalysis(
      displayName: displayName,
      amount: amount,
      per100g: {
        'calories': (data['calories_per_100g'] as num?)?.toDouble(),
        'protein': (data['protein_per_100g'] as num?)?.toDouble(),
        'fat': (data['fat_per_100g'] as num?)?.toDouble(),
        'carbs': (data['carbs_per_100g'] as num?)?.toDouble(),
        'sugar': (data['sugar_per_100g'] as num?)?.toDouble(),
        'fiber': (data['fiber_per_100g'] as num?)?.toDouble(),
        'sodium': (data['sodium_per_100g'] as num?)?.toDouble(),
      },
      labelRawText: (data['raw_text'] as String?)?.trim() ?? '',
    );
  }

  String _fmtNum(num v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// 相机预览上的识别模式切换 chip（餐食识别 / 包装食品）
  Widget _buildModeChip(bool mode, String label) {
    final selected = _isLabelMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _isLabelMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF1A1A1A) : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 把包装食品标签数据拼成"文字描述"，走与文字记录完全相同的 AI 分析链路
  ///
  /// 链路：本描述 → POST /foods/records（description/preset_nutrition → nutrition_agent）
  /// → SSE → FoodAnalysisPage（AI建议 / 收藏 / 确认记录 全部复用）。
  String _buildLabelDescription(
    String displayName,
    double amount,
    Map<String, double?> per100g,
    String labelRawText,
  ) {
    final parts = <String>[];
    void add(String key, String label, String unit) {
      final v = per100g[key];
      if (v != null) parts.add('$label${_fmtNum(v)}$unit');
    }

    add('calories', '能量', 'kcal');
    add('protein', '蛋白质', 'g');
    add('fat', '脂肪', 'g');
    add('carbs', '碳水化合物', 'g');
    add('sugar', '糖', 'g');
    add('fiber', '膳食纤维', 'g');
    add('sodium', '钠', 'mg');

    final buffer = StringBuffer()
      ..writeln('【包装食品】$displayName')
      ..writeln('包装营养成分表（每100克）：${parts.join('、')}。');
    if (labelRawText.isNotEmpty) {
      buffer.writeln('包装标注原文：$labelRawText');
    }
    buffer.writeln('本次食用量：${_fmtNum(amount)}克。');
    return buffer.toString();
  }

  /// 由包装标注值 × 食用量构造精确营养值（后端直接采用，不做 AI 估算）
  Map<String, dynamic> _buildPresetNutrition(
    String displayName,
    double amount,
    Map<String, double?> per100g,
  ) {
    final ratio = amount / 100.0;
    double scaled(String key) => (per100g[key] ?? 0) * ratio;

    return <String, dynamic>{
      'food_items': [displayName],
      'total_calories': scaled('calories'),
      'macronutrients': {
        'protein': scaled('protein'),
        'fat': scaled('fat'),
        'carbohydrates': scaled('carbs'),
        'dietary_fiber': scaled('fiber'),
        'sugar': scaled('sugar'),
      },
      'vitamins_minerals': {
        'sodium': scaled('sodium'),
      },
      'health_level': 3,
      'source_description':
          '包装食品营养成分表（每100克标注值 × 食用量${_fmtNum(amount)}克）',
    };
  }

  /// 开始 AI 分析：复用 /foods/records + FoodAnalysisPage
  void _startLabelAnalysis({
    required String displayName,
    required double amount,
    required Map<String, double?> per100g,
    required String labelRawText,
  }) {
    final pending = FoodRecordCreate(
      recordDate: widget.recordDate,
      recordTime: widget.recordTime ?? DateTime.now().toIso8601String(),
      mealType: widget.mealType ?? 1,
      foodName: displayName,
      description: _buildLabelDescription(
        displayName,
        amount,
        per100g,
        labelRawText,
      ),
      recordingMethod: 1, // AI扫描
      fromSource: 'barcode', // 包装食品识别来源
      cost: widget.costAmount,
      sourceTag: widget.costSource,
      targetUserId: widget.proxyTargetUserId,
      analyzeOnly: true, // 先分析、用户确认后再落库（与餐食流程一致）
      // 精确营养值：跳过 AI 估算，仅生成 AI 建议
      presetNutrition: _buildPresetNutrition(displayName, amount, per100g),
    );

    final analysisStream = _foodService.createFoodRecordStream(pending);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodAnalysisPage(
          analysisStream: analysisStream,
          analyzeOnly: true,
          pendingFoodData: pending,
        ),
      ),
    ).then((result) {
      // 分析页返回后，自动关闭相机页回到首页
      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      }
    });
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

          // 顶部模式切换 + 提示文字
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // 识别模式切换：餐食识别 / 包装食品
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeChip(false, '餐食识别'),
                      _buildModeChip(true, '包装食品'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isLabelMode ? '对准包装上的营养成分表' : '将食物放在框内',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
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
                child: const Icon(
                  LucideIcons.imagePlus,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '桌面端暂不支持相机',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLabelMode
                    ? '请选择包装食品营养成分表照片进行识别'
                    : '请从本地选择食物图片进行 AI 识别',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              // 识别模式切换
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('餐食识别'),
                    selected: !_isLabelMode,
                    onSelected: (_) => setState(() => _isLabelMode = false),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('包装食品'),
                    selected: _isLabelMode,
                    onSelected: (_) => setState(() => _isLabelMode = true),
                  ),
                ],
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

