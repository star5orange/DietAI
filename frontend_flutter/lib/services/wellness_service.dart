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

      final result = ApiResponse.fromJson(
        response.data,
        (json) => (json as List).map((e) => e as Map<String, dynamic>).toList(),
      );

      // 如果后端返回空数据（DB 表为空），fallback 到本地默认数据
      if (result.data == null || result.data!.isEmpty) {
        return ApiResponse(
          success: true,
          data: _getDefaultTips(),
          message: '使用本地养生知识数据',
        );
      }

      return result;
    } catch (e) {
      return ApiResponse(
        success: true,
        data: _getDefaultTips(),
        message: '使用本地养生知识数据',
      );
    }
  }

  /// 获取当前节气信息
  Future<ApiResponse<Map<String, dynamic>>> getCurrentSolarTerm() async {
    try {
      final response = await _apiService.dio.get(
        '/wellness/current-solar-term',
      );

      return ApiResponse.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取当前节气失败: $e',
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
    final now = DateTime.now();
    final term = _getCurrentSolarTerm(now);
    final season = _seasonForDate(now);
    final tips = _getSeasonalTips(term['name'] as String, season);

    return {
      'current_solar_term': term['name'],
      'current_season': season,
      'constitution_type': constitutionType,
      'recommended_ingredients': tips['ingredients'],
      'recommended_recipes': tips['recipes'],
      'wellness_tips': tips['tips'],
      'foods_to_avoid': tips['foods_to_avoid'],
    };
  }

  /// 根据日期获取当前节气
  Map<String, String> _getCurrentSolarTerm(DateTime date) {
    // 2026年节气日期（公历近似值）
    const terms = [
      {'name': '小寒', 'month': 1, 'day': 5},
      {'name': '大寒', 'month': 1, 'day': 20},
      {'name': '立春', 'month': 2, 'day': 4},
      {'name': '雨水', 'month': 2, 'day': 19},
      {'name': '惊蛰', 'month': 3, 'day': 5},
      {'name': '春分', 'month': 3, 'day': 20},
      {'name': '清明', 'month': 4, 'day': 4},
      {'name': '谷雨', 'month': 4, 'day': 20},
      {'name': '立夏', 'month': 5, 'day': 5},
      {'name': '小满', 'month': 5, 'day': 21},
      {'name': '芒种', 'month': 6, 'day': 5},
      {'name': '夏至', 'month': 6, 'day': 21},
      {'name': '小暑', 'month': 7, 'day': 7},
      {'name': '大暑', 'month': 7, 'day': 22},
      {'name': '立秋', 'month': 8, 'day': 7},
      {'name': '处暑', 'month': 8, 'day': 23},
      {'name': '白露', 'month': 9, 'day': 7},
      {'name': '秋分', 'month': 9, 'day': 23},
      {'name': '寒露', 'month': 10, 'day': 8},
      {'name': '霜降', 'month': 10, 'day': 23},
      {'name': '立冬', 'month': 11, 'day': 7},
      {'name': '小雪', 'month': 11, 'day': 22},
      {'name': '大雪', 'month': 12, 'day': 7},
      {'name': '冬至', 'month': 12, 'day': 22},
    ];

    for (int i = terms.length - 1; i >= 0; i--) {
      final t = terms[i];
      final termDate = DateTime(date.year, t['month'] as int, t['day'] as int);
      if (!date.isBefore(termDate)) {
        return {'name': t['name'] as String};
      }
    }
    return {'name': terms.last['name'] as String};
  }

  /// 根据日期判断季节
  String _seasonForDate(DateTime date) {
    final m = date.month;
    if (m >= 3 && m <= 5) return '春季';
    if (m >= 6 && m <= 8) return '夏季';
    if (m >= 9 && m <= 11) return '秋季';
    return '冬季';
  }

  /// 根据节气名和季节返回养生数据
  Map<String, dynamic> _getSeasonalTips(String termName, String season) {
    final now = DateTime.now();
    // 小暑/大暑 — 盛夏
    if (termName == '小暑' || termName == '大暑') {
      return {
        'ingredients': [
          {'name': '冬瓜', 'benefit': '清热解暑，利尿消肿'},
          {'name': '苦瓜', 'benefit': '清热解毒，消暑明目'},
          {'name': '鸭肉', 'benefit': '滋阴养胃，利水消肿'},
          {'name': '绿豆', 'benefit': '清热解毒，消暑利水'},
          {'name': '莲藕', 'benefit': '清热凉血，健脾开胃'},
        ],
        'recipes': [
          {
            'name': '冬瓜薏米老鸭汤',
            'description': '清热解暑，滋阴润燥',
            'benefits': '清热解暑、滋阴润燥',
            'ingredients': ['冬瓜300g', '薏米30g', '老鸭半只', '姜片3片'],
            'steps': ['老鸭焯水去血沫', '冬瓜去皮切块', '所有材料加水炖煮1.5小时', '加适量盐调味'],
          },
          {
            'name': '绿豆莲子汤',
            'description': '清热解暑，养心安神',
            'benefits': '清热解暑、养心安神',
            'ingredients': ['绿豆100g', '莲子30g', '百合20g', '冰糖适量'],
            'steps': ['绿豆莲子提前浸泡1小时', '加水大火煮沸', '转小火煮40分钟至豆烂', '加入冰糖调匀'],
          },
          {
            'name': '凉拌苦瓜',
            'description': '清热祛火，降血糖',
            'benefits': '清热祛火、开胃消食',
            'ingredients': ['苦瓜1根', '蒜末适量', '醋1勺', '香油少许'],
            'steps': ['苦瓜切薄片，沸水焯30秒', '捞出过凉水沥干', '加蒜末、醋、盐拌匀', '淋少许香油即可'],
          },
        ],
        'tips': [
          '$termName时节，暑热当令，应注意防暑降温',
          '饮食宜清淡，多食瓜类蔬菜，如冬瓜、丝瓜、黄瓜',
          '避免烈日暴晒，午后尽量减少户外活动',
          '可饮用绿豆汤、酸梅汤等解暑饮品',
        ],
        'foods_to_avoid': ['辛辣温燥食物', '油炸烧烤食品', '过量冷饮冰品', '高脂肪肉类'],
      };
    }

    // 春季
    if (season == '春季') {
      return {
        'ingredients': [
          {'name': '菠菜', 'benefit': '养血润燥，平肝明目'},
          {'name': '韭菜', 'benefit': '温阳补肾，行气活血'},
          {'name': '春笋', 'benefit': '清热化痰，益气和胃'},
          {'name': '山药', 'benefit': '补脾养胃，生津益肺'},
          {'name': '枸杞', 'benefit': '滋补肝肾，益精明目'},
        ],
        'recipes': [
          {
            'name': '春笋炒肉片',
            'description': '鲜嫩可口，健脾开胃',
            'benefits': '健脾开胃、补充营养',
            'ingredients': ['春笋200g', '瘦肉150g', '青椒1个', '姜末少许'],
            'steps': ['春笋切片焯水', '瘦肉切片加料酒腌制', '热锅凉油炒肉片', '加入笋片翻炒调味'],
          },
          {
            'name': '枸杞山药粥',
            'description': '滋补肝肾，健脾养胃',
            'benefits': '滋补肝肾、健脾养胃',
            'ingredients': ['山药100g', '大米100g', '枸杞15g', '红枣5颗'],
            'steps': ['山药去皮切块', '大米洗净加水煮沸', '加入山药红枣小火熬煮', '出锅前加枸杞'],
          },
        ],
        'tips': [
          '$termName时节，万物复苏，宜养肝护肝',
          '早睡早起，适当户外运动，舒展筋骨',
          '饮食宜少酸多甘，助阳气生发',
          '保持心情舒畅，避免急躁动怒',
        ],
        'foods_to_avoid': ['酸涩收敛食物', '过于油腻的食物', '生冷寒凉之品'],
      };
    }

    // 秋季
    if (season == '秋季') {
      return {
        'ingredients': [
          {'name': '银耳', 'benefit': '润肺生津，滋阴养胃'},
          {'name': '百合', 'benefit': '润肺止咳，清心安神'},
          {'name': '梨', 'benefit': '清热润肺，生津止渴'},
          {'name': '莲藕', 'benefit': '清热凉血，健脾开胃'},
          {'name': '蜂蜜', 'benefit': '润肺止咳，润肠通便'},
        ],
        'recipes': [
          {
            'name': '银耳莲子羹',
            'description': '润肺养阴，美容养颜',
            'benefits': '润肺养阴、美容养颜',
            'ingredients': ['银耳1朵', '莲子30g', '红枣5颗', '百合15g'],
            'steps': ['银耳泡发撕小朵', '所有材料加水煮沸', '小火慢炖1小时至粘稠', '加冰糖调味'],
          },
          {
            'name': '百合雪梨汤',
            'description': '润肺止咳，生津止渴',
            'benefits': '润肺止咳、清热生津',
            'ingredients': ['雪梨2个', '百合20g', '川贝3g', '冰糖适量'],
            'steps': ['雪梨去皮去核切块', '所有材料加水煮沸', '转小火炖30分钟', '加冰糖即可'],
          },
        ],
        'tips': [
          '$termName时节，天气转凉，宜润肺养阴',
          '多食白色食物如银耳、百合、山药',
          '早睡早起，收敛神气，避免悲秋情绪',
          '适当运动增强肺部功能，如深呼吸、慢跑',
        ],
        'foods_to_avoid': ['辛辣燥热食物', '过于香燥的炒货', '冰镇饮料'],
      };
    }

    // 冬季
    return {
      'ingredients': [
        {'name': '羊肉', 'benefit': '温补阳气，暖中祛寒'},
        {'name': '黑芝麻', 'benefit': '补肾益精，润肠通便'},
        {'name': '核桃', 'benefit': '温补肾阳，益智健脑'},
        {'name': '黑豆', 'benefit': '补肾益阴，健脾利湿'},
        {'name': '桂圆', 'benefit': '补心脾，益气血'},
      ],
      'recipes': [
        {
          'name': '当归生姜羊肉汤',
          'description': '温补阳气，暖身驱寒',
          'benefits': '温中补血、驱寒暖身',
          'ingredients': ['羊肉300g', '当归10g', '生姜5片', '枸杞15g'],
          'steps': ['羊肉切块焯水去血沫', '当归生姜放入纱布袋', '加水炖煮1.5小时', '出锅前加枸杞盐调味'],
        },
        {
          'name': '黑芝麻核桃粥',
          'description': '补肾益精，乌发养颜',
          'benefits': '补肾乌发、润肠通便',
          'ingredients': ['黑芝麻30g', '核桃20g', '大米100g', '红糖适量'],
          'steps': ['黑芝麻核桃炒香碾碎', '大米洗净加水煮沸', '加入芝麻核桃粉熬煮', '加红糖调匀'],
        },
      ],
      'tips': [
        '$termName时节，万物潜藏，宜养护阳气',
        '早睡晚起，待日出后活动，避免受寒',
        '饮食宜温热，适当进补，可食羊肉、核桃',
        '注意保暖，尤其是头颈、脚踝部位',
      ],
      'foods_to_avoid': ['生冷寒凉食物', '过量寒性水果', '冰镇饮料'],
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
