import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/scheduled_reminder.dart';
import 'notification_service_base.dart';

/// Mobile reminder scheduling via `flutter_local_notifications`. Each
/// reminder is a plain one-time notification at an absolute instant —
/// `ReminderPlannerService` already resolved every date, so no OS-side
/// recurrence is needed.
class NotificationService implements NotificationServiceBase {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'wellkept_reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    const darwinSettings = DarwinInitializationSettings(
      // Asked for later, only once there's something to remind about —
      // see NotificationProvider.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwinSettings,
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    if (Platform.isAndroid) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledReminder> reminders, {
    required String channelName,
    required String channelDescription,
  }) async {
    if (!_initialized) return;
    await _plugin.cancelAll();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        // fireAt is a local wall-clock time; converting it to an instant
        // in UTC avoids needing the device's IANA zone name. Reminders are
        // re-planned on every app start, so a DST change in between only
        // ever shifts not-yet-replanned reminders by an hour.
        tz.TZDateTime.from(reminder.fireAt, tz.UTC),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminder.itemId,
      );
    }
  }
}
