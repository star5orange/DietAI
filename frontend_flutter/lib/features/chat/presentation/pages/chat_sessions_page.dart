import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../services/chat_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import 'chat_page.dart';

class ChatSessionsPage extends ConsumerStatefulWidget {
  const ChatSessionsPage({super.key});

  @override
  ConsumerState<ChatSessionsPage> createState() => _ChatSessionsPageState();
}

class _ChatSessionsPageState extends ConsumerState<ChatSessionsPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatSessionSummary> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _selectedSessionType;
  bool _showSearchBar = false;

  // 消息级搜索结果
  List<ChatMessageSearchResult> _messageResults = [];
  bool _isDeepSearching = false;

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _chatService.getSessions(
        sessionType: _selectedSessionType,
        keyword: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
        startDate: _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        endDate: _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
        limit: 50,
      );

      if (response.success && response.data != null) {
        setState(() {
          _sessions = response.data!;
          _isLoading = false;
          _messageResults = [];
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载会话列表失败: $e';
        _isLoading = false;
      });
    }
  }

  /// 深度搜索：搜索消息内容
  Future<void> _deepSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isDeepSearching = true;
      _errorMessage = null;
    });

    try {
      final response = await _chatService.searchMessages(
        keyword: keyword,
        sessionType: _selectedSessionType,
        startDate: _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        endDate: _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
      );

      if (response.success && response.data != null) {
        setState(() {
          _messageResults = response.data!;
          _isDeepSearching = false;
        });
        if (_messageResults.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到相关消息')),
          );
        }
      } else {
        setState(() => _isDeepSearching = false);
      }
    } catch (e) {
      setState(() => _isDeepSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
      _loadSessions();
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _loadSessions();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedSessionType = null;
      _searchController.clear();
      _messageResults = [];
    });
    _loadSessions();
  }

  Future<void> _deleteSession(ChatSessionSummary session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定要删除会话"${session.title}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response =
            await _chatService.deleteSession(sessionId: session.id);

        if (response.success) {
          setState(() {
            _sessions.removeWhere((s) => s.id == session.id);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('会话已删除')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: ${response.message}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  void _openChat(ChatSessionSummary session) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ChatPage(
              sessionId: session.id,
              sessionType: session.sessionType,
              title: session.title,
            ),
          ),
        )
        .then((_) => _loadSessions()); // 返回时刷新列表
  }

  void _startNewChat() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildSessionTypeSelector(),
    );
  }

  Widget _buildSessionTypeSelector() {
    final sessionTypes = [
      {
        'type': 1,
        'name': '营养咨询',
        'icon': Icons.restaurant,
        'color': Colors.green
      },
      {
        'type': 2,
        'name': '健康评估',
        'icon': Icons.health_and_safety,
        'color': Colors.blue
      },
      {
        'type': 3,
        'name': '食物识别',
        'icon': Icons.camera_alt,
        'color': Colors.orange
      },
      {
        'type': 4,
        'name': '运动建议',
        'icon': Icons.fitness_center,
        'color': Colors.purple
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择对话类型',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...sessionTypes.map((type) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  type['icon'] as IconData,
                  color: type['color'] as Color,
                ),
                title: Text(type['name'] as String),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            sessionType: type['type'] as int,
                            title: type['name'] as String,
                          ),
                        ),
                      )
                      .then((_) => _loadSessions());
                },
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          'AI对话',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.close : Icons.search,
              color: const Color(0xFF2BAF74),
            ),
            onPressed: () {
              setState(() {
                _showSearchBar = !_showSearchBar;
                if (!_showSearchBar) {
                  _searchController.clear();
                  _messageResults = [];
                  _loadSessions();
                }
              });
            },
          ),
          PopupMenuButton<int?>(
            icon: const Icon(Icons.filter_list, color: Color(0xFF2BAF74)),
            onSelected: (sessionType) {
              setState(() => _selectedSessionType = sessionType);
              _loadSessions();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部类型'),
              ),
              const PopupMenuItem(value: 1, child: Text('营养咨询')),
              const PopupMenuItem(value: 2, child: Text('健康评估')),
              const PopupMenuItem(value: 3, child: Text('食物识别')),
              const PopupMenuItem(value: 4, child: Text('运动建议')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearchBar) _buildSearchBar(),
          if (_startDate != null || _endDate != null) _buildDateFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewChat,
        backgroundColor: const Color(0xFF2BAF74),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '搜索对话标题...',
                hintStyle:
                    const TextStyle(color: Color(0xFF999999), fontSize: 15),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF2BAF74), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _messageResults = [];
                          _loadSessions();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              style: const TextStyle(fontSize: 15),
              onSubmitted: (_) {
                _loadSessions();
                _deepSearch();
              },
            ),
          ),
          const SizedBox(width: 8),
          // 深度搜索按钮：搜索消息内容
          GestureDetector(
            onTap: _deepSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2BAF74),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isDeepSearching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '消息搜索',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF999999)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickStartDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _startDate != null
                    ? const Color(0xFF2BAF74).withValues(alpha: 0.1)
                    : const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _startDate != null
                      ? const Color(0xFF2BAF74)
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Text(
                _startDate != null
                    ? DateFormat('yyyy/MM/dd').format(_startDate!)
                    : '开始日期',
                style: TextStyle(
                  fontSize: 13,
                  color: _startDate != null
                      ? const Color(0xFF2BAF74)
                      : const Color(0xFF999999),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('~', style: TextStyle(color: Color(0xFF999999))),
          ),
          GestureDetector(
            onTap: _pickEndDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _endDate != null
                    ? const Color(0xFF2BAF74).withValues(alpha: 0.1)
                    : const Color(0xFFF5F7F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _endDate != null
                      ? const Color(0xFF2BAF74)
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Text(
                _endDate != null
                    ? DateFormat('yyyy/MM/dd').format(_endDate!)
                    : '结束日期',
                style: TextStyle(
                  fontSize: 13,
                  color: _endDate != null
                      ? const Color(0xFF2BAF74)
                      : const Color(0xFF999999),
                ),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '清除',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _isDeepSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 显示消息搜索结果
    if (_messageResults.isNotEmpty) {
      return _buildSearchResults();
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSessions,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_sessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          return _buildSessionTile(session);
        },
      ),
    );
  }

  /// 消息搜索结果展示
  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF2BAF74).withValues(alpha: 0.05),
          child: Row(
            children: [
              const Icon(Icons.search, size: 16, color: Color(0xFF2BAF74)),
              const SizedBox(width: 6),
              Text(
                '找到 ${_messageResults.length} 条相关消息',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2BAF74),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _messageResults = []),
                child:
                    const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _messageResults.length,
            itemBuilder: (context, index) {
              final result = _messageResults[index];
              return _buildSearchResultTile(result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultTile(ChatMessageSearchResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _openChat(ChatSessionSummary(
          id: result.sessionId,
          title: result.sessionTitle,
          lastMessage: result.contentSnippet,
          lastMessageTime: result.createdAt,
          sessionType: result.sessionType,
          sessionTypeName: result.sessionTypeName,
          messageCount: 0,
        )),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getSessionTypeIcon(result.sessionType),
                    size: 16,
                    color: _getSessionTypeColor(result.sessionType),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.sessionTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.contentSnippet,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                _formatTime(result.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBBBBBB),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedSessionType != null
                ? '暂无${_getSessionTypeName(_selectedSessionType!)}对话'
                : '暂无对话记录',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角的 + 号开始新的对话',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startNewChat,
            icon: const Icon(Icons.add),
            label: const Text('开始对话'),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(ChatSessionSummary session) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSessionTypeColor(session.sessionType),
          child: Icon(
            _getSessionTypeIcon(session.sessionType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          session.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.lastMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  session.sessionTypeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getSessionTypeColor(session.sessionType),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(session.lastMessageTime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.messageCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${session.messageCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('删除', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteSession(session);
                }
              },
            ),
          ],
        ),
        onTap: () => _openChat(session),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Color _getSessionTypeColor(int sessionType) {
    switch (sessionType) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getSessionTypeIcon(int sessionType) {
    switch (sessionType) {
      case 1:
        return Icons.restaurant;
      case 2:
        return Icons.health_and_safety;
      case 3:
        return Icons.camera_alt;
      case 4:
        return Icons.fitness_center;
      default:
        return Icons.chat;
    }
  }

  String _getSessionTypeName(int sessionType) {
    return _chatService.getSessionTypeName(sessionType);
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}分钟前';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}小时前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}天前';
      } else {
        return '${dateTime.month}/${dateTime.day}';
      }
    } catch (e) {
      return '';
    }
  }
}
