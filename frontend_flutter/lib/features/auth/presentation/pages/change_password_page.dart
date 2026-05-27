import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../providers/auth_provider.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ref.read(authStateProvider.notifier).changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );

      if (mounted) {
        if (success) {
          // 密码修改成功
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密码修改成功！'),
              backgroundColor: AppColors.primary,
            ),
          );

          // 返回上一页
          context.pop();
        } else {
          // 密码修改失败
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('密码修改失败，请检查您的旧密码'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('密码修改失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
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
      appBar: AppBar(
        title: const Text('修改密码'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 说明文字
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '为了保障您的账户安全，请先输入当前密码',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 当前密码输入框
                AppInput(
                  controller: _oldPasswordController,
                  label: '当前密码',
                  placeholder: '请输入您的当前密码',
                  prefixIcon: Icons.lock_outline,
                  type: AppInputType.password,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入当前密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 新密码输入框
                AppInput(
                  controller: _newPasswordController,
                  label: '新密码',
                  placeholder: '请输入新密码（至少6位）',
                  prefixIcon: Icons.lock,
                  type: AppInputType.password,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入新密码';
                    }
                    if (value.length < 6) {
                      return '新密码至少6位字符';
                    }
                    if (value == _oldPasswordController.text) {
                      return '新密码不能与当前密码相同';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // 确认新密码输入框
                AppInput(
                  controller: _confirmPasswordController,
                  label: '确认新密码',
                  placeholder: '请再次输入新密码',
                  prefixIcon: Icons.lock,
                  type: AppInputType.password,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请确认新密码';
                    }
                    if (value != _newPasswordController.text) {
                      return '两次输入的新密码不一致';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // 修改密码按钮
                AppButton(
                  text: '修改密码',
                  onPressed: _isLoading ? null : _handleChangePassword,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

                // 取消按钮
                TextButton(
                  onPressed: _isLoading ? null : () => context.pop(),
                  child: Text(
                    '取消',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
