import '../../shared/domain/models/api_response.dart';
import '../../shared/domain/models/reminder_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/api_service.dart';

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

  Future<ApiResponse<ReminderRecord>> updateReminder(
      ReminderRecord record) async {
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
      reminderType: record.type,
    );
  }

  // ==================== 后端 API 方法 ====================

  final ApiService _apiService = ApiService();

  /// 向后端创建提醒
  Future<ApiResponse<Map<String, dynamic>>> createRemoteReminder({
    required int reminderType,
    required String title,
    required int hour,
    required int minute,
    List<int>? repeatDays,
    String? message,
    bool isEnabled = true,
  }) async {
    try {
      final data = {
        'reminder_type': reminderType,
        'title': title,
        'hour': hour,
        'minute': minute,
        'is_enabled': isEnabled,
        if (repeatDays != null) 'repeat_days': repeatDays,
        if (message != null) 'message': message,
      };

      final response = await _apiService.post('/reminders/', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '创建提醒成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '创建提醒失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '创建提醒失败: $e',
      );
    }
  }

  /// 从后端获取提醒列表
  Future<ApiResponse<List<Map<String, dynamic>>>> getRemoteReminders({
    String? reminderType,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (reminderType != null) queryParams['reminder_type'] = reminderType;

      final response = await _apiService.get(
        '/reminders/',
        queryParameters: queryParams,
      );

      if (response.success && response.data != null) {
        final List<dynamic> dataList = response.data as List;
        final reminders =
            dataList.map((e) => e as Map<String, dynamic>).toList();
        return ApiResponse<List<Map<String, dynamic>>>.success(
          message: response.message.isNotEmpty ? response.message : '获取提醒列表成功',
          data: reminders,
        );
      }
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取提醒列表失败',
      );
    } catch (e) {
      return ApiResponse<List<Map<String, dynamic>>>.failure(
        message: '获取提醒列表失败: $e',
      );
    }
  }

  /// 从后端获取单个提醒详情
  Future<ApiResponse<Map<String, dynamic>>> getRemoteReminder(
      int reminderId) async {
    try {
      final response = await _apiService.get('/reminders/$reminderId');

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '获取提醒详情成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '获取提醒详情失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '获取提醒详情失败: $e',
      );
    }
  }

  /// 更新后端提醒
  Future<ApiResponse<Map<String, dynamic>>> updateRemoteReminder({
    required int reminderId,
    int? reminderType,
    String? title,
    int? hour,
    int? minute,
    List<int>? repeatDays,
    String? message,
    bool? isEnabled,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (reminderType != null) data['reminder_type'] = reminderType;
      if (title != null) data['title'] = title;
      if (hour != null) data['hour'] = hour;
      if (minute != null) data['minute'] = minute;
      if (repeatDays != null) data['repeat_days'] = repeatDays;
      if (message != null) data['message'] = message;
      if (isEnabled != null) data['is_enabled'] = isEnabled;

      final response =
          await _apiService.put('/reminders/$reminderId', data: data);

      if (response.success && response.data != null) {
        return ApiResponse<Map<String, dynamic>>.success(
          message: response.message.isNotEmpty ? response.message : '更新提醒成功',
          data: response.data as Map<String, dynamic>,
        );
      }
      return ApiResponse<Map<String, dynamic>>.failure(
        message: response.message.isNotEmpty ? response.message : '更新提醒失败',
      );
    } catch (e) {
      return ApiResponse<Map<String, dynamic>>.failure(
        message: '更新提醒失败: $e',
      );
    }
  }

  /// 删除后端提醒
  Future<ApiResponse<void>> deleteRemoteReminder(int reminderId) async {
    try {
      final response = await _apiService.delete('/reminders/$reminderId');

      if (response.success) {
        return ApiResponse<void>.success(
          message: response.message.isNotEmpty ? response.message : '删除提醒成功',
        );
      }
      return ApiResponse<void>.failure(
        message: response.message.isNotEmpty ? response.message : '删除提醒失败',
      );
    } catch (e) {
      return ApiResponse<void>.failure(
        message: '删除提醒失败: $e',
      );
    }
  }
}
