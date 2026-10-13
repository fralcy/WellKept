import '../models/scheduled_reminder.dart';
import 'notification_service_base.dart';

/// Fallback implementation selected when neither `dart.library.io` nor
/// `dart.library.js_interop` applies. Flutter always has one of the two,
/// so this exists only to keep the conditional export exhaustive.
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
