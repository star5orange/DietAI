import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../domain/social_models.dart';
import '../providers/social_provider.dart';
import '../widgets/relationship_label_dialog.dart';

/// 搜索用户页面
class SearchUserPage extends ConsumerStatefulWidget {
  const SearchUserPage({super.key});

  @override
  ConsumerState<SearchUserPage> createState() => _SearchUserPageState();
}

class _SearchUserPageState extends ConsumerState<SearchUserPage>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  String _addMode = 'friend'; // 'friend' or 'family'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用恢复前台时自动刷新搜索结果
    if (state == AppLifecycleState.resumed) {
      _refreshSearch();
    }
  }

  void _search() {
    final keyword = _controller.text.trim();
    if (keyword.isNotEmpty) {
      ref.read(userSearchKeywordProvider.notifier).state = keyword;
      ref.read(userSearchProvider.notifier).searchUsers(keyword);
    }
  }

  void _refreshSearch() {
    final keyword = ref.read(userSearchKeywordProvider);
    if (keyword.isNotEmpty) {
      ref.read(userSearchProvider.notifier).searchUsers(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索用户'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSearch,
            tooltip: '刷新搜索结果',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '输入用户名或ID搜索',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          // 添加模式选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('添加为：', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('好友'),
                  selected: _addMode == 'friend',
                  onSelected: (selected) {
                    if (selected) setState(() => _addMode = 'friend');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('家人'),
                  selected: _addMode == 'family',
                  onSelected: (selected) {
                    if (selected) setState(() => _addMode = 'family');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 搜索结果
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshSearch();
              },
              child: _buildResults(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(UserSearchState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text(state.error!, style: const TextStyle(color: Colors.grey)),
      );
    }

    if (state.results.isEmpty) {
      return const Center(
        child: Text('输入关键词搜索用户', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final user = state.results[index];
        return _UserSearchTile(
          user: user,
          addMode: _addMode,
          onRefresh: _refreshSearch,
        );
      },
    );
  }
}

class _UserSearchTile extends ConsumerWidget {
  final UserSearchResult user;
  final String addMode;
  final VoidCallback onRefresh;

  const _UserSearchTile({
    required this.user,
    required this.addMode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAlreadyRelated = (addMode == 'friend' && user.isFriend) ||
        (addMode == 'family' && user.isFamily);
    final isPending = (addMode == 'friend' && user.pendingFriend) ||
        (addMode == 'family' && user.pendingFamily);

    Widget trailing;
    if (isAlreadyRelated) {
      trailing = const Chip(
        label: Text('已添加', style: TextStyle(fontSize: 12)),
        backgroundColor: Color(0xFFE8F5E9),
      );
    } else if (isPending) {
      trailing = const Chip(
        label: Text('已发送申请', style: TextStyle(fontSize: 12)),
        backgroundColor: Color(0xFFF3E5F5),
      );
    } else {
      trailing = TextButton(
        onPressed: () => _handleAdd(context, ref),
        child: Text(addMode == 'friend' ? '添加好友' : '添加家人'),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[200],
        backgroundImage:
            user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null
            ? const Icon(Icons.person, size: 24, color: Colors.grey)
            : null,
      ),
      title: Text(user.realName ?? user.username),
      subtitle: Text('@${user.username}'),
      trailing: trailing,
    );
  }

  Future<void> _handleAdd(BuildContext context, WidgetRef ref) async {
    // 先选择对方与我的关系称谓（可跳过，按对方性别推荐）
    final label =
        await showRelationshipLabelDialog(context, gender: user.gender);

    bool success;
    String message;

    if (addMode == 'friend') {
      success = await ref
          .read(friendListProvider.notifier)
          .sendFriendRequest(user.id, relationshipLabel: label);
      message = success ? '好友申请已发送' : '发送申请失败';
    } else {
      success = await ref
          .read(friendListProvider.notifier)
          .addFamilyMember(user.id, relationshipLabel: label);
      message = success ? '家人申请已发送' : '发送申请失败';
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      // 成功后立即刷新搜索结果
      if (success) {
        // 确保关键词已保存
        final keyword = ref.read(userSearchKeywordProvider);
        if (keyword.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 300));
          ref.read(userSearchProvider.notifier).searchUsers(keyword);
        }
      }
    }
  }
}
