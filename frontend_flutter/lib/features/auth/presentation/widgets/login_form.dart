import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../../../../shared/domain/models/user_model.dart';
import '../providers/auth_provider.dart';

/// 登录表单组件
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            // 登录成功，跳转到首页
            context.go('/');
          }
        },
        loading: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        },
        error: (error, _) {
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });
        },
      );
    });

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 用户名/邮箱输入框
          AppInput(
            label: '用户名或邮箱',
            placeholder: '请输入用户名或邮箱',
            controller: _usernameController,
            prefixIcon: LucideIcons.user,
            textInputAction: TextInputAction.next,
            validator: _validateUsername,
          ),
          
          const SizedBox(height: 20),
          
          // 密码输入框
          AppInput(
            label: '密码',
            placeholder: '请输入密码',
            controller: _passwordController,
            type: AppInputType.password,
            prefixIcon: LucideIcons.lock,
            textInputAction: TextInputAction.done,
            validator: _validatePassword,
            onEditingComplete: _handleLogin,
          ),
          
          const SizedBox(height: 8),
          
          // 忘记密码链接
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _handleForgotPassword,
              child: Text(
                '忘记密码？',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 错误消息
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertCircle,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 登录按钮
          AppButton.primary(
            text: '登录',
            fullWidth: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleLogin,
          ),
          
          const SizedBox(height: 16),
          
          // 快速登录提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '测试账号',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '用户名: testuser  密码: 123456',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名或邮箱';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 6) {
      return '密码长度至少6位';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    // 清除之前的错误消息
    setState(() {
      _errorMessage = null;
    });

    // 验证表单
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await ref.read(authStateProvider.notifier).login(
        username: username,
        password: password,
      );
    } catch (e) {
      // 错误处理已在监听器中处理
    }
  }

  void _handleForgotPassword() {
    // TODO: 实现忘记密码功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('忘记密码功能开发中...'),
      ),
    );
  }
} 