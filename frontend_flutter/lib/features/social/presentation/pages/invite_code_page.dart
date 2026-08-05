import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_colors.dart';
import '../../data/social_api_service.dart';

/// 邀请码页面 - 查看自己的邀请码 / 输入邀请码加入家人
class InviteCodePage extends ConsumerStatefulWidget {
  const InviteCodePage({super.key});

  @override
  ConsumerState<InviteCodePage> createState() => _InviteCodePageState();
}

class _InviteCodePageState extends ConsumerState<InviteCodePage> {
  final TextEditingController _codeController = TextEditingController();
  String? _myInviteCode;
  String? _myUsername;
  bool _loadingCode = true;
  bool _joining = false;

  final SocialApiService _apiService = SocialApiService();

  @override
  void initState() {
    super.initState();
    _loadMyInviteCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyInviteCode() async {
    setState(() => _loadingCode = true);
    try {
      final res = await _apiService.getInviteCode();
      if (res.success && res.data != null) {
        setState(() {
          _myInviteCode = res.data!['invite_code'] as String?;
          _myUsername = res.data!['username'] as String?;
          _loadingCode = false;
        });
      } else {
        setState(() => _loadingCode = false);
      }
    } catch (e) {
      setState(() => _loadingCode = false);
    }
  }

  Future<void> _joinFamily() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入邀请码')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      final res = await _apiService.joinFamilyByInviteCode(code);
      if (!mounted) return;
      setState(() => _joining = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
        _codeController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败: $e')),
      );
    }
  }

  void _copyInviteCode() {
    if (_myInviteCode != null) {
      Clipboard.setData(ClipboardData(text: _myInviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邀请码已复制')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('邀请码'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 我的邀请码
            _buildMyInviteCodeCard(),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            // 输入邀请码加入家人
            _buildJoinFamilyCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyInviteCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '我的邀请码',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '分享给家人，TA 输入邀请码即可直接成为你的家人',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          if (_loadingCode)
            const Center(child: CircularProgressIndicator())
          else if (_myInviteCode != null)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      _myInviteCode!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _copyInviteCode,
                  icon: const Icon(Icons.copy, color: AppColors.primary),
                  tooltip: '复制邀请码',
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildJoinFamilyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '通过邀请码加入家人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '输入家人的邀请码，直接成为 TA 的家人',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: '请输入 6 位邀请码',
              prefixIcon: const Icon(Icons.vpn_key),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _joining ? null : _joinFamily,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _joining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('加入家人', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
