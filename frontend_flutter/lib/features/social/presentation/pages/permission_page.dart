import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../data/social_api_service.dart';

/// 数据权限管理页面 - 设置哪些数据对指定家人可见
class PermissionPage extends ConsumerStatefulWidget {
  final int targetUserId;
  final String targetUserName;

  const PermissionPage({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  ConsumerState<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends ConsumerState<PermissionPage> {
  final SocialApiService _apiService = SocialApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  List<String> _visibleFields = [];

  static const List<Map<String, String>> _allFields = [
    {'key': 'calories', 'label': '热量摄入', 'icon': '🔥'},
    {'key': 'water', 'label': '饮水记录', 'icon': '💧'},
    {'key': 'weight', 'label': '体重数据', 'icon': '⚖️'},
    {'key': 'exercise', 'label': '运动记录', 'icon': '🏃'},
    {'key': 'health_goal', 'label': '健康目标', 'icon': '🎯'},
    {'key': 'virtual_pet', 'label': '虚拟桌宠状态', 'icon': '🧚'},
    {'key': 'real_pet', 'label': '真实宠物状态', 'icon': '🐱'},
    {'key': 'exam_report', 'label': '体检报告', 'icon': '📋'},
    {'key': 'dietary_preferences', 'label': '饮食偏好', 'icon': '🍽️'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    setState(() => _isLoading = true);
    try {
      // getPermission 返回的是已解析好的 List<String>（visible_fields）
      final response = await _apiService.getPermission(widget.targetUserId);
      if (response.success && response.data != null) {
        _visibleFields = List<String>.from(response.data!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载权限失败: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _savePermission() async {
    setState(() => _isSaving = true);
    try {
      final response = await _apiService.updatePermission(
        widget.targetUserId,
        _visibleFields,
      );
      if (mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('权限保存成功')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _toggleField(String key) {
    setState(() {
      if (_visibleFields.contains(key)) {
        _visibleFields.remove(key);
      } else {
        _visibleFields.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.targetUserName}的数据权限'),
        actions: [
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _savePermission,
              child: const Text('保存', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '选择对 ${widget.targetUserName} 可见的数据类型',
                      style: TextStyle(color: Colors.blue[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._allFields.map((field) => _buildFieldTile(field)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _savePermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存设置', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTile(Map<String, String> field) {
    final isSelected = _visibleFields.contains(field['key']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Text(field['icon']!, style: const TextStyle(fontSize: 24)),
        title: Text(field['label']!),
        trailing: Switch(
          value: isSelected,
          onChanged: (_) => _toggleField(field['key']!),
          activeColor: AppColors.primary,
        ),
        onTap: () => _toggleField(field['key']!),
      ),
    );
  }
}
