import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/chat_service.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../core/themes/app_colors.dart';
import 'chat_history_page.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int? sessionId;
  final int sessionType;
  final String? title;

  const ChatPage({
    super.key,
    this.sessionId,
    this.sessionType = 1,
    this.title,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int? _currentSessionId;
  List<ChatMessageDetail> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_currentSessionId != null) {
      await _loadSessionMessages();
    } else {
      await _createNewSession();
    }
  }

  Future<void> _createNewSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _chatService.startSession(
        sessionType: widget.sessionType,
        title: widget.title,
      );

      if (response.success && response.data != null) {
        setState(() {
          _currentSessionId = response.data!.sessionId;
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
        _errorMessage = '创建会话失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSessionMessages() async {
    if (_currentSessionId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _chatService.getSessionMessages(
        sessionId: _currentSessionId!,
      );

      if (response.success && response.data != null) {
        setState(() {
          _messages = response.data!.messages;
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载消息失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // 添加用户消息到界面
    setState(() {
      _messages.add(ChatMessageDetail(
        id: DateTime.now().millisecondsSinceEpoch,
        role: 'user',
        content: message,
        timestamp: DateTime.now().toIso8601String(),
      ));
      _isSending = true;
    });

    _scrollToBottom();

    try {
      // 准备AI消息占位符
      final aiMessageId = DateTime.now().millisecondsSinceEpoch + 1;
      String aiContent = '';

      // 添加AI消息占位符
      setState(() {
        _messages.add(ChatMessageDetail(
          id: aiMessageId,
          role: 'assistant',
          content: '',
          timestamp: DateTime.now().toIso8601String(),
        ));
      });

      // 使用流式API
      await for (final event in _chatService.sendMessageStream(
        message: message,
        sessionId: _currentSessionId,
        sessionType: widget.sessionType,
      )) {
        if (event.isSession && event.sessionId != null) {
          // 更新会话ID
          setState(() {
            _currentSessionId = event.sessionId;
          });
        } else if (event.isContent && event.content != null) {
          // 累积AI回复内容
          aiContent += event.content!;

          setState(() {
            // 更新AI消息内容
            final index = _messages.indexWhere((m) => m.id == aiMessageId);
            if (index != -1) {
              _messages[index] = ChatMessageDetail(
                id: aiMessageId,
                role: 'assistant',
                content: aiContent,
                timestamp: DateTime.now().toIso8601String(),
              );
            }
          });

          _scrollToBottom();
        } else if (event.isComplete) {
          // 完成流式响应
          setState(() {
            _isSending = false;
          });
          break;
        } else if (event.isError) {
          // 处理错误
          setState(() {
            final index = _messages.indexWhere((m) => m.id == aiMessageId);
            if (index != -1) {
              _messages[index] = ChatMessageDetail(
                id: aiMessageId,
                role: 'assistant',
                content: event.message ?? '抱歉，我暂时无法回复您的消息。请稍后再试。',
                timestamp: DateTime.now().toIso8601String(),
              );
            }
            _isSending = false;
          });
          break;
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessageDetail(
          id: DateTime.now().millisecondsSinceEpoch,
          role: 'assistant',
          content: '发送消息时出现错误，请检查网络连接后重试。',
          timestamp: DateTime.now().toIso8601String(),
        ));
        _isSending = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: Text(
          widget.title ?? _chatService.getSessionTypeName(widget.sessionType),
          style: const TextStyle(
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
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              size: 22,
              color: Color(0xFFE74C3C),
            ),
            tooltip: '清除所有对话',
            onPressed: _clearAllHistory,
          ),
          IconButton(
            icon: const Icon(
              Icons.history,
              size: 24,
              color: Color(0xFF2BAF74),
            ),
            onPressed: () => _navigateToChatHistory(),
          ),
          if (_currentSessionId != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2BAF74),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              onPressed: _showSessionInfo,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeChat,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return _buildWelcomeMessage();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildWelcomeMessage() {
    String welcomeText;
    IconData welcomeIcon;
    switch (widget.sessionType) {
      case 1:
        welcomeText = '您好！我是您的专属营养顾问，可以为您提供个性化的营养建议和饮食指导。有什么问题想要咨询吗？';
        welcomeIcon = Icons.restaurant_menu;
        break;
      case 2:
        welcomeText = '欢迎来到健康评估！我可以帮您分析健康状况，提供个性化的健康建议。请告诉我您的需求。';
        welcomeIcon = Icons.favorite;
        break;
      case 3:
        welcomeText = '我可以帮您识别食物并分析营养成分。您可以发送食物图片或描述您想了解的食物。';
        welcomeIcon = Icons.camera_alt;
        break;
      case 4:
        welcomeText = '作为您的运动顾问，我可以为您制定个性化的运动计划和建议。有什么运动相关的问题吗？';
        welcomeIcon = Icons.fitness_center;
        break;
      default:
        welcomeText = '您好！我是DietAI智能助手，随时为您提供健康和营养方面的帮助。有什么可以为您服务的吗？';
        welcomeIcon = Icons.smart_toy;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              welcomeIcon,
              size: 40,
              color: const Color(0xFF2BAF74),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            welcomeText,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    List<String> suggestions;
    switch (widget.sessionType) {
      case 1:
        suggestions = ['今天吃什么好？', '如何制定减脂饮食计划？', '我的营养摄入够吗？'];
        break;
      case 2:
        suggestions = ['分析我的健康状况', '如何改善我的健康评分？', '给我一些健康建议'];
        break;
      case 3:
        suggestions = ['这个食物有什么营养？', '帮我分析这餐的热量', '推荐健康的食物搭配'];
        break;
      case 4:
        suggestions = ['制定运动计划', '什么运动适合减脂？', '如何提高运动效果？'];
        break;
      default:
        suggestions = ['了解我的健康状况', '制定饮食计划', '运动建议'];
    }

    return Column(
      children: suggestions.map((suggestion) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                _messageController.text = suggestion;
                _sendMessage();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2BAF74), width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              child: Text(
                suggestion,
                style: const TextStyle(
                  color: Color(0xFF2BAF74),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageBubble(ChatMessageDetail message) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF2BAF74),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF2BAF74) : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 如果是AI消息且内容为空，显示输入指示器
                  if (!isUser && message.content.isEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '正在思考中',
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2BAF74),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF222222),
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF999999),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF55C89F),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide:
                          const BorderSide(color: Color(0xFF2BAF74), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F7F6),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF222222),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending
                    ? const Color(0xFFE6FAF0)
                    : const Color(0xFF2BAF74),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _isSending ? const Color(0xFF999999) : Colors.white,
                  size: 20,
                ),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
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
      } else {
        return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  void _navigateToChatHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatHistoryPage(
          sessionType: widget.sessionType,
          onSessionSelected: (sessionId) {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  sessionId: sessionId,
                  sessionType: widget.sessionType,
                  title: widget.title,
                ),
              ),
            );
          },
        ),
      ),
    );
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
            _messages.clear();
            _currentSessionId = null;
          });
          await _createNewSession();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('所有对话已清除'),
                backgroundColor: AppColors.success,
              ),
            );
          }
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

  void _showSessionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会话信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('会话ID: ${_currentSessionId ?? '未知'}'),
            const SizedBox(height: 8),
            Text(
                '会话类型: ${_chatService.getSessionTypeName(widget.sessionType)}'),
            const SizedBox(height: 8),
            Text('消息数量: ${_messages.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
