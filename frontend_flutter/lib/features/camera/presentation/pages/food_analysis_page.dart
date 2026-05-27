import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:async';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../../shared/presentation/widgets/error_handler.dart';
import '../../../chat/presentation/pages/chat_page.dart';

class FoodAnalysisPage extends StatefulWidget {
  final FoodRecord? foodRecord;
  final Stream<Map<String, dynamic>>? analysisStream;
  final File? imageFile;

  const FoodAnalysisPage({
    super.key,
    this.foodRecord,
    this.analysisStream,
    this.imageFile,
  });

  @override
  State<FoodAnalysisPage> createState() => _FoodAnalysisPageState();
}

class _FoodAnalysisPageState extends State<FoodAnalysisPage> 
    with TickerProviderStateMixin {
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
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
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
  
  @override
  void initState() {
    super.initState();
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
              _updateProgressAnimation();
              break;
            case 'upload_complete':
              _currentStep = 'upload_complete';
              _currentMessage = data['message'] ?? '图片上传完成';
              _currentStepIndex = 1;
              _analysisProgress = 0.32;
              _updateProgressAnimation();
              break;
            case 'record_created':
              if (data['record'] != null) {
                _currentRecord = FoodRecord.fromJson(data['record']);
                _foodName = _currentRecord!.foodName;
              }
              _currentStep = 'record_created';
              _currentMessage = data['message'] ?? '记录创建成功';
              _currentStepIndex = 2;
              _analysisProgress = 0.48;
              _updateProgressAnimation();
              break;
            case 'analysis_started':
              _currentStep = 'analysis_started';
              _currentMessage = data['message'] ?? '开始AI分析...';
              _currentStepIndex = 2;
              _analysisProgress = 0.48;
              _updateProgressAnimation();
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
              _updateProgressAnimation();
              break;
            case 'nutrition_saved':
              _currentStep = 'nutrition_saved';
              _currentMessage = data['message'] ?? '营养数据保存完成';
              _currentStepIndex = 5;
              _analysisProgress = 1.0;
              _updateProgressAnimation();
              break;
            case 'stream_complete':
              _currentStep = 'completed';
              _currentMessage = '分析完成';
              _analysisProgress = 1.0;
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
    _updateProgressAnimation();
  }

  void _updateProgressAnimation() {
    _progressController.animateTo(_analysisProgress);
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
    if (_currentRecord?.analysisStatus == 3 && _currentRecord?.analysisResult != null) {
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
    _foodName = record.foodName;
    
    if (record.analysisResult != null) {
      final analysisResult = record.analysisResult!;
      _imageDescription = analysisResult.imageDescription;
    
      // 解析营养成分
      _totalCalories = analysisResult.nutritionFacts.totalCalories;
      _macronutrients = {
        'protein': analysisResult.nutritionFacts.macronutrients.protein,
        'fat': analysisResult.nutritionFacts.macronutrients.fat,
        'carbohydrates': analysisResult.nutritionFacts.macronutrients.carbohydrates,
      };
      
      // 转换营养成分为Map格式以兼容现有UI
      _nutritionFacts = {
        'total_calories': _totalCalories,
        'macronutrients': _macronutrients,
        'food_items': analysisResult.nutritionFacts.foodItems ?? [],
      };
      
      // 转换推荐建议为Map格式以兼容现有UI
      _recommendations = {
        'health_tips': analysisResult.recommendations.recommendations ?? [],
        'dietary_advice': analysisResult.recommendations.dietaryTips ?? [],
        'warnings': analysisResult.recommendations.warnings ?? [],
        'alternative_foods': analysisResult.recommendations.alternativeFoods ?? [],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            
            const SizedBox(height: 100), // 底部按钮预留空间
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
    
    // 默认占位符
    return const Icon(LucideIcons.image, size: 60, color: Colors.grey);
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
                        _currentMessage.isNotEmpty ? _currentMessage : 'AI正在分析您的食物...',
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
                          return LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: const Color(0xFFE6FAF0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2BAF74)),
                            minHeight: 6,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_analysisProgress * 100).round()}% 完成',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
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
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
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
          _isLoading ? '分析中...' : _foodName,
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
                decoration: const BoxDecoration(
                  color: Color(0xFF2BAF74),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.bookmark,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              onPressed: () {},
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 卡路里信息
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_totalCalories * _servingCount).round()} 卡路里',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FAF0),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _servingCount > 1 ? () {
                          setState(() => _servingCount--);
                        } : null,
                        icon: const Icon(LucideIcons.minus, size: 16),
                        color: const Color(0xFF2BAF74),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          '$_servingCount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _servingCount++);
                        },
                        icon: const Icon(LucideIcons.plus, size: 16),
                        color: const Color(0xFF2BAF74),
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
                    value: '${(_macronutrients['carbohydrates']! * _servingCount).round()}g',
                    color: const Color(0xFF2BAF74),
                    percentage: _calculatePercentage(_macronutrients['carbohydrates']!),
                  ),
                ),
                Expanded(
                  child: _buildNutrientCircle(
                    label: '蛋白质',
                    value: '${(_macronutrients['protein']! * _servingCount).round()}g',
                    color: const Color(0xFFA6E3C1),
                    percentage: _calculatePercentage(_macronutrients['protein']!),
                  ),
                ),
                Expanded(
                  child: _buildNutrientCircle(
                    label: '脂肪',
                    value: '${(_macronutrients['fat']! * _servingCount).round()}g',
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
  
  Widget _buildAIRecommendationsCard() {
    final healthTips = _recommendations['health_tips'] as List? ?? [];
    final dietaryAdvice = _recommendations['dietary_advice'] as List? ?? [];
    
    if (healthTips.isEmpty && dietaryAdvice.isEmpty) {
      return const SizedBox.shrink();
    }
    
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
            
            const SizedBox(height: 16),
            
            // 健康提示
            if (healthTips.isNotEmpty) ...[
              ...healthTips.take(3).map((tip) => Padding(
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
              )).toList(),
            ],
            
            // 饮食建议
            if (dietaryAdvice.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...dietaryAdvice.take(2).map((advice) => Padding(
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
              )).toList(),
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
            ...foodItems.take(5).map((item) => Container(
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
            )).toList(),
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
            onPressed: _isLoading ? null : () {
              Navigator.pop(context);
              Navigator.pop(context); // 返回到主页
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLoading ? const Color(0xFFE6FAF0) : const Color(0xFF2BAF74),
              foregroundColor: _isLoading ? const Color(0xFF666666) : Colors.white,
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
                : const Text(
                    '记录餐食',
                    style: TextStyle(
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