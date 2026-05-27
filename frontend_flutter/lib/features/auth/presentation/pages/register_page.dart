import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../shared/presentation/widgets/app_button.dart';
import '../../../../shared/presentation/widgets/app_input.dart';
import '../providers/auth_provider.dart';
import '../../../onboarding/presentation/providers/onboarding_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📝 开始注册流程...');
      
      final success = await ref.read(authStateProvider.notifier).registerAndLogin(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
      );

      if (mounted) {
        if (success) {
          print('✅ 注册成功，直接跳转到引导流程...');
          
          // 新用户直接跳转到引导流程，跳过API检查（临时解决方案）
          print('✅ 新用户，跳转到引导流程');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('注册成功！让我们设置您的个人资料'),
              backgroundColor: AppColors.primary,
            ),
          );
          
          // 等待短暂的时间让用户看到消息
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (mounted) {
            context.go('/onboarding');
          }
        } else {
          print('❌ 注册失败');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('注册失败，请检查您的信息'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('注册失败：$e'),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Logo和标题区域
              _buildHeader(),
              
              const SizedBox(height: 32),
              
              // 注册表单
              _buildRegisterForm(),
              
              const SizedBox(height: 24),
              
              // 登录提示
              _buildLoginPrompt(),
              
              const SizedBox(height: 20),
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
          '创建新账户',
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 副标题
        Text(
          '加入我们，开始您的健康之旅',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 用户名输入框
          AppInput(
            controller: _usernameController,
            label: '用户名',
            placeholder: '请输入用户名',
            prefixIcon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入用户名';
              }
              if (value.trim().length < 3) {
                return '用户名至少3位字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 邮箱输入框
          AppInput(
            controller: _emailController,
            label: '邮箱',
            placeholder: '请输入您的邮箱',
            prefixIcon: Icons.email_outlined,
            type: AppInputType.email,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入邮箱';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 手机号输入框（可选）
          AppInput(
            controller: _phoneController,
            label: '手机号（可选）',
            placeholder: '请输入手机号',
            prefixIcon: Icons.phone_outlined,
            type: AppInputType.number,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim())) {
                  return '请输入有效的手机号';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 密码输入框
          AppInput(
            controller: _passwordController,
            label: '密码',
            placeholder: '请输入密码（至少6位）',
            prefixIcon: Icons.lock_outline,
            type: AppInputType.password,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请输入密码';
              }
              if (value.length < 6) {
                return '密码至少6位字符';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // 确认密码输入框
          AppInput(
            controller: _confirmPasswordController,
            label: '确认密码',
            placeholder: '请再次输入密码',
            prefixIcon: Icons.lock_outline,
            type: AppInputType.password,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '请确认密码';
              }
              if (value != _passwordController.text) {
                return '两次输入的密码不一致';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // 注册按钮
          AppButton(
            text: '注册',
            onPressed: _isLoading ? null : _handleRegister,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '已有账户？',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: () {
            context.pop();
          },
          child: Text(
            '立即登录',
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