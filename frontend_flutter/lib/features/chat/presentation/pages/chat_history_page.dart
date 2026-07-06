import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../services/chat_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import 'chat_page.dart';

class ChatHistoryPage extends ConsumerStatefulWidget {
  final int sessionType;
  final Function(int sessionId)? onSessionSelected;

  const ChatHistoryPage({
    super.key,
    required this.sessionType,
    this.onSessionSelected,
  });

  @override
  ConsumerState<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends ConsumerState<ChatHistoryPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  List<ChatSessionSummary> _sessions = [];
  List<ChatSessionSummary> _filteredSessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _showSearchBar = false;

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
        sessionType: widget.sessionType,
        keyword: _searchController.text.trim().isNotEmpty
            ? _searchController.text.trim()
            : null,
        startDate: _startDate != null
            ? DateFormat('yyyy-MM-dd').format(_startDate!)
            : null,
        endDate: _endDate != null
            ? DateFormat('yyyy-MM-dd').format(_endDate!)
            : null,
      );

      if (response.success && response.data != null) {
        setState(() {
          _sessions = response.data!;
          _filteredSessions = _sessions;
          _isLoading = false;
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
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
      setState(() {
        _endDate = picked;
      });
      _loadSessions();
    }
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchController.clear();
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            _filteredSessions = _sessions;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('会话已删除')),
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

  void _openSession(ChatSessionSummary session) {
    if (widget.onSessionSelected != null) {
      widget.onSessionSelected!(session.id);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            sessionId: session.id,
            sessionType: session.sessionType,
            title: session.title,
          ),
        ),
      ).then((_) => _loadSessions());
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有对话'),
        content: const Text('确定要删除所有对话记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final response = await _chatService.deleteAllSessions(
          sessionType: widget.sessionType,
        );
        if (response.success && mounted) {
          setState(() {
            _sessions.clear();
            _filteredSessions.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('所有对话已清除'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text(
          '历史对话',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF222222)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Color(0xFFE74C3C),
              ),
              tooltip: '清除所有对话',
              onPressed: _clearAllHistory,
            ),
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
                  _loadSessions();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearchBar) _buildSearchBar(),
          _buildDateFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: '搜索对话内容...',
          hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2BAF74), size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
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
        onSubmitted: (_) => _loadSessions(),
      ),
    );
  }

  Widget _buildDateFilter() {
    final hasFilter = _startDate != null || _endDate != null;

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
          if (hasFilter)
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadSessions, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_filteredSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              '暂无对话记录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('开始新的对话吧', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      color: const Color(0xFF2BAF74),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _filteredSessions.length,
        itemBuilder: (context, index) {
          final session = _filteredSessions[index];
          return _buildSessionTile(session);
        },
      ),
    );
  }

  Widget _buildSessionTile(ChatSessionSummary session) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        onTap: () => _openSession(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getSessionTypeColor(session.sessionType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSessionTypeIcon(session.sessionType),
                  color: _getSessionTypeColor(session.sessionType),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getSessionTypeColor(session.sessionType).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            session.sessionTypeName,
                            style: TextStyle(
                              fontSize: 11,
                              color: _getSessionTypeColor(session.sessionType),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(session.lastMessageTime),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                        ),
                        if (session.messageCount > 0) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${session.messageCount}条',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFCCCCCC)),
                onPressed: () => _deleteSession(session),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSessionTypeColor(int sessionType) {
    switch (sessionType) {
      case 1:
        return const Color(0xFF2BAF74);
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
        return DateFormat('yyyy/MM/dd').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }
}
