import '../models/scheduled_reminder.dart';

/// Shared shape implemented identically by `notification_service_stub.dart`,
/// `_io.dart`, and `_web.dart`. `NotificationService` itself can't be a
/// single class (each platform file defines its own, picked by conditional
/// export), so this interface exists so `NotificationProvider` can depend
/// on a testable type instead of the concrete platform singleton.
abstract class NotificationServiceBase {
  Future<void> init();

  /// Asks the OS for permission to show notifications; true if granted
  /// (or not needed on this platform).
  Future<bool> requestPermission();

  /// Cancels everything previously scheduled and schedules [reminders]
  /// instead — callers always pass the complete set.
  Future<void> replaceAll(
    List<ScheduledReminder> reminders, {
    required String channelName,
    required String channelDescription,
  });

  /// Item ids of reminders the user taps while the app is running.
  Stream<String> get tappedItemIds;

  /// The item id of the reminder whose tap launched the app from closed,
  /// if that's how it was started; null otherwise.
  Future<String?> launchItemId();
}
