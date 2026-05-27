---
name: pattern-recognition
description: 饮食/行为模式识别指南，定义要检测的模式类型和阈值
metadata:
  version: "1.0"
  author: DietAI
---

# 模式识别技能

## 触发条件
- 每 5 次食物分析后自动触发
- 每日汇总时触发
- 用户请求健康报告时触发
- 每周定期触发

## 要检测的模式

### 1. 营养缺口模式
- **定义**: 连续 7+ 天某营养素摄入低于目标的 70%
- **阈值**: < 0.7 * 每日目标
- **营养素**: 蛋白质、钙、铁、维生素 D、膳食纤维
- **输出**: type="nutrient_gap", nutrient, avg_intake, target, days

### 2. 饮食多样性模式
- **定义**: 最常吃的 3 种食物占总摄入的比例
- **阈值**: > 60% 为低多样性
- **输出**: type="low_diversity", top_foods, percentage

### 3. 用餐规律模式
- **定义**: 用餐时间的稳定性和跳餐频率
- **阈值**: 跳餐 > 3 次/周 或 用餐时间标准差 > 90 分钟
- **输出**: type="irregular_meals", pattern, frequency

### 4. 周趋势变化
- **定义**: 本周 vs 上周的摄入量变化
- **阈值**: 变化 > 15% 标记为显著
- **输出**: type="trend_change", metric, this_week, last_week, change_pct

### 5. 周末偏差模式
- **定义**: 工作日 vs 周末的摄入差异
- **阈值**: 差异 > 20%
- **输出**: type="weekend_deviation", weekday_avg, weekend_avg, deviation_pct

## 洞察输出格式
写入 `/memories/insights.md` 的格式：
```markdown
## 检测到的模式 ({date})

### {pattern_type}
- 描述: {description}
- 置信度: {confidence}
- 数据支撑: {evidence}
- 建议: {recommendation}
- 状态: 待确认 | 已确认 | 已处理
```

## 确认流程
- 置信度 >= 0.8: 可直接记录
- 置信度 0.5-0.8: 需要向用户确认
- 置信度 < 0.5: 仅记录为观察，不主动提醒
