import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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

  String _formatErrorMessage(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return '用户名或密码错误，请重新输入';
    }
    if (errorStr.contains('404') || errorStr.contains('Not Found')) {
      return '用户不存在，请检查用户名';
    }
    if (errorStr.contains('Connection') ||
        errorStr.contains('SocketException') ||
        errorStr.contains('network')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (errorStr.contains('timeout') || errorStr.contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    }
    if (errorStr.contains('500') ||
        errorStr.contains('Internal Server Error')) {
      return '服务器错误，请稍后重试';
    }
    if (errorStr.contains('Exception:')) {
      return errorStr.replaceFirst('Exception:', '').trim();
    }
    return errorStr;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authStateProvider.notifier).login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

      if (mounted) {
        final authState = ref.read(authStateProvider);

        if (authState.hasValue && authState.value != null) {
          final onboardingState = ref.read(onboardingProvider);

          if (onboardingState.isCompleted) {
            context.go('/');
          } else {
            context.go('/onboarding');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录成功！'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        } else if (authState.hasError) {
          setState(() {
            _errorMessage = _formatErrorMessage(authState.error);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              _buildHeader(),
              const SizedBox(height: 48),
              _buildLoginForm(),
              const SizedBox(height: 32),
              _buildRegisterPrompt(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.go('/onboarding');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                ),
                child: Text(
                  '测试引导流程',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo容器
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🍳',
              style: TextStyle(fontSize: 32),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 欢迎文案
        Text(
          '欢迎回来！',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 8),

        // 副标题
        Text(
          '登录您的账户继续使用',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppInput(
            controller: _usernameController,
            label: '用户名/邮箱',
            placeholder: '请输入用户名或邮箱',
            prefixIcon: Icons.person_outline,
            type: AppInputType.email,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入用户名或邮箱';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppInput(
            controller: _passwordController,
            label: '密码',
            placeholder: '请输入您的密码',
            prefixIcon: Icons.lock_outline,
            type: AppInputType.password,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    child: Icon(
                      Icons.close,
                      color: AppColors.error.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppButton(
            text: '登录',
            onPressed: _isLoading ? null : _handleLogin,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '还没有账户？',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () {
            context.push('/register');
          },
          child: Text(
            '立即注册',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
