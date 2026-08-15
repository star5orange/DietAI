/// 用户搜索结果
class UserSearchResult {
  final int id;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final int? gender;
  final bool isFriend;
  final bool isFamily;
  final bool pendingFriend;
  final bool pendingFamily;

  UserSearchResult({
    required this.id,
    required this.username,
    this.realName,
    this.avatarUrl,
    this.gender,
    this.isFriend = false,
    this.isFamily = false,
    this.pendingFriend = false,
    this.pendingFamily = false,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['real_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as int?,
      isFriend: json['is_friend'] as bool? ?? false,
      isFamily: json['is_family'] as bool? ?? false,
      pendingFriend: json['pending_friend'] as bool? ?? false,
      pendingFamily: json['pending_family'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'real_name': realName,
      'avatar_url': avatarUrl,
      'gender': gender,
      'is_friend': isFriend,
      'is_family': isFamily,
      'pending_friend': pendingFriend,
      'pending_family': pendingFamily,
    };
  }
}

/// 好友申请
class FriendRequest {
  final int requestId;
  final int senderId;
  final String senderUsername;
  final String? senderRealName;
  final String? senderAvatarUrl;
  final int? senderGender;
  final String relationshipType;
  final String? relationshipLabel;
  final DateTime createdAt;

  FriendRequest({
    required this.requestId,
    required this.senderId,
    required this.senderUsername,
    this.senderRealName,
    this.senderAvatarUrl,
    this.senderGender,
    required this.relationshipType,
    this.relationshipLabel,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      requestId: json['request_id'] as int,
      senderId: json['sender_id'] as int,
      senderUsername: json['sender_username'] as String? ?? '',
      senderRealName: json['sender_real_name'] as String?,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      senderGender: json['sender_gender'] as int?,
      relationshipType: json['relationship_type'] as String? ?? 'friend',
      relationshipLabel: json['relationship_label'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'sender_id': senderId,
      'sender_username': senderUsername,
      'sender_real_name': senderRealName,
      'sender_avatar_url': senderAvatarUrl,
      'sender_gender': senderGender,
      'relationship_type': relationshipType,
      'relationship_label': relationshipLabel,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 用户关系（含资料）
class UserRelation {
  final int relationId;
  final int userId;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final int? gender;
  final String relationshipType;
  final String status;
  final String? note;
  final DateTime createdAt;

  UserRelation({
    required this.relationId,
    required this.userId,
    required this.username,
    this.realName,
    this.avatarUrl,
    this.gender,
    required this.relationshipType,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory UserRelation.fromJson(Map<String, dynamic> json) {
    return UserRelation(
      relationId: json['relation_id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['real_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gender: json['gender'] as int?,
      relationshipType: json['relationship_type'] as String? ?? 'friend',
      status: json['status'] as String? ?? 'accepted',
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'relation_id': relationId,
      'user_id': userId,
      'username': username,
      'real_name': realName,
      'avatar_url': avatarUrl,
      'relationship_type': relationshipType,
      'status': status,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 好友列表
class FriendList {
  final List<UserRelation> family;
  final List<UserRelation> friends;

  FriendList({
    this.family = const [],
    this.friends = const [],
  });

  factory FriendList.fromJson(Map<String, dynamic> json) {
    return FriendList(
      family: (json['family'] as List<dynamic>?)
              ?.map((e) => UserRelation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      friends: (json['friends'] as List<dynamic>?)
              ?.map((e) => UserRelation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'family': family.map((e) => e.toJson()).toList(),
      'friends': friends.map((e) => e.toJson()).toList(),
    };
  }
}

/// 好友健康摘要（基础健康信息）
class FriendHealthSummary {
  final int userId;
  final double? totalCalories;
  final double? targetCalories;
  final int? waterIntake;
  final int? waterGoal;
  final String? petMood;
  final String? petName;

  FriendHealthSummary({
    required this.userId,
    required this.totalCalories,
    required this.targetCalories,
    required this.waterIntake,
    required this.waterGoal,
    required this.petMood,
    required this.petName,
  });

  factory FriendHealthSummary.fromJson(Map<String, dynamic> json) {
    return FriendHealthSummary(
      userId: json['user_id'] as int,
      totalCalories: (json['total_calories'] as num?)?.toDouble(),
      targetCalories: (json['target_calories'] as num?)?.toDouble(),
      waterIntake: (json['water_intake'] as num?)?.toInt(),
      waterGoal: (json['water_goal'] as num?)?.toInt(),
      petMood: json['pet_mood'] as String?,
      petName: json['pet_name'] as String?,
    );
  }
}

/// 好友排行榜条目
class LeaderboardItem {
  final int userId;
  final String username;
  final String? realName;
  final String? avatarUrl;
  final double weeklyBurnedCalories;
  final int exerciseCount;

  LeaderboardItem({
    required this.userId,
    required this.username,
    this.realName,
    this.avatarUrl,
    required this.weeklyBurnedCalories,
    required this.exerciseCount,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['real_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      weeklyBurnedCalories:
          (json['weekly_burned_calories'] as num?)?.toDouble() ?? 0,
      exerciseCount: (json['exercise_count'] as num?)?.toInt() ?? 0,
    );
  }

  String get displayName => realName ?? username;
}

/// 在线状态（在线标记 + 最后在线时间）
class OnlineStatusData {
  final bool isOnline;
  final DateTime? lastOnlineAt;

  OnlineStatusData({required this.isOnline, this.lastOnlineAt});

  factory OnlineStatusData.fromJson(Map<String, dynamic> json) {
    return OnlineStatusData(
      isOnline: json['is_online'] as bool? ?? false,
      lastOnlineAt: DateTime.tryParse(json['last_online_at'] as String? ?? ''),
    );
  }
}
