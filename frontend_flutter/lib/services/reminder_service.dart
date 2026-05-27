import '../../shared/domain/models/api_response.dart';
import '../../shared/domain/models/reminder_model.dart';
import '../../core/services/notification_service.dart';

class ReminderService {
  final NotificationService _notificationService = NotificationService();

  Future<ApiResponse<List<ReminderRecord>>> getReminders() async {
    try {
      final records = await ReminderStorage.loadAll();
      return ApiResponse<List<ReminderRecord>>.success(
        message: '获取提醒列表成功',
        data: records,
      );
    } catch (e) {
      return ApiResponse<List<ReminderRecord>>.failure(
        message: '获取提醒列表失败: $e',
      );
    }
  }

  Future<ApiResponse<ReminderRecord>> addReminder(ReminderRecord record) async {
    try {
      await ReminderStorage.add(record);
      if (record.isEnabled) {
        await _scheduleNotification(record);
      }
      return ApiResponse<ReminderRecord>.success(
        message: '添加提醒成功',
        data: record,
      );
    } catch (e) {
      return ApiResponse<ReminderRecord>.failure(
        message: '添加提醒失败: $e',
      );
    }
  }

  Future<ApiResponse<ReminderRecord>> updateReminder(ReminderRecord record) async {
    try {
      await ReminderStorage.update(record);
      final idHash = record.id.hashCode;
      await _notificationService.cancelReminder(idHash);
      if (record.isEnabled) {
        await _scheduleNotification(record);
      }
      return ApiResponse<ReminderRecord>.success(
        message: '更新提醒成功',
        data: record,
      );
    } catch (e) {
      return ApiResponse<ReminderRecord>.failure(
        message: '更新提醒失败: $e',
      );
    }
  }

  Future<ApiResponse<void>> deleteReminder(String id) async {
    try {
      await _notificationService.cancelReminder(id.hashCode);
      await ReminderStorage.delete(id);
      return ApiResponse<void>.success(message: '删除提醒成功');
    } catch (e) {
      return ApiResponse<void>.failure(message: '删除提醒失败: $e');
    }
  }

  Future<ApiResponse<void>> toggleReminder(String id, bool enabled) async {
    try {
      await ReminderStorage.toggleEnabled(id, enabled);
      final records = await ReminderStorage.loadAll();
      final record = records.where((r) => r.id == id).firstOrNull;
      if (record != null) {
        final idHash = id.hashCode;
        if (enabled) {
          await _scheduleNotification(record);
        } else {
          await _notificationService.cancelReminder(idHash);
        }
      }
      return ApiResponse<void>.success(
        message: enabled ? '已开启提醒' : '已关闭提醒',
      );
    } catch (e) {
      return ApiResponse<void>.failure(message: '切换提醒状态失败: $e');
    }
  }

  Future<void> rescheduleAllReminders() async {
    try {
      await _notificationService.cancelAllReminders();
      final records = await ReminderStorage.loadAll();
      for (final record in records) {
        if (record.isEnabled) {
          await _scheduleNotification(record);
        }
      }
    } catch (e) {
      throw Exception('重新调度提醒失败: $e');
    }
  }

  Future<void> _scheduleNotification(ReminderRecord record) async {
    final idHash = record.id.hashCode;
    final title = record.title;
    final body = record.message ?? ReminderType.getLabel(record.type);

    await _notificationService.scheduleReminder(
      id: idHash,
      title: title,
      body: body,
      hour: record.hour,
      minute: record.minute,
      repeatDays: record.repeatDays,
    );
  }
}
