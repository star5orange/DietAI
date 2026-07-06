import 'dart:convert';
import '../core/services/api_service.dart';
import '../shared/domain/models/api_response.dart';

class ChatService {
  final ApiService _apiService = ApiService();

  /// 发送聊天消息并获取AI回复 (流式)
  Stream<ChatStreamEvent> sendMessageStream({
    required String message,
    int? sessionId,
    int sessionType = 1,
  }) async* {
    try {
      final requestData = {
        'message': message,
        'session_type': sessionType,
        if (sessionId != null) 'session_id': sessionId,
      };

      // 使用ApiService的流式方法
      await for (final chunk in _apiService.postStream('/chat/send-message-stream', data: requestData)) {
        if (chunk.trim().isEmpty) continue;
        
        // 解析SSE数据
        if (chunk.startsWith('data: ')) {
          final jsonStr = chunk.substring(6); // 移除 "data: " 前缀
          try {
            final Map<String, dynamic> data = json.decode(jsonStr);
            yield ChatStreamEvent.fromJson(data);
          } catch (e) {
            print('Error parsing SSE data: $e');
            continue;
          }
        }
      }
    } catch (e) {
      yield ChatStreamEvent(
        type: 'error',
        message: '发送消息失败: $e',
      );
    }
  }

  /// 发送聊天消息并获取AI回复 (兼容旧版API)
  Future<ApiResponse<ChatResponse>> sendMessage({
    required String message,
    int? sessionId,
    int sessionType = 1,
  }) async {
    try {
      final requestData = {
        'message': message,
        'session_type': sessionType,
        if (sessionId != null) 'session_id': sessionId,
      };

      final response = await _apiService.post(
        '/chat/send-message',
        data: requestData,
      );
      
      if (response.success && response.data != null) {
        final chatResponse = ChatResponse.fromJson(response.data);
        
        return ApiResponse<ChatResponse>.success(
          message: response.message.isNotEmpty ? response.message : '消息发送成功',
          data: chatResponse,
        );
      } else {
        return ApiResponse<ChatResponse>.failure(
          message: response.message.isNotEmpty ? response.message : '发送消息失败',
        );
      }
    } catch (e) {
      return ApiResponse<ChatResponse>.failure(
        message: '发送消息失败: $e',
      );
    }
  }

  /// 开始新的聊天会话
  Future<ApiResponse<ChatSession>> startSession({
    int sessionType = 1,
    String? title,
  }) async {
    try {
      final requestData = {
        'session_type': sessionType,
        if (title != null) 'title': title,
      };

      final response = await _apiService.post(
        '/chat/start-session',
        data: requestData,
      );
      
      if (response.success && response.data != null) {
        final session = ChatSession.fromJson(response.data);
        
        return ApiResponse<ChatSession>.success(
          message: response.message.isNotEmpty ? response.message : '会话创建成功',
          data: session,
        );
      } else {
        return ApiResponse<ChatSession>.failure(
          message: response.message.isNotEmpty ? response.message : '创建会话失败',
        );
      }
    } catch (e) {
      return ApiResponse<ChatSession>.failure(
        message: '创建会话失败: $e',
      );
    }
  }

  /// 获取用户的聊天会话列表
  Future<ApiResponse<List<ChatSessionSummary>>> getSessions({
    int? sessionType,
    String? keyword,
    String? startDate,
    String? endDate,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
        if (sessionType != null) 'session_type': sessionType,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      };

      final response = await _apiService.get(
        '/chat/sessions',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data is List 
          ? response.data 
          : [];
        final sessions = dataList.map((json) => ChatSessionSummary.fromJson(json)).toList();
        
        return ApiResponse<List<ChatSessionSummary>>.success(
          message: response.message.isNotEmpty ? response.message : '获取会话列表成功',
          data: sessions,
        );
      } else {
        return ApiResponse<List<ChatSessionSummary>>.failure(
          message: response.message.isNotEmpty ? response.message : '获取会话列表失败',
        );
      }
    } catch (e) {
      return ApiResponse<List<ChatSessionSummary>>.failure(
        message: '获取会话列表失败: $e',
      );
    }
  }

  /// 获取会话消息历史
  Future<ApiResponse<ChatSessionDetail>> getSessionMessages({
    required int sessionId,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };

      final response = await _apiService.get(
        '/chat/sessions/$sessionId/messages',
        queryParameters: queryParams,
      );
      
      if (response.success && response.data != null) {
        final sessionDetail = ChatSessionDetail.fromJson(response.data);
        
        return ApiResponse<ChatSessionDetail>.success(
          message: response.message.isNotEmpty ? response.message : '获取消息历史成功',
          data: sessionDetail,
        );
      } else {
        return ApiResponse<ChatSessionDetail>.failure(
          message: response.message.isNotEmpty ? response.message : '获取消息历史失败',
        );
      }
    } catch (e) {
      return ApiResponse<ChatSessionDetail>.failure(
        message: '获取消息历史失败: $e',
      );
    }
  }

  /// 获取会话上下文信息
  Future<ApiResponse<SessionContext>> getSessionContext({
    required int sessionId,
  }) async {
    try {
      final response = await _apiService.get('/chat/sessions/$sessionId/context');
      
      if (response.success && response.data != null) {
        final context = SessionContext.fromJson(response.data);
        
        return ApiResponse<SessionContext>.success(
          message: response.message.isNotEmpty ? response.message : '获取会话上下文成功',
          data: context,
        );
      } else {
        return ApiResponse<SessionContext>.failure(
          message: response.message.isNotEmpty ? response.message : '获取会话上下文失败',
        );
      }
    } catch (e) {
      return ApiResponse<SessionContext>.failure(
        message: '获取会话上下文失败: $e',
      );
    }
  }

  /// 删除聊天会话
  Future<ApiResponse<void>> deleteSession({
    required int sessionId,
  }) async {
    try {
      final response = await _apiService.delete('/chat/sessions/$sessionId');
      
      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '会话删除成功',
        );
      } else {
        return ApiResponse<void>.failure(
          message: response.message.isNotEmpty ? response.message : '删除会话失败',
        );
      }
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除会话失败: $e',
      );
    }
  }

  /// 删除当前用户的所有会话（可按类型筛选）
  Future<ApiResponse<void>> deleteAllSessions({
    int? sessionType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (sessionType != null) {
        queryParams['session_type'] = sessionType.toString();
      }
      final response = await _apiService.delete(
        '/chat/sessions',
        queryParameters: queryParams,
      );

      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '所有会话已删除',
        );
      } else {
        return ApiResponse<void>.failure(
          message: response.message.isNotEmpty ? response.message : '删除会话失败',
        );
      }
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除会话失败: $e',
      );
    }
  }

  /// 基于食物分析结果的聊天
  Future<ApiResponse<ChatResponse>> chatWithFoodAnalysis({
    required String message,
    required Map<String, dynamic> foodAnalysis,
    int? sessionId,
  }) async {
    try {
      final requestData = {
        'message': message,
        'food_analysis': foodAnalysis,
        if (sessionId != null) 'session_id': sessionId,
      };

      final response = await _apiService.post(
        '/analysis-chat/chat-with-analysis',
        data: requestData,
      );
      
      if (response.success && response.data != null) {
        final chatResponse = ChatResponse.fromJson(response.data);
        
        return ApiResponse<ChatResponse>.success(
          message: response.message.isNotEmpty ? response.message : '分析聊天成功',
          data: chatResponse,
        );
      } else {
        return ApiResponse<ChatResponse>.failure(
          message: response.message.isNotEmpty ? response.message : '分析聊天失败',
        );
      }
    } catch (e) {
      return ApiResponse<ChatResponse>.failure(
        message: '分析聊天失败: $e',
      );
    }
  }

  /// 获取会话类型名称
  String getSessionTypeName(int sessionType) {
    const sessionTypes = {
      1: '营养咨询',
      2: '健康评估',
      3: '食物识别',
      4: '运动建议',
    };
    return sessionTypes[sessionType] ?? '通用咨询';
  }
}

// 数据模型类
class ChatResponse {
  final int sessionId;
  final String? langgraphThreadId;
  final ChatMessage userMessage;
  final ChatMessage aiResponse;
  final List<String> suggestions;

  ChatResponse({
    required this.sessionId,
    this.langgraphThreadId,
    required this.userMessage,
    required this.aiResponse,
    required this.suggestions,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      sessionId: json['session_id'] ?? 0,
      langgraphThreadId: json['langgraph_thread_id'],
      userMessage: ChatMessage.fromJson(json['user_message'] ?? {}),
      aiResponse: ChatMessage.fromJson(json['ai_response'] ?? {}),
      suggestions: List<String>.from(json['suggestions'] ?? []),
    );
  }
}

class ChatMessage {
  final int id;
  final String content;
  final String createdAt;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.content,
    required this.createdAt,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      metadata: json['metadata'],
    );
  }
}

class ChatSession {
  final int sessionId;
  final String? langgraphThreadId;
  final int sessionType;
  final String title;
  final String createdAt;

  ChatSession({
    required this.sessionId,
    this.langgraphThreadId,
    required this.sessionType,
    required this.title,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      sessionId: json['session_id'] ?? 0,
      langgraphThreadId: json['langgraph_thread_id'],
      sessionType: json['session_type'] ?? 1,
      title: json['title'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ChatSessionSummary {
  final int id;
  final String title;
  final int sessionType;
  final String sessionTypeName;
  final String lastMessage;
  final String lastMessageTime;
  final int messageCount;

  ChatSessionSummary({
    required this.id,
    required this.title,
    required this.sessionType,
    required this.sessionTypeName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.messageCount,
  });

  factory ChatSessionSummary.fromJson(Map<String, dynamic> json) {
    return ChatSessionSummary(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      sessionType: json['session_type'] ?? 1,
      sessionTypeName: json['session_type_name'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] ?? '',
      messageCount: json['message_count'] ?? 0,
    );
  }
}

class ChatSessionDetail {
  final int sessionId;
  final String sessionTitle;
  final int sessionType;
  final List<ChatMessageDetail> messages;

  ChatSessionDetail({
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionType,
    required this.messages,
  });

  factory ChatSessionDetail.fromJson(Map<String, dynamic> json) {
    final messagesList = <ChatMessageDetail>[];
    if (json['messages'] != null) {
      messagesList.addAll(
        (json['messages'] as List).map((item) => ChatMessageDetail.fromJson(item))
      );
    }

    return ChatSessionDetail(
      sessionId: json['session_id'] ?? 0,
      sessionTitle: json['session_title'] ?? '',
      sessionType: json['session_type'] ?? 1,
      messages: messagesList,
    );
  }
}

class ChatMessageDetail {
  final int id;
  final String role; // 'user' or 'assistant'
  final String content;
  final String timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessageDetail({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessageDetail.fromJson(Map<String, dynamic> json) {
    return ChatMessageDetail(
      id: json['id'] ?? 0,
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] ?? '',
      metadata: json['metadata'],
    );
  }
}

class SessionContext {
  final int sessionId;
  final Map<String, dynamic> userContext;
  final List<Map<String, dynamic>> recentMeals;
  final Map<String, dynamic> healthGoals;
  final Map<String, dynamic>? cachedContext;

  SessionContext({
    required this.sessionId,
    required this.userContext,
    required this.recentMeals,
    required this.healthGoals,
    this.cachedContext,
  });

  factory SessionContext.fromJson(Map<String, dynamic> json) {
    return SessionContext(
      sessionId: json['session_id'] ?? 0,
      userContext: Map<String, dynamic>.from(json['user_context'] ?? {}),
      recentMeals: List<Map<String, dynamic>>.from(json['recent_meals'] ?? []),
      healthGoals: Map<String, dynamic>.from(json['health_goals'] ?? {}),
      cachedContext: json['cached_context'] != null 
        ? Map<String, dynamic>.from(json['cached_context']) 
        : null,
    );
  }
}

// 流式聊天事件数据模型
class ChatStreamEvent {
  final String type;
  final String? message;
  final String? content;
  final int? sessionId;
  final int? messageId;
  final Map<String, dynamic>? data;

  ChatStreamEvent({
    required this.type,
    this.message,
    this.content,
    this.sessionId,
    this.messageId,
    this.data,
  });

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      type: json['type'] ?? '',
      message: json['message'],
      content: json['content'],
      sessionId: json['session_id'] ?? json['data']?['session_id'],
      messageId: json['message_id'],
      data: json['data'],
    );
  }

  bool get isSession => type == 'session';
  bool get isStatus => type == 'status';
  bool get isContent => type == 'content';
  bool get isComplete => type == 'complete';
  bool get isError => type == 'error';
}