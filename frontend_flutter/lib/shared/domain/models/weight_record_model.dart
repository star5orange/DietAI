class WeightRecord {
  final int id;
  final int userId;
  final double weight;
  final double? bodyFatPercentage;
  final double? muscleMass;
  final double? bmi;
  final String measuredAt;
  final String? notes;
  final String? deviceType;
  final String createdAt;

  WeightRecord({
    required this.id,
    required this.userId,
    required this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.bmi,
    required this.measuredAt,
    this.notes,
    this.deviceType,
    required this.createdAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      weight: json['weight']?.toDouble() ?? 0.0,
      bodyFatPercentage: json['body_fat_percentage']?.toDouble(),
      muscleMass: json['muscle_mass']?.toDouble(),
      bmi: json['bmi']?.toDouble(),
      measuredAt: json['measured_at'] as String,
      notes: json['notes'] as String?,
      deviceType: json['device_type'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'weight': weight,
      'body_fat_percentage': bodyFatPercentage,
      'muscle_mass': muscleMass,
      'bmi': bmi,
      'measured_at': measuredAt,
      'notes': notes,
      'device_type': deviceType,
      'created_at': createdAt,
    };
  }

  // Helper getters for UI display
  String get formattedWeight => '${weight.toStringAsFixed(1)} kg';
  
  String get formattedBmi => bmi != null ? bmi!.toStringAsFixed(1) : '--';
  
  String get formattedBodyFat => bodyFatPercentage != null 
    ? '${bodyFatPercentage!.toStringAsFixed(1)}%' 
    : '--';
  
  String get formattedMuscleMass => muscleMass != null 
    ? '${muscleMass!.toStringAsFixed(1)} kg' 
    : '--';

  String get bmiCategory {
    if (bmi == null) return '未知';
    
    if (bmi! < 18.5) return '偏瘦';
    if (bmi! < 24) return '正常';
    if (bmi! < 28) return '超重';
    return '肥胖';
  }

  String get formattedDate {
    try {
      final date = DateTime.parse(measuredAt);
      return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return measuredAt;
    }
  }
}

class CreateWeightRecordRequest {
  final double weight;
  final double? bodyFatPercentage;
  final double? muscleMass;
  final String? measuredAt;
  final String? notes;
  final String? deviceType;

  CreateWeightRecordRequest({
    required this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.measuredAt,
    this.notes,
    this.deviceType,
  });

  factory CreateWeightRecordRequest.fromJson(Map<String, dynamic> json) {
    return CreateWeightRecordRequest(
      weight: json['weight']?.toDouble() ?? 0.0,
      bodyFatPercentage: json['body_fat_percentage']?.toDouble(),
      muscleMass: json['muscle_mass']?.toDouble(),
      measuredAt: json['measured_at'] as String?,
      notes: json['notes'] as String?,
      deviceType: json['device_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'body_fat_percentage': bodyFatPercentage,
      'muscle_mass': muscleMass,
      'measured_at': measuredAt,
      'notes': notes,
      'device_type': deviceType,
    };
  }
}

class UpdateWeightRecordRequest {
  final double? weight;
  final double? bodyFatPercentage;
  final double? muscleMass;
  final String? measuredAt;
  final String? notes;
  final String? deviceType;

  UpdateWeightRecordRequest({
    this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.measuredAt,
    this.notes,
    this.deviceType,
  });

  factory UpdateWeightRecordRequest.fromJson(Map<String, dynamic> json) {
    return UpdateWeightRecordRequest(
      weight: json['weight']?.toDouble(),
      bodyFatPercentage: json['body_fat_percentage']?.toDouble(),
      muscleMass: json['muscle_mass']?.toDouble(),
      measuredAt: json['measured_at'] as String?,
      notes: json['notes'] as String?,
      deviceType: json['device_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (weight != null) data['weight'] = weight;
    if (bodyFatPercentage != null) data['body_fat_percentage'] = bodyFatPercentage;
    if (muscleMass != null) data['muscle_mass'] = muscleMass;
    if (measuredAt != null) data['measured_at'] = measuredAt;
    if (notes != null) data['notes'] = notes;
    if (deviceType != null) data['device_type'] = deviceType;
    return data;
  }
}

// Weight trend analysis model
class WeightTrend {
  final double currentWeight;
  final double? previousWeight;
  final double weightChange;
  final double changePercentage;
  final String trendDirection; // 'up', 'down', 'stable'
  final int daysTracked;
  final double averageWeeklyChange;

  WeightTrend({
    required this.currentWeight,
    this.previousWeight,
    required this.weightChange,
    required this.changePercentage,
    required this.trendDirection,
    required this.daysTracked,
    required this.averageWeeklyChange,
  });

  factory WeightTrend.fromJson(Map<String, dynamic> json) {
    return WeightTrend(
      currentWeight: json['current_weight']?.toDouble() ?? 0.0,
      previousWeight: json['previous_weight']?.toDouble(),
      weightChange: json['weight_change']?.toDouble() ?? 0.0,
      changePercentage: json['change_percentage']?.toDouble() ?? 0.0,
      trendDirection: json['trend_direction'] as String? ?? 'stable',
      daysTracked: json['days_tracked'] as int? ?? 0,
      averageWeeklyChange: json['average_weekly_change']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_weight': currentWeight,
      'previous_weight': previousWeight,
      'weight_change': weightChange,
      'change_percentage': changePercentage,
      'trend_direction': trendDirection,
      'days_tracked': daysTracked,
      'average_weekly_change': averageWeeklyChange,
    };
  }

  // Helper getters
  String get trendIcon {
    switch (trendDirection) {
      case 'up':
        return '📈';
      case 'down':
        return '📉';
      case 'stable':
        return '➡️';
      default:
        return '📊';
    }
  }

  String get trendText {
    switch (trendDirection) {
      case 'up':
        return '上升趋势';
      case 'down':
        return '下降趋势';
      case 'stable':
        return '保持稳定';
      default:
        return '数据不足';
    }
  }

  String get formattedChange {
    final sign = weightChange >= 0 ? '+' : '';
    return '$sign${weightChange.toStringAsFixed(1)} kg';
  }
}