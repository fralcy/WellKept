import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/l10n/app_localizations.dart';
import 'package:well_kept/core/models/scheduled_reminder.dart';
import 'package:well_kept/core/utils/due_calculator_service.dart';
import 'package:well_kept/core/utils/reminder_planner_service.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  const planner = ReminderPlannerService();
  const calc = DueCalculatorService();
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 10, 13, 9, 30);

  List<ScheduledReminder> plan(
    List<TrackedItem> items, {
    int hour = 8,
    int minute = 0,
    AppLocalizations? l10n,
  }) => planner.plan(
    items: items,
    statusFor: (item) => calc.calculate(item, const [], today: now),
    hour: hour,
    minute: minute,
    l10n: l10n ?? vi,
    now: now,
  );

  TrackedItem byTime(
    String id, {
    required DateTime start,
    int interval = 30,
    int lead = 7,
  }) => TrackedItem(
    id: id,
    name: 'Item $id',
    recurrenceType: RecurrenceType.byTime,
    recurrenceIntervalDays: interval,
    purchaseDate: start,
    reminderLeadDays: lead,
  );

  test('schedules a lead reminder and a due-day reminder at the set time', () {
    // Due 2026-11-12; lead 7 → 2026-11-05.
    final reminders = plan(
      [byTime('a', start: DateTime(2026, 10, 13))],
      hour: 19,
      minute: 15,
    );

    expect(reminders.map((r) => r.fireAt), [
      DateTime(2026, 11, 5, 19, 15),
      DateTime(2026, 11, 12, 19, 15),
    ]);
    expect(reminders.first.title, 'Item a');
    expect(reminders.first.itemId, 'a');
    expect(reminders.first.body, 'Còn 7 ngày tới hạn bảo trì (12/11/2026)');
    expect(reminders.last.body, 'Hôm nay tới hạn bảo trì');
  });

  test('warranties use the expiry wording', () {
    final reminders = plan([
      TrackedItem(
        id: 'tv',
        name: 'Tivi',
        recurrenceType: RecurrenceType.once,
        expiryDate: DateTime(2026, 12, 1),
        reminderLeadDays: 30,
      ),
    ], l10n: en);

    expect(reminders.map((r) => r.body), [
      'Warranty ends in 30 days (Dec 1, 2026)',
      'Warranty ends today',
    ]);
    expect(reminders.first.fireAt, DateTime(2026, 11, 1, 8));
  });

  test('skips reminder times already in the past', () {
    // Due in 3 days with a 7-day lead: the lead reminder's time has passed.
    final soon = plan([
      byTime('a', start: DateTime(2026, 9, 16)), // due 2026-10-16
    ]);
    expect(soon.map((r) => r.fireAt), [DateTime(2026, 10, 16, 8)]);

    // Due today, but the 08:00 reminder time is already past (now 09:30).
    final dueTodayEarly = plan([byTime('b', start: DateTime(2026, 9, 13))]);
    expect(dueTodayEarly, isEmpty);

    // Due today and the reminder time is still ahead.
    final dueTodayLate = plan([
      byTime('c', start: DateTime(2026, 9, 13)),
    ], hour: 18);
    expect(dueTodayLate.map((r) => r.fireAt), [DateTime(2026, 10, 13, 18)]);
  });

  test('overdue items get no reminders', () {
    expect(plan([byTime('a', start: DateTime(2026, 1, 1))]), isEmpty);
  });

  test('a lead of 0 days means only the due-day reminder', () {
    final reminders = plan([
      byTime('a', start: DateTime(2026, 10, 13), lead: 0),
    ]);
    expect(reminders, hasLength(1));
    expect(reminders.single.fireAt, DateTime(2026, 11, 12, 8));
  });

  test('value-based and no-reminder items are never scheduled', () {
    expect(
      plan([
        TrackedItem(
          id: 'bike',
          name: 'Xe',
          recurrenceType: RecurrenceType.byValue,
          recurrenceIntervalValue: 2000,
          currentValue: 1000,
        ),
        TrackedItem(id: 'n', name: 'n'),
      ]),
      isEmpty,
    );
  });

  test('sorted soonest first, ids sequential, capped at maxReminders', () {
    final items = [
      for (var i = 0; i < 40; i++)
        byTime('$i', start: DateTime(2026, 10, 13), interval: 40 - i),
    ];
    final reminders = plan(items);

    expect(reminders, hasLength(ReminderPlannerService.maxReminders));
    expect(reminders.map((r) => r.id), [
      for (var i = 0; i < ReminderPlannerService.maxReminders; i++) i,
    ]);
    for (var i = 1; i < reminders.length; i++) {
      expect(reminders[i].fireAt.isBefore(reminders[i - 1].fireAt), isFalse);
    }
  });
}
