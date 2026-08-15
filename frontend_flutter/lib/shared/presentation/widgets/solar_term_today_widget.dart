import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/themes/app_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../../../services/wellness_service.dart';

/// 节气日历联动 - 今日养生组件
/// 根据当前日期自动判断节气，展示对应的养生建议
/// 支持人群标签差异化：减脂/健身/养生/普通
class SolarTermTodayWidget extends StatefulWidget {
  final VoidCallback? onTapDetails;
  final String crowdTag;

  const SolarTermTodayWidget({
    super.key,
    this.onTapDetails,
    this.crowdTag = '均衡维持',
  });

  /// 24节气数据（静态，供所有组件复用）
  static const _solarTermsData = [
    ('小寒', '01-06', '冬', '温补驱寒', '羊肉、核桃、红枣', '寒凉生冷'),
    ('大寒', '01-20', '冬', '温补养肾', '牛肉、板栗、桂圆', '过度进补'),
    ('立春', '02-04', '春', '护阳生发', '韭菜、春笋、蜂蜜', '酸味过重'),
    ('雨水', '02-19', '春', '健脾祛湿', '山药、薏米、红枣', '生冷油腻'),
    ('惊蛰', '03-06', '春', '疏肝养血', '梨、菠菜、银耳', '辛辣燥热'),
    ('春分', '03-21', '春', '调和阴阳', '荠菜、鸡蛋、核桃', '偏热偏寒'),
    ('清明', '04-05', '春', '疏肝健脾', '荠菜、银耳、菊花', '辛辣发物'),
    ('谷雨', '04-20', '春', '健脾祛湿', '薏米、红豆、香椿', '生冷过甜'),
    ('立夏', '05-06', '夏', '养心安神', '莲子、绿豆、苦瓜', '过度贪凉'),
    ('小满', '05-21', '夏', '清热利湿', '绿豆、冬瓜、鲫鱼', '肥甘厚味'),
    ('芒种', '06-06', '夏', '清热祛湿', '绿豆、西瓜、酸梅', '油腻甜食'),
    ('夏至', '06-21', '夏', '养心护阳', '西瓜、苦瓜、荷叶', '过度寒凉'),
    ('小暑', '07-07', '夏', '清热解暑', '莲藕、黄鳝、丝瓜', '过度冷饮'),
    ('大暑', '07-23', '夏', '防暑养阴', '绿豆、银耳、鸭肉', '辛辣燥热'),
    ('立秋', '08-07', '秋', '滋阴润燥', '银耳、梨、蜂蜜', '辛辣煎炸'),
    ('处暑', '08-23', '秋', '润肺安神', '梨、百合、芝麻', '烧烤煎炸'),
    ('白露', '09-08', '秋', '养肺润燥', '山药、红枣、核桃', '寒凉生冷'),
    ('秋分', '09-23', '秋', '阴阳平衡', '银耳、百合、莲子', '辛辣燥热'),
    ('寒露', '10-08', '秋', '温补防寒', '板栗、红枣、芝麻', '寒凉生冷'),
    ('霜降', '10-23', '秋', '温补养胃', '柿子、牛肉、老鸭', '过度辛辣'),
    ('立冬', '11-07', '冬', '温补养肾', '羊肉、板栗、黑豆', '寒凉生冷'),
    ('小雪', '11-22', '冬', '补肾养血', '核桃、黑芝麻、桂圆', '过度燥热'),
    ('大雪', '12-07', '冬', '温补驱寒', '羊肉、韭菜、红枣', '过度油腻'),
    ('冬至', '12-22', '冬', '温补养阳', '羊肉、饺子、汤圆', '寒凉生冷'),
  ];

  static bool _dateInRange(String date, String start, String end) {
    if (start.compareTo(end) <= 0) {
      return date.compareTo(start) >= 0 && date.compareTo(end) < 0;
    }
    return date.compareTo(start) >= 0 || date.compareTo(end) < 0;
  }

  /// 获取当前节气名称（静态方法，供其他组件调用）
  static String getCurrentSolarTermName() {
    final now = DateTime.now();
    final mmdd =
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    String currentName = '小寒';
    for (int i = 0; i < _solarTermsData.length; i++) {
      final term = _solarTermsData[i];
      final nextIdx = (i + 1) % _solarTermsData.length;
      final nextTerm = _solarTermsData[nextIdx];
      if (_dateInRange(mmdd, term.$2, nextTerm.$2)) {
        currentName = term.$1;
        break;
      }
    }
    return currentName;
  }

  @override
  State<SolarTermTodayWidget> createState() => _SolarTermTodayWidgetState();
}

class _SolarTermTodayWidgetState extends State<SolarTermTodayWidget> {
  Map<String, dynamic>? _currentTerm;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentSolarTerm();
  }

  Future<void> _loadCurrentSolarTerm() async {
    try {
      final service = WellnessService();
      final result = await service.getCurrentSolarTerm();
      if (result.isSuccess && result.data != null && mounted) {
        setState(() {
          _currentTerm = result.data;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    // API 失败，fallback 到本地硬编码节气数据
    if (mounted) {
      setState(() {
        _currentTerm = _getCurrentSolarTerm();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getCurrentSolarTerm() {
    final now = DateTime.now();
    final mmdd = now.month.toString().padLeft(2, '0') +
        '-' +
        now.day.toString().padLeft(2, '0');

    // 找到当前日期所在的节气区间
    String currentName = '小寒';
    String currentSeason = '冬';
    String currentPrinciple = '温补驱寒';
    String currentFoods = '羊肉、核桃、红枣';
    String currentAvoid = '寒凉生冷';
    String nextName = '大寒';

    final terms = SolarTermTodayWidget._solarTermsData;
    for (int i = 0; i < terms.length; i++) {
      final term = terms[i];
      final nextIdx = (i + 1) % terms.length;
      final nextTerm = terms[nextIdx];

      if (SolarTermTodayWidget._dateInRange(mmdd, term.$2, nextTerm.$2)) {
        currentName = term.$1;
        currentSeason = term.$3;
        currentPrinciple = term.$4;
        currentFoods = term.$5;
        currentAvoid = term.$6;
        nextName = nextTerm.$1;
        break;
      }
    }

    return {
      'name': currentName,
      'season': currentSeason,
      'principle': currentPrinciple,
      'foods': currentFoods,
      'avoid': currentAvoid,
      'next': nextName,
    };
  }

  Color _seasonColor(String season) {
    switch (season) {
      case '春':
        return const Color(0xFF43A047);
      case '夏':
        return const Color(0xFFFF7043);
      case '秋':
        return const Color(0xFFFFA726);
      case '冬':
        return const Color(0xFF42A5F5);
      default:
        return AppColors.primary;
    }
  }

  IconData _seasonIcon(String season) {
    switch (season) {
      case '春':
        return LucideIcons.flower2;
      case '夏':
        return LucideIcons.sun;
      case '秋':
        return LucideIcons.leaf;
      case '冬':
        return LucideIcons.snowflake;
      default:
        return LucideIcons.calendar;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_currentTerm == null) return const SizedBox.shrink();

    final name = (_currentTerm!['name'] as String?) ?? '';
    final season = (_currentTerm!['season'] as String?) ?? '';
    final principle = (_currentTerm!['principle'] as String?) ??
        (_currentTerm!['wellness'] as String?) ??
        '';
    final next = (_currentTerm!['next'] as String?) ??
        (_currentTerm!['next_term'] as String?) ??
        '';
    final color = _seasonColor(season);

    // 根据本地节气表计算下一节气名称与剩余天数（与数据源无关，保证一致）
    final nowDate = DateTime.now();
    final today = DateTime(nowDate.year, nowDate.month, nowDate.day);
    String nextName = next;
    int daysToNext = 0;
    const terms = SolarTermTodayWidget._solarTermsData;
    final currentIdx = terms.indexWhere((t) => t.$1 == name);
    if (currentIdx >= 0) {
      final nextTerm = terms[(currentIdx + 1) % terms.length];
      nextName = nextTerm.$1;
      final mm = int.parse(nextTerm.$2.substring(0, 2));
      final dd = int.parse(nextTerm.$2.substring(3));
      var nextDate = DateTime(nowDate.year, mm, dd);
      // 下一节气日期已过（跨年），顺延到明年
      if (nextDate.isBefore(today)) {
        nextDate = DateTime(nowDate.year + 1, mm, dd);
      }
      daysToNext = nextDate.difference(today).inDays;
    }

    // 根据人群标签差异化提示
    String? crowdTip;

    switch (widget.crowdTag) {
      case '减脂':
        crowdTip = '减脂期控制总热量，优选低脂高蛋白食材';
        break;
      case '健身':
        crowdTip = '健身期增加蛋白质摄入，训练前后及时补充';
        break;
      case '养生':
        crowdTip = '顺应节气调养，注意体质偏颇针对性食补';
        break;
    }

    return GestureDetector(
      onTap: widget.onTapDetails,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：节气名 + 季节图标
            Row(
              children: [
                Icon(_seasonIcon(season),
                    color: AppColors.textInverse, size: 14),
                const SizedBox(width: 8),
                Text('当前节气：$name',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textInverse,
                      fontWeight: FontWeight.w700,
                    )),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.whiteWithOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    daysToNext > 0
                        ? '距$nextName还有$daysToNext天'
                        : '下一节气：$nextName',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.whiteWithOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 养生原则
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.whiteWithOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '养生原则：$principle',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.whiteWithOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (crowdTip != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.whiteWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.whiteWithOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        crowdTip!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.whiteWithOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}
