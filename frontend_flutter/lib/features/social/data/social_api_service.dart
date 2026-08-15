import '../../../core/services/api_service.dart';
import '../../../shared/domain/models/api_response.dart';
import '../domain/social_models.dart';

/// 社交关系 API 服务
/// 对接后端 /api/social/* 端点
class SocialApiService {
  final ApiService _api = ApiService();

  ApiResponse<Map<String, dynamic>> _wrapMap(ApiResponse<dynamic> res) {
    return ApiResponse<Map<String, dynamic>>(
      success: res.success,
      message: res.message,
      data: res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : null,
    );
  }

  ApiResponse<List<dynamic>> _wrapList(ApiResponse<dynamic> res) {
    return ApiResponse<List<dynamic>>(
      success: res.success,
      message: res.message,
      data: res.data is List ? res.data as List : [],
    );
  }

  // ==================== 搜索用户 ====================

  /// 搜索用户
  Future<ApiResponse<List<UserSearchResult>>> searchUsers(
      String keyword) async {
    try {
      final res = await _api
          .get('/social/search', queryParameters: {'keyword': keyword});
      if (res.success && res.data is List) {
        final users = (res.data as List)
            .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(message: res.message, data: users);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '搜索用户失败', error: e.toString());
    }
  }

  // ==================== 好友申请 ====================

  /// 发送好友申请
  Future<ApiResponse<void>> sendFriendRequest(int targetUserId,
      {String? message, String? relationshipLabel}) async {
    try {
      final res = await _api.post('/social/friend-request', data: {
        'target_user_id': targetUserId,
        if (message != null) 'message': message,
        if (relationshipLabel != null) 'relationship_label': relationshipLabel,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '发送好友申请失败', error: e.toString());
    }
  }

  /// 处理好友申请
  Future<ApiResponse<void>> handleFriendRequest(int requestId, String action,
      {String? relationshipLabel}) async {
    try {
      final res =
          await _api.put('/social/friend-request/$requestId', queryParameters: {
        'action': action,
        if (relationshipLabel != null) 'relationship_label': relationshipLabel,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '处理好友申请失败', error: e.toString());
    }
  }

  /// 获取待处理申请
  Future<ApiResponse<List<FriendRequest>>> getPendingRequests() async {
    try {
      final res = await _api.get('/social/pending-requests');
      if (res.success && res.data is List) {
        final requests = (res.data as List)
            .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(message: res.message, data: requests);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取待处理申请失败', error: e.toString());
    }
  }

  // ==================== 家人关系 ====================

  /// 添加家人
  Future<ApiResponse<void>> addFamilyMember(int targetUserId,
      {String? relationshipLabel}) async {
    try {
      final res = await _api.post('/social/family', data: {
        'target_user_id': targetUserId,
        if (relationshipLabel != null) 'relationship_label': relationshipLabel,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '添加家人失败', error: e.toString());
    }
  }

  /// 好友升级为家人
  Future<ApiResponse<void>> upgradeToFamily(int targetUserId,
      {String? relationshipLabel}) async {
    try {
      final res = await _api
          .post('/social/upgrade-to-family/$targetUserId', queryParameters: {
        if (relationshipLabel != null) 'relationship_label': relationshipLabel,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '升级为家人失败', error: e.toString());
    }
  }

  /// 更新我方对某关系（好友/家人）的称谓
  Future<ApiResponse<void>> updateRelationNote(
      int relationId, String relationshipLabel) async {
    try {
      final res = await _api.put(
        '/social/relation/$relationId/note',
        data: {'relationship_label': relationshipLabel},
      );
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新关系称谓失败', error: e.toString());
    }
  }

  // ==================== 好友列表 ====================

  /// 获取好友列表
  Future<ApiResponse<FriendList>> getFriendList() async {
    try {
      final res = await _api.get('/social/friends');
      if (res.success && res.data is Map<String, dynamic>) {
        final friendList =
            FriendList.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: friendList);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取好友列表失败', error: e.toString());
    }
  }

  // ==================== 移除关系 ====================

  /// 移除好友/解除家人关系
  Future<ApiResponse<void>> removeRelation(int relationId) async {
    try {
      final res = await _api.delete('/social/relation/$relationId');
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '移除关系失败', error: e.toString());
    }
  }

  // ==================== 数据权限管理 ====================

  /// 获取数据权限
  Future<ApiResponse<List<String>>> getPermission(int targetUserId) async {
    try {
      final res = await _api.get('/social/permission/$targetUserId');
      if (res.success && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final fields = List<String>.from(data['visible_fields'] ?? []);
        return ApiResponse.success(message: res.message, data: fields);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取权限失败', error: e.toString());
    }
  }

  /// 更新数据权限
  Future<ApiResponse<void>> updatePermission(
      int targetUserId, List<String> visibleFields) async {
    try {
      final res = await _api.put(
        '/social/permission/$targetUserId',
        data: {'visible_fields': visibleFields},
      );
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '更新权限失败', error: e.toString());
    }
  }

  // ==================== 在线状态 ====================

  /// 获取用户在线状态（在线标记 + 最后在线时间）
  Future<ApiResponse<OnlineStatusData>> getOnlineStatus(int userId) async {
    try {
      final res = await _api.get('/messages/online-status/$userId');
      if (res.success && res.data is Map<String, dynamic>) {
        final data = OnlineStatusData.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: data);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取在线状态失败', error: e.toString());
    }
  }

  // ==================== 好友健康信息 ====================

  /// 获取好友基础健康信息
  Future<ApiResponse<FriendHealthSummary>> getFriendHealth(int userId) async {
    try {
      final res = await _api.get('/social/friend-health/$userId');
      if (res.success && res.data is Map<String, dynamic>) {
        final summary =
            FriendHealthSummary.fromJson(res.data as Map<String, dynamic>);
        return ApiResponse.success(message: res.message, data: summary);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取好友健康信息失败', error: e.toString());
    }
  }

  // ==================== 好友排行榜 ====================

  /// 获取好友饮食排行榜
  Future<ApiResponse<List<LeaderboardItem>>> getLeaderboard() async {
    try {
      final res = await _api.get('/social/leaderboard');
      if (res.success && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final items = (data['leaderboard'] as List<dynamic>? ?? [])
            .map((e) => LeaderboardItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(message: res.message, data: items);
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取排行榜失败', error: e.toString());
    }
  }

  // ==================== 邀请码 ====================

  /// 获取我的邀请码
  Future<ApiResponse<Map<String, dynamic>>> getInviteCode() async {
    try {
      final res = await _api.get('/social/invite-code');
      if (res.success && res.data is Map<String, dynamic>) {
        return ApiResponse<Map<String, dynamic>>(
          success: true,
          message: res.message,
          data: res.data as Map<String, dynamic>,
        );
      }
      return ApiResponse.failure(message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '获取邀请码失败', error: e.toString());
    }
  }

  /// 通过邀请码加入家人
  Future<ApiResponse<void>> joinFamilyByInviteCode(String inviteCode) async {
    try {
      final res = await _api.post('/social/join-family', data: {
        'invite_code': inviteCode,
      });
      return ApiResponse(success: res.success, message: res.message);
    } catch (e) {
      return ApiResponse.failure(message: '加入家人失败', error: e.toString());
    }
  }
}
