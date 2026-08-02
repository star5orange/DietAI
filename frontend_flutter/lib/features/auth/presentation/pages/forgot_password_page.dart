import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/domain/models/api_response.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../domain/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入手机号'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_phoneController.text.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('手机号格式不正确'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.forgotPassword(_phoneController.text.trim());

      if (!mounted) return;

      if (response.success) {
        setState(() => _codeSent = true);

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? '验证码已发送'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 开发环境：显示验证码（仅用于测试）
        if (response.data != null && response.data!['code'] != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('验证码: ${response.data!['code']} (开发模式)'),
              backgroundColor: AppColors.info,
              duration: const Duration(seconds: 10),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // 开始倒计时
        _startCountdown();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? '发送失败'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发送失败: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 开始倒计时
  void _startCountdown() {
    _countdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _codeSent = false);
      }
    });
  }

  /// 验证验证码
  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await _authService.verifyResetCode(
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      if (response.success) {
        setState(() => _codeVerified = true);

        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码验证成功'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 延迟跳转到重置密码页面
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            context.push('/reset-password', extra: {
              'phone': _phoneController.text.trim(),
              'code': _codeController.text.trim(),  // 传递验证码
            });
          }
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? '验证码错误'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('验证失败: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标和说明
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 80,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '重置密码',
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请输入注册时使用的手机号和验证码',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 手机号输入框
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    maxLength: 11,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入11位手机号',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: _countdown > 0
                          ? TextButton(
                              onPressed: null,
                              child: Text('${_countdown}s'),
                            )
                          : null,
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入手机号';
                      }
                      if (value.length != 11) {
                        return '手机号长度必须为11位';
                      }
                      if (!value.startsWith('1')) {
                        return '手机号格式不正确';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // 发送验证码按钮
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _countdown > 0 ? null : _sendCode,
                      child: Text(
                        _codeSent && _countdown > 0
                            ? '${_countdown}秒后可重新发送'
                            : '发送验证码',
                        style: TextStyle(color: _countdown > 0 ? AppColors.textSecondary : AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 验证码输入框
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: '验证码',
                      hintText: '请输入6位验证码',
                      prefixIcon: Icon(Icons.sms_outlined),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入验证码';
                      }
                      if (value.length != 6) {
                        return '验证码长度必须为6位';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // 下一步按钮
                  AppButton.primary(
                    text: '下一步',
                    onPressed: _verifyCode,
                    isLoading: _isLoading,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 32),

                  // 提示信息
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '验证码有效期为5分钟，请及时使用',
                            style: AppTextStyles.caption.copyWith(color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 加载指示器
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}