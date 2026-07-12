import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FoodRecordModal extends StatefulWidget {
  final String mealName;
  final Function(String, {double? cost, String? sourceTag}) onRecordMethod;

  const FoodRecordModal({
    super.key,
    required this.mealName,
    required this.onRecordMethod,
  });

  @override
  State<FoodRecordModal> createState() => _FoodRecordModalState();
}

class _FoodRecordModalState extends State<FoodRecordModal> {
  final _costController = TextEditingController();
  String? _selectedSource;
  bool _showCostInput = false;

  final List<Map<String, String>> _sourceOptions = [
    {'id': 'canteen', 'name': '食堂', 'icon': '🍳'},
    {'id': 'delivery', 'name': '外卖', 'icon': '🛵'},
    {'id': 'home', 'name': '自制', 'icon': '🏠'},
    {'id': 'restaurant', 'name': '餐厅', 'icon': '🍽️'},
    {'id': 'snack', 'name': '零食', 'icon': '🍪'},
    {'id': 'other', 'name': '其他', 'icon': '📦'},
  ];

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部指示器
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 标题
              Center(
                child: Text(
                  '记录${widget.mealName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 消费金额输入（可展开）
              _buildCostSection(),

              const SizedBox(height: 20),

              // 记录方式选项
              ..._buildRecordOptions(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 展开/收起按钮
          InkWell(
            onTap: () => setState(() => _showCostInput = !_showCostInput),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    size: 20,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '消费记录（可选）',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  Icon(
                    _showCostInput ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 20,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          if (_showCostInput) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 金额输入
                  Row(
                    children: [
                      const Text('¥', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          decoration: InputDecoration(
                            hintText: '输入金额',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 来源选择
                  Text(
                    '来源',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sourceOptions.map((source) => _buildSourceChip(source)).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceChip(Map<String, String> source) {
    final isSelected = _selectedSource == source['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = isSelected ? null : source['id']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3ECC7A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3ECC7A) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(source['icon']!, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              source['name']!,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecordOptions() {
    final options = [
      _RecordOption(
        icon: LucideIcons.scanLine,
        title: 'AI扫描器',
        subtitle: '拍照识别食物营养',
        methodId: 'ai_scan',
        isNew: false,
      ),
      _RecordOption(
        icon: LucideIcons.messageSquare,
        title: '文字描述',
        subtitle: '手动输入食物信息',
        methodId: 'text_describe',
        isNew: false,
      ),
      _RecordOption(
        icon: LucideIcons.bookmark,
        title: '已保存的菜品',
        subtitle: '从收藏中选择',
        methodId: 'saved_meals',
        isNew: false,
      ),
      _RecordOption(
        icon: LucideIcons.mic,
        title: '语音记录',
        subtitle: '即将推出',
        methodId: 'voice_record',
        isNew: true,
      ),
    ];

    return options.map((option) => _buildOptionTile(option)).toList();
  }

  Widget _buildOptionTile(_RecordOption option) {
    final isDisabled = option.methodId == 'voice_record';
    return GestureDetector(
      onTap: isDisabled ? null : () => _handleRecordMethod(option.methodId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标容器
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey[400] : const Color(0xFF3ECC7A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                option.icon,
                color: Colors.white,
                size: 24,
              ),
            ),

            const SizedBox(width: 16),

            // 标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDisabled ? Colors.grey[500] : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),

            // 标签
            if (option.isNew)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6F61).withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '即将推出',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleRecordMethod(String methodId) {
    // 解析金额
    double? cost;
    if (_costController.text.isNotEmpty) {
      cost = double.tryParse(_costController.text);
    }

    // 调用回调
    widget.onRecordMethod(
      methodId,
      cost: cost,
      sourceTag: _selectedSource,
    );
  }
}

class _RecordOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final String methodId;
  final bool isNew;

  const _RecordOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.methodId,
    required this.isNew,
  });
}