import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';

/// 宠物健康评分卡组件
/// 综合饮食达标率 + 体重管理 + 疫苗状态，给出0-100分
/// 设计参考人类健康评分：圆环+总分+等级+分项明细+改善建议
class PetHealthScoreCard extends StatelessWidget {
  final int dietScore; // 饮食达标率得分 (0-40)
  final int weightScore; // 体重管理得分 (0-30)
  final int vaccineScore; // 疫苗状态得分 (0-30)
  final String? dietDetail;
  final String? weightDetail;
  final String? vaccineDetail;
  final List<String> suggestions; // 改善建议（参考人类健康评分的建议区）

  const PetHealthScoreCard({
    super.key,
    required this.dietScore,
    required this.weightScore,
    required this.vaccineScore,
    this.dietDetail,
    this.weightDetail,
    this.vaccineDetail,
    this.suggestions = const [],
  });

  /// 从真实数据快速构造（硬编码演示用）
  factory PetHealthScoreCard.demo() {
    return const PetHealthScoreCard(
      dietScore: 36,
      weightScore: 25,
      vaccineScore: 20,
      dietDetail: '本周达标5/7天',
      weightDetail: '体重稳定，在理想范围',
      vaccineDetail: '1项疫苗已过期',
      suggestions: [
        '本周饮食有2天未达标，建议规律喂食',
        '狂犬疫苗已过期，请尽快补种',
        '体重保持良好，继续保持当前喂食量',
      ],
    );
  }

  /// 根据宠物数据自动计算评分（供 home_page 使用）
  factory PetHealthScoreCard.autoCompute({
    required List<Map<String, dynamic>> feedingRecords,
    required double targetCalories,
    required double weight,
    required List<Map<String, dynamic>>? vaccineRecords,
  }) {
    // 饮食评分 (0-40)：最近7天达标天数
    final todayCal = feedingRecords.fold<double>(
      0,
      (sum, r) => sum + ((r['calories'] as num).toDouble()),
    );
    final dietRatio = (todayCal / targetCalories).clamp(0.0, 1.5);
    // 达标率 90%-110% 得满分，偏差越大扣分越多
    final dietScore = dietRatio >= 0.9 && dietRatio <= 1.1
        ? 40.0
        : 40.0 * (1.0 - ((dietRatio - 1.0).abs() * 2.0).clamp(0.0, 1.0));

    // 体重评分 (0-30)：基于体重合理性评估
    // TODO: 理想范围应通过 API GET /pets/{id}/weight-trend 获取品种标准体重
    double weightScore;
    if (weight <= 0) {
      weightScore = 10; // 无体重数据
    } else if (weight < 0.5 || weight > 80) {
      weightScore = 15; // 体重异常
    } else {
      weightScore = 25; // 体重在合理范围（无法获取品种标准时的估计值）
    }

    // 疫苗评分 (0-30)：检查是否有过期疫苗
    int vaccineScore = 30;
    final expiredCount = vaccineRecords
            ?.where(
              (v) => (v['status'] as String?) == '已过期',
            )
            .length ??
        0;
    vaccineScore = 30 - (expiredCount * 10).clamp(0, 30);

    final suggestions = <String>[];
    if (dietScore < 35) {
      suggestions.add(dietRatio > 1.1 ? '今日摄入超标，建议适当减少喂食量' : '今日摄入不足，建议补充营养');
    }
    if (expiredCount > 0) suggestions.add('有$expiredCount项疫苗已过期，请尽快补种');
    final weightStatus = weight <= 0
        ? '无体重数据'
        : (weight < 0.5 || weight > 80)
            ? '体重数据异常'
            : '体重正常';
    if (weightScore < 20) suggestions.add('体重偏离理想范围，建议咨询兽医');

    return PetHealthScoreCard(
      dietScore: dietScore.round(),
      weightScore: weightScore.round(),
      vaccineScore: vaccineScore,
      dietDetail: '今日 ${todayCal.round()}/${targetCalories.round()} kcal',
      weightDetail: '${weight}kg，$weightStatus',
      vaccineDetail: expiredCount > 0 ? '$expiredCount项已过期' : '全部正常',
      suggestions: suggestions,
    );
  }

  int get totalScore => (dietScore + weightScore + vaccineScore).clamp(0, 100);

  Color get _scoreColor {
    if (totalScore >= 80) return AppColors.success;
    if (totalScore >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String get _grade {
    if (totalScore >= 90) return '优秀';
    if (totalScore >= 80) return '良好';
    if (totalScore >= 60) return '一般';
    return '需要关注';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 总分展示
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 圆环
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: totalScore / 100,
                        strokeWidth: 8,
                        color: _scoreColor,
                        backgroundColor: _scoreColor.withValues(alpha: 0.12),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$totalScore',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor,
                          ),
                        ),
                        Text(
                          _grade,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _scoreColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // 分项说明
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '健康评分',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    _buildSubScore(LucideIcons.utensils, '饮食', dietScore, 40,
                        AppColors.caloriesColor, dietDetail),
                    _buildSubScore(LucideIcons.scale, '体重', weightScore, 30,
                        AppColors.primary, weightDetail),
                    _buildSubScore(LucideIcons.syringe, '疫苗', vaccineScore, 30,
                        AppColors.warning, vaccineDetail),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 8),

          // 评分说明
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: AppColors.textTertiary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '评分基于近7天数据，80分以上为健康状态',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),

          // 改善建议（参考人类健康评分卡的建议区）
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _scoreColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _scoreColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.lightbulb, size: 14, color: _scoreColor),
                      const SizedBox(width: 6),
                      Text(
                        '改善建议',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...suggestions.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('· ',
                                style: TextStyle(
                                    fontSize: 13, color: _scoreColor)),
                            Expanded(
                              child: Text(
                                s,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubScore(IconData icon, String label, int score, int max,
      Color color, String? detail) {
    final ratio = max > 0 ? score / max : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 30,
            child: Text(
              '$score/$max',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: detail,
              child: const Icon(LucideIcons.info,
                  size: 12, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
