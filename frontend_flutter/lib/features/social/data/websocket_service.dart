import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_config.dart';
import '../../../core/services/api_service.dart';
import '../domain/message_models.dart';

/// WebSocket 聊天服务
/// 用于实时接收和发送消息
class WebSocketChatService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final ApiService _apiService = ApiService();

  /// 收到新消息的回调
  final ValueChanged<Message> onNewMessage;

  /// 收到对方输入状态的回调
  final ValueChanged<int>? onUserTyping;

  /// 连接状态变化回调
  final ValueChanged<bool>? onConnectionChanged;

  bool _isConnected = false;
  int? _currentUserId;
  Timer? _pingTimer;

  WebSocketChatService({
    required this.onNewMessage,
    this.onUserTyping,
    this.onConnectionChanged,
  });

  /// 是否已连接
  bool get isConnected => _isConnected;

  /// 连接到 WebSocket 服务器
  Future<void> connect(int userId) async {
    if (_isConnected) {
      print('⚠️ WebSocket 已连接，跳过重复连接');
      return;
    }

    try {
      _currentUserId = userId;

      // 获取 token
      final token = await _apiService.getAccessToken();
      if (token == null) {
        print(' WebSocket 连接失败：没有 access token');
        return;
      }

      // 构建 WebSocket URL
      final baseUrl = ApiConfig.effectiveBaseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final wsUrl = '$baseUrl/api/messages/ws/$token';

      print('🔌 正在连接 WebSocket: $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // 启动心跳
      _startPing();

      _isConnected = true;
      onConnectionChanged?.call(true);
      print('✅ WebSocket 连接成功');
    } catch (e) {
      print('❌ WebSocket 连接失败: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _stopPing();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnected = false;
    _currentUserId = null;
    onConnectionChanged?.call(false);
    print('🔌 WebSocket 已断开');
  }

  /// 通过 WebSocket 发送消息
  Future<bool> sendMessage(int receiverId, String content,
      {String messageType = 'text'}) async {
    if (!_isConnected || _channel == null) {
      print('⚠️ WebSocket 未连接，无法发送消息');
      return false;
    }

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'send_message',
        'receiver_id': receiverId,
        'content': content,
        'message_type': messageType,
      }));
      return true;
    } catch (e) {
      print(' WebSocket 发送消息失败: $e');
      return false;
    }
  }

  /// 发送输入状态
  void sendTyping(int receiverId) {
    if (!_isConnected || _channel == null) return;

    _channel!.sink.add(jsonEncode({
      'type': 'typing',
      'receiver_id': receiverId,
    }));
  }

  /// 处理收到的消息
  void _onMessage(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'new_message':
          // 对方发来的新消息
          final msgData = data['data'] as Map<String, dynamic>;
          final message = Message.fromJson(msgData);
          onNewMessage(message);
          print(' 收到新消息: ${message.content}');
          break;

        case 'message_sent':
          // 自己发送的消息确认（包含服务端分配的 ID）
          final msgData = data['data'] as Map<String, dynamic>;
          final message = Message.fromJson(msgData);
          onNewMessage(message);
          print('✅ 消息发送确认: ${message.content}');
          break;

        case 'user_typing':
          // 对方正在输入
          final userId = data['data']?['user_id'] as int?;
          if (userId != null) {
            onUserTyping?.call(userId);
          }
          break;

        case 'pong':
          // 心跳响应，无需处理
          break;

        case 'error':
          print('❌ WebSocket 错误: ${data['message']}');
          break;

        default:
          print('⚠️ 未知 WebSocket 消息类型: $type');
      }
    } catch (e) {
      print('❌ 解析 WebSocket 消息失败: $e');
    }
  }

  void _onError(dynamic error) {
    print('❌ WebSocket 错误: $error');
    _isConnected = false;
    onConnectionChanged?.call(false);
  }

  void _onDone() {
    print('🔌 WebSocket 连接关闭');
    _isConnected = false;
    onConnectionChanged?.call(false);
  }

  /// 启动心跳
  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
}
