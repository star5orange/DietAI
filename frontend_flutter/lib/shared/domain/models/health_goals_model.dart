class HealthGoal {
  final int id;
  final int userId;
  final int goalType;
  final double? targetWeight;
  final String? targetDate;
  final int currentStatus;
  final String createdAt;
  final String updatedAt;

  HealthGoal({
    required this.id,
    required this.userId,
    required this.goalType,
    this.targetWeight,
    this.targetDate,
    required this.currentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HealthGoal.fromJson(Map<String, dynamic> json) {
    return HealthGoal(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      goalType: json['goal_type'] as int,
      targetWeight: json['target_weight']?.toDouble(),
      targetDate: json['target_date'] as String?,
      currentStatus: json['current_status'] as int,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'goal_type': goalType,
      'target_weight': targetWeight,
      'target_date': targetDate,
      'current_status': currentStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Helper getters for UI display
  String get goalTypeText {
    switch (goalType) {
      case 1:
        return '减重';
      case 2:
        return '增重';
      case 3:
        return '维持体重';
      case 4:
        return '增肌';
      case 5:
        return '减脂';
      default:
        return '其他';
    }
  }

  String get statusText {
    switch (currentStatus) {
      case 1:
        return '进行中';
      case 2:
        return '已完成';
      case 3:
        return '已暂停';
      case 4:
        return '已取消';
      default:
        return '未知';
    }
  }

  String get goalIcon {
    switch (goalType) {
      case 1:
        return '⬇️'; // 减重
      case 2:
        return '⬆️'; // 增重
      case 3:
        return '⚖️'; // 维持
      case 4:
        return '💪'; // 增肌
      case 5:
        return '🔥'; // 减脂
      default:
        return '🎯';
    }
  }
}

class CreateHealthGoalRequest {
  final int goalType;
  final double? targetWeight;
  final String? targetDate;

  CreateHealthGoalRequest({
    required this.goalType,
    this.targetWeight,
    this.targetDate,
  });

  factory CreateHealthGoalRequest.fromJson(Map<String, dynamic> json) {
    return CreateHealthGoalRequest(
      goalType: json['goal_type'] as int,
      targetWeight: json['target_weight']?.toDouble(),
      targetDate: json['target_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_type': goalType,
      'target_weight': targetWeight,
      'target_date': targetDate,
    };
  }
}

class UpdateHealthGoalRequest {
  final int? goalType;
  final double? targetWeight;
  final String? targetDate;
  final int? currentStatus;

  UpdateHealthGoalRequest({
    this.goalType,
    this.targetWeight,
    this.targetDate,
    this.currentStatus,
  });

  factory UpdateHealthGoalRequest.fromJson(Map<String, dynamic> json) {
    return UpdateHealthGoalRequest(
      goalType: json['goal_type'] as int?,
      targetWeight: json['target_weight']?.toDouble(),
      targetDate: json['target_date'] as String?,
      currentStatus: json['current_status'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (goalType != null) data['goal_type'] = goalType;
    if (targetWeight != null) data['target_weight'] = targetWeight;
    if (targetDate != null) data['target_date'] = targetDate;
    if (currentStatus != null) data['current_status'] = currentStatus;
    return data;
  }
}

// Health Goal Progress Model
class HealthGoalProgress {
  final int goalId;
  final double currentWeight;
  final double? targetWeight;
  final double progressPercentage;
  final int daysRemaining;
  final bool isOnTrack;

  HealthGoalProgress({
    required this.goalId,
    required this.currentWeight,
    this.targetWeight,
    required this.progressPercentage,
    required this.daysRemaining,
    required this.isOnTrack,
  });

  factory HealthGoalProgress.fromJson(Map<String, dynamic> json) {
    return HealthGoalProgress(
      goalId: json['goal_id'] as int,
      currentWeight: json['current_weight']?.toDouble() ?? 0.0,
      targetWeight: json['target_weight']?.toDouble(),
      progressPercentage: json['progress_percentage']?.toDouble() ?? 0.0,
      daysRemaining: json['days_remaining'] as int? ?? 0,
      isOnTrack: json['is_on_track'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_id': goalId,
      'current_weight': currentWeight,
      'target_weight': targetWeight,
      'progress_percentage': progressPercentage,
      'days_remaining': daysRemaining,
      'is_on_track': isOnTrack,
    };
  }
}