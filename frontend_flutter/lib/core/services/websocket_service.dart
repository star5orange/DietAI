import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import 'notification_service.dart';
import 'package:flutter/foundation.dart';

/// WebSocket 服务 - 实时消息推送
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  static final _storage = FlutterSecureStorage();

  /// 是否抑制新消息本地通知（聊天页/聊天列表页打开时置 true）
  static bool suppressNewMessageNotification = false;

  // 消息回调
  Function(Map<String, dynamic>)? onMessageReceived;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(int userId, bool isOnline)? onOnlineStatusChanged;

  bool get isConnected => _isConnected;

  /// 连接 WebSocket
  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('WebSocket: 未找到 token，无法连接');
        return;
      }

      final wsUrl = '${AppConstants.wsUrl}/api/messages/ws/$token';
      debugPrint('WebSocket: 尝试连接 $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _handleDisconnect();
        },
        onError: (error) {
          debugPrint('WebSocket 错误: $error');
          _handleDisconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _startHeartbeat();
      onConnected?.call();
      debugPrint('WebSocket: 连接成功');
    } catch (e) {
      debugPrint('WebSocket 连接失败: $e');
      _handleDisconnect();
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String);
      debugPrint('WebSocket 收到消息: $data');

      if (data is Map<String, dynamic>) {
        final type = data['type'];

        if (type == 'pong') {
          // 心跳响应，忽略
          return;
        }

        if (type == 'new_message' && data['data'] != null) {
          final msg = data['data'] as Map<String, dynamic>;
          // 本地通知兜底（FCM 未启用时）：不在聊天页时弹系统通知提示新消息
          if (!suppressNewMessageNotification) {
            _showLocalNotification(msg);
          }
          onMessageReceived?.call(msg);
        }

        if (type == 'online_status' && data['data'] != null) {
          final d = data['data'] as Map<String, dynamic>;
          final userId = d['user_id'];
          final isOnline = d['is_online'] == true;
          if (userId is int) {
            onOnlineStatusChanged?.call(userId, isOnline);
          } else if (userId is num) {
            onOnlineStatusChanged?.call(userId.toInt(), isOnline);
          }
        }
      }
    } catch (e) {
      debugPrint('WebSocket 消息解析失败: $e');
    }
  }

  /// 弹出新消息本地通知（按消息类型生成友好文案）
  void _showLocalNotification(Map<String, dynamic> msg) {
    final sender = msg['sender_username'] as String? ?? '好友';
    final type = msg['message_type'] as String? ?? 'text';
    final content = msg['content'] as String? ?? '';
    final body = switch (type) {
      'image' => '[图片] 给你发了一张照片',
      'food_card' => '[饮食记录] 分享了一条饮食记录',
      'poke' => content.isNotEmpty ? content : '戳了戳你',
      'emoji' => content.isNotEmpty ? content : '发来一个表情',
      _ => content.isNotEmpty ? content : '发来一条消息',
    };
    NotificationService().showImmediateNotification(
      id: (msg['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      title: '$sender 发来新消息',
      body: body,
    );
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _isConnected = false;
    _stopHeartbeat();
    onDisconnected?.call();
    debugPrint('WebSocket: 连接断开');

    // 尝试重连
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      debugPrint(
          'WebSocket: ${_reconnectDelay.inSeconds}秒后尝试重连 ($_reconnectAttempts/$_maxReconnectAttempts)');
      _reconnectTimer = Timer(_reconnectDelay, () {
        connect();
      });
    } else {
      debugPrint('WebSocket: 达到最大重连次数，停止重连');
    }
  }

  /// 开始心跳
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
        debugPrint('WebSocket: 发送心跳');
      }
    });
  }

  /// 停止心跳
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 发送消息
  void send(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      debugPrint('WebSocket: 未连接，无法发送消息');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
      debugPrint('WebSocket: 发送消息 $message');
    } catch (e) {
      debugPrint('WebSocket 发送失败: $e');
    }
  }

  /// 断开连接
  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = _maxReconnectAttempts; // 阻止自动重连

    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    debugPrint('WebSocket: 主动断开连接');
  }

  /// 重置重连计数（用于手动重连）
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }
}
