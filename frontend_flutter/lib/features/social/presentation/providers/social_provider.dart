import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/social_api_service.dart';
import '../../domain/social_models.dart';

/// 社交 API 服务 Provider
final socialApiServiceProvider = Provider<SocialApiService>((ref) {
  return SocialApiService();
});

/// 好友列表状态
class FriendListState {
  final List<UserRelation> family;
  final List<UserRelation> friends;
  final bool isLoading;
  final String? error;

  FriendListState({
    this.family = const [],
    this.friends = const [],
    this.isLoading = false,
    this.error,
  });

  FriendListState copyWith({
    List<UserRelation>? family,
    List<UserRelation>? friends,
    bool? isLoading,
    String? error,
  }) {
    return FriendListState(
      family: family ?? this.family,
      friends: friends ?? this.friends,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 好友列表 Provider
class FriendListNotifier extends StateNotifier<FriendListState> {
  final SocialApiService _apiService;

  FriendListNotifier(this._apiService) : super(FriendListState());

  Future<void> loadFriendList() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getFriendList();
      if (response.success && response.data != null) {
        state = state.copyWith(
          family: response.data!.family,
          friends: response.data!.friends,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> sendFriendRequest(int targetUserId,
      {String? message, String? relationshipLabel}) async {
    try {
      final response = await _apiService.sendFriendRequest(targetUserId,
          message: message, relationshipLabel: relationshipLabel);
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addFamilyMember(int targetUserId,
      {String? relationshipLabel}) async {
    try {
      final response = await _apiService.addFamilyMember(targetUserId,
          relationshipLabel: relationshipLabel);
      if (response.success) {
        await loadFriendList();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> upgradeToFamily(int targetUserId,
      {String? relationshipLabel}) async {
    try {
      final response = await _apiService.upgradeToFamily(targetUserId,
          relationshipLabel: relationshipLabel);
      if (response.success) {
        await loadFriendList();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateRelationNote(
      int relationId, String relationshipLabel) async {
    try {
      final response =
          await _apiService.updateRelationNote(relationId, relationshipLabel);
      if (response.success) {
        await loadFriendList();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> handleFriendRequest(int requestId, String action,
      {String? relationshipLabel}) async {
    try {
      final response = await _apiService.handleFriendRequest(requestId, action,
          relationshipLabel: relationshipLabel);
      if (response.success) {
        await loadFriendList();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeRelation(int relationId) async {
    try {
      final response = await _apiService.removeRelation(relationId);
      if (response.success) {
        await loadFriendList();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }
}

final friendListProvider =
    StateNotifierProvider<FriendListNotifier, FriendListState>((ref) {
  return FriendListNotifier(ref.watch(socialApiServiceProvider));
});

/// 待处理申请状态
class PendingRequestsState {
  final List<FriendRequest> requests;
  final bool isLoading;
  final String? error;

  PendingRequestsState({
    this.requests = const [],
    this.isLoading = false,
    this.error,
  });

  PendingRequestsState copyWith({
    List<FriendRequest>? requests,
    bool? isLoading,
    String? error,
  }) {
    return PendingRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 待处理申请 Provider
class PendingRequestsNotifier extends StateNotifier<PendingRequestsState> {
  final SocialApiService _apiService;

  PendingRequestsNotifier(this._apiService) : super(PendingRequestsState());

  Future<void> loadPendingRequests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getPendingRequests();
      if (response.success && response.data != null) {
        state = state.copyWith(
          requests: response.data!,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> handleRequest(int requestId, String action,
      {String? relationshipLabel}) async {
    try {
      final response = await _apiService.handleFriendRequest(requestId, action,
          relationshipLabel: relationshipLabel);
      if (response.success) {
        await loadPendingRequests();
      }
      return response.success;
    } catch (e) {
      return false;
    }
  }
}

final pendingRequestsProvider =
    StateNotifierProvider<PendingRequestsNotifier, PendingRequestsState>((ref) {
  return PendingRequestsNotifier(ref.watch(socialApiServiceProvider));
});

/// 用户搜索关键词（持久化，不随页面销毁）
final userSearchKeywordProvider = StateProvider<String>((ref) => '');

/// 用户搜索状态
class UserSearchState {
  final List<UserSearchResult> results;
  final bool isLoading;
  final String? error;

  UserSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
  });

  UserSearchState copyWith({
    List<UserSearchResult>? results,
    bool? isLoading,
    String? error,
  }) {
    return UserSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 用户搜索 Provider
class UserSearchNotifier extends StateNotifier<UserSearchState> {
  final SocialApiService _apiService;

  UserSearchNotifier(this._apiService) : super(UserSearchState());

  Future<void> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = state.copyWith(results: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.searchUsers(keyword);
      if (response.success && response.data != null) {
        state = state.copyWith(
          results: response.data!,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearResults() {
    state = UserSearchState();
  }
}

final userSearchProvider =
    StateNotifierProvider<UserSearchNotifier, UserSearchState>((ref) {
  return UserSearchNotifier(ref.watch(socialApiServiceProvider));
});

/// 在线状态
class OnlineStatusState {
  final bool isOnline;
  final bool isLoading;

  OnlineStatusState({
    this.isOnline = false,
    this.isLoading = false,
  });

  OnlineStatusState copyWith({
    bool? isOnline,
    bool? isLoading,
  }) {
    return OnlineStatusState(
      isOnline: isOnline ?? this.isOnline,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 在线状态 Notifier（按用户 ID 缓存）
class OnlineStatusNotifier extends StateNotifier<OnlineStatusState> {
  final SocialApiService _apiService;
  final int _userId;

  OnlineStatusNotifier(this._apiService, this._userId)
      : super(OnlineStatusState(isLoading: true)) {
    _checkOnline();
  }

  Future<void> _checkOnline() async {
    try {
      final response = await _apiService.getOnlineStatus(_userId);
      if (response.success && response.data != null) {
        state = OnlineStatusState(isOnline: response.data!);
      } else {
        state = OnlineStatusState(isOnline: false);
      }
    } catch (_) {
      state = OnlineStatusState(isOnline: false);
    }
  }

  /// 刷新在线状态
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _checkOnline();
  }

  /// 直接设置在线状态（由 WebSocket 在线状态推送触发，无需重新请求）
  void setOnline(bool isOnline) {
    state = OnlineStatusState(isOnline: isOnline);
  }
}

/// 在线状态 Provider（按用户 ID 缓存）
final onlineStatusProvider =
    StateNotifierProvider.family<OnlineStatusNotifier, OnlineStatusState, int>(
        (ref, userId) {
  return OnlineStatusNotifier(ref.watch(socialApiServiceProvider), userId);
});

/// 好友健康摘要 Notifier（按用户 ID 缓存）
class FriendHealthNotifier
    extends StateNotifier<AsyncValue<FriendHealthSummary>> {
  final SocialApiService _apiService;
  final int _userId;

  FriendHealthNotifier(this._apiService, this._userId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final response = await _apiService.getFriendHealth(_userId);
      if (response.success && response.data != null) {
        state = AsyncValue.data(response.data!);
      } else {
        state =
            AsyncValue.error(Exception(response.message), StackTrace.current);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// 好友健康摘要 Provider（按用户 ID 缓存）
final friendHealthProvider = StateNotifierProvider.family<FriendHealthNotifier,
    AsyncValue<FriendHealthSummary>, int>((ref, userId) {
  return FriendHealthNotifier(ref.watch(socialApiServiceProvider), userId);
});

/// 排行榜状态
class LeaderboardState {
  final List<LeaderboardItem> items;
  final bool isLoading;
  final String? error;

  LeaderboardState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  LeaderboardState copyWith({
    List<LeaderboardItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return LeaderboardState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 排行榜 Notifier
class LeaderboardNotifier extends StateNotifier<LeaderboardState> {
  final SocialApiService _apiService;

  LeaderboardNotifier(this._apiService) : super(LeaderboardState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiService.getLeaderboard();
      if (response.success && response.data != null) {
        state = state.copyWith(items: response.data!, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: response.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// 排行榜 Provider
final leaderboardProvider =
    StateNotifierProvider<LeaderboardNotifier, LeaderboardState>((ref) {
  return LeaderboardNotifier(ref.watch(socialApiServiceProvider));
});
