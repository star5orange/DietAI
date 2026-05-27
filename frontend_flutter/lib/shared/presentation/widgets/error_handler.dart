import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// 全局错误处理器
class ErrorHandler {
  static void showError(
    BuildContext context,
    String message, {
    String title = '错误',
    VoidCallback? onRetry,
    bool showRetryButton = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              LucideIcons.alertCircle,
              color: Colors.red[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
          if (showRetryButton && onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3ECC7A),
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String title = '成功',
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              LucideIcons.checkCircle,
              color: Colors.green[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onOk?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3ECC7A),
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    String title = '警告',
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: Colors.orange[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel?.call();
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  static void showLoading(
    BuildContext context, {
    String message = '加载中...',
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3ECC7A)),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  static void hideLoading(BuildContext context) {
    Navigator.pop(context);
  }
}

/// 网络错误处理
class NetworkErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error.toString().contains('SocketException')) {
      return '网络连接失败，请检查网络设置';
    } else if (error.toString().contains('TimeoutException')) {
      return '请求超时，请稍后重试';
    } else if (error.toString().contains('401')) {
      return '身份验证失败，请重新登录';
    } else if (error.toString().contains('403')) {
      return '权限不足，无法访问';
    } else if (error.toString().contains('404')) {
      return '请求的资源不存在';
    } else if (error.toString().contains('500')) {
      return '服务器内部错误，请稍后重试';
    } else {
      return '未知错误：${error.toString()}';
    }
  }

  static void handleApiError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    final message = getErrorMessage(error);
    ErrorHandler.showError(
      context,
      message,
      onRetry: onRetry,
      showRetryButton: onRetry != null,
    );
  }
}

/// 自定义SnackBar
class CustomSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? Colors.white),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF3ECC7A),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message,
      backgroundColor: const Color(0xFF3ECC7A),
      icon: LucideIcons.checkCircle,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context,
      message,
      backgroundColor: Colors.red[400],
      icon: LucideIcons.alertCircle,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message,
      backgroundColor: Colors.orange[400],
      icon: LucideIcons.alertTriangle,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message,
      backgroundColor: Colors.blue[400],
      icon: LucideIcons.info,
      duration: duration,
    );
  }
}

/// 加载状态组件
class LoadingWidget extends StatelessWidget {
  final String message;
  final bool showMessage;
  final Color? color;

  const LoadingWidget({
    super.key,
    this.message = '加载中...',
    this.showMessage = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? const Color(0xFF3ECC7A),
              ),
            ),
          ),
          if (showMessage) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 空状态组件
class EmptyWidget extends StatelessWidget {
  final String message;
  final String? description;
  final IconData? icon;
  final Widget? action;

  const EmptyWidget({
    super.key,
    required this.message,
    this.description,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? LucideIcons.inbox,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误状态组件
class CustomErrorWidget extends StatelessWidget {
  final String message;
  final String? description;
  final VoidCallback? onRetry;
  final IconData? icon;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.description,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? LucideIcons.alertCircle,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3ECC7A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}