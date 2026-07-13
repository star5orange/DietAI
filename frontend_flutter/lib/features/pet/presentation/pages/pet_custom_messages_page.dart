import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../core/services/api_service.dart';

/// 宠物自定义提示语设置页面
class PetCustomMessagesPage extends ConsumerStatefulWidget {
  const PetCustomMessagesPage({super.key});

  @override
  ConsumerState<PetCustomMessagesPage> createState() =>
      _PetCustomMessagesPageState();
}

class _PetCustomMessagesPageState extends ConsumerState<PetCustomMessagesPage> {
  final ApiService _apiService = ApiService();

  Map<String, String> _customMessages = {};
  Map<String, String> _defaultMessages = {};
  List<Map<String, String>> _allowedScenes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSaving = false;

  // 临时编辑的提示语
  final Map<String, TextEditingController> _controllers = {};

  // 禁止词汇列表（前端预验证）
  static const List<String> forbiddenWords = [
    "主人",
    "奴隶",
    "臣服",
    "爱恋",
    "痴迷",
    "迷恋",
    "亲爱的",
    "宝贝",
    "心肝",
    "老公",
    "老婆",
    "男友",
    "女友",
    "恋人",
    "情人",
    "情侣",
    "我想你",
    "我爱你",
    "我好喜欢你",
    "你是我的",
    "服从",
    "跪下",
    "听话",
    "惩罚",
    "奖励",
    "小主",
    "奴家",
    "臣妾",
    "本宫",
    "朕",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.get('/virtual-pet/custom-messages');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        setState(() {
          _customMessages =
              Map<String, String>.from(data['custom_messages'] ?? {});
          _defaultMessages =
              Map<String, String>.from(data['default_messages'] ?? {});
          _allowedScenes = (data['allowed_scenes'] as List?)
                  ?.map((e) => Map<String, String>.from(e))
                  .toList() ??
              [];

          // 为每个场景创建编辑控制器
          for (var scene in _allowedScenes) {
            final key = scene['scene'] ?? '';
            _controllers[key] = TextEditingController(
              text: _customMessages[key] ?? '',
            );
          }
        });
      } else {
        setState(() => _errorMessage = response.message);
      }
    } catch (e) {
      setState(() => _errorMessage = '加载失败，请稍后重试');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMessages() async {
    // 收集所有编辑的提示语
    final messages = <String, String>{};
    for (var entry in _controllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        messages[entry.key] = text;
      }
    }

    // 前端预验证
    final validationErrors = <String, String>{};
    for (var entry in messages.entries) {
      final error = _validateMessage(entry.value);
      if (error != null) {
        validationErrors[entry.key] = error;
      }
    }

    if (validationErrors.isNotEmpty) {
      _showErrorDialog('提示语验证失败', validationErrors);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await _apiService.post(
        '/virtual-pet/custom-messages',
        data: {'messages': messages},
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? '保存成功'),
              backgroundColor: AppColors.success,
            ),
          );

          // 如果有不合规的提示语，显示详情
          if (result['invalid_count'] > 0) {
            _showErrorDialog(
              '部分提示语不合规',
              Map<String, String>.from(result['error_details']),
            );
          }
        }

        // 刷新数据
        await _loadData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请稍后重试'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateMessage(String message) {
    if (message.isEmpty) {
      return null; // 空提示语表示删除
    }

    if (message.length > 100) {
      return '提示语长度不能超过100字';
    }

    // 检查禁止词汇
    for (var word in forbiddenWords) {
      if (message.contains(word)) {
        return '包含不合规词汇：$word';
      }
    }

    // 检查情感诱导模式
    if (_containsEmotionalPatterns(message)) {
      return '包含情感诱导或不合规表达';
    }

    return null;
  }

  bool _containsEmotionalPatterns(String message) {
    final patterns = [
      RegExp(r'我想.*[爱恋喜欢]'),
      RegExp(r'[你我].*属于'),
      RegExp(r'永远.*在一起'),
      RegExp(r'你的.*[心肝宝贝]'),
    ];

    for (var pattern in patterns) {
      if (pattern.hasMatch(message)) {
        return true;
      }
    }

    return false;
  }

  void _showErrorDialog(String title, Map<String, String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: errors.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '• ${e.key}: ${e.value}',
                  style: AppTextStyles.bodySmall,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _resetToDefault(String scene) {
    final defaultText = _defaultMessages[scene] ?? '';
    _controllers[scene]?.text = defaultText;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '自定义提示语',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveMessages,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.alertCircle,
                          size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 说明卡片
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.info,
                                color: AppColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '您可以自定义宠物在不同场景下的提示语。系统会自动过滤不合规词汇。',
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: AppColors.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 场景列表
                      ...List.generate(_allowedScenes.length, (index) {
                        final scene = _allowedScenes[index];
                        final sceneKey = scene['scene'] ?? '';
                        final sceneDesc = scene['description'] ?? '';
                        final controller = _controllers[sceneKey];

                        if (controller == null) return const SizedBox();

                        return _buildMessageCard(
                            sceneKey, sceneDesc, controller);
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildMessageCard(
    String sceneKey,
    String sceneDesc,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppColors.lightShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(sceneDesc, style: AppTextStyles.h6),
              TextButton(
                onPressed: () => _resetToDefault(sceneKey),
                child: const Text('恢复默认'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: '请输入提示语（可选）',
              hintStyle: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              counterStyle: AppTextStyles.numberXSmall,
            ),
            style: AppTextStyles.bodyMedium,
          ),
          if (_defaultMessages.containsKey(sceneKey))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '默认：${_defaultMessages[sceneKey]}',
                style: AppTextStyles.numberXSmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}
