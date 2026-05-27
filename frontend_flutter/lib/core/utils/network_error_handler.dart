import 'package:flutter/material.dart';

/// 网络错误处理器
class NetworkErrorHandler {
  /// 显示错误信息
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 显示成功信息
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 显示信息
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 显示警告
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// 处理API错误
  static void handleApiError(
    BuildContext context, 
    dynamic error, {
    VoidCallback? onRetry,
  }) {
    String message = parseErrorMessage(error);
    
    if (onRetry != null) {
      showErrorDialog(
        context,
        title: '请求失败',
        message: message,
        actionText: '重试',
        onAction: onRetry,
      );
    } else {
      showError(context, message);
    }
  }

  /// 解析错误消息
  static String parseErrorMessage(dynamic error) {
    if (error is String) {
      return error;
    }
    
    if (error is Map<String, dynamic>) {
      return error['message'] ?? error['error'] ?? '未知错误';
    }
    
    return error?.toString() ?? '未知错误';
  }

  /// 显示错误对话框
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionText),
            ),
        ],
      ),
    );
  }
}