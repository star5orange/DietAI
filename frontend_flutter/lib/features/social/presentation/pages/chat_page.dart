import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/themes/app_colors.dart';
import '../../../../services/food_service.dart';
import '../../../../shared/domain/models/food_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/message_api_service.dart';
import '../../data/websocket_service.dart';
import '../../domain/message_models.dart';
import '../providers/message_provider.dart';
import '../widgets/message_bubble.dart';

/// 聊天页面
class ChatPage extends ConsumerStatefulWidget {
  final int targetUserId;
  final String? targetUserName;
  final String? targetUserAvatar;

  const ChatPage({
    super.key,
    required this.targetUserId,
    this.targetUserName,
    this.targetUserAvatar,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FoodService _foodService = FoodService();
  final MessageApiService _messageApiService = MessageApiService();
  WebSocketChatService? _ws;
  List<FoodRecord> _foodRecords = [];
  bool _isLoadingRecords = false;

  int get _currentUserId {
    final user = ref.watch(currentUserProvider);
    return user?.id ?? 0;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(messageHistoryProvider.notifier)
          .loadHistory(widget.targetUserId);
      _connectWebSocket();
    });
    _scrollController.addListener(_onScroll);
  }

  /// 建立 WebSocket 连接，实时接收对方消息
  void _connectWebSocket() {
    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) return;
    final ws = WebSocketChatService(
      onNewMessage: _handleNewMessage,
    );
    _ws?.disconnect();
    _ws = ws;
    ws.connect(currentUserId);
  }

  /// 收到对方实时消息：追加到列表并滚动到底部
  void _handleNewMessage(Message message) {
    if (!mounted) return;
    if (message.senderId == widget.targetUserId) {
      ref.read(messageHistoryProvider.notifier).appendMessage(message);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _ws?.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    // 不在 dispose 中调用 ref.read，避免 widget 已销毁后访问 provider
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 0) {
      ref.read(messageHistoryProvider.notifier).loadMore();
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(messageHistoryProvider.notifier).sendMessage(content);
    _messageController.clear();
    // 滚动到底部
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showPokeMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('戳一戳',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: const Text('提醒喝水'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(messageHistoryProvider.notifier).sendPoke('water');
              },
            ),
            ListTile(
              leading: const Icon(Icons.restaurant, color: Colors.orange),
              title: const Text('提醒吃饭'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(messageHistoryProvider.notifier).sendPoke('eat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.waving_hand, color: Colors.green),
              title: const Text('打个招呼'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(messageHistoryProvider.notifier).sendPoke('general');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('发送图片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('拍照'),
              onTap: () async {
                Navigator.pop(ctx);
                final pickedFile =
                    await picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  await _sendImageMessage(File(pickedFile.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('从相册选择'),
              onTap: () async {
                Navigator.pop(ctx);
                final pickedFile =
                    await picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  await _sendImageMessage(File(pickedFile.path));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImageMessage(File imageFile) async {
    // 显示加载对话框
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // 上传图片
      final uploadResponse =
          await _messageApiService.uploadImage(imageFile.path);

      if (!mounted) return;
      // 使用对话框的 context 关闭，避免 pop 掉聊天页本身
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }

      if (uploadResponse.success && uploadResponse.data != null) {
        final imageUrl = uploadResponse.data!;
        // 发送图片消息
        ref.read(messageHistoryProvider.notifier).sendMessage(
              imageUrl,
              messageType: 'image',
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('图片发送成功')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: ${uploadResponse.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (dialogContext != null && Navigator.canPop(dialogContext!)) {
        Navigator.pop(dialogContext!);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发送失败: $e')),
      );
    }
  }

  Future<void> _showFoodShareDialog() async {
    setState(() => _isLoadingRecords = true);

    // Load today's food records
    final today = DateTime.now();
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final response = await _foodService.getFoodRecordsByDay(todayString);

    if (mounted) {
      setState(() {
        _isLoadingRecords = false;
        if (response.success && response.data != null) {
          _foodRecords = response.data!;
        }
      });

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('分享食物记录',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (_foodRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child:
                      Text('今天还没有食物记录', style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _foodRecords.length,
                    itemBuilder: (context, index) {
                      final record = _foodRecords[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.restaurant,
                              color: AppColors.primary),
                        ),
                        title: Text(record.foodName ?? '未命名食物'),
                        subtitle: Text(
                            '${(record.nutritionDetail?.calories ?? 0).toStringAsFixed(0)} 千卡'),
                        trailing:
                            const Icon(Icons.send, color: AppColors.primary),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _shareFoodRecord(record);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _shareFoodRecord(FoodRecord record) async {
    final response = await _messageApiService.shareFoodRecord(
      receiverId: widget.targetUserId,
      foodRecordId: record.id,
    );

    if (mounted) {
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('食物记录已分享')),
        );
        // Reload message history
        ref
            .read(messageHistoryProvider.notifier)
            .loadHistory(widget.targetUserId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: ${response.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messageHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.targetUserAvatar != null)
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(widget.targetUserAvatar!),
              )
            else
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 16),
              ),
            const SizedBox(width: 12),
            Text(widget.targetUserName ?? '聊天'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showPokeMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const Center(
                        child:
                            Text('开始聊天吧', style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: false,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          return MessageBubble(
                            message: message,
                            isMe: message.senderId == _currentUserId,
                            currentUserId: _currentUserId,
                          );
                        },
                      ),
          ),
          // 输入框
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // 戳一戳按钮
                  IconButton(
                    icon: const Icon(Icons.touch_app, color: Colors.grey),
                    onPressed: _showPokeMenu,
                  ),
                  // 食物分享按钮
                  IconButton(
                    icon: const Icon(Icons.restaurant_menu, color: Colors.grey),
                    onPressed: _showFoodShareDialog,
                  ),
                  // 图片选择按钮
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.grey),
                    onPressed: _pickAndSendImage,
                  ),
                  // 输入框
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      maxLines: 4,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 发送按钮
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
