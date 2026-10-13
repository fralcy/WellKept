/// One OS notification to schedule — fully resolved (text already
/// localized, time already absolute) by `ReminderPlannerService`, so the
/// platform notification service only has to hand it to the OS.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.itemId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  /// Notification id, unique within one scheduling pass.
  final int id;
  final String itemId;
  final String title;
  final String body;

  /// Local date-time to fire at.
  final DateTime fireAt;

  @override
  String toString() => 'ScheduledReminder($id, $title, $body, $fireAt)';
}
