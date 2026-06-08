import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

class WellnessService {
  final ApiService _apiService = ApiService();

  /// 获取养生知识
  Future<ApiResponse<List<Map<String, dynamic>>>> getWellnessTips({
    String? category,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null) {
        queryParams['category'] = category;
      }

      final response = await _apiService.dio.get(
        '/wellness/tips',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => (json as List).map((e) => e as Map<String, dynamic>).toList(),
      );
    } catch (e) {
      return ApiResponse(
        success: true,
        data: _getDefaultTips(),
        message: '使用本地养生知识数据',
      );
    }
  }

  /// 本地默认养生知识
  List<Map<String, dynamic>> _getDefaultTips() {
    return [
      {
        'title': '中医九种体质',
        'icon': 'heart_pulse',
        'color': '#EF5350',
        'items': [
          '平和质：最健康的体质，阴阳气血调和',
          '气虚质：元气不足，容易疲劳感冒',
          '阳虚质：阳气不足，畏寒怕冷',
          '阴虚质：阴液亏少，口干手足心热',
          '痰湿质：痰湿凝聚，形体肥胖',
          '湿热质：湿热内蕴，面垢油光',
          '血瘀质：血行不畅，肤色晦暗',
          '气郁质：气机郁滞，情绪低落',
          '特禀质：过敏体质，易过敏',
        ],
      },
      {
        'title': '四季养生原则',
        'icon': 'sun',
        'color': '#FFA726',
        'items': [
          '春养肝：早睡早起，舒展身体，宜食绿色蔬菜',
          '夏养心：晚睡早起，适当午休，宜食苦味食物',
          '秋养肺：早睡早起，润燥养阴，宜食白色食物',
          '冬养肾：早睡晚起，保暖防寒，宜食黑色食物',
        ],
      },
      {
        'title': '饮食养生要点',
        'icon': 'utensils',
        'color': '#43A047',
        'items': [
          '饮食有节：定时定量，不暴饮暴食',
          '五味调和：酸苦甘辛咸均衡摄入',
          '因时制宜：根据季节调整饮食结构',
          '因人制宜：根据体质选择适宜食物',
          '药食同源：善用药膳调理身体',
        ],
      },
    ];
  }

  /// 获取每日养生推荐
  Future<ApiResponse<Map<String, dynamic>>> getDailyRecommendation({
    String? constitutionType,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (constitutionType != null) {
        queryParams['constitution_type'] = constitutionType;
      }

      final response = await _apiService.dio.get(
        '/wellness/daily-recommendation',
        queryParameters: queryParams,
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      // 返回本地默认数据
      return ApiResponse(
        success: true,
        data: _getDefaultRecommendation(constitutionType),
        message: '使用本地推荐数据',
      );
    }
  }

  /// 获取节气列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getSolarTerms({
    int year = 2026,
  }) async {
    try {
      final response = await _apiService.dio.get(
        '/wellness/solar-terms',
        queryParameters: {'year': year},
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => (json as List).map((e) => e as Map<String, dynamic>).toList(),
      );
    } catch (e) {
      return ApiResponse(
        success: true,
        data: _getDefaultSolarTerms(),
        message: '使用本地节气数据',
      );
    }
  }

  /// 本地默认推荐数据
  Map<String, dynamic> _getDefaultRecommendation(String? constitutionType) {
    return {
      'current_solar_term': '芒种',
      'current_season': '夏季',
      'constitution_type': constitutionType,
      'recommended_ingredients': [
        {'name': '绿豆', 'benefit': '清热解毒，消暑利水'},
        {'name': '薏米', 'benefit': '健脾祛湿，清热排脓'},
        {'name': '莲子', 'benefit': '补脾止泻，养心安神'},
        {'name': '百合', 'benefit': '润肺止咳，清心安神'},
        {'name': '山药', 'benefit': '补脾养胃，生津益肺'},
      ],
      'recommended_recipes': [
        {
          'name': '绿豆薏米粥',
          'description': '清热祛湿，适合夏季食用',
          'benefits': '清热解毒、健脾祛湿',
          'ingredients': ['绿豆50g', '薏米30g', '大米50g'],
          'steps': ['绿豆、薏米提前浸泡2小时', '所有材料加水大火煮沸', '转小火慢煮40分钟', '加少许冰糖调味'],
        },
        {
          'name': '莲子百合汤',
          'description': '养心安神，润肺止咳',
          'benefits': '养心安神、润肺止咳',
          'ingredients': ['莲子30g', '百合20g', '红枣5颗', '枸杞10g'],
          'steps': ['莲子去芯，百合洗净', '加水大火煮沸', '转小火煮30分钟', '加入枸杞和冰糖'],
        },
        {
          'name': '山药排骨汤',
          'description': '补脾养胃，增强体质',
          'benefits': '补脾养胃、增强体质',
          'ingredients': ['山药200g', '排骨300g', '枸杞10g', '姜片3片'],
          'steps': ['排骨焯水去血沫', '山药去皮切块', '排骨加姜片炖煮1小时', '加入山药继续炖30分钟'],
        },
      ],
      'wellness_tips': [
        '芒种时节，气温升高，湿气加重，应注意清热祛湿',
        '饮食宜清淡，多食蔬菜水果，少食油腻辛辣',
        '适当午休，保证充足睡眠，避免过度劳累',
        '可适量饮用菊花茶、绿豆汤等清热饮品',
      ],
      'foods_to_avoid': ['辛辣刺激食物', '油腻煎炸食品', '过甜过咸食物', '生冷食物'],
    };
  }

  /// 本地默认节气数据
  List<Map<String, dynamic>> _getDefaultSolarTerms() {
    return [
      {'name': '立春', 'date': '02-04', 'description': '春季开始'},
      {'name': '雨水', 'date': '02-19', 'description': '降雨开始'},
      {'name': '惊蛰', 'date': '03-05', 'description': '春雷始鸣'},
      {'name': '春分', 'date': '03-20', 'description': '昼夜平分'},
      {'name': '清明', 'date': '04-04', 'description': '天清地明'},
      {'name': '谷雨', 'date': '04-20', 'description': '雨生百谷'},
      {'name': '立夏', 'date': '05-05', 'description': '夏季开始'},
      {'name': '小满', 'date': '05-21', 'description': '麦粒饱满'},
      {'name': '芒种', 'date': '06-05', 'description': '麦类成熟'},
      {'name': '夏至', 'date': '06-21', 'description': '日最长夜最短'},
      {'name': '小暑', 'date': '07-07', 'description': '暑热初起'},
      {'name': '大暑', 'date': '07-22', 'description': '暑热最盛'},
      {'name': '立秋', 'date': '08-07', 'description': '秋季开始'},
      {'name': '处暑', 'date': '08-23', 'description': '暑气渐消'},
      {'name': '白露', 'date': '09-07', 'description': '露水始白'},
      {'name': '秋分', 'date': '09-23', 'description': '昼夜平分'},
      {'name': '寒露', 'date': '10-08', 'description': '露水渐寒'},
      {'name': '霜降', 'date': '10-23', 'description': '初霜始降'},
      {'name': '立冬', 'date': '11-07', 'description': '冬季开始'},
      {'name': '小雪', 'date': '11-22', 'description': '初雪始降'},
      {'name': '大雪', 'date': '12-07', 'description': '雪量增大'},
      {'name': '冬至', 'date': '12-22', 'description': '日最短夜最长'},
      {'name': '小寒', 'date': '01-05', 'description': '寒气初起'},
      {'name': '大寒', 'date': '01-20', 'description': '寒气最盛'},
    ];
  }
}
