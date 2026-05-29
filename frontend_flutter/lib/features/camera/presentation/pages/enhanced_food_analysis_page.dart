import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import '../widgets/parallax_background_image.dart';
import '../widgets/nutrition_stats_card.dart';
import '../widgets/ai_analysis_progress_indicator.dart';
import '../widgets/floating_action_section.dart';

class EnhancedFoodAnalysisPage extends StatefulWidget {
  final FoodRecord? foodRecord;
  final Stream<Map<String, dynamic>>? analysisStream;
  final File? imageFile;

  const EnhancedFoodAnalysisPage({
    super.key,
    this.foodRecord,
    this.analysisStream,
    this.imageFile,
  });

  @override
  State<EnhancedFoodAnalysisPage> createState() => _EnhancedFoodAnalysisPageState();
}

class _EnhancedFoodAnalysisPageState extends State<EnhancedFoodAnalysisPage> 
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  int _servingCount = 1;
  final FoodService _foodService = FoodService();
  String? _imageUrl;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // 流式分析相关
  FoodRecord? _currentRecord;
  String _currentStep = '';
  String _currentMessage = '';
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  
  // 动画控制器
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _backgroundController;
  late Animation<double> _backgroundAnimation;
  
  // 从分析数据中提取营养信息
  Map<String, dynamic> _nutritionFacts = {};
  Map<String, dynamic> _recommendations = {};
  String _imageDescription = '';
  String _foodName = '分析中...';
  double _totalCalories = 0.0;
  Map<String, double> _macronutrients = {
    'protein': 0.0,
    'fat': 0.0,
    'carbohydrates': 0.0,
  };

  // 分析进度
  double _analysisProgress = 0.0;
  List<String> _analysisSteps = [
    '上传图片',
    '创建记录',
    '识别食物',
    '提取营养',
    '生成建议',
    '保存数据'
  ];
  int _currentStepIndex = 0;

  // 背景图片透明度控制
  double _backgroundOpacity = 1.0;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeScrollListener();
    _initializeAnalysis();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _backgroundController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _initializeAnimations() {
    // 滑入动画
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
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

    // 背景动画
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeOut),
    );

    // 启动动画
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  void _initializeScrollListener() {
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      final maxScroll = _scrollController.position.maxScrollExtent;
      
      // 计算背景透明度 - 随着滚动渐变
      final scrollProgress = (offset / 300).clamp(0.0, 1.0);
      final newOpacity = 1.0 - (scrollProgress * 0.7); // 最多减少70%透明度
      
      if (_backgroundOpacity != newOpacity) {
        setState(() {
          _backgroundOpacity = newOpacity;
        });
      }
      
      // 当滚动到一定位置时触发背景动画
      if (offset > 200 && !_backgroundController.isCompleted) {
        _backgroundController.forward();
      } else if (offset <= 200 && _backgroundController.isCompleted) {
        _backgroundController.reverse();
      }
    });
  }

  void _initializeAnalysis() {
    if (widget.foodRecord != null) {
      _currentRecord = widget.foodRecord;
      _checkLoadingState();
    } else if (widget.analysisStream != null) {
      _listenToAnalysisStream();
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
              break;
            case 'upload_complete':
              _currentStep = 'upload_complete';
              _currentMessage = data['message'] ?? '图片上传完成';
              _currentStepIndex = 1;
              _analysisProgress = 0.32;
              break;
            case 'record_created':
              if (data['record'] != null) {
                _currentRecord = FoodRecord.fromJson(data['record']);
                _foodName = _currentRecord!.foodName ?? '';
              }
              _currentStep = 'record_created';
              _currentMessage = data['message'] ?? '记录创建成功';
              _currentStepIndex = 2;
              _analysisProgress = 0.48;
              break;
            case 'analysis_started':
              _currentStep = 'analysis_started';
              _currentMessage = data['message'] ?? '开始AI分析...';
              _currentStepIndex = 2;
              _analysisProgress = 0.48;
              break;
            case 'analysis_progress':
              _currentStep = data['current_step'] ?? 'analyzing';
              _currentMessage = _getStepMessage(_currentStep);
              _updateAnalysisProgress(_currentStep);
              break;
            case 'analysis_complete':
              _parseAnalysisDataFromResponse(data);
              _currentStep = 'analysis_complete';
              _currentMessage = '分析完成';
              _currentStepIndex = 4;
              _analysisProgress = 0.85;
              break;
            case 'nutrition_saved':
              _currentStep = 'nutrition_saved';
              _currentMessage = data['message'] ?? '营养数据保存完成';
              _currentStepIndex = 5;
              _analysisProgress = 1.0;
              break;
            case 'stream_complete':
              _currentStep = 'completed';
              _currentMessage = '分析完成';
              _analysisProgress = 1.0;
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

  void _updateAnalysisProgress(String step) {
    switch (step) {
      case 'state_init':
        _currentStepIndex = 2;
        _analysisProgress = 0.50;
        break;
      case 'analyze_image':
        _currentStepIndex = 3;
        _analysisProgress = 0.65;
        break;
      case 'extract_nutrition':
        _currentStepIndex = 3;
        _analysisProgress = 0.75;
        break;
      case 'generate_advice':
        _currentStepIndex = 4;
        _analysisProgress = 0.80;
        break;
      case 'format_response':
        _currentStepIndex = 4;
        _analysisProgress = 0.85;
        break;
    }
  }

  String _getStepMessage(String step) {
    switch (step) {
      case 'state_init':
        return '初始化AI分析系统...';
      case 'analyze_image':
        return '🔍 AI正在识别食物种类...';
      case 'extract_nutrition':
        return '🧮 计算营养成分和卡路里...';
      case 'generate_advice':
        return '💡 生成个性化健康建议...';
      case 'format_response':
        return '📊 整理分析结果...';
      default:
        return '正在处理...';
    }
  }

  void _parseAnalysisDataFromResponse(Map<String, dynamic> data) {
    if (data['image_description'] != null) {
      _imageDescription = data['image_description'];
    }
    
    if (data['nutrition_facts'] != null) {
      final nutritionFacts = data['nutrition_facts'] as Map<String, dynamic>;
      _totalCalories = (nutritionFacts['total_calories'] as num?)?.toDouble() ?? 0.0;
      
      if (nutritionFacts['macronutrients'] != null) {
        final macros = nutritionFacts['macronutrients'] as Map<String, dynamic>;
        _macronutrients = {
          'protein': (macros['protein'] as num?)?.toDouble() ?? 0.0,
          'fat': (macros['fat'] as num?)?.toDouble() ?? 0.0,
          'carbohydrates': (macros['carbohydrates'] as num?)?.toDouble() ?? 0.0,
        };
      }
      
      _nutritionFacts = {
        'total_calories': _totalCalories,
        'macronutrients': _macronutrients,
        'food_items': nutritionFacts['food_items'] ?? [],
      };
    }
    
    if (data['recommendations'] != null) {
      final recommendations = data['recommendations'] as Map<String, dynamic>;
      _recommendations = {
        'health_tips': recommendations['recommendations'] ?? [],
        'dietary_advice': recommendations['dietary_tips'] ?? [],
        'warnings': recommendations['warnings'] ?? [],
        'alternative_foods': recommendations['alternative_foods'] ?? [],
      };
    }
  }

  void _checkLoadingState() {
    if (_currentRecord?.analysisStatus == 3 && _currentRecord?.analysisResult != null) {
      _parseAnalysisData();
      setState(() {
        _isLoading = false;
      });
    } else {
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

      int attempts = 0;
      const maxAttempts = 30;
      
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        
        final result = await _foodService.getFoodRecord(_currentRecord!.id);

        if (result.success && result.data != null) {
          final updatedRecord = result.data!;
          
          if (updatedRecord.analysisStatus == 3) {
            _parseAnalysisDataFromRecord(updatedRecord);
            setState(() {
              _isLoading = false;
            });
            return;
          } else if (updatedRecord.analysisStatus == 4) {
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
        NetworkErrorHandler.handleApiError(context, e, onRetry: _pollAnalysisResult);
      }
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
    
      _totalCalories = analysisResult.nutritionFacts.totalCalories;
      _macronutrients = {
        'protein': analysisResult.nutritionFacts.macronutrients.protein,
        'fat': analysisResult.nutritionFacts.macronutrients.fat,
        'carbohydrates': analysisResult.nutritionFacts.macronutrients.carbohydrates,
      };
      
      _nutritionFacts = {
        'total_calories': _totalCalories,
        'macronutrients': _macronutrients,
        'food_items': analysisResult.nutritionFacts.foodItems ?? [],
      };
      
      _recommendations = {
        'health_tips': analysisResult.recommendations.recommendations ?? [],
        'dietary_advice': analysisResult.recommendations.dietaryTips ?? [],
        'warnings': analysisResult.recommendations.warnings ?? [],
        'alternative_foods': analysisResult.recommendations.alternativeFoods ?? [],
      };
    } else if (record.nutritionDetail != null) {
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

  String? get _displayImageUrl {
    if (widget.imageFile != null) {
      return widget.imageFile!.path;
    }
    return _imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // 背景图片层 - 实现你要求的效果
          ParallaxBackgroundImage(
            imageFile: widget.imageFile,
            imageUrl: _imageUrl,
            scrollController: _scrollController,
            opacity: _backgroundOpacity,
          ),
          
          // 内容层
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return SlideTransition(
                position: _slideAnimation,
                child: _buildContent(),
              );
            },
          ),
          
          // 浮动操作按钮
          if (!_isLoading && !_hasError)
            FloatingActionSection(
              onSaveRecord: _handleSaveRecord,
              onShareResult: _handleShareResult,
            ),
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
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: IconButton(
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              LucideIcons.moreVertical,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _showMoreOptions,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // 顶部留白，让背景图片显示
        const SliverToBoxAdapter(
          child: SizedBox(height: 300),
        ),
        
        // 主要内容区域
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: _isLoading 
              ? _buildLoadingContent()
              : _hasError 
                ? _buildErrorContent() 
                : _buildAnalysisContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // AI分析进度指示器
          AIAnalysisProgressIndicator(
            progress: _analysisProgress,
            currentStep: _currentMessage,
            steps: _analysisSteps,
            currentStepIndex: _currentStepIndex,
          ),
          
          const SizedBox(height: 200),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
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
                    child: const Text(
                      '重新拍摄',
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
          
          const SizedBox(height: 200),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 拖拽指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // 食物标题和描述
            _buildFoodTitle(),
            
            const SizedBox(height: 24),
            
            // 营养统计卡片
            NutritionStatsCard(
              totalCalories: _totalCalories,
              macronutrients: _macronutrients,
              servingCount: _servingCount,
              onServingChanged: (count) {
                setState(() {
                  _servingCount = count;
                });
              },
            ),
            
            const SizedBox(height: 20),
            
            // AI建议卡片
            _buildAIRecommendationsCard(),
            
            const SizedBox(height: 20),
            
            // 识别的食物
            _buildIngredientsCard(),
            
            const SizedBox(height: 100), // 底部留白
          ],
        ),
      ),
    );
  }

  Widget _buildFoodTitle() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _foodName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
              height: 1.2,
            ),
          ),
          
          if (_imageDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _imageDescription,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 快速统计
          Row(
            children: [
              _buildQuickStat(
                icon: LucideIcons.flame,
                value: '${_totalCalories.round()}',
                label: '卡路里',
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 20),
              _buildQuickStat(
                icon: LucideIcons.activity,
                value: '${_macronutrients['protein']!.round()}g',
                label: '蛋白质',
                color: const Color(0xFF4ECDC4),
              ),
              const SizedBox(width: 20),
              _buildQuickStat(
                icon: LucideIcons.zap,
                value: '${_macronutrients['carbohydrates']!.round()}g',
                label: '碳水',
                color: const Color(0xFFFFE66D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendationsCard() {
    final healthTips = _recommendations['health_tips'] as List? ?? [];
    final dietaryAdvice = _recommendations['dietary_advice'] as List? ?? [];
    
    if (healthTips.isEmpty && dietaryAdvice.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: Color(0xFF2BAF74),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'AI智能建议',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 健康提示
          if (healthTips.isNotEmpty) ...[
            ...healthTips.take(3).map((tip) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2BAF74).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
                ),
              ),
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
                        fontSize: 15,
                        color: Color(0xFF222222),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildIngredientsCard() {
    final foodItems = _nutritionFacts['food_items'] as List? ?? [];
    
    if (foodItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '识别的食物',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 食物列表
          ...foodItems.take(5).map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.utensils, 
                    size: 16, 
                    color: Color(0xFF2BAF74),
                  ),
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
          )).toList(),
        ],
      ),
    );
  }

  void _showMoreOptions() {
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
            
            ListTile(
              leading: const Icon(LucideIcons.share2, color: Color(0xFF2BAF74)),
              title: const Text('分享结果'),
              onTap: () {
                Navigator.pop(context);
                _handleShareResult();
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.bookmark, color: Color(0xFF2BAF74)),
              title: const Text('保存到收藏'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 实现保存功能
              },
            ),
            
            ListTile(
              leading: const Icon(LucideIcons.messageCircle, color: Color(0xFF2BAF74)),
              title: const Text('AI对话咨询'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 跳转到AI对话页面
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleSaveRecord() {
    Navigator.pop(context);
    Navigator.pop(context); // 返回到主页
  }

  void _handleShareResult() {
    // TODO: 实现分享功能
  }
}