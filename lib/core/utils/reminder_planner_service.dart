import '../../models/tracked_item.dart';
import '../l10n/app_localizations.dart';
import '../models/due_status.dart';
import '../models/scheduled_reminder.dart';
import 'item_labels.dart';

/// Pure Dart: which reminders to schedule, when, and with what text. The
/// platform notification service just hands the result to the OS.
///
/// Only date-based due points (`byTime`, `once`) get reminders — the app
/// can't read an odometer, so a `byValue` item can't know when it's due.
class ReminderPlannerService {
  const ReminderPlannerService();

  /// iOS keeps at most 64 pending local notifications per app and silently
  /// drops the rest — stay under it, keeping the soonest ones. Rescheduling
  /// on every data change/app start tops the queue back up over time.
  static const int maxReminders = 60;

  /// For each date-based item: one reminder `reminderLeadDays` before the
  /// due date and one on the due date itself, both at [hour]:[minute]
  /// local time. Reminders whose time has already passed are skipped, so
  /// an overdue item gets none (its card already says so).
  List<ScheduledReminder> plan({
    required List<TrackedItem> items,
    required DueStatus Function(TrackedItem item) statusFor,
    required int hour,
    required int minute,
    required AppLocalizations l10n,
    required DateTime now,
  }) {
    final drafts = <_Draft>[];

    for (final item in items) {
      final status = statusFor(item);
      final dueDate = status.nextDueDate;
      final isDateBased =
          status.type == RecurrenceType.byTime ||
          status.type == RecurrenceType.once;
      if (!isDateBased || dueDate == null) continue;

      final isWarranty = status.type == RecurrenceType.once;
      final dateText = formatDate(l10n, dueDate);

      final onDueDay = _at(dueDate, 0, hour, minute);
      if (onDueDay.isAfter(now)) {
        drafts.add(
          _Draft(
            item,
            isWarranty ? l10n.notifExpiresToday : l10n.notifDueToday,
            onDueDay,
          ),
        );
      }

      final lead = item.reminderLeadDays;
      if (lead > 0) {
        final before = _at(dueDate, -lead, hour, minute);
        if (before.isAfter(now)) {
          drafts.add(
            _Draft(
              item,
              isWarranty
                  ? l10n.notifExpiresInDays(lead, dateText)
                  : l10n.notifDueInDays(lead, dateText),
              before,
            ),
          );
        }
      }
    }

    drafts.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return [
      for (var i = 0; i < drafts.length && i < maxReminders; i++)
        ScheduledReminder(
          id: i,
          itemId: drafts[i].item.id,
          title: drafts[i].item.name,
          body: drafts[i].body,
          fireAt: drafts[i].fireAt,
        ),
    ];
  }

  /// [day] shifted by [dayOffset] calendar days, at [hour]:[minute] local —
  /// via the DateTime constructor so DST can't shift the wall-clock time.
  static DateTime _at(DateTime day, int dayOffset, int hour, int minute) =>
      DateTime(day.year, day.month, day.day + dayOffset, hour, minute);
}

class _Draft {
  _Draft(this.item, this.body, this.fireAt);

  final TrackedItem item;
  final String body;
  final DateTime fireAt;
}
