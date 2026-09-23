import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../../services/chat_service.dart';
import '../../../../services/food_service.dart';
import '../../../../core/constants/app_constants.dart';
import 'chat_history_page.dart';
import '../../../advisor/presentation/pages/advisor_style_page.dart';
import '../../../advisor/data/services/advisor_service.dart';
import '../../../camera/presentation/widgets/camera_source_sheet.dart';
import '../../../pet/data/real_pet_api_service.dart';
import '../../../camera/presentation/pages/camera_page.dart';
import '../../../../core/services/api_service.dart';

/// 页面 → 对话携带的上下文（PRD 4.8）。
///
/// 从页面进入对话时不再是"空白开聊"：带上"当前正在看什么"，
/// Agent 首轮即可直接对当前对象执行动作（如「这条记错了，改成 200 克」）。
class ChatPageContext {
  /// 上下文类型（food_record / pet …），决定横幅图标
  final String type;

  /// 横幅展示文案，如「宫保鸡丁 · 午餐 · 2026-09-13」
  final String title;

  /// 随首条消息注入给模型的上下文描述
  final String hint;

  const ChatPageContext({
    required this.type,
    required this.title,
    required this.hint,
  });
}

class ChatPage extends ConsumerStatefulWidget {
  final int? sessionId;
  final int sessionType;
  final String? title;
  final bool hideAppBar;
  final int? petId; // 宠物ID（session_type=6时必填）

  /// 是否走 DietDeepAgent 统一对话内核（支持动作卡片、撤销等写操作）；
  /// 图片分析追问、宠物等场景暂走原咨询链路。
  final bool useDeepAgent;

  /// 作为 App 首页主入口（PRD D15）：不显示返回箭头，并显示「数据看板」入口
  final bool isHomeEntry;

  /// 页面 → 对话携带的上下文（PRD 4.8）：明示当前对象，并随首条消息交给 Agent
  final ChatPageContext? pageContext;

  const ChatPage({
    super.key,
    this.sessionId,
    this.sessionType = 1,
    this.title,
    this.hideAppBar = false,
    this.petId,
    this.useDeepAgent = true,
    this.isHomeEntry = false,
    this.pageContext,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int? _currentSessionId;
  List<ChatMessageDetail> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  String _currentStyleName = '获取中...';

  /// 当前上下文域（PRD D18）：默认「人的饮食对话」，可一键切到宠物模式。
  /// 切换后走独立的 session_type（1=人 / 6=宠物），数据与人/家人对话不混用。
  late int _sessionType = widget.sessionType;
  late int? _petId = widget.petId;
  String? _petName;
  bool _switchingMode = false;

  /// 页面上下文（PRD 4.8）：只在本次进入对话的首条消息注入一次
  late bool _contextPending = widget.pageContext != null;
  bool _contextDismissed = false;

  /// AI 消息附带的动作卡片（key = 界面消息 id），PRD 4.8 记录结果卡
  final Map<int, List<_ActionCardState>> _cardsByMessageId = {};

  /// 正在流式输出的 AI 占位消息 id：仅它显示「正在思考中」。
  /// 纯卡片轮（文字被吞）与历史空内容消息完成后不再卡在思考态。
  int? _activeAiMessageId;

  /// 重试治理（PRD 4.6）：点重试后原轮标注「已重试」并停止应答，
  /// 原轮旧卡片隐藏——直达卡片只在重试产生的新一轮出现一次。
  final Set<int> _retriedUserIds = {};
  final Set<int> _suppressedCardMsgIds = {};

  // ---------- 语音输入（PRD 4.9：App 语音复用现有 ASR 链路） ----------
  final FoodService _foodService = FoodService();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isRecognizingVoice = false;
  Timer? _voiceTimer;
  int _voiceSeconds = 0;

  final Map<String, String> _styleLabels = {
    'nutritionist': '营养师',
    'fitness_coach': '健身教练',
    'tcm_healer': '中医养生师',
    'encouraging_friend': '鼓励型伙伴',
  };

  final Map<String, String> _petStyleLabels = {
    'vet_assistant': '兽医助理',
    'pet_nutritionist': '宠物营养师',
    'pet_caregiver': '贴心宠管',
  };

  @override
  void initState() {
    super.initState();
    _currentSessionId = widget.sessionId;
    _initializeChat();
    _loadAdvisorStyle();
  }

  Future<void> _loadAdvisorStyle() async {
    try {
      final advisorService = AdvisorService(ApiService());
      final settings = await advisorService.getSettings();
      final isPet = _sessionType == 6;
      if (mounted) {
        setState(() {
          if (isPet) {
            _currentStyleName =
                _petStyleLabels[settings.petAdvisorStyle] ?? '兽医助理';
          } else {
            _currentStyleName = _styleLabels[settings.advisorStyle] ?? '营养师';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentStyleName = _sessionType == 6 ? '兽医助理' : '营养师');
      }
    }
  }

  Widget _buildStyleChip() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdvisorStylePage(sessionType: _sessionType),
          ),
        );
        _loadAdvisorStyle();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2BAF74).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2BAF74).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.tune,
              size: 10,
              color: Color(0xFF2BAF74),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _currentStyleName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2BAF74),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    _voiceTimer?.cancel();
    _voiceRecorder.dispose();
    super.dispose();
  }

  // ---------- 语音输入（PRD 4.9） ----------

  Future<void> _toggleVoiceInput() async {
    if (_isRecognizingVoice) return;
    if (_isRecording) {
      await _stopVoiceInput();
    } else {
      await _startVoiceInput();
    }
  }

  Future<void> _startVoiceInput() async {
    try {
      if (!await Permission.microphone.isGranted) {
        final result = await Permission.microphone.request();
        if (!result.isGranted) {
          _showSnackBar('需要麦克风权限才能语音输入');
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}${Platform.pathSeparator}chat_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _voiceRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _voiceSeconds = 0;
      });
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _voiceSeconds++);
      });
    } catch (e) {
      _showSnackBar('录音失败: $e');
    }
  }

  Future<void> _stopVoiceInput() async {
    try {
      _voiceTimer?.cancel();
      final path = await _voiceRecorder.stop();

      setState(() {
        _isRecording = false;
        _isRecognizingVoice = true;
      });

      if (path == null || !await File(path).exists()) {
        setState(() => _isRecognizingVoice = false);
        _showSnackBar('录音保存失败，请重试');
        return;
      }

      final result = await _foodService.recognizeVoice(File(path));
      final text =
          result.success ? (result.data?['text'] as String? ?? '') : '';

      if (!mounted) return;
      setState(() => _isRecognizingVoice = false);

      if (text.isEmpty) {
        _showSnackBar(
          result.message.isNotEmpty ? result.message : '没听清，请再说一次',
        );
        return;
      }

      // 识别结果回填输入框，用户可编辑后发送（结果可见、可纠错）
      _messageController.text = text;
      _messageController.selection =
          TextSelection.fromPosition(TextPosition(offset: text.length));
      _inputFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isRecognizingVoice = false;
      });
      _showSnackBar('语音识别失败: $e');
    }
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
        sessionType: _sessionType,
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
          _restoreCardsFromHistory(_messages);
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

  /// 历史消息回显动作卡片：卡片存在 AI 消息 metadata.cards 里（PRD 4.8），
  /// 重进会话时恢复卡片，撤销入口按 undo_deadline 自动决定是否可点。
  void _restoreCardsFromHistory(List<ChatMessageDetail> messages) {
    _cardsByMessageId.clear();
    for (final message in messages) {
      if (message.role != 'assistant') continue;
      final cards = message.metadata?['cards'];
      if (cards is! List || cards.isEmpty) continue;
      final restored = <_ActionCardState>[];
      for (final item in cards) {
        if (item is Map) {
          restored.add(_ActionCardState(Map<String, dynamic>.from(item)));
        }
      }
      if (restored.isNotEmpty) {
        _cardsByMessageId[message.id] = restored;
      }
    }
  }

  /// 撤销结果卡到达时调用：撤销对象是「最近一条」写操作，
  /// 因此只把最后一张记录卡置为已撤销（更早的卡片不受影响）。
  void _markLatestRecordCardUndone() {
    _ActionCardState? latest;
    for (final cards in _cardsByMessageId.values) {
      for (final card in cards) {
        // 只认记录结果卡（待确认卡虽然 action 同名，但并没有落库）
        if (card.cardType == 'record_result' &&
            card.action.startsWith('record_')) {
          latest = card;
        }
      }
    }
    latest?.undone = true;
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    _messageController.clear();
    await _sendText(message);
  }

  // ---------- 拍照记录（PRD 4.9）：对话内快捷入口，复用相机页 AI 图像分析链路 ----------
  //
  // 体检报告上传为低频操作，不常驻对话栏：入口在「体检」页（自带 5.4 隐私提醒
  // 与 AI 分析开关），对话内由 Agent 按话题引导前往（见 registry 提示词）。
  Future<void> _openCameraRecord() async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    // 先弹「拍照目的 + 来源」选择，不直接进取景器：
    // 拍照不一定记录食物——也可能拍包装食品的营养成分表（OCR），按目的分流
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => CameraSourceSheet(
        onSelect: (s) => Navigator.pop(ctx, s),
      ),
    );
    if (!mounted || source == null) return;
    // 弹窗已选定目的（餐食/包装），取景器内锁定模式不再显示切换选项
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CameraPage(
          recordDate: today,
          autoPickGallery: CameraSheetSource.useGallery(source),
          initialLabelMode: CameraSheetSource.isLabel(source),
          allowModeSwitch: false,
        ),
      ),
    );
  }

  /// 发送一条文本并走流式链路（输入框与卡片快捷选项共用）
  Future<void> _sendText(String message) async {
    if (message.isEmpty || _isSending) return;

    // 页面上下文（PRD 4.8）：首条消息附带"当前正在看什么"，界面只展示用户原话
    final ctx = widget.pageContext;
    final outgoing = (_contextPending && !_contextDismissed && ctx != null)
        ? '【当前页面上下文】${ctx.hint}\n\n$message'
        : message;
    _contextPending = false;

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

    // AI 占位消息 id 提到 try 外：catch 分支也要复用它更新占位内容
    final aiMessageId = DateTime.now().millisecondsSinceEpoch + 1;
    try {
      String aiContent = '';

      // 添加AI消息占位符
      setState(() {
        _messages.add(ChatMessageDetail(
          id: aiMessageId,
          role: 'assistant',
          content: '',
          timestamp: DateTime.now().toIso8601String(),
        ));
        _activeAiMessageId = aiMessageId;
      });

      // 使用流式API
      await for (final event in _chatService.sendMessageStream(
        message: outgoing,
        sessionId: _currentSessionId,
        sessionType: _sessionType,
        petId: _petId,
        useDeepAgent: widget.useDeepAgent,
      )) {
        if (event.isSession && event.sessionId != null) {
          // 更新会话ID
          setState(() {
            _currentSessionId = event.sessionId;
          });
        } else if (event.isCard && event.card != null) {
          // 动作结果卡片（记录结果卡，PRD 4.8）
          setState(() {
            final card = _ActionCardState(event.card!);
            _cardsByMessageId.putIfAbsent(aiMessageId, () => []).add(card);
            // 撤销结果卡：把最近一张记录卡同步置为已撤销（撤销对象即最近一条）
            if (card.action == 'undo') _markLatestRecordCardUndone();
          });
          _scrollToBottom();
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
            _activeAiMessageId = null;
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
            _activeAiMessageId = null;
          });
          break;
        }
      }

      // 服务端断流兜底：没等到完成/错误事件也终结思考态，
      // 避免占位气泡永远卡在「正在思考中」
      if (_activeAiMessageId == aiMessageId) {
        setState(() {
          _isSending = false;
          _activeAiMessageId = null;
        });
      }
    } catch (e) {
      setState(() {
        // 复用占位消息展示错误，不追加新消息（避免残留空白思考气泡）
        final index = _messages.indexWhere((m) => m.id == aiMessageId);
        if (index != -1) {
          _messages[index] = ChatMessageDetail(
            id: aiMessageId,
            role: 'assistant',
            content: '发送消息时出现错误，请检查网络连接后重试。',
            timestamp: DateTime.now().toIso8601String(),
          );
        }
        _isSending = false;
        _activeAiMessageId = null;
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
    final body = Column(
      children: [
        Expanded(
          child: _buildMessageList(),
        ),
        _buildContextBanner(),
        _buildInputArea(),
      ],
    );

    if (widget.hideAppBar) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        body: body,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title ??
                  (_sessionType == 6
                      ? '宠物健康对话'
                      : widget.isHomeEntry
                          ? 'AI 饮食助手' // 首页主入口显示产品级标题，而非单一会话类型名（D15）
                          : _chatService.getSessionTypeName(_sessionType)),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 2),
            _buildStyleChip(),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        // 首页主入口不给返回箭头（PRD D15）
        leading: widget.isHomeEntry
            ? null
            : IconButton(
                icon:
                    const Icon(Icons.arrow_back_ios, color: Color(0xFF222222)),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: false,
        actions: [
          // 数据看板：页面层入口保留在页面层，可切换访问（PRD D15）
          // go 平级切换，与看板页右上角「回对话」(go('/')) 完全对称
          if (widget.isHomeEntry)
            IconButton(
              icon: const Icon(
                Icons.grid_view_rounded,
                size: 22,
                color: Color(0xFF2BAF74),
              ),
              tooltip: '数据看板',
              onPressed: () => context.go('/dashboard'),
            ),
          // 人 ↔ 宠物 模式切换（PRD 4.8 / D18）
          IconButton(
            icon: Icon(
              _sessionType == 6 ? Icons.person_outline : Icons.pets_outlined,
              size: 22,
              color: const Color(0xFF2BAF74),
            ),
            tooltip: _sessionType == 6 ? '切换到人的饮食对话' : '切换到宠物模式',
            onPressed: _switchingMode ? null : _toggleAgentMode,
          ),
          IconButton(
            icon: const Icon(
              Icons.history,
              size: 24,
              color: Color(0xFF2BAF74),
            ),
            tooltip: '历史记录',
            onPressed: () => _navigateToChatHistory(),
          ),
          // 会话信息收进溢出菜单，降低 AppBar 密度
          if (_currentSessionId != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 22,
                color: Color(0xFF2BAF74),
              ),
              tooltip: '更多',
              onSelected: (value) {
                if (value == 'session_info') _showSessionInfo();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'session_info',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Color(0xFF2BAF74)),
                      SizedBox(width: 8),
                      Text('会话信息'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: body,
    );
  }

  /// 人 ↔ 宠物上下文域切换（PRD D18）：切换即换 session_type 并重开会话，
  /// 数据/人设/能力集隔离，不与人/家人数据混用。
  Future<void> _toggleAgentMode() async {
    if (_sessionType != 6) {
      final pet = await _pickPetForMode();
      if (pet == null) return;
      setState(() {
        _switchingMode = true;
        _sessionType = 6;
        _petId = (pet['id'] as num?)?.toInt();
        _petName = (pet['name'] ?? '').toString();
      });
    } else {
      setState(() {
        _switchingMode = true;
        _sessionType = widget.sessionType == 6 ? 1 : widget.sessionType;
        _petId = null;
        _petName = null;
      });
    }
    // 换上下文域必须换会话：清空当前会话与卡片，重新建会话
    setState(() {
      _messages = [];
      _cardsByMessageId.clear();
      _currentSessionId = null;
      // 页面上下文属于原上下文域（如人的饮食记录），换域后不得再注入（PRD 4.8 / D18）
      _contextPending = false;
      _contextDismissed = true;
    });
    await _createNewSession();
    await _loadAdvisorStyle();
    if (mounted) {
      setState(() => _switchingMode = false);
      _showSnackBar(_sessionType == 6
          ? '已切换到宠物模式${_petName == null ? '' : '（$_petName）'}'
          : '已切换到人的饮食对话');
    }
  }

  /// 选一只宠物进入宠物模式：无宠物则提示去添加，多只让用户选
  Future<Map<String, dynamic>?> _pickPetForMode() async {
    List<Map<String, dynamic>> pets = [];
    try {
      final result = await RealPetApiService().getPets();
      if (result.success && result.data != null) {
        pets = List<Map<String, dynamic>>.from(result.data!['pets'] ?? []);
      }
    } catch (_) {
      pets = [];
    }
    if (!mounted) return null;
    if (pets.isEmpty) {
      _showSnackBar('还没有添加宠物，请先到「我的 → 我的宠物」添加');
      return null;
    }
    if (pets.length == 1) return pets.first;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择要聊的宠物',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            for (final pet in pets)
              ListTile(
                leading: const Icon(Icons.pets, color: Color(0xFF2BAF74)),
                title: Text((pet['name'] ?? '未命名').toString()),
                subtitle: Text((pet['species'] ?? '').toString()),
                onTap: () => Navigator.of(ctx).pop(pet),
              ),
          ],
        ),
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
      return SingleChildScrollView(child: _buildWelcomeMessage());
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        // 部分失败可重试（PRD 4.6）：仅最近一条用户消息提供重试入口；
        // 已重试过的原轮不再提供（避免连环重试产生多张重复卡片）
        final isLastUserMessage = message.role == 'user' &&
            index == _messages.lastIndexWhere((m) => m.role == 'user') &&
            !_isSending &&
            !_retriedUserIds.contains(message.id);
        return _buildMessageBubble(message, allowRetry: isLastUserMessage);
      },
    );
  }

  Widget _buildWelcomeMessage() {
    String welcomeText;
    IconData welcomeIcon;
    switch (_sessionType) {
      case 1:
        // 首页主入口：按时段问候 + 一句话点明能力（与标题「AI 饮食助手」呼应）
        welcomeText = '${_dayGreeting()}！我是 AI 饮食助手。'
            '吃了什么告诉我或点相机拍一拍，我帮你记录；'
            '查今天吃了多少、看趋势出周报，随时开口。';
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
      case 5:
        welcomeText = '欢迎来到养生咨询！我可以根据您的体质和当前节气，为您提供个性化的养生调理建议。';
        welcomeIcon = Icons.spa;
        break;
      case 6:
        welcomeText = '您好！我是您的宠物健康顾问，可以帮您分析宠物的饮食、体重、疫苗等健康数据。请告诉我您的宠物情况吧！';
        welcomeIcon = Icons.pets;
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

  /// 时段问候语（与后端/相机页的餐次口径一致：5-10 早、10-15 午、15-17 下午、17-21 晚、其余夜深）
  String _dayGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) return '早上好';
    if (hour >= 11 && hour < 14) return '中午好';
    if (hour >= 14 && hour < 18) return '下午好';
    if (hour >= 18 && hour < 23) return '晚上好';
    return '夜深了';
  }

  Widget _buildQuickActions() {
    List<String> suggestions;
    switch (_sessionType) {
      case 1:
        // V5 动作向导（PRD 1.2「聊天能办事」）：第一条记录示范按当前餐次动态生成
        // （餐次口径与后端 record_food._infer_meal_type 一致）；不引导 V6 三期动作
        suggestions = [
          _mealTimeRecordExample(),
          '我今天吃了多少',
          '给我出一份饮食周报',
        ];
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
      case 5:
        suggestions = ['我是什么体质？', '当前节气如何养生？', '推荐适合我的药膳茶饮'];
        break;
      case 6:
        suggestions = ['我家猫的饮食健康吗？', '宠物体重管理建议', '宠物疫苗接种计划', '推荐适合的宠物食品'];
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

  /// 按当前时段生成一句话记录示范（餐次口径与后端 record_food._infer_meal_type 一致：
  /// 5-10 早、10-15 午、15-17 加、17-21 晚、其余夜宵）
  String _mealTimeRecordExample() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) return '帮我记录：早餐吃了一个包子和一杯豆浆';
    if (hour >= 10 && hour < 15) return '帮我记录：午饭吃了宫保鸡丁';
    if (hour >= 15 && hour < 17) return '帮我记录：下午喝了一杯奶茶';
    if (hour >= 17 && hour < 21) return '帮我记录：晚饭吃了红烧肉';
    return '帮我记录：夜宵吃了一碗泡面';
  }

  Widget _buildMessageBubble(
    ChatMessageDetail message, {
    bool allowRetry = false,
  }) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI 气泡仅在有文字或本轮流式输出中时渲染；
                // 纯卡片轮（文字被吞）与历史空消息收起气泡，只留卡片
                if (isUser ||
                    message.content.isNotEmpty ||
                    _activeAiMessageId == message.id)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                        // 仅本轮流式输出中的占位显示思考态（历史空消息/纯卡片轮不显示）
                        if (!isUser &&
                            message.content.isEmpty &&
                            _activeAiMessageId == message.id)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '正在思考中',
                                style: TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
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
                              color: isUser
                                  ? Colors.white
                                  : const Color(0xFF222222),
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
                // 动作结果卡片（记录结果卡：撤销 + 跳转饮食记录页）
                if (!isUser) _buildActionCards(message.id),
                // 部分失败可重试（PRD 4.6）：重发这条用户消息；
                // 点过重试的原轮改标「已重试」并停用入口
                if (isUser && _retriedUserIds.contains(message.id))
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 14, color: Color(0xFF999999)),
                        SizedBox(width: 2),
                        Text('已重试',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF999999))),
                      ],
                    ),
                  ),
                if (isUser && allowRetry)
                  _buildRetryEntry(message.content, message.id),
              ],
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

  /// 重试入口（PRD 4.6：多动作批量执行时失败项需可重试）
  ///
  /// 只对"最近一条用户消息"展示：点一下即重发同一句，动作链路会重新解析执行；
  /// 已成功的项不会重复写入（写操作按内容重新走确认/撤销规则）。
  Widget _buildRetryEntry(String content, int messageId) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 4),
        child: InkWell(
          onTap: _isSending ? null : () => _retryMessage(messageId, content),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF999999)),
                SizedBox(width: 2),
                Text(
                  '重试',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 重试（PRD 4.6）：原轮停止应答并标注「已重试」，原轮旧卡片隐藏——
  /// 直达卡片只在重试产生的新一轮出现一次
  void _retryMessage(int messageId, String content) {
    setState(() {
      _retriedUserIds.add(messageId);
      // 原轮 AI 消息 = 紧随其后的 assistant 消息，其卡片一并隐藏
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1 && idx + 1 < _messages.length) {
        final next = _messages[idx + 1];
        if (next.role == 'assistant') _suppressedCardMsgIds.add(next.id);
      }
    });
    _sendText(content);
  }

  /// 页面上下文横幅（PRD 4.8）：明示"本次对话已带上当前内容"，
  /// 关闭即表示不带入（首条消息不再注入上下文）。
  Widget _buildContextBanner() {
    final ctx = widget.pageContext;
    if (ctx == null || _contextDismissed) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2BAF74).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2BAF74).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ctx.type == 'pet' ? Icons.pets_outlined : Icons.link,
            size: 16,
            color: const Color(0xFF2BAF74),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '已带入当前内容',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2BAF74),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ctx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: '不带入该内容',
            onPressed: () => setState(() => _contextDismissed = true),
          ),
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
                  focusNode: _inputFocusNode,
                  decoration: InputDecoration(
                    hintText: _isRecording
                        ? '正在录音 ${_voiceSeconds}s，点右侧红色按钮停止并识别'
                        : '输入消息...',
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
            const SizedBox(width: 8),
            // 拍照记录（PRD 4.9）：高频动作单击直达相机页（AI 图像分析，营养自动补齐落库）。
            // 体检报告为低频操作，不常驻对话栏——由体检页上传入口与 Agent 引导承接（5.4）。
            // 仅人的对话域显示（D18/D3）：宠物模式无宠物图像链路，且不能把记录落进人的数据域
            if (_sessionType != 6)
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7F6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: '拍照记录',
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF2BAF74),
                    size: 20,
                  ),
                  onPressed: _openCameraRecord,
                ),
              ),
            const SizedBox(width: 8),
            // 语音输入（PRD 4.9）：录音中变红，识别中转圈
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isRecording
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFF5F7F6),
                shape: BoxShape.circle,
              ),
              child: _isRecognizingVoice
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2BAF74),
                      ),
                    )
                  : IconButton(
                      tooltip: _isRecording ? '停止并识别' : '语音输入',
                      icon: Icon(
                        _isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_none_rounded,
                        color: _isRecording
                            ? const Color(0xFFE53935)
                            : const Color(0xFF2BAF74),
                        size: 20,
                      ),
                      onPressed: _toggleVoiceInput,
                    ),
            ),
            const SizedBox(width: 8),
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

  /// 动作结果卡片列表（记录结果卡挂载在 AI 消息下方）
  Widget _buildActionCards(int messageId) {
    // 被重试替代的原轮：卡片不再展示（直达卡片只在最新一轮出现一次）
    if (_suppressedCardMsgIds.contains(messageId)) {
      return const SizedBox.shrink();
    }
    final cards = _cardsByMessageId[messageId];
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildActionCard(card),
          ),
      ],
    );
  }

  /// 记录结果卡（PRD 4.8：刚记录项 + 撤销 + 查看今日饮食）
  Widget _buildActionCard(_ActionCardState card) {
    // 按卡片类型分派（PRD 4.8 卡片类型与跳转映射）
    switch (card.cardType) {
      // 待确认卡（PRD 4.3）：模糊量词追问 + 快捷选项，就地回答、不跳转
      case 'pending_confirm':
        return _buildPendingConfirmCard(card);
      case 'daily_summary':
        return _buildDailySummaryCard(card);
      case 'family_status':
        return _buildFamilyStatusCard(card);
      case 'trend':
        return _buildTrendCard(card);
      case 'weekly_report':
        return _buildWeeklyReportCard(card);
      case 'exam_metric':
        return _buildExamMetricCard(card);
      case 'cost':
        return _buildCostCard(card);
      case 'action_confirm':
        if (card.action == 'open_page') return _buildPageGuideCard(card);
        return _buildActionConfirmCard(card);
    }
    final data = card.data;
    final isUndoResult = card.action == 'undo';
    final source = isUndoResult && data['undone'] is Map
        ? Map<String, dynamic>.from(data['undone'] as Map)
        : data;

    final foodName = _cardTitle(source);
    final mealLabel = (source['meal_type_label'] ?? '').toString();
    final undone = card.undone || isUndoResult;
    final accent = undone ? const Color(0xFF9E9E9E) : const Color(0xFF2BAF74);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(
                  undone ? Icons.undo : Icons.check_circle_outline,
                  size: 15,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  undone
                      ? '已撤销${mealLabel.isEmpty ? '' : ' · $mealLabel'}'
                      : '已记录${mealLabel.isEmpty ? '' : ' · $mealLabel'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foodName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF222222),
                    decoration: undone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _cardDetailLine(source, isUndoResult),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    card.footerHint(undone),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
                if (!undone && card.canUndo)
                  TextButton(
                    onPressed: card.undoing ? null : () => _undoCard(card),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      foregroundColor: const Color(0xFFE74C3C),
                    ),
                    child: card.undoing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('撤销', style: TextStyle(fontSize: 13)),
                  ),
                TextButton(
                  onPressed: () => _openRecordCardEntry(card, source),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    foregroundColor: const Color(0xFF2BAF74),
                  ),
                  child: Text(
                    _recordCardEntryLabel(card),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 查询类卡片（PRD 4.8） ====================

  /// 查询类卡片统一外壳：结论 + 关键数字 + 「下一步入口」
  Widget _cardShell({
    required Color accent,
    required IconData icon,
    required String title,
    List<Widget> body = const [],
    List<Widget> actions = const [],
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: body,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 卡片「下一步入口」按钮（PRD 4.8：一键跳转并携带上下文）
  Widget _jumpButton(String label, VoidCallback onTap, {Color? color}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: color ?? const Color(0xFF2BAF74),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
    );
  }

  /// 卡片跳转（PRD 4.8）：按后端 jump.page 定位页面，并携带上下文
  void _openCardJump(
    Map<String, dynamic>? jump, {
    int? memberId,
    String? memberName,
  }) {
    final page = (jump?['page'] ?? '').toString();
    final date = (jump?['date'] ?? '').toString();
    switch (page) {
      case 'history':
      case 'diet_records':
        context.push(
          date.isEmpty
              ? AppConstants.historyRoute
              : '${AppConstants.historyRoute}?date=$date',
        );
        break;
      case 'weight_trend':
        context.push('/weight-trend');
        break;
      case 'family_health':
        if (memberId != null) {
          context.push(
            '/social/family-health/$memberId',
            extra: {'name': memberName},
          );
        } else {
          context.push('/family-dashboard');
        }
        break;
      case 'weekly_report':
        context.push('/family/weekly-report');
        break;
      case 'cost':
        // 成本卡：查看明细 → 花销统计页（PRD 4.8）
        context.push('/cost-statistics');
        break;
      case 'reminder':
        // 操作确认卡：管理提醒 → 提醒设置页（PRD 4.8）
        context.push('/reminder-settings');
        break;
      case 'exam_report':
        // 体检指标卡：查看报告 → 体检报告详情页（PRD 4.8）
        final reportId = _asNum(jump?['report_id'])?.toInt();
        if (reportId != null) {
          context.push('/exam/detail/$reportId');
        } else {
          context.push('/exam/reports');
        }
        break;
      case 'exam_reports':
        context.push('/exam/reports');
        break;
      case 'exam_upload':
        // 页面引导卡（open_page）：上传体检报告（页面自带 5.4 隐私提醒）
        context.push('/exam/upload');
        break;
      default:
        // 今日汇总卡 / 营养与体检概览卡：查看详情 → 健康分析页（PRD 4.8）
        context.push(AppConstants.healthRoute);
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  num? _asNum(dynamic raw) => raw is num ? raw : null;

  /// 数字展示：整数不带小数点，小数最多一位
  String _trimNum(num value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  /// 进度条（0~1）
  Widget _cardProgress(double value, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: color.withValues(alpha: 0.12),
        color: color,
      ),
    );
  }

  /// 关键数字一行（左标签右数值）
  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 餐次概要（卡片只给餐次 + 食物名 + 该餐热量，明细留给页面）
  List<Widget> _mealLines(List<dynamic> meals) {
    final lines = <Widget>[];
    for (final raw in meals) {
      if (raw is! Map) continue;
      final meal = Map<String, dynamic>.from(raw);
      final label = (meal['meal_type_label'] ?? '').toString();
      final items = meal['items'] is List
          ? (meal['items'] as List).map((e) => e.toString()).join('、')
          : '';
      final kcal = _asNum(meal['calories']) ?? 0;
      if (label.isEmpty && items.isEmpty) continue;
      lines.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 116,
                child: Text(
                  label.isEmpty ? '其他' : label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                ),
              ),
              Expanded(
                child: Text(
                  items.isEmpty
                      ? '${_trimNum(kcal)} kcal'
                      : '$items · ${_trimNum(kcal)} kcal',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF444444)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return lines;
  }

  /// 今日汇总卡（PRD 4.8：热量/营养/饮水进度 → 查看详情）
  Widget _buildDailySummaryCard(_ActionCardState card) {
    final data = card.data;
    final calories = _asMap(data['calories']);
    final macros = _asMap(data['macros']);
    final water = _asMap(data['water']);
    final meals = data['meals'] is List ? data['meals'] as List : const [];
    final intake = _asNum(calories['intake']) ?? 0;
    final target = _asNum(calories['target']) ?? 0;
    final remaining = _asNum(calories['remaining']) ?? 0;
    final progress = _asNum(calories['progress'])?.toDouble() ?? 0;
    final pending = _asNum(data['pending_nutrition_count']) ?? 0;
    final date = (data['date'] ?? '').toString();
    final jump = _asMap(data['jump']);
    const accent = Color(0xFF2BAF74);

    return _cardShell(
      accent: accent,
      icon: Icons.donut_large,
      title: date.isEmpty ? '今日汇总' : '汇总 · $date',
      body: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _trimNum(intake),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222222),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 3, bottom: 3),
              child: Text('kcal',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ),
            const Spacer(),
            if (target > 0)
              Text(
                '目标 ${_trimNum(target)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _cardProgress(progress, accent),
        const SizedBox(height: 6),
        if (target > 0)
          Text(
            remaining >= 0
                ? '距目标还差 ${_trimNum(remaining)} kcal'
                : '已超出目标 ${_trimNum(remaining.abs())} kcal',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        const SizedBox(height: 8),
        _metricRow(
          '蛋白质/脂肪/碳水',
          '${_trimNum(_asNum(macros['protein']) ?? 0)} / '
              '${_trimNum(_asNum(macros['fat']) ?? 0)} / '
              '${_trimNum(_asNum(macros['carbohydrates']) ?? 0)} g',
        ),
        _metricRow(
          '饮水',
          '${(_asNum(water['intake_ml']) ?? 0).round()} / '
              '${(_asNum(water['goal_ml']) ?? 0).round()} ml',
        ),
        ..._mealLines(meals),
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '另有 ${pending.round()} 条记录待补营养，暂未计入热量',
              style: const TextStyle(fontSize: 11, color: Color(0xFFF39C12)),
            ),
          ),
      ],
      actions: [
        _jumpButton(
          '查看今日饮食',
          () => _openCardJump({
            'page': 'history',
            'date': date,
          }),
        ),
        _jumpButton('查看详情', () => _openCardJump(jump)),
      ],
    );
  }

  /// 家人状态卡（PRD 4.8：父母今日三餐摘要 → 家人健康页）
  Widget _buildFamilyStatusCard(_ActionCardState card) {
    final data = card.data;
    final members =
        data['members'] is List ? data['members'] as List : const [];
    final date = (data['date'] ?? '').toString();
    final jump = _asMap(data['jump']);
    const accent = Color(0xFF3498DB);

    if (members.isEmpty) {
      return _cardShell(
        accent: accent,
        icon: Icons.family_restroom,
        title: date.isEmpty ? '家人状态' : '家人状态 · $date',
        body: [
          Text(
            (card.payload['message'] ?? '暂无家人数据').toString(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
        ],
      );
    }

    int? singleId;
    String? singleName;
    final body = <Widget>[];
    for (final raw in members) {
      if (raw is! Map) continue;
      final member = Map<String, dynamic>.from(raw);
      final name = (member['name'] ?? '家人').toString();
      final note = (member['note'] ?? '').toString();
      final calories = _asMap(member['calories']);
      final water = _asMap(member['water']);
      final meals =
          member['meals'] is List ? member['meals'] as List : const [];
      final intake = _asNum(calories['intake']) ?? 0;
      final target = _asNum(calories['target']) ?? 0;
      final mealCount = _asNum(member['meal_count']) ?? 0;
      if (singleId == null) {
        singleId = _asNum(member['user_id'])?.toInt();
        singleName = name;
      }
      body.add(
        Padding(
          padding: EdgeInsets.only(top: body.isEmpty ? 0 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                    ),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '（$note）',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '已摄入 ${_trimNum(intake)} kcal · 共 $mealCount 餐'
                '${target > 0 ? ' · 目标 ${_trimNum(target)}' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 2),
              Text(
                '饮水 ${(_asNum(water['intake_ml']) ?? 0).round()} / '
                '${(_asNum(water['goal_ml']) ?? 0).round()} ml',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
              ..._mealLines(meals),
            ],
          ),
        ),
      );
    }

    return _cardShell(
      accent: accent,
      icon: Icons.family_restroom,
      title: date.isEmpty ? '家人状态' : '家人状态 · $date',
      body: body,
      actions: [
        _jumpButton(
          members.length > 1 ? '查看家人看板' : '查看详情',
          () => _openCardJump(
            jump,
            memberId: members.length > 1 ? null : singleId,
            memberName: members.length > 1 ? null : singleName,
          ),
          color: accent,
        ),
      ],
    );
  }

  /// 趋势卡（PRD 4.8：体重/热量缩略趋势 → 体重趋势页）
  /// 生产者是二期的 query_weight_trend（V5.1 无动作）；渲染器按 D7 先就位，缺数据时只显示结论。
  Widget _buildTrendCard(_ActionCardState card) {
    final data = card.data;
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();
    final unit = (data['unit'] ?? '').toString();
    final change = _asNum(data['change']);
    final points = data['points'] is List ? data['points'] as List : const [];
    final values = points
        .whereType<Map>()
        .map((p) => _asNum(p['value']))
        .whereType<num>()
        .toList();
    const accent = Color(0xFF9B59B6);

    final body = <Widget>[];
    if (values.isNotEmpty) {
      final maxValue = values.reduce((a, b) => a > b ? a : b);
      final minValue = values.reduce((a, b) => a < b ? a : b);
      final span =
          (maxValue - minValue).abs() < 0.01 ? 1.0 : (maxValue - minValue);
      body.add(
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 8 + 34 * ((value - minValue).abs() / span),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      body.add(const SizedBox(height: 6));
      body.add(
        Text(
          '${_trimNum(values.first)}$unit → ${_trimNum(values.last)}$unit',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
      );
      if (change != null && change.abs() >= 0.05) {
        body.add(
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '期间${change > 0 ? '增加' : '减少'} ${_trimNum(change.abs())}$unit',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ),
        );
      }
    } else if (message.isNotEmpty) {
      body.add(
        Text(
          message,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
      );
    }

    return _cardShell(
      accent: accent,
      icon: Icons.show_chart,
      title: '趋势',
      body: body.isEmpty
          ? [
              const Text(
                '暂无趋势数据',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ]
          : body,
      actions: [
        _jumpButton(
          '查看完整趋势',
          () => _openCardJump(
            jump.isEmpty ? {'page': 'weight_trend'} : jump,
          ),
          color: accent,
        ),
      ],
    );
  }

  /// 周报卡（PRD 4.8：本周摘要 + 一句建议 → 周报页）
  /// 生产者是二期的 generate_weekly_report；渲染器按 D7 先就位。
  Widget _buildWeeklyReportCard(_ActionCardState card) {
    final data = card.data;
    final range = _asMap(data['range']);
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();
    final suggestion = (data['suggestion'] ?? '').toString();
    final highlights =
        data['highlights'] is List ? data['highlights'] as List : const [];
    final start = (range['start'] ?? '').toString();
    final end = (range['end'] ?? '').toString();
    const accent = Color(0xFF16A085);

    final body = <Widget>[];
    if (message.isNotEmpty) {
      body.add(
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF444444),
          ),
        ),
      );
    }
    for (final item in highlights) {
      final text =
          item is Map ? (item['text'] ?? '').toString() : item.toString();
      if (text.isEmpty) continue;
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.circle, size: 5, color: Color(0xFF16A085)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (suggestion.isNotEmpty) {
      body.add(
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            suggestion,
            style: const TextStyle(fontSize: 12, color: Color(0xFF2C6E63)),
          ),
        ),
      );
    }

    return _cardShell(
      accent: accent,
      icon: Icons.assignment_outlined,
      title: start.isEmpty || end.isEmpty ? '饮食周报' : '周报 · $start ~ $end',
      body: body.isEmpty
          ? [
              const Text(
                '暂无周报数据',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ]
          : body,
      actions: [
        _jumpButton(
          '查看完整周报',
          () => _openCardJump(
            jump.isEmpty ? {'page': 'weekly_report'} : jump,
          ),
          color: accent,
        ),
      ],
    );
  }

  /// 体检指标卡（PRD 4.8：单项指标 + 参考范围 → 体检报告详情页；PRD 5.4：附统一话术）
  /// 生产者是二期的 query_exam（仅在报告已开启 AI 分析时才会出这张卡）
  Widget _buildExamMetricCard(_ActionCardState card) {
    final data = card.data;
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();
    final examDate = (data['exam_date'] ?? '').toString();
    final hospital = (data['hospital_name'] ?? '').toString();
    final rawMetrics =
        data['metrics'] is List ? data['metrics'] as List : const [];
    final metrics = rawMetrics.whereType<Map>().toList();
    final abnormalCount = _asNum(data['abnormal_count']);
    final reportId = _asNum(data['report_id'])?.toInt();
    const accent = Color(0xFFD35400);

    final body = <Widget>[];
    final subtitle =
        [examDate, hospital].where((text) => text.isNotEmpty).join(' · ');
    if (subtitle.isNotEmpty) {
      body.add(
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
        ),
      );
    }
    if (message.isNotEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF444444),
            ),
          ),
        ),
      );
    }
    for (final item in metrics.take(6)) {
      final name = (item['metric_name'] ?? '').toString();
      if (name.isEmpty) continue;
      final value = _asNum(item['metric_value']);
      final unit = (item['unit'] ?? '').toString();
      final range = (item['reference_range'] ?? '').toString();
      final isAbnormal = item['is_abnormal'] == true;
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              Text(
                '${value == null ? '—' : _trimNum(value)}$unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAbnormal
                      ? const Color(0xFFE74C3C)
                      : const Color(0xFF222222),
                ),
              ),
            ],
          ),
        ),
      );
      if (range.isNotEmpty) {
        body.add(
          Text(
            '参考范围 $range',
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
          ),
        );
      }
    }
    if (abnormalCount != null) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            abnormalCount > 0
                ? '共 ${_trimNum(abnormalCount)} 项异常'
                : '各项指标均在参考范围内',
            style: TextStyle(
              fontSize: 12,
              color: abnormalCount > 0
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF2BAF74),
            ),
          ),
        ),
      );
    }
    body.add(
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '仅供参考，不构成医疗建议',
          style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
        ),
      ),
    );

    return _cardShell(
      accent: accent,
      icon: Icons.health_and_safety_outlined,
      title: '体检指标',
      body: body,
      actions: [
        _jumpButton(
          '查看报告',
          () => _openCardJump(
            reportId == null
                ? (jump.isEmpty ? {'page': 'exam_reports'} : jump)
                : {'page': 'exam_report', 'report_id': reportId},
          ),
          color: accent,
        ),
      ],
    );
  }

  /// 成本卡（PRD 4.8：花销统计 → 花销统计页）
  /// 生产者是二期的 query_cost
  Widget _buildCostCard(_ActionCardState card) {
    final data = card.data;
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();
    final period = (data['period'] ?? 'week').toString();
    final total = _asNum(data['total_cost']) ?? 0;
    final dailyAvg = _asNum(data['daily_avg']) ?? 0;
    final count = _asNum(data['record_count']) ?? 0;
    final budget = _asNum(data['budget']);
    final remaining = _asNum(data['budget_remaining']);
    final rawBreakdown =
        data['by_meal_time'] is List ? data['by_meal_time'] as List : const [];
    const accent = Color(0xFFF39C12);

    final body = <Widget>[];
    body.add(
      Text(
        '¥${_trimNum(total)}',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF222222),
        ),
      ),
    );
    if (count > 0) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${period == 'month' ? '本月' : '本周'} · 共 ${_trimNum(count)} 笔 · 日均 ¥${_trimNum(dailyAvg)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    } else if (message.isNotEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    }
    if (budget != null && budget > 0) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _cardProgress((total / budget).clamp(0.0, 1.0), accent),
        ),
      );
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            remaining == null
                ? '预算 ¥${_trimNum(budget)}'
                : '预算 ¥${_trimNum(budget)} · 剩余 ¥${_trimNum(remaining)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ),
      );
    }
    for (final item in rawBreakdown.take(4)) {
      if (item is! Map) continue;
      final label = (item['meal_type_label'] ?? '').toString();
      if (label.isEmpty) continue;
      final cost = _asNum(item['cost']) ?? 0;
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              Text(
                '¥${_trimNum(cost)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF444444)),
              ),
            ],
          ),
        ),
      );
    }

    return _cardShell(
      accent: accent,
      icon: Icons.account_balance_wallet_outlined,
      title: '花销统计',
      body: body,
      actions: [
        _jumpButton(
          '查看明细',
          () => _openCardJump(jump.isEmpty ? {'page': 'cost'} : jump),
          color: accent,
        ),
      ],
    );
  }

  /// 页面引导卡（open_page 动作，PRD 4.8）：Agent 判断需要页面级操作时
  /// 出一张引导卡，用户点「前往」直达；低频页面操作不常驻对话栏的承接方案
  Widget _buildPageGuideCard(_ActionCardState card) {
    final data = card.data;
    final title = (data['title'] ?? '快捷直达').toString();
    final desc = (data['desc'] ?? '').toString();
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();

    final body = <Widget>[];
    if (message.isNotEmpty) {
      body.add(
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF444444),
          ),
        ),
      );
    }
    if (desc.isNotEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            desc,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    }

    return _cardShell(
      accent: const Color(0xFF2BAF74),
      icon: Icons.open_in_new,
      title: title,
      body: body.isEmpty
          ? [
              const Text(
                '点击「前往」完成操作',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ]
          : body,
      actions: [
        _jumpButton('前往', () => _openCardJump(jump)),
      ],
    );
  }

  /// 操作确认卡（PRD 4.8：提醒已设置 / 已发送）
  /// 生产者是二期的 set_reminder（可撤销）与 send_reminder_to_family（仅发提醒，不可撤销）
  Widget _buildActionConfirmCard(_ActionCardState card) {
    final data = card.data;
    final jump = _asMap(data['jump']);
    final message = (card.payload['message'] ?? '').toString();
    final isReminder = card.action == 'set_reminder';
    final undone = card.undone;
    final accent = undone ? const Color(0xFF9E9E9E) : const Color(0xFF2BAF74);

    final body = <Widget>[];
    if (message.isNotEmpty) {
      body.add(
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF444444),
          ),
        ),
      );
    }
    final detail = isReminder
        ? _reminderDetailLine(data)
        : [
            (data['member_name'] ?? data['target_name'] ?? '').toString(),
            (data['content'] ?? '').toString(),
          ].where((text) => text.isNotEmpty).join(' · ');
    if (detail.isNotEmpty) {
      body.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
          ),
        ),
      );
    }

    return _cardShell(
      accent: accent,
      icon: undone
          ? Icons.undo
          : (isReminder ? Icons.alarm_on_outlined : Icons.favorite_border),
      title: undone ? '已撤销' : (isReminder ? '提醒已设置' : '提醒已发送'),
      body: body.isEmpty
          ? [
              const Text(
                '已完成',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            ]
          : body,
      actions: [
        if (!undone && card.canUndo)
          TextButton(
            onPressed: card.undoing ? null : () => _undoCard(card),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: const Color(0xFFE74C3C),
            ),
            child: card.undoing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('撤销', style: TextStyle(fontSize: 13)),
          ),
        _jumpButton(
          isReminder ? '管理提醒' : '查看家人健康',
          () => _openCardJump(
            jump.isEmpty
                ? {'page': isReminder ? 'reminder' : 'family_health'}
                : jump,
          ),
          color: accent,
        ),
      ],
    );
  }

  /// 提醒卡的关键信息行：重复方式 + 时间 + 标题
  String _reminderDetailLine(Map<String, dynamic> data) {
    final clock = (data['remind_time'] ?? '').toString();
    final repeat = (data['repeat'] ?? '').toString();
    final title = (data['title'] ?? '').toString();
    final repeatLabel =
        repeat == 'daily' ? '每天' : (repeat == 'weekdays' ? '每个工作日' : '单次');
    return [
      if (clock.isNotEmpty) '$repeatLabel $clock',
      if (title.isNotEmpty) title,
    ].join(' · ');
  }

  /// 待确认卡（PRD 4.3 / 4.8）：一句追问 + 快捷选项，点一下即答完，不跳转页面
  Widget _buildPendingConfirmCard(_ActionCardState card) {
    final data = card.data;
    final question = (data['question'] ?? '这个份量大概是多少？').toString();
    final rawOptions = data['options'];
    final options = rawOptions is List ? rawOptions : const [];
    final answered = card.answeredLabel;
    const accent = Color(0xFFF39C12);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.help_outline, size: 15, color: accent),
                SizedBox(width: 6),
                Text(
                  '需要确认一下',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF222222),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  if (option is Map)
                    _buildPendingOption(
                      card,
                      Map<String, dynamic>.from(option),
                      answered != null,
                    ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Text(
              answered != null ? '已选择「$answered」，正在记录…' : '点一下选项即可，不用打字',
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }

  /// 待确认卡的一个快捷选项
  Widget _buildPendingOption(
    _ActionCardState card,
    Map<String, dynamic> option,
    bool answered,
  ) {
    const accent = Color(0xFFF39C12);
    final label = (option['label'] ?? '').toString();
    final enabled = !answered && !_isSending;
    return InkWell(
      onTap: enabled ? () => _answerPendingCard(card, option) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: enabled ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: enabled ? 0.45 : 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: enabled ? accent : const Color(0xFFBBBBBB),
          ),
        ),
      ),
    );
  }

  /// 待确认卡作答：快捷选项直接补记（把选项文案当作一句用户消息发出去）；
  /// 「其他」只聚焦输入框，让用户自己说数值，不替他假定（PRD 4.3）
  Future<void> _answerPendingCard(
    _ActionCardState card,
    Map<String, dynamic> option,
  ) async {
    if (_isSending || card.answeredLabel != null) return;
    if (option['value'] == null) {
      _inputFocusNode.requestFocus();
      _showSnackBar('请输入具体数值，比如「180g」');
      return;
    }
    final label = (option['label'] ?? '').toString();
    setState(() => card.answeredLabel = label);
    await _sendText(label);
  }

  /// 记录结果卡标题：饮食取菜名，饮水取饮品，体重固定「体重」
  String _cardTitle(Map<String, dynamic> source) {
    final food = source['food_name'];
    if (food != null && food.toString().isNotEmpty) return food.toString();
    if (source['amount_ml'] != null) {
      final drink = source['drink_type'];
      return drink == null ? '饮水' : drink.toString();
    }
    if (source['weight_kg'] != null) return '体重';
    return '记录';
  }

  String _cardDetailLine(Map<String, dynamic> source, bool isUndoResult) {
    final parts = <String>[];

    // 饮水记录：饮水量（营养不适用）
    final amount = source['amount_ml'];
    if (amount is num) parts.add('${amount.round()}ml');

    // 体重记录：kg + BMI + 较上次变化
    final weight = source['weight_kg'];
    if (weight is num) {
      parts.add('${weight}kg');
      final bmi = source['bmi'];
      if (bmi is num) parts.add('BMI $bmi');
      final delta = source['delta_kg'];
      if (!isUndoResult && delta is num && delta.abs() >= 0.05) {
        parts.add('较上次${delta > 0 ? '增加' : '减少'} ${delta.abs()}kg');
      }
    }

    // 饮食记录：份量 + 热量
    final grams = source['quantity_g'];
    if (grams is num) {
      parts.add('约 ${grams.toStringAsFixed(0)}g');
    }
    if (!isUndoResult && source['food_name'] != null) {
      final matched = source['nutrition_matched'] == true;
      final nutrition = source['nutrition'];
      final calories = nutrition is Map ? nutrition['calories'] : null;
      if (matched && calories is num) {
        parts.add('${calories.toStringAsFixed(0)} kcal');
      } else {
        parts.add('营养库未命中，暂不计入今日汇总');
      }
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// 卡片「撤销」：直调后端动作（仅最近一条 + 10 分钟窗口，PRD 4.5）
  Future<void> _undoCard(_ActionCardState card) async {
    if (card.undoing || card.undone) return;
    setState(() => card.undoing = true);
    try {
      // 带上本卡片的撤销凭证：后端据此校验「点哪张撤哪张」
      final response = await _chatService.undoLastAction(
        undoToken: card.undoToken,
      );
      if (!mounted) return;
      setState(() => card.undoing = false);
      if (response.success) {
        setState(() => card.undone = true);
        _showSnackBar(
          response.message.isNotEmpty ? response.message : '已撤销该记录',
        );
      } else {
        _showSnackBar(
          response.message.isNotEmpty
              ? response.message
              : '撤销失败：该条已超过可撤销时间或不是最近一条',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => card.undoing = false);
      _showSnackBar('撤销失败: $e');
    }
  }

  /// 记录结果卡的「下一步入口」（PRD 4.8）：优先按后端下发的 jump 跳转并携带上下文；
  /// 无 jump 或不可识别的页面（如宠物喂养卡的 health 域）时回退「查看今日饮食」
  void _openRecordCardEntry(
      _ActionCardState card, Map<String, dynamic> source) {
    final jump = _asMap(card.data['jump']);
    final page = (jump['page'] ?? '').toString();
    if (card.action != 'undo' &&
        (page == 'history' ||
            page == 'diet_records' ||
            page == 'weight_trend')) {
      _openCardJump(jump);
      return;
    }
    _openDietRecords(source);
  }

  /// 记录结果卡入口按钮文案：体重卡引导看趋势，其余默认「查看今日饮食」
  String _recordCardEntryLabel(_ActionCardState card) {
    if (card.action != 'undo' &&
        (card.data['jump']?['page'] ?? '').toString() == 'weight_trend') {
      return '查看体重趋势';
    }
    return '查看今日饮食';
  }

  /// 记录结果卡「查看今日饮食」：跳饮食记录页并携带该条记录的日期（PRD 4.8）
  void _openDietRecords(Map<String, dynamic> source) {
    final raw =
        (source['record_date'] ?? source['record_time'] ?? '').toString();
    final date = raw.length >= 10 ? raw.substring(0, 10) : '';
    context.push(
      date.isEmpty
          ? AppConstants.historyRoute
          : '${AppConstants.historyRoute}?date=$date',
    );
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatTime(String timestamp) {
    try {
      // 后端返回带时区的时间戳（UTC），统一转成本地时间再比较/展示
      final dateTime = DateTime.parse(timestamp).toLocal();
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
          sessionType: _sessionType,
          onSessionSelected: (sessionId) {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  sessionId: sessionId,
                  sessionType: _sessionType,
                  title: widget.title,
                ),
              ),
            );
          },
        ),
      ),
    );
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
            Text('会话类型: ${_chatService.getSessionTypeName(_sessionType)}'),
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

/// 动作结果卡片状态（记录结果卡 / 待确认卡 / 撤销结果卡）
class _ActionCardState {
  final Map<String, dynamic> payload;
  bool undone;
  bool undoing = false;

  /// 待确认卡已作答的选项文案（本地标记，避免重复点击）
  String? answeredLabel;

  /// 已撤销标记来自后端回写（重进会话历史回显时卡片显示「已撤销」）；
  /// 撤销结果卡的 payload 里 undone 是 data 内的对象，不会命中这里的严格判断。
  _ActionCardState(this.payload) : undone = payload['undone'] == true;

  String get action => (payload['action'] ?? '').toString();

  /// 卡片类型（PRD 4.8：record_result / pending_confirm / daily_summary / family_status…）
  String get cardType => (payload['card_type'] ?? '').toString();

  /// 撤销凭证（后端据此校验「点哪张撤哪张」）
  String get undoToken => (payload['undo_token'] ?? '').toString();

  Map<String, dynamic> get data {
    final raw = payload['data'];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// 撤销窗口内（记录后 10 分钟，最终以后端校验为准）
  bool get canUndo {
    if (payload['undo_token'] == null) return false;
    final deadline = payload['undo_deadline'];
    if (deadline is! String) return false;
    try {
      return DateTime.parse(deadline).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String footerHint(bool undone) {
    if (undone) return '已撤销，今日统计已更新';
    if (canUndo) return '记录后 10 分钟内可撤销';
    return '已超过可撤销时间，可在记录页修改';
  }
}
