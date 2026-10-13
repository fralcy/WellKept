import '../models/scheduled_reminder.dart';
import 'notification_service_base.dart';

/// Web has no reliable background-notification story (a closed tab can't
/// fire a local notification), so nothing is scheduled here — the settings
/// screen tells web users to use the phone app for reminders, and the item
/// list itself already shows what's due.
class NotificationService implements NotificationServiceBase {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(
    List<ScheduledReminder> reminders, {
    required String channelName,
    required String channelDescription,
  }) async {}
}
