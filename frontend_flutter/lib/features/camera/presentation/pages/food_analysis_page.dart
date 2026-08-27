import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../../../../services/food_service.dart';
import '../../../../services/goal_tracking_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../home/presentation/widgets/cost_input_widget.dart'; // 导入消费输入组件
import '../../../../services/saved_meal_service.dart';
import '../../../../shared/domain/models/saved_meal_model.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class FoodAnalysisPage extends ConsumerStatefulWidget {
  final FoodRecord? foodRecord;
  final Stream<Map<String, dynamic>>? analysisStream;
  final File? imageFile;

  /// 仅分析模式：不落库，展示结果后由用户点"确认创建记录"再落库
  final bool analyzeOnly;

  /// 仅分析模式下，确认落库所需的原始创建数据
  final FoodRecordCreate? pendingFoodData;

  const FoodAnalysisPage({
    super.key,
    this.foodRecord,
    this.analysisStream,
    this.imageFile,
    this.analyzeOnly = false,
    this.pendingFoodData,
  });

  @override
  ConsumerState<FoodAnalysisPage> createState() => _FoodAnalysisPageState();
}

class _FoodAnalysisPageState extends ConsumerState<FoodAnalysisPage>
    with TickerProviderStateMixin {
  int _servingCount = 1;
  final FoodService _foodService = FoodService();
  final GoalTrackingService _goalService = GoalTrackingService();
  final SavedMealService _savedMealService = SavedMealService();
  bool _isSaving = false;
  bool _hasSaved = false;
  int? _savedMealId;
  String? _imageUrl;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _targetCalories = 0; // 每日卡路里目标

  // 流式分析相关
  FoodRecord? _currentRecord;
  String _currentStep = '';
  String _currentMessage = '';
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  // 消费金额和来源
  double? _costAmount;
  String? _costSource;

  // 动画控制器
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  // 从分析数据中提取营养信息
  Map<String, dynamic> _nutritionFacts = {};
  Map<String, dynamic> _recommendations = {};

  // 完整的 AI 营养分析结果（确认落库时原样回传）
  Map<String, dynamic> _rawAnalysisData = {};
  String _imageDescription = '';
  String _shortComment = '';
  String _foodName = '分析中...';
  double _totalCalories = 0.0;
  Map<String, double> _macronutrients = {
    'protein': 0.0,
    'fat': 0.0,
    'carbohydrates': 0.0,
  };

  // 分析进度
  double _analysisProgress = 0.0;
  late List<String> _analysisSteps;
  late bool _isTextAnalysis;
  int _currentStepIndex = 0;

  // 上传成功后的图片 object_name（仅分析模式下 _currentRecord 为空，确认时回传）
  String? _uploadedImageUrl;

  /// 文字分析比图片分析少"上传图片"和"上传完成"两步，索引偏移-2；
  /// 仅分析模式比完整流程少"创建记录/保存数据"两步，索引再偏移-1
  int _stepIndex(int imageBaseIndex) {
    if (_isTextAnalysis) return imageBaseIndex - 2;
    if (widget.analyzeOnly) return imageBaseIndex - 1;
    return imageBaseIndex;
  }

  @override
  void initState() {
    super.initState();
    // 根据是否有图片决定分析步骤；仅分析模式：先分析、确认后再创建记录
    _isTextAnalysis = widget.imageFile == null && widget.foodRecord == null;
    _analysisSteps = _isTextAnalysis
        ? ['创建记录', '分析食物', '提取营养', '生成建议', '保存数据']
        : (widget.analyzeOnly
            ? ['上传图片', '识别食物', '提取营养', '生成建议', '等待确认']
            : ['上传图片', '创建记录', '识别食物', '提取营养', '生成建议', '保存数据']);
    _initializeAnimations();
    _initializeAnalysis();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _progressController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnalysis() {
    _loadDailyTarget();
    if (widget.foodRecord != null) {
      _currentRecord = widget.foodRecord;
      _checkLoadingState();
    } else if (widget.analysisStream != null) {
      _listenToAnalysisStream();
    }
  }

  Future<void> _loadDailyTarget() async {
    try {
      // 与首页一致：优先使用用户手动设置的卡路里目标，
      // 未设置时才回退到系统按 TDEE 计算的值（daily_targets.calories）
      final userProfile =
          await ref.read(userProfileProvider.notifier).loadUserProfileAndGet();
      final userTarget = userProfile?.targetCalories;
      if (userTarget != null && userTarget > 0) {
        if (mounted) {
          setState(() {
            _targetCalories = userTarget.toDouble();
          });
        }
      }

      final result = await _goalService.getDailyStatus();
      if (result.success && result.data != null) {
        final targets = result.data!['daily_targets'] as Map<String, dynamic>?;
        if (targets != null && mounted) {
          setState(() {
            if (_targetCalories <= 0) {
              _targetCalories = (targets['calories'] as num?)?.toDouble() ?? 0;
            }
          });
        }
      }
    } catch (e) {
      // 非关键功能，静默失败
    }
  }

  void _listenToAnalysisStream() {
    if (widget.analysisStream == null) return;

    _streamSubscription = widget.analysisStream!.listen(
      (event) {
        if (!mounted) return;

        final type = event['type'] as String?;
        final success = event['success'] as bool? ?? false;
        final data = event['data'] as Map<String, dynamic>? ?? {};

        setState(() {
          switch (type) {
            case 'upload_started':
              _currentStep = 'upload';
              _currentMessage = data['message'] ?? '正在上传图片...';
              _currentStepIndex = 0;
              _analysisProgress = 0.16;
              _updateProgressAnimation();
              break;
            case 'upload_complete':
              _currentStep = 'upload_complete';
              _currentMessage = data['message'] ?? '图片上传完成';
              // 保存图片 object_name（仅分析模式确认创建时回传）
              if (data['object_name'] != null) {
                _uploadedImageUrl = data['object_name'].toString();
              }
              _currentStepIndex = 1;
              _analysisProgress = 0.32;
              _updateProgressAnimation();
              break;
            case 'record_created':
              if (data['record'] != null) {
                try {
                  _currentRecord = FoodRecord.fromJson(data['record']);
                  _foodName = _currentRecord!.foodName ?? '';
                } catch (parseErr) {
                  // 防御：临时记录字段异常时不阻断后续分析流程
                  print('⚠️ record_created 解析失败: $parseErr');
                }
              }
              _currentStep = 'record_created';
              _currentMessage = data['message'] ?? '记录创建成功';
              _currentStepIndex = _stepIndex(2);
              _analysisProgress = 0.48;
              _updateProgressAnimation();
              break;
            case 'analysis_started':
              _currentStep = 'analysis_started';
              _currentMessage = data['message'] ?? '开始AI分析...';
              _currentStepIndex = _stepIndex(2);
              _analysisProgress = 0.30;
              _updateProgressAnimation();
              break;
            case 'analysis_progress':
              _currentStep = data['current_step'] ?? 'analyzing';
              _currentMessage = _getStepMessage(_currentStep);
              _updateAnalysisProgress(
                _currentStep,
                data['percentage'] as double?,
              );
              break;
            case 'analysis_complete':
              _parseAnalysisDataFromResponse(data);
              _currentStep = 'analysis_complete';
              _currentMessage = '分析完成';
              _currentStepIndex = _stepIndex(4);
              _analysisProgress = 0.95;
              _updateProgressAnimation();
              break;
            case 'nutrition_saved':
              _currentStep = 'nutrition_saved';
              _currentMessage = data['message'] ?? '营养数据保存完成';
              _currentStepIndex = _stepIndex(5);
              _analysisProgress = 1.0;
              _updateProgressAnimation();
              break;
            case 'stream_complete':
              _currentStep = 'completed';
              _currentMessage = '分析完成';
              _analysisProgress = 1.0;
              // 用后端返回的最终食物名更新（兜底确保不空白）
              if (data['food_name'] != null &&
                  data['food_name'].toString().isNotEmpty) {
                _foodName = data['food_name'].toString();
              }
              _updateProgressAnimation();
              setState(() {
                _isLoading = false;
              });
              break;
            case 'error':
            case 'upload_failed':
            case 'analysis_failed':
              _hasError = true;
              _errorMessage = data['error'] ?? data['message'] ?? '处理失败';
              _isLoading = false;
              break;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = '流式处理错误: $error';
          _isLoading = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        if (_currentStep != 'completed') {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  /// 根据 Agent 实际推进的节点更新进度。
  /// [percentage] 为后端按实际完成度下发的值（0.30-0.95），只增不减避免进度回退；
  /// 缺省时回退到按步骤的估算值。
  void _updateAnalysisProgress(String step, [double? percentage]) {
    switch (step) {
      case 'starting':
      case 'state_init':
        _currentStepIndex = _stepIndex(2);
        if (percentage == null) _analysisProgress = 0.35;
        break;
      case 'image_analyzed':
      case 'analyze_image':
      case 'analyze_text':
      case 'text_analyzed':
        _currentStepIndex = _stepIndex(2);
        if (percentage == null) _analysisProgress = 0.50;
        break;
      case 'nutrition_extracted':
      case 'extract_nutrition':
        _currentStepIndex = _stepIndex(3);
        if (percentage == null) _analysisProgress = 0.70;
        break;
      case 'retrieve_nutrition_knowledge':
        _currentStepIndex = _stepIndex(3);
        if (percentage == null) _analysisProgress = 0.78;
        break;
      case 'advice_generated':
      case 'generate_advice':
        _currentStepIndex = _stepIndex(4);
        if (percentage == null) _analysisProgress = 0.88;
        break;
      case 'allergy_checked':
      case 'format_response':
        _currentStepIndex = _stepIndex(4);
        if (percentage == null) _analysisProgress = 0.95;
        break;
    }
    if (percentage != null) {
      final p = percentage.clamp(0.0, 0.95);
      if (p > _analysisProgress) {
        _analysisProgress = p;
      }
    }
    _updateProgressAnimation();
  }

  void _updateProgressAnimation() {
    _progressController.animateTo(_analysisProgress);
  }

  String _getStepMessage(String step) {
    switch (step) {
      case 'starting':
      case 'state_init':
        return '🚀 初始化AI分析系统...';
      case 'image_analyzed':
      case 'analyze_image':
      case 'analyze_text':
      case 'text_analyzed':
        return '🔍 AI正在识别食物种类...';
      case 'nutrition_extracted':
      case 'extract_nutrition':
        return '🧮 计算营养成分和卡路里...';
      case 'retrieve_nutrition_knowledge':
        return '📚 检索营养知识库...';
      case 'advice_generated':
      case 'generate_advice':
        return '💡 生成个性化健康建议...';
      case 'allergy_checked':
      case 'format_response':
        return '⚖️ 检查过敏与饮食禁忌...';
      default:
        return '正在处理...';
    }
  }

  void _parseAnalysisDataFromResponse(Map<String, dynamic> data) {
    // 保存完整分析结果，供"确认创建记录"时原样回传后端落库
    _rawAnalysisData = Map<String, dynamic>.of(data);

    if (data['image_description'] != null) {
      _imageDescription = data['image_description'];
    }

    if (data['short_comment'] != null &&
        data['short_comment'].toString().isNotEmpty) {
      _shortComment = data['short_comment'].toString();
    }

    if (data['nutrition_facts'] != null) {
      final nutritionFacts = data['nutrition_facts'] as Map<String, dynamic>;
      _totalCalories =
          (nutritionFacts['total_calories'] as num?)?.toDouble() ?? 0.0;

      if (nutritionFacts['macronutrients'] != null) {
        final macros = nutritionFacts['macronutrients'] as Map<String, dynamic>;
        _macronutrients = {
          'protein': (macros['protein'] as num?)?.toDouble() ?? 0.0,
          'fat': (macros['fat'] as num?)?.toDouble() ?? 0.0,
          'carbohydrates': (macros['carbohydrates'] as num?)?.toDouble() ?? 0.0,
        };
      }

      final foodItems = nutritionFacts['food_items'] as List? ?? [];
      _nutritionFacts = {
        'total_calories': _totalCalories,
        'macronutrients': _macronutrients,
        'food_items': foodItems,
      };

      // 用AI识别的食物名称更新标题
      if (foodItems.isNotEmpty) {
        _foodName = foodItems.length == 1
            ? foodItems[0].toString()
            : foodItems.take(3).join('、');
      }
    }

    if (data['recommendations'] != null) {
      final recommendations = data['recommendations'] as Map<String, dynamic>;
      _recommendations = {
        'health_tips': recommendations['recommendations'] ?? [],
        'dietary_advice': recommendations['dietary_tips'] ?? [],
        'warnings': recommendations['warnings'] ?? [],
        'alternative_foods': recommendations['alternative_foods'] ?? [],
        'action_items': recommendations['action_items'] ?? [],
      };
    }
  }

  void _initializeAnimations() {
    // 脉冲动画 - 用于加载指示器
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 闪光动画 - 用于骨架屏
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // 进度动画
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );

    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  void _checkLoadingState() {
    // 检查分析状态：1-待分析，2-分析中，3-已完成
    if (_currentRecord?.analysisStatus == 3 &&
        _currentRecord?.analysisResult != null) {
      // 已完成分析，解析结果
      _parseAnalysisData();
      setState(() {
        _isLoading = false;
      });
    } else {
      // 分析中或待分析，轮询等待结果
      _pollAnalysisResult();
    }
    _loadImageUrl();
  }

  Future<void> _pollAnalysisResult() async {
    if (_currentRecord == null) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // 轮询检查分析结果
      int attempts = 0;
      const maxAttempts = 30; // 最多等待30次 (30秒)

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));

        final result = await _foodService.getFoodRecord(_currentRecord!.id);

        if (result.success && result.data != null) {
          final updatedRecord = result.data!;

          if (updatedRecord.analysisStatus == 3) {
            // 分析完成
            _parseAnalysisDataFromRecord(updatedRecord);
            setState(() {
              _isLoading = false;
            });
            return;
          } else if (updatedRecord.analysisStatus == 4) {
            // 分析失败
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = '食物分析失败，请重试';
            });
            return;
          }
        }

        attempts++;
      }

      // 超时
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '分析超时，请稍后查看分析结果';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '获取分析结果失败: $e';
      });
      if (mounted) {
        NetworkErrorHandler.handleApiError(context, e,
            onRetry: _pollAnalysisResult);
      }
    }
  }

  /// 更新记录的消费信息
  Future<void> _updateRecordCost() async {
    if (_currentRecord == null) return;

    try {
      // 使用 FoodRecordCreate 更新消费信息
      final updateData = FoodRecordCreate(
        recordDate: _currentRecord!.recordDate,
        recordTime: _currentRecord!.recordTime,
        mealType: _currentRecord!.mealType,
        foodName: _currentRecord!.foodName ?? '未命名食物', // 处理可空值
        description: _currentRecord!.description,
        imageUrl: _currentRecord!.imageUrl,
        recordingMethod: _currentRecord!.recordingMethod,
        cost: _costAmount,
        sourceTag: _costSource,
      );

      final result = await _foodService.updateFoodRecord(
        _currentRecord!.id,
        updateData,
      );

      if (!result.success) {
        print('更新消费信息失败: ${result.message}');
      }
    } catch (e) {
      print('更新消费信息异常: $e');
    }
  }

  /// 仅分析模式：用户确认后一次性创建记录
  Future<void> _confirmCreateRecord() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final pending = widget.pendingFoodData;
      final nfRaw = _rawAnalysisData['nutrition_facts'];
      final nfMap =
          nfRaw is Map ? Map<String, dynamic>.from(nfRaw) : <String, dynamic>{};
      final foodItems = (nfMap['food_items'] as List?) ?? [];

      final payload = <String, dynamic>{
        'record_date': pending?.recordDate ?? _currentRecord?.recordDate,
        'record_time': pending?.recordTime ?? _currentRecord?.recordTime,
        'meal_type': pending?.mealType ?? _currentRecord?.mealType ?? 1,
        'food_name': _foodName == '分析中...' ? '' : _foodName,
        'description': pending?.description ?? _currentRecord?.description,
        'image_url':
            _uploadedImageUrl ?? _currentRecord?.imageUrl ?? pending?.imageUrl,
        'recording_method': 1, // AI扫描
        'from_source': 'camera',
        'cost': _costAmount ?? pending?.cost,
        'source_tag': _costSource ?? pending?.sourceTag,
        'target_user_id': pending?.targetUserId,
        'nutrition_facts': nfMap,
        'recommendations': _recommendations,
        'short_comment': _shortComment,
        'image_description': _imageDescription,
        'food_items': foodItems,
      };

      final result = await _foodService.confirmCreateFoodRecord(payload);
      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: ${result.message}')),
        );
      }
    } catch (e) {
      print('❌ 确认创建食物记录异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _parseAnalysisData() {
    if (_currentRecord != null) {
      _parseAnalysisDataFromRecord(_currentRecord!);
    }
  }

  void _parseAnalysisDataFromRecord(FoodRecord record) {
    _foodName = record.foodName ?? '';

    if (record.analysisResult != null) {
      final analysisResult = record.analysisResult!;
      _imageDescription = analysisResult.imageDescription;
      _shortComment = analysisResult.shortComment ?? '';

      // 解析营养成分（优先nutritionDetail，其次analysisResult.nutritionFacts）
      if (analysisResult.nutritionFacts != null) {
        final nf = analysisResult.nutritionFacts!;
        _totalCalories = nf.totalCalories;
        _macronutrients = {
          'protein': nf.macronutrients.protein,
          'fat': nf.macronutrients.fat,
          'carbohydrates': nf.macronutrients.carbohydrates,
        };
        _nutritionFacts = {
          'total_calories': _totalCalories,
          'macronutrients': _macronutrients,
          'food_items': nf.foodItems ?? [],
        };
      } else if (record.nutritionDetail != null) {
        final nd = record.nutritionDetail!;
        _totalCalories = nd.calories;
        _macronutrients = {
          'protein': nd.protein,
          'fat': nd.fat,
          'carbohydrates': nd.carbohydrates,
        };
        _nutritionFacts = {
          'total_calories': _totalCalories,
          'macronutrients': _macronutrients,
          'food_items': [],
        };
      }

      // 转换推荐建议为Map格式以兼容现有UI
      _recommendations = {
        'health_tips': analysisResult.recommendations.recommendations ?? [],
        'dietary_advice': analysisResult.recommendations.dietaryTips ?? [],
        'warnings': analysisResult.recommendations.warnings ?? [],
        'alternative_foods':
            analysisResult.recommendations.alternativeFoods ?? [],
        'action_items': (analysisResult.recommendations.actionItems ?? [])
            .map((item) => {'action': item.action, 'priority': item.priority})
            .toList(),
      };
    } else if (record.nutritionDetail != null) {
      // 如果没有AI分析结果，但有营养详情，则使用营养详情数据
      final nutrition = record.nutritionDetail!;
      _totalCalories = nutrition.calories;
      _macronutrients = {
        'protein': nutrition.protein,
        'fat': nutrition.fat,
        'carbohydrates': nutrition.carbohydrates,
      };

      _nutritionFacts = {
        'total_calories': _totalCalories,
        'macronutrients': _macronutrients,
        'food_items': [],
      };

      _recommendations = {
        'health_tips': ['营养数据已更新'],
        'dietary_advice': ['请保持均衡饮食'],
        'warnings': [],
        'alternative_foods': [],
        'action_items': [],
      };
    }
  }

  Future<void> _loadImageUrl() async {
    final imageUrl = _currentRecord?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final result = await _foodService.getImageUrl(imageUrl);
        if (result.success && result.data != null) {
          setState(() {
            _imageUrl = result.data!.fileUrl;
          });
        }
      } catch (e) {
        print('获取图片URL失败: $e');
        if (mounted) {
          NetworkErrorHandler.handleApiError(context, e);
        }
      }
    }
  }

  Widget _buildLoadingView() {
    return Container(
      color: const Color(0xFFF5F7F6),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食物图片预览 (立即显示)
            _buildFoodImageHeader(),

            // AI分析进度卡片
            _buildAnalysisProgressCard(),

            // 分析步骤展示
            _buildAnalysisStepsCard(),

            // 预览卡片（骨架屏）
            _buildPreviewCards(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: const Color(0xFFF5F7F6),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.alertCircle,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '分析失败',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BAF74),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: Text(
                      _isTextAnalysis ? '重试' : '重新拍摄',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentView() {
    return Container(
      color: const Color(0xFFF5F7F6),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 食物图片和基本信息
            _buildFoodImageHeader(),

            if (_shortComment.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildShortCommentCard(),
            ],

            const SizedBox(height: 12),

            // 卡路里和份量
            _buildCaloriesAndServingCard(),

            const SizedBox(height: 12),

            // 宏营养素圆环图
            _buildMacronutrientsCard(),

            const SizedBox(height: 12),

            // AI建议卡片
            _buildAIRecommendationsCard(),

            const SizedBox(height: 12),

            // 配料信息
            _buildIngredientsCard(),

            const SizedBox(height: 12),

            // 消费输入组件
            CostInputWidget(
              initialAmount: widget.foodRecord?.cost,
              initialSource: widget.foodRecord?.sourceTag,
              onChanged: (amount, source) {
                setState(() {
                  _costAmount = amount;
                  _costSource = source;
                });
              },
            ),

            const SizedBox(height: 100), // 底部按钮预留空间
          ],
        ),
      ),
    );
  }

  Widget _buildShortCommentCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2BAF74), Color(0xFF1E8C5E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2BAF74).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _shortComment,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodImageHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 食物图片
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImageContent(),
              ),
            ),

            const SizedBox(height: 20),

            // 食物名称
            Text(
              _foodName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
              textAlign: TextAlign.center,
            ),

            if (_imageDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _imageDescription,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    // 优先显示传入的本地图片文件
    if (widget.imageFile != null) {
      return Image.file(
        widget.imageFile!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(LucideIcons.image, size: 60, color: Colors.grey),
      );
    }

    // 其次显示网络图片URL
    if (_imageUrl != null) {
      return Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(LucideIcons.image, size: 60, color: Colors.grey),
      );
    }

    // 文字分析显示文字描述图标
    return Icon(
      _isTextAnalysis ? LucideIcons.fileText : LucideIcons.image,
      size: 60,
      color: Colors.grey,
    );
  }

  Widget _buildAnalysisProgressCard() {
    if (!_isLoading) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2BAF74),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStepIcon(_currentStep),
                          color: Colors.white,
                          size: 24,
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
                      Text(
                        _currentMessage.isNotEmpty
                            ? _currentMessage
                            : 'AI正在分析您的食物...',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          final progress = _progressAnimation.value;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFE6FAF0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2BAF74)),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${(progress * 100).round()}% 完成',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisStepsCard() {
    if (!_isLoading) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '分析步骤',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            ..._analysisSteps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isCompleted = index < _currentStepIndex;
              final isCurrent = index == _currentStepIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF2BAF74)
                            : isCurrent
                                ? const Color(0xFFA6E3C1)
                                : const Color(0xFFE6FAF0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted ? LucideIcons.check : LucideIcons.circle,
                        size: 12,
                        color: isCompleted
                            ? Colors.white
                            : isCurrent
                                ? const Color(0xFF2BAF74)
                                : const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      step,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCompleted || isCurrent
                            ? const Color(0xFF222222)
                            : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCards() {
    return Column(
      children: [
        _buildSkeletonCard(height: 120, title: '营养信息'),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 200, title: '营养成分分析'),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 160, title: 'AI健康建议'),
      ],
    );
  }

  Widget _buildSkeletonCard({required double height, required String title}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        height: height,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[200]!,
                          Colors.grey[100]!,
                          Colors.grey[200]!,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment(_shimmerAnimation.value, 0),
                        end: Alignment(_shimmerAnimation.value + 1, 0),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStepIcon(String step) {
    switch (step) {
      case 'upload':
        return LucideIcons.upload;
      case 'upload_complete':
        return LucideIcons.checkCircle;
      case 'record_created':
        return LucideIcons.database;
      case 'analysis_started':
      case 'state_init':
        return LucideIcons.brain;
      case 'analyze_image':
        return LucideIcons.eye;
      case 'extract_nutrition':
        return LucideIcons.activity;
      case 'generate_advice':
        return LucideIcons.heart;
      case 'format_response':
        return LucideIcons.fileText;
      case 'analysis_complete':
      case 'nutrition_saved':
        return LucideIcons.checkCircle;
      default:
        return LucideIcons.brain;
    }
  }

  Future<void> _saveToFavorites() async {
    if (_isSaving) return;

    // 分析未完成时给出反馈，而不是静默无响应
    final bool analysisReady = _currentRecord != null ||
        (widget.analyzeOnly && _foodName.isNotEmpty && _foodName != '分析中...');
    if (!analysisReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('分析未完成，暂无法收藏'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }
    setState(() => _isSaving = true);

    if (_hasSaved) {
      // 取消收藏
      try {
        final result = await _savedMealService.deleteSavedMeal(_savedMealId!);
        if (result.success) {
          setState(() {
            _hasSaved = false;
            _savedMealId = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('已取消收藏'), duration: Duration(seconds: 2)),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message.isEmpty ? '操作失败' : result.message),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('取消收藏失败: $e'),
                duration: const Duration(seconds: 2)),
          );
        }
      }
    } else {
      // 保存收藏
      try {
        final String mealName = _foodName.isNotEmpty && _foodName != '分析中...'
            ? _foodName
            : 'AI分析菜品';
        final String? description = _imageDescription.isNotEmpty
            ? (_imageDescription.length > 200
                ? _imageDescription.substring(0, 200)
                : _imageDescription)
            : null;

        final ApiResponse<SavedMeal> result;
        if (_currentRecord != null) {
          // 有真实食物记录：走 from-food-record 接口
          result = await _savedMealService.createSavedMealFromRecord(
            foodRecordId: _currentRecord!.id,
            mealName: mealName,
            description: description,
          );
        } else {
          // 仅分析模式：_currentRecord 为 null，用内存中的分析结果直接创建收藏
          result = await _savedMealService.createSavedMeal(
            SavedMealCreate(
              mealName: mealName,
              description: description,
              imageUrl: _uploadedImageUrl,
              nutrition: SavedMealNutrition(
                servingSize: _servingCount.toDouble(),
                servingUnit: '份',
                calories: _totalCalories,
                protein: _macronutrients['protein'] ?? 0,
                fat: _macronutrients['fat'] ?? 0,
                carbohydrates: _macronutrients['carbohydrates'] ?? 0,
                dietaryFiber: 0,
                sugar: 0,
                sodium: 0,
                cholesterol: 0,
                vitaminA: 0,
                vitaminC: 0,
                vitaminD: 0,
                calcium: 0,
                iron: 0,
                potassium: 0,
              ),
            ),
          );
        }

        if (result.success && result.data != null) {
          setState(() {
            _hasSaved = true;
            _savedMealId = result.data!.id;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('已保存到收藏'), duration: Duration(seconds: 2)),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.message.isEmpty ? '保存失败' : result.message),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('保存失败: $e'),
                duration: const Duration(seconds: 2)),
          );
        }
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isLoading ? '分析中...' : (_foodName.isNotEmpty ? _foodName : 'AI分析结果'),
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading) ...[
            // 营养师问答按钮
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2BAF74),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              tooltip: '营养师问答',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatPage(
                      sessionType: 3,
                      title: '食物营养咨询',
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _hasSaved
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF2BAF74),
                  shape: BoxShape.circle,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        LucideIcons.bookmark,
                        size: 16,
                        color: Colors.white,
                      ),
              ),
              onPressed: _isLoading ? null : _saveToFavorites,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _hasError
              ? _buildErrorView()
              : _buildContentView(),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildCaloriesAndServingCard() {
    final actualCalories = (_totalCalories * _servingCount).round();
    final budgetPercent = _targetCalories > 0
        ? (actualCalories / _targetCalories * 100).round()
        : 0;
    final budgetColor = budgetPercent > 100
        ? const Color(0xFFFF6B6B)
        : budgetPercent > 70
            ? const Color(0xFFFFA726)
            : const Color(0xFF2BAF74);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 卡路里信息
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BAF74),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.flame,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$actualCalories 千卡',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // 份量控制器
                Row(
                  children: [
                    const Text(
                      '份量',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FAF0),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: _servingCount > 1
                                ? () {
                                    setState(() => _servingCount--);
                                  }
                                : null,
                            icon: const Icon(LucideIcons.minus, size: 14),
                            color: const Color(0xFF2BAF74),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            child: Text(
                              '$_servingCount',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _servingCount++);
                            },
                            icon: const Icon(LucideIcons.plus, size: 14),
                            color: const Color(0xFF2BAF74),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 热量预算占比
            if (_targetCalories > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: budgetColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          budgetPercent > 100
                              ? LucideIcons.alertTriangle
                              : LucideIcons.target,
                          size: 16,
                          color: budgetColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '占每日目标 ${_targetCalories.round()} kcal 的 $budgetPercent%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: budgetColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (budgetPercent / 100).clamp(0.0, 1.0),
                        backgroundColor: const Color(0xFFE6FAF0),
                        valueColor: AlwaysStoppedAnimation<Color>(budgetColor),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          budgetPercent > 100
                              ? '已超出每日目标 ${actualCalories - _targetCalories.round()} kcal'
                              : '剩余 ${_targetCalories.round() - actualCalories} kcal 可摄入',
                          style: TextStyle(
                            fontSize: 12,
                            color: budgetColor,
                          ),
                        ),
                        Text(
                          '$budgetPercent%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: budgetColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacronutrientsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '营养成分分析',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),

            const SizedBox(height: 20),

            // 营养成分圆环图
            Row(
              children: [
                Expanded(
                  child: _buildNutrientCircle(
                    label: '碳水化合物',
                    value:
                        '${(_macronutrients['carbohydrates']! * _servingCount).round()}g',
                    color: const Color(0xFF2BAF74),
                    percentage:
                        _calculatePercentage(_macronutrients['carbohydrates']!),
                  ),
                ),
                Expanded(
                  child: _buildNutrientCircle(
                    label: '蛋白质',
                    value:
                        '${(_macronutrients['protein']! * _servingCount).round()}g',
                    color: const Color(0xFFA6E3C1),
                    percentage:
                        _calculatePercentage(_macronutrients['protein']!),
                  ),
                ),
                Expanded(
                  child: _buildNutrientCircle(
                    label: '脂肪',
                    value:
                        '${(_macronutrients['fat']! * _servingCount).round()}g',
                    color: const Color(0xFFDEF5E9),
                    percentage: _calculatePercentage(_macronutrients['fat']!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculatePercentage(double value) {
    final total = _macronutrients.values.fold(0.0, (sum, val) => sum + val);
    return total > 0 ? value / total : 0.0;
  }

  Widget _buildNutrientCircle({
    required String label,
    required String value,
    required Color color,
    required double percentage,
  }) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: const Color(0xFFE6FAF0),
              ),
            ),
            Text(
              value.split('g')[0],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Map<String, dynamic> _getPriorityConfig(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return {
          'label': '紧急',
          'bgColor': const Color(0xFFFFEBEE),
          'textColor': const Color(0xFFD32F2F),
        };
      case 'medium':
        return {
          'label': '建议',
          'bgColor': const Color(0xFFFFF8E1),
          'textColor': const Color(0xFFF57C00),
        };
      case 'low':
        return {
          'label': '可选',
          'bgColor': const Color(0xFFE6FAF0),
          'textColor': const Color(0xFF2BAF74),
        };
      default:
        return {
          'label': '建议',
          'bgColor': const Color(0xFFFFF8E1),
          'textColor': const Color(0xFFF57C00),
        };
    }
  }

  Widget _buildAIRecommendationsCard() {
    final healthTips = _recommendations['health_tips'] as List? ?? [];
    final dietaryAdvice = _recommendations['dietary_advice'] as List? ?? [];
    final actionItemsRaw = _recommendations['action_items'] as List? ?? [];

    if (healthTips.isEmpty && dietaryAdvice.isEmpty && actionItemsRaw.isEmpty) {
      return const SizedBox.shrink();
    }

    // 解析行动项
    final actionItems = actionItemsRaw
        .map((item) {
          if (item is Map<String, dynamic>) {
            return ActionItem(
              action: item['action'] as String? ?? '',
              priority: item['priority'] as String? ?? 'medium',
            );
          }
          return null;
        })
        .whereType<ActionItem>()
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2BAF74).withValues(alpha: 0.05),
              const Color(0xFF2BAF74).withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2BAF74),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'AI健康建议',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
              ],
            ),

            // 行动项（优先展示）
            if (actionItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.listChecks,
                          size: 16,
                          color: Color(0xFFF57C00),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '建议行动',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF57C00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...actionItems.map((item) {
                      final priorityConfig = _getPriorityConfig(item.priority);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: priorityConfig['bgColor'],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                priorityConfig['label'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: priorityConfig['textColor'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.action,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF222222),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 健康提示
            if (healthTips.isNotEmpty) ...[
              ...healthTips
                  .take(3)
                  .map((tip) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2BAF74),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF222222),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],

            // 饮食建议
            if (dietaryAdvice.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...dietaryAdvice
                  .take(2)
                  .map((advice) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(top: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFA6E3C1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                advice.toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF222222),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ],

            // 营养师问答按钮
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatPage(
                        sessionType: 3,
                        title: '食物营养咨询',
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  LucideIcons.messageCircle,
                  size: 18,
                  color: Color(0xFF2BAF74),
                ),
                label: const Text(
                  '向AI营养师咨询更多',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2BAF74),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2BAF74), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsCard() {
    final foodItems = _nutritionFacts['food_items'] as List? ?? [];

    if (foodItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '识别的食物',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),

            const SizedBox(height: 16),

            // 食物列表
            ...foodItems
                .take(5)
                .map((item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FAF0),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.utensils,
                            size: 20,
                            color: Color(0xFF2BAF74),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF222222),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    if (widget.analyzeOnly) {
                      // 仅分析模式：展示结果后由用户确认，再创建记录
                      await _confirmCreateRecord();
                    } else {
                      // 更新消费信息
                      if (_currentRecord != null &&
                          (_costAmount != null || _costSource != null)) {
                        await _updateRecordCost();
                      }

                      if (mounted) {
                        Navigator.of(context).pop(true);
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoading
                  ? const Color(0xFFE6FAF0)
                  : const Color(0xFF2BAF74),
              foregroundColor:
                  _isLoading ? const Color(0xFF666666) : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
            ),
            child: _isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF2BAF74),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '分析中...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    widget.analyzeOnly ? '确认创建记录' : '记录餐食',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
