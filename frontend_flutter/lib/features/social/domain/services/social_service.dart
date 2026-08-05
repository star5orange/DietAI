import '../../data/social_api_service.dart';
import '../../domain/social_models.dart';

/// 社交业务逻辑服务
/// 封装社交功能的业务规则和数据转换
class SocialService {
  final SocialApiService _apiService;

  SocialService(this._apiService);

  /// 发送好友申请
  Future<bool> sendFriendRequest(int targetUserId, {String? message}) async {
    final response = await _apiService.sendFriendRequest(targetUserId, message: message);
    return response.success;
  }

  /// 处理好友申请
  Future<bool> handleFriendRequest(int requestId, String action) async {
    final response = await _apiService.handleFriendRequest(requestId, action);
    return response.success;
  }

  /// 添加家人
  Future<bool> addFamilyMember(int targetUserId, {String? relationshipLabel}) async {
    final response = await _apiService.addFamilyMember(targetUserId, relationshipLabel: relationshipLabel);
    return response.success;
  }

  /// 获取好友列表
  Future<FriendList?> getFriendList() async {
    final response = await _apiService.getFriendList();
    if (response.success && response.data != null) {
      return response.data;
    }
    return null;
  }

  /// 移除关系
  Future<bool> removeRelation(int relationId) async {
    final response = await _apiService.removeRelation(relationId);
    return response.success;
  }

  /// 搜索用户
  Future<List<UserSearchResult>> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) {
      return [];
    }
    final response = await _apiService.searchUsers(keyword);
    if (response.success && response.data != null) {
      return response.data!;
    }
    return [];
  }

  /// 获取待处理申请
  Future<List<FriendRequest>> getPendingRequests() async {
    final response = await _apiService.getPendingRequests();
    if (response.success && response.data != null) {
      return response.data!;
    }
    return [];
  }

  /// 检查是否已是好友
  bool isFriend(FriendList friendList, int userId) {
    return friendList.friends.any((f) => f.userId == userId);
  }

  /// 检查是否已是家人
  bool isFamily(FriendList friendList, int userId) {
    return friendList.family.any((f) => f.userId == userId);
  }

  /// 获取家人数量
  int getFamilyCount(FriendList friendList) {
    return friendList.family.length;
  }

  /// 获取好友数量
  int getFriendCount(FriendList friendList) {
    return friendList.friends.length;
  }
}
